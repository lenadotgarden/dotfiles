import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
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

    // Fixed height: 44px logical (scaling 1.6 on MacBook Pro 14" = ~70 native px)
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: 44

    implicitHeight: expanded ? 320 : (hudVisible ? 78 : 44)
    color: "transparent"

    property bool expanded: false
    property string activeTab: "control"

    // Default typography font family
    property string customFontFamily: "Iosevka"

    // Unified spacing constant across all items and outer margins
    property int itemSpacing: 16

    // pywal dynamic theme colors
    property color pywalBg: "#11111b"
    property color pywalFg: "#ffffff"
    property color pywalAccent: "#89b4fa"
    property color pywalCard: "#1e1e2e"
    property color pywalOledNotch: "#000000" // Pure OLED black

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

    // pywal colors parser
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
                    if (line.indexOf("color6=") === 0 || line.indexOf("color4=") === 0) {
                        var accVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (accVal !== "") barWindow.pywalAccent = accVal
                    }
                    if (line.indexOf("color8=") === 0 || line.indexOf("color0=") === 0) {
                        var cardVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (cardVal !== "") barWindow.pywalCard = cardVal
                    }
                }
            }
        }
    }

    // Pywal accent color state

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pywalCatProc.running = true
    }

    Component.onCompleted: pywalCatProc.running = true

    // UNIFIED NOTCH HUD OVERLAY STATE (Supports Volume, Brightness, and future OSDs)
    property bool hudVisible: false
    property int hudValue: 0
    property string hudIcon: "󰕾"
    property bool hudMuted: false

    property int lastVolVal: -1
    property bool lastVolMuted: false
    property int lastBrightVal: -1

    Timer {
        id: hudTimer
        interval: 1200
        repeat: false
        onTriggered: barWindow.hudVisible = false
    }

    function triggerHUD(icon, value, isMuted) {
        barWindow.hudIcon = icon
        barWindow.hudValue = value
        barWindow.hudMuted = isMuted
        if (!barWindow.expanded) {
            barWindow.hudVisible = true
            hudTimer.restart()
        }
    }

    // MAIN NOTCH EXTENSION CONTAINER
    Item {
        id: notchIslandContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: barWindow.expanded ? 460 : (leftWingRow.implicitWidth + 270 + rightWingRow.implicitWidth + 56)
        height: barWindow.expanded ? 300 : (barWindow.hudVisible ? 78 : 44)

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

        // Clean Canvas Drawing: Notch Extension with Top Inverse Fillets + Rounded Capsule Bottom
        Canvas {
            id: notchCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = barWindow.pywalOledNotch.toString();

                var w = notchIslandContainer.width;
                var h = notchIslandContainer.height;
                var r = 18; // Constant bottom corner radius
                var f = barWindow.expanded ? 0 : 12;  // Top inverse fillets always preserved for notch bar!

                ctx.beginPath();
                ctx.moveTo(0, 0);

                // Top-Left Inverse Curve flaring down into left capsule wall
                ctx.arcTo(f, 0, f, f, f);

                // Left vertical side down
                ctx.lineTo(f, h - r);

                // Bottom-Left Outer Capsule Curve
                ctx.arcTo(f, h, f + r, h, r);

                // Bottom horizontal edge
                ctx.lineTo(w - f - r, h);

                // Bottom-Right Outer Capsule Curve
                ctx.arcTo(w - f, h, w - f, h - r, r);

                // Right vertical side up
                ctx.lineTo(w - f, f);

                // Top-Right Inverse Curve flaring up into screen top edge
                ctx.arcTo(w - f, 0, w, 0, f);

                // Close top edge to (0,0)
                ctx.lineTo(w, 0);
                ctx.closePath();
                ctx.fill();

                if (barWindow.expanded) {
                    ctx.strokeStyle = barWindow.pywalAccent.toString();
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
            }

            Connections {
                target: barWindow
                function onExpandedChanged() { notchCanvas.requestPaint(); }
                function onHudVisibleChanged() { notchCanvas.requestPaint(); }
                function onPywalOledNotchChanged() { notchCanvas.requestPaint(); }
                function onPywalAccentChanged() { notchCanvas.requestPaint(); }
            }

            Connections {
                target: notchIslandContainer
                function onWidthChanged() { notchCanvas.requestPaint(); }
                function onHeightChanged() { notchCanvas.requestPaint(); }
            }
        }

        // Shared Volume Process Listener
        Process {
            id: volGetProc
            command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var str = data.trim()
                    var muted = str.indexOf("[MUTED]") !== -1
                    var parts = str.split(" ")
                    if (parts.length >= 2) {
                        var newVol = Math.round(parseFloat(parts[1]) * 100)
                        if (!isNaN(newVol)) {
                            if (barWindow.lastVolVal !== -1 && (newVol !== barWindow.lastVolVal || muted !== barWindow.lastVolMuted)) {
                                var icon = muted ? "󰝟" : (newVol === 0 ? "󰕿" : (newVol < 50 ? "󰖀" : "󰕾"))
                                barWindow.triggerHUD(icon, newVol, muted)
                            }
                            barWindow.lastVolVal = newVol
                            barWindow.lastVolMuted = muted
                        }
                    }
                }
            }
        }

        // Shared Brightness Process Listener
        Process {
            id: brightGetProc
            command: ["brightnessctl", "-m"]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var str = data.trim()
                    var parts = str.split(",")
                    if (parts.length >= 4) {
                        var pctStr = parts[3].replace("%", "")
                        var newBright = Math.round(parseFloat(pctStr))
                        if (!isNaN(newBright)) {
                            if (barWindow.lastBrightVal !== -1 && newBright !== barWindow.lastBrightVal) {
                                var icon = newBright < 30 ? "󰃞" : (newBright < 70 ? "󰃟" : "󰃠")
                                barWindow.triggerHUD(icon, newBright, false)
                            }
                            barWindow.lastBrightVal = newBright
                        }
                    }
                }
            }
        }

        Timer {
            interval: 200
            running: true
            repeat: true
            onTriggered: {
                volGetProc.running = true
                brightGetProc.running = true
            }
        }

        // UNIFIED NOTCH HUD OVERLAY DISPLAY (Positioned under physical notch)
        Item {
            id: notchHUD
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 24
            visible: !barWindow.expanded && barWindow.hudVisible
            opacity: (visible && barWindow.hudVisible) ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                anchors.fill: parent
                spacing: 12

                Text {
                    text: barWindow.hudIcon
                    color: barWindow.hudMuted ? "#6c7185" : barWindow.pywalAccent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                }

                // Smooth 0% to 100% progress bar (No percentage text)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 5
                    radius: 3
                    color: barWindow.pywalCard

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1.0, Math.max(0.0, barWindow.hudValue / 100.0))
                        radius: 3
                        color: barWindow.hudMuted ? "#6c7185" : barWindow.pywalAccent

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    }
                }
            }
        }

        // CONTENT LAYOUT
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 0

            // TOP COMPACT ROW
            RowLayout {
                id: notchContentRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 0

                // LEFT WING: Minimal Typography Workspaces (Fade out on HUD)
                RowLayout {
                    id: leftWingRow
                    spacing: barWindow.itemSpacing
                    opacity: (barWindow.hudVisible && !barWindow.expanded) ? 0.0 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Repeater {
                        model: [1, 2, 3, 4]

                        MouseArea {
                            required property int modelData
                            property var wsObj: Hyprland.workspaces.values.find(w => w.id === modelData)
                            property bool isFocused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === modelData : false
                            property bool isExists: wsObj !== undefined

                            implicitWidth: wsText.implicitWidth
                            implicitHeight: 28
                            cursorShape: Qt.PointingHandCursor

                            onClicked: Hyprland.dispatch("workspace " + modelData)

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: modelData
                                color: isFocused ? barWindow.pywalAccent : barWindow.pywalFg
                                opacity: isFocused ? 1.0 : (isExists ? 0.6 : 0.25)
                                font.family: barWindow.customFontFamily
                                font.pixelSize: 15
                                font.bold: isFocused

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }

                // PHYSICAL HARDWARE NOTCH CLEARANCE SPACER (270px)
                MouseArea {
                    Layout.preferredWidth: barWindow.expanded ? 110 : 270
                    Layout.fillHeight: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barWindow.expanded = !barWindow.expanded

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250 } }
                }

                // RIGHT WING: Battery + Clock (Fade out on HUD)
                RowLayout {
                    id: rightWingRow
                    spacing: barWindow.itemSpacing
                    opacity: (barWindow.hudVisible && !barWindow.expanded) ? 0.0 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // Battery
                    RowLayout {
                        id: batContent
                        implicitWidth: batContent.implicitWidth
                        implicitHeight: 28
                        spacing: 8

                        Text {
                            property var displayBat: UPower.displayDevice
                            property double pct: displayBat ? displayBat.percentage * 100 : 100
                            property int state: displayBat ? displayBat.state : UPowerDeviceState.Unknown

                            text: {
                                if (state === UPowerDeviceState.Charging) return "󰂄"
                                if (pct <= 20) return "󰁺"
                                if (pct <= 40) return "󰁼"
                                if (pct <= 60) return "󰁾"
                                if (pct <= 80) return "󰂀"
                                return "󰁹"
                            }
                            color: state === UPowerDeviceState.Charging ? "#a6e3a1" : (pct <= 20 ? "#f38ba8" : barWindow.pywalAccent)
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                        }

                        Text {
                            property var displayBat: UPower.displayDevice
                            text: displayBat ? Math.round(displayBat.percentage * 100) + "%" : "100%"
                            color: barWindow.pywalFg
                            font.family: barWindow.customFontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    // Clock
                    Text {
                        id: clockText
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        color: barWindow.pywalFg
                        font.family: barWindow.customFontFamily
                        font.pixelSize: 15
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

            // EXPANDED BODY (Control Center)
            Item {
                id: expandedContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: barWindow.expanded
                opacity: barWindow.expanded ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 8

                    // Tabs Header
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
                                        font.family: barWindow.customFontFamily
                                        font.pixelSize: 11
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
                                    font.family: barWindow.customFontFamily
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
                            spacing: 8

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
                                        Text { text: "Toggle Theme"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
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
                                        Text { text: "Night Light"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
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
                                    Text { text: "🔊 Volume"; color: barWindow.pywalAccent; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { text: volWidget.volVal + "%"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11 }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MouseArea {
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
                                            volSetProc.running = true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: barWindow.pywalBg
                                            Text { anchors.centerIn: parent; text: "- 5%"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
                                        }
                                    }

                                    MouseArea {
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]
                                            volSetProc.running = true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: barWindow.pywalBg
                                            Text { anchors.centerIn: parent; text: "+ 5%"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 10; font.bold: true }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "☀️ Brightness"; color: barWindow.pywalAccent; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MouseArea {
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            brightSetProc.command = ["brightnessctl", "set", "5%-"]
                                            brightSetProc.running = true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: barWindow.pywalBg
                                            Text { anchors.centerIn: parent; text: "- 5%"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
                                        }
                                    }

                                    MouseArea {
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            brightSetProc.command = ["brightnessctl", "set", "+5%"]
                                            brightSetProc.running = true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: barWindow.pywalBg
                                            Text { anchors.centerIn: parent; text: "+ 5%"; color: barWindow.pywalFg; font.family: barWindow.customFontFamily; font.pixelSize: 11; font.bold: true }
                                        }
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
                                implicitHeight: 38
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
                                        font.family: barWindow.customFontFamily
                                        font.pixelSize: 11
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
                            implicitHeight: 40
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
                                    font.family: barWindow.customFontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
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
    Process { id: hyprBorderProc; command: [] }
}
