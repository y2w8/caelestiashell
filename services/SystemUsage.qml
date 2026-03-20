pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // CPU properties
    property string cpuName: ""
    property real cpuPerc
    property real cpuTemp

    // GPU properties
    readonly property string gpuType: Config.services.gpuType.toUpperCase() || autoGpuType
    property string autoGpuType: "NONE"
    property string gpuName: ""
    property real gpuPerc
    property real gpuTemp

    // Memory properties
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0

    // Storage properties (aggregated from lsblk-based disks)
    readonly property real storagePerc: {
        let totalUsed = 0;
        let totalSize = 0;
        for (const disk of disks) {
            totalUsed += disk.used;
            totalSize += disk.total;
        }
        return totalSize > 0 ? totalUsed / totalSize : 0;
    }

    // lsblk-based disks (existing, untouched)
    property var disks: []

    // df-based mount points for StorageDiskCard
    property var mountedDisks: []

    property real lastCpuIdle
    property real lastCpuTotal

    property int refCount

    function cleanCpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|CPU|\d+(?:th|nd|rd|st) Gen |Core |Processor/gi, "").replace(/\s+/g, " ").trim();
    }

    function cleanGpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|Graphics/gi, "").replace(/\s+/g, " ").trim();
    }

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    Timer {
        running: root.refCount > 0
        interval: Config.dashboard.resourceUpdateInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            storage.running = true;
            mountedStorage.running = true;
            gpuUsage.running = true;
            sensors.running = true;
        }
    }

    // One-time CPU info detection (name)
    FileView {
        id: cpuinfoInit

        path: "/proc/cpuinfo"
        onLoaded: {
            const nameMatch = text().match(/model name\s*:\s*(.+)/);
            if (nameMatch)
                root.cpuName = root.cleanCpuName(nameMatch[1]);
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const data = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (data) {
                const stats = data.slice(1).map(n => parseInt(n, 10));
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3] + (stats[4] ?? 0);

                const totalDiff = total - root.lastCpuTotal;
                const idleDiff = idle - root.lastCpuIdle;
                root.cpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            root.memTotal = parseInt(data.match(/MemTotal: *(\d+)/)[1], 10) || 1;
            root.memUsed = (root.memTotal - parseInt(data.match(/MemAvailable: *(\d+)/)[1], 10)) || 0;
        }
    }

    Process {
        id: storage

        command: ["lsblk", "-b", "-o", "NAME,SIZE,TYPE,FSUSED,FSSIZE", "-P"]
        stdout: StdioCollector {
            onStreamFinished: {
                const diskMap = {};
                const lines = text.trim().split("\n");

                // Helper to recursively sum usage from children (partitions, crypt, lvm)
                const aggregateUsage = dev => {
                    let used = 0;
                    let size = 0;
                    let isRoot = dev.mountpoint === "/" || (dev.mountpoints && dev.mountpoints.includes("/"));

                    const nameMatch = line.match(/NAME="([^"]+)"/);
                    const sizeMatch = line.match(/SIZE="([^"]+)"/);
                    const typeMatch = line.match(/TYPE="([^"]+)"/);
                    const fsusedMatch = line.match(/FSUSED="([^"]*)"/);
                    const fssizeMatch = line.match(/FSSIZE="([^"]*)"/);

                    if (dev.children) {
                        for (const child of dev.children) {
                            const stats = aggregateUsage(child);
                            used += stats.used;
                            size += stats.size;
                            if (stats.isRoot)
                                isRoot = true;
                        }
                    }
                    return {
                        used,
                        size,
                        isRoot
                    };
                };

                for (const dev of data.blockdevices) {
                    // Only process physical disks at the top level
                    if (dev.type === "disk" && !dev.name.startsWith("zram")) {
                        const stats = aggregateUsage(dev);

                    if (type === "disk") {
                        if (name.startsWith("zram"))
                            continue;

                        if (!diskMap[name]) {
                            diskMap[name] = {
                                name: name,
                                totalSize: size,
                                used: 0,
                                fsTotal: 0
                            };
                        }
                    } else if (type === "part") {
                        let parentDisk = name.replace(/p?\d+$/, "");
                        if (name.match(/nvme\d+n\d+p\d+/))
                            parentDisk = name.replace(/p\d+$/, "");

                        if (diskMap[parentDisk]) {
                            diskMap[parentDisk].used += fsused;
                            diskMap[parentDisk].fsTotal += fssize;
                        }
                    }
                }

                const diskList = [];
                for (const diskName of Object.keys(diskMap).sort()) {
                    const disk = diskMap[diskName];
                    const total = disk.fsTotal > 0 ? disk.fsTotal : disk.totalSize;
                    const used = disk.used;
                    const perc = total > 0 ? used / total : 0;

                    diskList.push({
                        mount: disk.name,
                        used: used / 1024,
                        total: total / 1024,
                        free: (total - used) / 1024,
                        perc: perc
                    });
                }

                root.disks = diskList;
            }
        }
    }

    // Mount-point based storage for StorageDiskCard
    // Uses df to get real mount points (/, /home, /boot etc.)
    // Kept separate from `disks` so nothing else breaks
    Process {
        id: mountedStorage

        // Plain df with no fancy --output flag for maximum compatibility
        // Columns: Filesystem  1K-blocks  Used  Available  Use%  Mounted-on
        command: ["df", "-k"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const result = [];

                for (let i = 1; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line)
                        continue;

                    // df -k columns: Filesystem 1K-blocks Used Available Use% Mountpoint
                    // Some lines wrap (long fs name), handle by joining with next line
                    const parts = line.split(/\s+/);
                    if (parts.length < 6)
                        continue;

                    // Mount point is always the last column
                    const mount = parts[parts.length - 1];
                    const total = parseInt(parts[parts.length - 5], 10) || 0;
                    const used = parseInt(parts[parts.length - 4], 10) || 0;
                    const free = parseInt(parts[parts.length - 3], 10) || 0;
                    const perc = total > 0 ? used / total : 0;

                    // Skip pseudo/kernel/snap filesystems
                    const fs = parts[0];
                    if (fs.startsWith("tmpfs") ||
                        fs.startsWith("devtmpfs") ||
                        fs.startsWith("udev") ||
                        fs.startsWith("overlay") ||
                        fs === "none" ||
                        fs.startsWith("/dev/loop") ||
                        fs.startsWith("squashfs"))
                        continue;

                    // Skip non-real mount paths
                    if (mount.startsWith("/dev") ||
                        mount.startsWith("/sys") ||
                        mount.startsWith("/proc") ||
                        mount.startsWith("/run") ||
                        mount.startsWith("/snap"))
                        continue;

                    // Skip zero-size entries
                    if (total === 0)
                        continue;

                    result.push({ mount, used, total, free, perc });
                }

                root.mountedDisks = result;
            }
        }
    }

    // GPU name detection (one-time)
    Process {
        id: gpuNameDetect

        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || glxinfo -B 2>/dev/null | grep 'Device:' | cut -d':' -f2 | cut -d'(' -f1 || lspci 2>/dev/null | grep -i 'vga\\|3d controller\\|display' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (!output)
                    return;

                if (output.toLowerCase().includes("nvidia") || output.toLowerCase().includes("geforce") || output.toLowerCase().includes("rtx") || output.toLowerCase().includes("gtx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else if (output.toLowerCase().includes("rx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else {
                    const bracketMatch = output.match(/\[([^\]]+)\]/);
                    if (bracketMatch) {
                        root.gpuName = root.cleanGpuName(bracketMatch[1]);
                    } else {
                        const colonMatch = output.match(/:\s*(.+)/);
                        if (colonMatch)
                            root.gpuName = root.cleanGpuName(colonMatch[1]);
                    }
                }
            }
        }
    }

    Process {
        id: gpuTypeCheck

        running: !Config.services.gpuType
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.autoGpuType = text.trim()
        }
    }

    Process {
        id: gpuUsage

        command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gpuType === "GENERIC") {
                    const percs = text.trim().split("\n");
                    const sum = percs.reduce((acc, d) => acc + parseInt(d, 10), 0);
                    root.gpuPerc = sum / percs.length / 100;
                } else if (root.gpuType === "NVIDIA") {
                    const [usage, temp] = text.trim().split(",");
                    root.gpuPerc = parseInt(usage, 10) / 100;
                    root.gpuTemp = parseInt(temp, 10);
                } else {
                    root.gpuPerc = 0;
                    root.gpuTemp = 0;
                }
            }
        }
    }

    Process {
        id: sensors

        command: ["sensors"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                let cpuTemp = text.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/);
                if (!cpuTemp)
                    cpuTemp = text.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/);

                if (cpuTemp)
                    root.cpuTemp = parseFloat(cpuTemp[1]);

                if (root.gpuType !== "GENERIC")
                    return;

                let eligible = false;
                let sum = 0;
                let count = 0;

                for (const line of text.trim().split("\n")) {
                    if (line === "Adapter: PCI adapter")
                        eligible = true;
                    else if (line === "")
                        eligible = false;
                    else if (eligible) {
                        let match = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
                        if (!match)
                            match = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);

                        if (match) {
                            sum += parseFloat(match[2]);
                            count++;
                        }
                    }
                }

                root.gpuTemp = count > 0 ? sum / count : 0;
            }
        }
    }
}
