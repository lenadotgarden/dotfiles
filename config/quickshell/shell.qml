import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Io

PanelWindow {
    id: root

    screen: Quickshell.screens[0]

    // Anchored across top with exclusive height for notch area
    anchors {
        top: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: root.expanded ? 280 : 42

    implicitHeight: root.expanded ? 280 : 42
    color: "transparent"

    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
    }

    // Dynamic color properties (syncing pywal/catppuccin)
    property color pywalBg: "#11111b"
    property color pywalFg: "#cdd6f4"
    property color pywalAccent: "#89b4fa"
    property color pywalCard: "#1e1e2e"
    property color pywalMantle: "#181825"

    property bool expanded: false
    property string activeTab: "control"

    function calcReadableColor(bgHex) {
        try {
            var str = bgHex.toString().replace("#", "")
            var r = parseInt(str.substr(0, 2), 16) / 255
            var g = parseInt(str.substr(2, 2), 16) / 255
            var b = parseInt(str.substr(4, 2), 16) / 255
            var lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return lum > 0.55 ? "#11111b" : "#ffffff"
        } catch(e) {
            return "#ffffff"
        }
    }

    // Process to update pywal colors
    Process {
        id: pywalCatProc
        command: ["bash", "-c", "cat ~/.cache/wal/colors.sh"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.indexOf("background=") === 0) {
                        var bgVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (bgVal !== "") root.pywalBg = bgVal
                    }
                    if (line.indexOf("foreground=") === 0) {
                        var fgVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (fgVal !== "") root.pywalFg = fgVal
                    }
                    if (line.indexOf("color4=") === 0 || line.indexOf("color6=") === 0 || line.indexOf("color1=") === 0) {
                        var accVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (accVal !== "") root.pywalAccent = accVal
                    }
                    if (line.indexOf("color8=") === 0 || line.indexOf("color0=") === 0) {
                        var cardVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (cardVal !== "") root.pywalCard = cardVal
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: pywalCatProc.running = true
    }

    Component.onCompleted: pywalCatProc.running = true

    // MAIN CONTAINER ROW ACROSS NOTCH
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 4
        spacing: 0

        // LEFT WING: Workspaces Pill
        MouseArea {
            id: leftWing
            Layout.preferredWidth: leftContent.implicitWidth + 24
            Layout.preferredHeight: 34
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.expanded = !root.expanded
                if (root.expanded) root.activeTab = "control"
            }

            Rectangle {
                anchors.fill: parent
                radius: 17
                color: root.pywalBg
                opacity: 0.92
                border.color: root.pywalAccent
                border.width: 1.5

                RowLayout {
                    id: leftContent
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "❄"
                        color: root.pywalAccent
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Repeater {
                        model: [1, 2, 3, 4]

                        Rectangle {
                            required property int modelData
                            property bool isFocused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === modelData : false
                            implicitWidth: isFocused ? 18 : 8
                            implicitHeight: 8
                            radius: 4
                            color: isFocused ? root.pywalAccent : root.pywalFg
                            opacity: isFocused ? 1.0 : 0.4

                            Behavior on implicitWidth {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }
        }

        // CENTER NOTCH SPACER (Clears MacBook Notch ~220px)
        Item {
            Layout.fillWidth: true
        }

        Item {
            Layout.preferredWidth: 230
            Layout.preferredHeight: 34
        }

        Item {
            Layout.fillWidth: true
        }

        // RIGHT WING: Clock & Battery/Volume Controls Pill
        MouseArea {
            id: rightWing
            Layout.preferredWidth: rightContent.implicitWidth + 24
            Layout.preferredHeight: 34
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.expanded = !root.expanded
                if (root.expanded) root.activeTab = "control"
            }

            Rectangle {
                anchors.fill: parent
                radius: 17
                color: root.pywalBg
                opacity: 0.92
                border.color: root.pywalAccent
                border.width: 1.5

                RowLayout {
                    id: rightContent
                    anchors.centerIn: parent
                    spacing: 10

                    // Clock
                    Text {
                        id: clockText
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        color: root.pywalFg
                        font.pixelSize: 12
                        font.bold: true

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                        }
                    }

                    // Battery Indicator
                    RowLayout {
                        spacing: 4
                        Text {
                            property var displayBat: UPower.displayDevice
                            property double pct: displayBat ? displayBat.percentage * 100 : 100
                            property int state: displayBat ? displayBat.state : UPowerDeviceState.Unknown

                            text: {
                                if (state === UPowerDeviceState.Charging) return "⚡"
                                if (pct <= 20) return "🪫"
                                return "🔋"
                            }
                            color: state === UPowerDeviceState.Charging ? "#a6e3a1" : (pct <= 20 ? "#f38ba8" : root.pywalAccent)
                            font.pixelSize: 11
                        }

                        Text {
                            property var displayBat: UPower.displayDevice
                            text: displayBat ? Math.round(displayBat.percentage * 100) + "%" : "100%"
                            color: root.pywalFg
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // EXPANDED CONTROL CENTER CARD (Positioned below the notch when expanded)
    Rectangle {
        id: expandedCenterCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 44
        width: 440
        height: 220

        visible: root.expanded
        radius: 22
        color: root.pywalBg
        border.color: root.pywalAccent
        border.width: 1.5

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Navigation Tabs Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { id: "control", label: "🎛️ Control Center" },
                        { id: "theme", label: "🎨 Themes" },
                        { id: "wallpaper", label: "🖼️ Wallpapers" }
                    ]

                    MouseArea {
                        required property var modelData
                        implicitWidth: tabBtn.implicitWidth
                        implicitHeight: 28
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.activeTab = modelData.id

                        Rectangle {
                            id: tabBtn
                            implicitWidth: tabLabel.implicitWidth + 16
                            implicitHeight: 28
                            radius: 14
                            color: root.activeTab === modelData.id ? root.pywalAccent : root.pywalCard

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.activeTab === modelData.id ? root.calcReadableColor(root.pywalAccent) : root.pywalFg
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Close Button
                MouseArea {
                    implicitWidth: 28
                    implicitHeight: 28
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = false

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.pywalCard

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: root.pywalFg
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // TAB 1: Control Center
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "control"
                spacing: 8

                // Quick Toggles Grid
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MouseArea {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleThemeProc.running = true

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.pywalCard

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "☯️"; font.pixelSize: 12 }
                                Text { text: "Toggle Theme"; color: root.pywalFg; font.pixelSize: 11; font.bold: true }
                            }
                        }
                    }

                    MouseArea {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleWlProc.running = true

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.pywalCard

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "🌙"; font.pixelSize: 12 }
                                Text { text: "Night Light"; color: root.pywalFg; font.pixelSize: 11; font.bold: true }
                            }
                        }
                    }
                }

                // Sliders Container (Volume & Brightness)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: root.pywalCard

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // Volume Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "🔊"; color: root.pywalAccent; font.pixelSize: 12 }
                            Text { text: "Volume"; color: root.pywalFg; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                        }

                        Slider {
                            id: volSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: 50
                            onMoved: {
                                volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value) + "%"]
                                volSetProc.running = true
                            }
                        }

                        // Brightness Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "☀️"; color: root.pywalAccent; font.pixelSize: 12 }
                            Text { text: "Brightness"; color: root.pywalFg; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                        }

                        Slider {
                            id: brightSlider
                            Layout.fillWidth: true
                            from: 5
                            to: 100
                            value: 80
                            onMoved: {
                                brightSetProc.command = ["brightnessctl", "set", Math.round(value) + "%"]
                                brightSetProc.running = true
                            }
                        }
                    }
                }
            }

            // TAB 2: Themes Selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "theme"
                spacing: 6

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: [
                            { name: "Catppuccin Mocha", flag: "catppuccin" },
                            { name: "Gruvbox Dark", flag: "gruvbox" },
                            { name: "Nord Ice", flag: "nord" },
                            { name: "Tokyo Night", flag: "tokyonight" }
                        ]

                        MouseArea {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                themeSetProc.command = ["/home/lena/dotfiles/home/scripts/toggle-theme.sh", modelData.flag]
                                themeSetProc.running = true
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: root.pywalCard

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: root.pywalFg
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // TAB 3: Wallpaper Selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "wallpaper"
                spacing: 6

                MouseArea {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallSelectProc.running = true

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: root.pywalAccent

                        Text {
                            anchors.centerIn: parent
                            text: "🖼️ Launch Wallpaper Picker"
                            color: root.calcReadableColor(root.pywalAccent)
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // Helper Processes
    Process { id: toggleThemeProc; command: ["/home/lena/dotfiles/home/scripts/toggle-theme.sh"] }
    Process { id: toggleWlProc; command: ["pkill", "-TOGGLE", "wlsunset"] }
    Process { id: wallSelectProc; command: ["/home/lena/dotfiles/home/scripts/wallselect.sh"] }
    Process { id: volSetProc; command: [] }
    Process { id: brightSetProc; command: [] }
    Process { id: themeSetProc; command: [] }
}
