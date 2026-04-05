import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Internal
import qs.components
import qs.components.misc
import qs.services
import qs.config

Item {
    id: root

    readonly property int minWidth: 400 + 400 + Appearance.spacing.normal + 120 + Appearance.padding.large * 2

    function displayTemp(temp: real): string {
        return `${Math.ceil(Config.services.useFahrenheitPerformance ? temp * 1.8 + 32 : temp)}°${Config.services.useFahrenheitPerformance ? "F" : "C"}`;
    }

    implicitWidth: Math.max(minWidth, content.implicitWidth)
    implicitHeight: placeholder.visible ? placeholder.height : content.implicitHeight

    StyledRect {
        id: placeholder

        anchors.centerIn: parent
        width: 400
        height: 350
        radius: Appearance.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        visible: !Config.dashboard.performance.showCpu && !(Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE") && !Config.dashboard.performance.showMemory && !Config.dashboard.performance.showStorage && !Config.dashboard.performance.showNetwork && !(UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "tune"
                font.pointSize: Appearance.font.size.extraLarge * 2
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No widgets enabled")
                font.pointSize: Appearance.font.size.large
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Enable widgets in dashboard settings")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.normal
        visible: !placeholder.visible

        Ref {
            service: SystemUsage
        }

        ColumnLayout {
            id: mainColumn

            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal
                visible: Config.dashboard.performance.showCpu || (Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE")

                HeroCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 400
                    Layout.preferredHeight: 150
                    visible: Config.dashboard.performance.showCpu
                    icon: "memory"
                    title: SystemUsage.cpuName ? `${SystemUsage.cpuName}` : qsTr("CPU")
                    mainValue: `${Math.round(SystemUsage.cpuPerc * 100)}%`
                    mainLabel: qsTr("Usage")
                    secondaryValue: root.displayTemp(SystemUsage.cpuTemp)
                    secondaryLabel: qsTr("Temp")
                    usage: SystemUsage.cpuPerc
                    temperature: SystemUsage.cpuTemp
                    accentColor: Colours.palette.m3blue
                }

                HeroCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 400
                    Layout.preferredHeight: 150
                    visible: Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE"
                    icon: "desktop_windows"
                    title: SystemUsage.gpuName ? `${SystemUsage.gpuName}` : qsTr("GPU")
                    mainValue: `${Math.round(SystemUsage.gpuPerc * 100)}%`
                    mainLabel: qsTr("Usage")
                    secondaryValue: root.displayTemp(SystemUsage.gpuTemp)
                    secondaryLabel: qsTr("Temp")
                    usage: SystemUsage.gpuPerc
                    temperature: SystemUsage.gpuTemp
                    accentColor: Colours.palette.m3green
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal
                visible: Config.dashboard.performance.showMemory || Config.dashboard.performance.showStorage || Config.dashboard.performance.showNetwork

                GaugeCard {
                    Layout.minimumWidth: 250
                    Layout.preferredHeight: 220
                    Layout.fillWidth: !Config.dashboard.performance.showStorage && !Config.dashboard.performance.showNetwork
                    icon: "memory_alt"
                    title: qsTr("Memory")
                    percentage: SystemUsage.memPerc
                    subtitle: {
                        const usedFmt = SystemUsage.formatKib(SystemUsage.memUsed);
                        const totalFmt = SystemUsage.formatKib(SystemUsage.memTotal);
                        return `${usedFmt.value.toFixed(1)} / ${Math.floor(totalFmt.value)} ${totalFmt.unit}`;
                    }
                    accentColor: Colours.palette.m3error
                    visible: Config.dashboard.performance.showMemory
                }

                StorageDiskCard {
                    Layout.minimumWidth: 400
                    Layout.preferredHeight: 220
                    Layout.fillWidth: !Config.dashboard.performance.showNetwork
                    visible: Config.dashboard.performance.showStorage
                }

                NetworkCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.preferredHeight: 220
                    visible: Config.dashboard.performance.showNetwork
                }
            }
        }
    }

    // ── Shared sub-components ────────────────────────────────────────────────

    component CardHeader: RowLayout {
        property string icon
        property string title
        property color accentColor: Colours.palette.m3primary

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        MaterialIcon {
            text: parent.icon
            fill: 1
            color: parent.accentColor
            font.pointSize: Appearance.spacing.large
        }

        StyledText {
            Layout.fillWidth: true
            text: parent.title
            font.pointSize: Appearance.font.size.normal
            elide: Text.ElideRight
        }
    }

    component ProgressBar: StyledRect {
        id: progressBar

        property real value: 0
        property color fgColor: Colours.palette.m3primary
        property color bgColor: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        property real animatedValue: 0

        color: bgColor
        radius: Appearance.rounding.full
        Component.onCompleted: animatedValue = value
        onValueChanged: animatedValue = value

        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * progressBar.animatedValue
            color: progressBar.fgColor
            radius: Appearance.rounding.full
        }

        Behavior on animatedValue {
            Anim {
                duration: Appearance.anim.durations.large
            }
        }
    }

    // Disk progress bar — identical to ProgressBar but named separately
    // to avoid any future conflicts if ProgressBar gains new properties
    component DiskProgressBar: StyledRect {
        id: diskProgressBar

        property real value: 0
        property color fgColor: Colours.palette.m3secondary
        property color bgColor: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        property real animatedValue: 0

        color: bgColor
        radius: Appearance.rounding.full
        Component.onCompleted: animatedValue = value
        onValueChanged: animatedValue = value

        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * diskProgressBar.animatedValue
            color: diskProgressBar.fgColor
            radius: Appearance.rounding.full
        }

        Behavior on animatedValue {
            Anim {
                duration: Appearance.anim.durations.large
            }
        }
    }

    component HeroCard: StyledClippingRect {
        id: heroCard

        property string icon
        property string title
        property string mainValue
        property string mainLabel
        property string secondaryValue
        property string secondaryLabel
        property real usage: 0
        property real temperature: 0
        property color accentColor: Colours.palette.m3primary
        readonly property real maxTemp: 100
        readonly property real tempProgress: Math.min(1, Math.max(0, temperature / maxTemp))
        property real animatedUsage: 0
        property real animatedTemp: 0

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large
        Component.onCompleted: {
            animatedUsage = usage;
            animatedTemp = tempProgress;
        }
        onUsageChanged: animatedUsage = usage
        onTempProgressChanged: animatedTemp = tempProgress

        // StyledRect {
        //     anchors.left: parent.left
        //     anchors.top: parent.top
        //     anchors.bottom: parent.bottom
        //     implicitWidth: parent.width * heroCard.animatedUsage
        //     color: Qt.alpha(heroCard.accentColor, 0.15)
        // }

        CardHeader {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Appearance.padding.large
            anchors.topMargin: Math.round(Appearance.padding.large * 1.2)

            width: parent.width - anchors.leftMargin - usageColumn.anchors.rightMargin - usageLabel.width - Appearance.spacing.normal
            icon: heroCard.icon
            title: heroCard.title
            accentColor: heroCard.accentColor
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(Appearance.padding.large * 1.2)
            anchors.bottomMargin: Math.round(Appearance.padding.large * 1.3)

            spacing: Appearance.spacing.small

            Row {
                spacing: Appearance.spacing.small

                StyledText {
                    text: heroCard.secondaryValue
                    color: heroCard.temperature >= 80 ? Colours.palette.m3error : heroCard.temperature >= 60 ? Colours.palette.m3yellow : Colours.palette.m3onBackground
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Medium
                }

                StyledText {
                    text: heroCard.secondaryLabel
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    anchors.baseline: parent.children[0].baseline
                }
            }

            ProgressBar {
                implicitWidth: parent.width * 0.5
                implicitHeight: 6
                value: heroCard.animatedUsage
                fgColor: heroCard.accentColor
                bgColor: Qt.alpha(heroCard.accentColor, 0.2)
            }
        }

        Column {
            id: usageColumn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large
            anchors.rightMargin: 32
            spacing: 0

            StyledText {
                id: usageLabel

                anchors.right: parent.right
                text: heroCard.mainLabel
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                anchors.right: parent.right
                text: heroCard.mainValue
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: Font.Medium
                color: heroCard.accentColor
            }
        }

        Behavior on animatedUsage {
            Anim {
                duration: Appearance.anim.durations.large
            }
        }

        Behavior on animatedTemp {
            Anim {
                duration: Appearance.anim.durations.large
            }
        }
    }

    component GaugeCard: StyledRect {
        id: gaugeCard

        property string icon
        property string title
        property real percentage: 0
        property string subtitle
        property color accentColor: Colours.palette.m3primary
        readonly property real arcStartAngle: 0.75 * Math.PI
        readonly property real arcSweep: 1.5 * Math.PI
        property real animatedPercentage: 0

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large
        clip: true
        Component.onCompleted: animatedPercentage = percentage
        onPercentageChanged: animatedPercentage = percentage

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.smaller

            CardHeader {
                icon: gaugeCard.icon
                title: gaugeCard.title
                accentColor: gaugeCard.accentColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ArcGauge {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    percentage: gaugeCard.animatedPercentage
                    accentColor: gaugeCard.accentColor
                    trackColor: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                    startAngle: gaugeCard.arcStartAngle
                    sweepAngle: gaugeCard.arcSweep
                }

                StyledText {
                    anchors.centerIn: parent
                    text: `${Math.round(gaugeCard.percentage * 100)}%`
                    font.pointSize: Appearance.font.size.extraLarge
                    font.weight: Font.Medium
                    color: gaugeCard.accentColor
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: gaugeCard.subtitle
                font.pointSize: Appearance.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        Behavior on animatedPercentage {
            Anim {
                duration: Appearance.anim.durations.large
            }
        }
    }

    // ── New storage card: real mount points via df, 3 per page ───────────────
    component StorageDiskCard: StyledRect {
        id: storageDiskCard

        property int pageIndex: 0
        property color accentColor: Colours.palette.m3secondary

        readonly property var pageDiskList: {
            const all = SystemUsage.mountedDisks;
            if (!all || all.length === 0)
                return [];
            return all.slice(pageIndex * 3, pageIndex * 3 + 3);
        }

        readonly property int totalPages: Math.max(1, Math.ceil(SystemUsage.mountedDisks.length / 3))

        // Header title: mount of first entry on this page, e.g. "/"
        readonly property string cardTitle: pageDiskList.length > 0 ? pageDiskList[0].mount : qsTr("Storage")

        // Top-right: usage % of first entry on this page
        readonly property string topPerc: pageDiskList.length > 0 ? `${Math.round(pageDiskList[0].perc * 100)}%` : "—"

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large
        clip: true

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => {
                if (wheel.angleDelta.y < 0)
                    storageDiskCard.pageIndex = (storageDiskCard.pageIndex + 1) % storageDiskCard.totalPages;
                else
                    storageDiskCard.pageIndex = (storageDiskCard.pageIndex - 1 + storageDiskCard.totalPages) % storageDiskCard.totalPages;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.small

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                MaterialIcon {
                    text: "hard_disk"
                    fill: 1
                    color: storageDiskCard.accentColor
                    font.pointSize: Appearance.spacing.large
                }

                // Shows first mount on this page e.g. "/" or "/home"
                StyledText {
                    Layout.fillWidth: true
                    text: "nvme0n1"
                    font.pointSize: Appearance.font.size.normal
                    elide: Text.ElideRight
                }

                // Scroll hint — only when more than one page
                MaterialIcon {
                    text: "unfold_more"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.normal
                    visible: storageDiskCard.totalPages > 1
                    opacity: 0.7
                    ToolTip.visible: scrollHint.hovered
                    ToolTip.text: qsTr("Scroll to see more")
                    ToolTip.delay: 500

                    HoverHandler {
                        id: scrollHint
                    }
                }

                // Usage % of first mount on this page
                StyledText {
                    text: storageDiskCard.topPerc
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Medium
                    color: storageDiskCard.accentColor
                }
            }

            // Up to 3 disk rows per page
            Repeater {
                model: storageDiskCard.pageDiskList

                delegate: RowLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    // Left: label row + progress bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.mount
                                font.pointSize: Appearance.font.size.small
                                font.weight: Font.Medium
                                color: [
                                    Colours.palette.m3error,
                                    Colours.palette.m3tertiary,
                                    Colours.palette.m3blue
                                ][index % 3]
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: `${Math.round(modelData.perc * 100)}%`
                                font.pointSize: Appearance.font.size.small
                                font.weight: Font.Medium
                                color: [
                                    Colours.palette.m3error,
                                    Colours.palette.m3tertiary,
                                    Colours.palette.m3blue
                                ][index % 3]
                            }
                        }

                      DiskProgressBar {
                          Layout.fillWidth: true
                          height: 8
                          value: modelData.perc
                          fgColor: [
                              Colours.palette.m3error,
                              Colours.palette.m3tertiary,
                              Colours.palette.m3blue
                          ][index % 3]
                      }
                    }

                    // Right: used / total
                    ColumnLayout {
                        spacing: 2
                        Layout.minimumWidth: 90

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: {
                                const fmt = SystemUsage.formatKib(modelData.used);
                                return `${fmt.value.toFixed(1)} ${fmt.unit}`;
                            }
                            font.pointSize: Appearance.font.size.smaller
                            font.weight: Font.Medium
                            color: [
                                Colours.palette.m3error,
                                Colours.palette.m3tertiary,
                                Colours.palette.m3blue
                            ][index % 3]
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: {
                                const fmt = SystemUsage.formatKib(modelData.total);
                                return `/ ${Math.floor(fmt.value)} ${fmt.unit}`;
                            }
                            font.pointSize: Appearance.font.size.smaller
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            // Empty state — shown while df hasn't returned yet
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No disks found")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                visible: SystemUsage.mountedDisks.length === 0
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    component NetworkCard: StyledRect {
        id: networkCard

        property color accentColor: Colours.palette.m3primary

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large
        clip: true

        Ref {
            service: NetworkUsage
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.small

            CardHeader {
                icon: "swap_vert"
                title: qsTr("Network")
                accentColor: networkCard.accentColor
            }

            // Sparkline graph
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SparklineItem {
                    id: sparkline

                    property real targetMax: 1024
                    property real smoothMax: targetMax

                    anchors.fill: parent
                    line1: NetworkUsage.uploadBuffer // qmllint disable missing-type
                    line1Color: Colours.palette.m3teal
                    line1FillAlpha: 0.15
                    line2: NetworkUsage.downloadBuffer // qmllint disable missing-type
                    line2Color: Colours.palette.m3green
                    line2FillAlpha: 0.2
                    maxValue: smoothMax
                    historyLength: NetworkUsage.historyLength

                    Connections {
                        function onValuesChanged(): void {
                            sparkline.targetMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                            slideAnim.restart();
                        }

                        target: NetworkUsage.downloadBuffer
                    }

                    NumberAnimation {
                        id: slideAnim

                        target: sparkline
                        property: "slideProgress"
                        from: 0
                        to: 1
                        duration: Config.dashboard.resourceUpdateInterval
                    }

                    Behavior on smoothMax {
                        Anim {
                            duration: Appearance.anim.durations.large
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Collecting data...")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    visible: NetworkUsage.downloadBuffer.count < 2
                    opacity: 0.6
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "download"
                    color: Colours.palette.m3green
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    text: qsTr("Download")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: {
                        const fmt = NetworkUsage.formatBytes(NetworkUsage.downloadSpeed ?? 0);
                        return fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s";
                    }
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Medium
                    color: Colours.palette.m3green
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "upload"
                    color: Colours.palette.m3teal
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    text: qsTr("Upload")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: {
                        const fmt = NetworkUsage.formatBytes(NetworkUsage.uploadSpeed ?? 0);
                        return fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s";
                    }
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Medium
                    color: Colours.palette.m3teal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "history"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    text: qsTr("Total")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: {
                        const down = NetworkUsage.formatBytesTotal(NetworkUsage.downloadTotal ?? 0);
                        const up = NetworkUsage.formatBytesTotal(NetworkUsage.uploadTotal ?? 0);
                        return (down && up) ? `↓${down.value.toFixed(1)}${down.unit} ↑${up.value.toFixed(1)}${up.unit}` : "↓0.0B ↑0.0B";
                    }
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
