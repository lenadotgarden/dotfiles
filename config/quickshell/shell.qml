import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Io

PanelWindow {
    id: barWindow

    screen: Quickshell.screens[0]

    anchors {
        top: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: expanded ? 290 : 38

    implicitHeight: expanded ? 290 : 38
    color: "transparent"

    property bool expanded: false
    property string activeTab: "control"

    // pywal dynamic theme colors (automatic sync preserved!)
    property color pywalBg: "#11111b"
    property color pywalFg: "#ffffff"
    property color pywalAccent: "#89b4fa"
    property color pywalCard: "#1e1e2e"
    property color pywalOledNotch: "#000000" // OLED pure black for notch integration

    // wcag luminance contrast calculator for text readability
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

    // pywal colors parser & active hyprland border sync
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
                        if (bgVal !== "") barWindow.pywalBg = bgVal
                    }
                    if (line.indexOf("foreground=") === 0) {
                        var fgVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (fgVal !== "") barWindow.pywalFg = fgVal
                    }
                    if (line.indexOf("color4=") === 0 || line.indexOf("color6=") === 0 || line.indexOf("color1=") === 0) {
                        var accVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (accVal !== "") {
                            barWindow.pywalAccent = accVal
                        }
                    }
                    if (line.indexOf("color8=") === 0 || line.indexOf("color0=") === 0) {
                        var cardVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (cardVal !== "") barWindow.pywalCard = cardVal
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pywalCatProc.running = true
    }

    Component.onCompleted: pywalCatProc.running = true

    // MAIN NOTCH EXTENSION CAPSULE
    // Designed to seamlessly wrap around the MacBook Pro 14" Notch in OLED Black (#000000)
    Rectangle {
        id: notchIsland
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 0

        width: barWindow.expanded ? 460 : notchContentRow.implicitWidth + 36
        height: barWindow.expanded ? 280 : 36

        radius: barWindow.expanded ? 24 : 18
        color: barWindow.pywalOledNotch
        border.color: barWindow.expanded ? barWindow.pywalAccent : "transparent"
        border.width: barWindow.expanded ? 1.5 : 0

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6

            // TOP COMPACT ROW (Seamless Extension of the Notch)
            RowLayout {
                id: notchContentRow
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 8

                // LEFT: Workspaces & NixOS Icon (Left side of physical notch)
                RowLayout {
                    spacing: 6

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        color: barWindow.pywalAccent
                        radius: 12

                        Text {
                            anchors.centerIn: parent
                            text: "❄"
                            color: barWindow.calcReadableColor(barWindow.pywalAccent)
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    RowLayout {
                        spacing: 5

                        Repeater {
                            model: [1, 2, 3, 4]

                            MouseArea {
                                required property int modelData
                                property var wsObj: Hyprland.workspaces.values.find(w => w.id === modelData)
                                property bool isFocused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === modelData : false
                                property bool isExists: wsObj !== undefined

                                implicitWidth: wsRect.implicitWidth
                                implicitHeight: 22
                                cursorShape: Qt.PointingHandCursor

                                onClicked: Hyprland.dispatch("workspace " + modelData)

                                Rectangle {
                                    id: wsRect
                                    implicitWidth: isFocused ? 22 : 14
                                    implicitHeight: 22
                                    radius: 11
                                    color: isFocused ? barWindow.pywalAccent : (isExists ? barWindow.pywalCard : "#1a1a1a")

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: isFocused ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalFg
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Behavior on implicitWidth { NumberAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }

                // PHYSICAL NOTCH SPACER (~220px to perfectly frame the hardware camera notch)
                MouseArea {
                    Layout.preferredWidth: barWindow.expanded ? 120 : 210
                    Layout.fillHeight: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWindow.expanded = !barWindow.expanded

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250 } }

                    // Subtle indicator in notch center when collapsed
                    Item {
                        anchors.centerIn: parent
                        visible: !barWindow.expanded
                    }
                }

                // RIGHT: Clock, Volume, Battery (Right side of physical notch)
                RowLayout {
                    spacing: 8

                    // Volume
                    MouseArea {
                        id: volWidget
                        property int volVal: 0
                        property bool isMuted: false

                        implicitWidth: volContent.implicitWidth + 10
                        implicitHeight: 22
                        cursorShape: Qt.PointingHandCursor

                        function updateVol() { volGetProc.running = true }
                        Component.onCompleted: updateVol()

                        Process {
                            id: volGetProc
                            command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                            stdout: SplitParser {
                                onRead: data => {
                                    var muted = data.indexOf("[MUTED]") !== -1
                                    var parts = data.trim().split(" ")
                                    if (parts.length >= 2) {
                                        volWidget.volVal = Math.round(parseFloat(parts[1]) * 100)
                                        volWidget.isMuted = muted
                                    }
                                }
                            }
                        }

                        Process {
                            id: volSetProc
                            command: []
                            onExited: volWidget.updateVol()
                        }

                        onClicked: {
                            volSetProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                            volSetProc.running = true
                        }

                        onWheel: (wheel) => {
                            var change = wheel.angleDelta.y > 0 ? "5%+" : "5%-"
                            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", change]
                            volSetProc.running = true
                        }

                        Timer {
                            interval: 2000
                            running: true
                            repeat: true
                            onTriggered: volWidget.updateVol()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: barWindow.pywalCard

                            RowLayout {
                                id: volContent
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: volWidget.isMuted ? "🔇" : (volWidget.volVal < 50 ? "🔉" : "🔊")
                                    color: barWindow.pywalAccent
                                    font.pixelSize: 10
                                }
                                Text {
                                    text: volWidget.isMuted ? "M" : volWidget.volVal + "%"
                                    color: barWindow.pywalFg
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Battery
                    Rectangle {
                        implicitWidth: batContent.implicitWidth + 10
                        implicitHeight: 22
                        color: barWindow.pywalCard
                        radius: 11

                        RowLayout {
                            id: batContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                property var displayBat: UPower.displayDevice
                                property double pct: displayBat ? displayBat.percentage * 100 : 100
                                property int state: displayBat ? displayBat.state : UPowerDeviceState.Unknown

                                text: state === UPowerDeviceState.Charging ? "⚡" : (pct <= 20 ? "🪫" : "🔋")
                                color: state === UPowerDeviceState.Charging ? "#a6e3a1" : (pct <= 20 ? "#f38ba8" : barWindow.pywalAccent)
                                font.pixelSize: 10
                            }

                            Text {
                                property var displayBat: UPower.displayDevice
                                text: displayBat ? Math.round(displayBat.percentage * 100) + "%" : "100%"
                                color: barWindow.pywalFg
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    // Clock
                    Rectangle {
                        implicitWidth: clockText.implicitWidth + 12
                        implicitHeight: 22
                        color: barWindow.pywalAccent
                        radius: 11

                        Text {
                            id: clockText
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(new Date(), "HH:mm")
                            color: barWindow.calcReadableColor(barWindow.pywalAccent)
                            font.pixelSize: 10
                            font.bold: true

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                            }
                        }
                    }
                }
            }

            // EXPANDED BODY (Morphs smoothly out of the Notch Extension)
            Item {
                id: expandedContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: barWindow.expanded
                opacity: barWindow.expanded ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    // Navigation Tabs
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "control", label: "🎛️ Control Center" },
                                { id: "theme", label: "🎨 Themes" },
                                { id: "wallpaper", label: "🖼️ Wallpapers" }
                            ]

                            MouseArea {
                                required property var modelData
                                implicitWidth: tabBtn.implicitWidth
                                implicitHeight: 26
                                cursorShape: Qt.PointingHandCursor

                                onClicked: barWindow.activeTab = modelData.id

                                Rectangle {
                                    id: tabBtn
                                    implicitWidth: tabLabel.implicitWidth + 14
                                    implicitHeight: 26
                                    radius: 13
                                    color: barWindow.activeTab === modelData.id ? barWindow.pywalAccent : barWindow.pywalCard

                                    Text {
                                        id: tabLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: barWindow.activeTab === modelData.id ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalFg
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        MouseArea {
                            implicitWidth: 26
                            implicitHeight: 26
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barWindow.expanded = false

                            Rectangle {
                                anchors.fill: parent
                                radius: 13
                                color: barWindow.pywalCard

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: barWindow.pywalFg
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    // TAB 1: Control Center
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: barWindow.activeTab === "control"
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MouseArea {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleThemeProc.running = true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: barWindow.pywalCard

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "☯️"; font.pixelSize: 12 }
                                        Text { text: "Toggle Theme"; color: barWindow.pywalFg; font.pixelSize: 10; font.bold: true }
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
                                    color: barWindow.pywalCard

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "🌙"; font.pixelSize: 12 }
                                        Text { text: "Night Light"; color: barWindow.pywalFg; font.pixelSize: 10; font.bold: true }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: barWindow.pywalCard

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "🔊 Volume"; color: barWindow.pywalAccent; font.pixelSize: 10; font.bold: true }
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

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "☀️ Brightness"; color: barWindow.pywalAccent; font.pixelSize: 10; font.bold: true }
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

                    // TAB 2: Themes
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: barWindow.activeTab === "theme"
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
                                    color: barWindow.pywalCard

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: barWindow.pywalFg
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    // TAB 3: Wallpapers
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: barWindow.activeTab === "wallpaper"

                        MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallSelectProc.running = true

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: barWindow.pywalAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: "🖼️ Launch Wallpaper Picker"
                                    color: barWindow.calcReadableColor(barWindow.pywalAccent)
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper Processes & Script Callbacks
    Process { id: toggleThemeProc; command: ["/home/lena/dotfiles/home/scripts/toggle-theme.sh"] }
    Process { id: toggleWlProc; command: ["pkill", "-TOGGLE", "wlsunset"] }
    Process { id: wallSelectProc; command: ["/home/lena/dotfiles/home/scripts/wallselect.sh"] }
    Process { id: brightSetProc; command: [] }
    Process { id: themeSetProc; command: [] }
}
