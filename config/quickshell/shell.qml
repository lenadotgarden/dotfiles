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

    implicitHeight: expanded ? 460 : (hudVisible ? 78 : 44)
    color: "transparent"

    // Invisible full-window backdrop to dismiss Control Center when clicking outside
    MouseArea {
        anchors.fill: parent
        enabled: barWindow.expanded
        z: -1
        onClicked: barWindow.expanded = false
    }

    property bool expanded: false
    property string activeTab: "control"

    Connections {
        target: Hyprland
        function onFocusedWindowChanged() { if (barWindow.expanded) barWindow.expanded = false; }
        function onFocusedWorkspaceChanged() { if (barWindow.expanded) barWindow.expanded = false; }
    }

    // Default typography font family
    property string customFontFamily: "Iosevka"

    // Unified spacing constant across all items and outer margins
    property int itemSpacing: 16

    // pywal dynamic theme colors
    property color pywalBg: "#11111b"
    property color pywalFg: "#ffffff"
    property color pywalAccent: "#89b4fa"
    property color pywalCard: "#181825"
    property color pywalSubtle: "#11111b"
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
                    if (line.indexOf("color0=") === 0 || line.indexOf("color8=") === 0) {
                        var cVal = line.split("=")[1].replace(/'/g, "").replace(/"/g, "").trim()
                        if (cVal !== "") {
                            barWindow.pywalCard = cVal === "#000000" ? "#181825" : cVal
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: pywalCatProc.running = true

    // UNIFIED NOTCH HUD OVERLAY STATE
    property bool hudVisible: false
    property int hudValue: 0
    property string hudIcon: "󰕾"
    property bool hudMuted: false

    property int lastVolVal: -1
    property bool lastVolMuted: false
    property int lastBrightVal: -1

    // Quick Toggles State
    property bool wifiEnabled: true
    property string wifiSSID: "Wi-Fi"
    property bool btEnabled: true
    property string btDevice: "Bluetooth"
    property bool dndEnabled: false
    property string mediaTitle: "No Media Playing"
    property string mediaArtist: "Media Player"
    property bool mediaPlaying: false

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
        height: barWindow.expanded ? 460 : (barWindow.hudVisible ? 78 : 44)

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

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
                var r = barWindow.expanded ? 24 : 18; // Constant bottom corner radius
                var f = 12;  // Top inverse fillets always preserved for notch bar!

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

        // Wi-Fi Status Process
        Process {
            id: wifiProc
            command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2"]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var ssid = data.trim()
                    if (ssid !== "") {
                        barWindow.wifiEnabled = true
                        barWindow.wifiSSID = ssid
                    } else {
                        barWindow.wifiEnabled = false
                        barWindow.wifiSSID = "Disconnected"
                    }
                }
            }
        }

        // Media Status Process
        Process {
            id: mediaProc
            command: ["bash", "-c", "nix run nixpkgs#playerctl -- metadata --format '{{title}};;;{{artist}};;;{{status}}' 2>/dev/null"]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var parts = data.trim().split(";;;")
                    if (parts.length >= 3 && parts[0] !== "") {
                        barWindow.mediaTitle = parts[0]
                        barWindow.mediaArtist = parts[1] !== "" ? parts[1] : "Unknown Artist"
                        barWindow.mediaPlaying = parts[2].toLowerCase() === "playing"
                    } else {
                        barWindow.mediaTitle = "No Media Playing"
                        barWindow.mediaArtist = "Media Player"
                        barWindow.mediaPlaying = false
                    }
                }
            }
        }

        Timer {
            interval: 10000 // 10s pour préserver les réveils CPU sur batterie
            running: true
            repeat: true
            onTriggered: {
                volGetProc.running = true
                brightGetProc.running = true
                wifiProc.running = true
                mediaProc.running = true
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
            anchors.bottomMargin: 28
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
                            interval: 30000 // 30s au lieu d'une boucle chaque seconde
                            running: true
                            repeat: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                        }
                    }
                }
            }

            // EXPANDED CONTROL CENTER BODY (iOS/Android Style)
            Item {
                id: expandedContent
                Layout.fillWidth: true
                Layout.preferredHeight: 410
                visible: barWindow.expanded
                opacity: barWindow.expanded ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: controlColumn
                    anchors.fill: parent
                    anchors.topMargin: 4
                    spacing: 8

                    // ROW 1: QUICK TOGGLES GRID (Wi-Fi, Bluetooth, Audio, Wallpapers, Theme, DND)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        // 1. WI-FI TOGGLE & MENU
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.wifiEnabled ? barWindow.pywalCard : "#181825"
                            border.color: barWindow.wifiEnabled ? barWindow.pywalAccent : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MouseArea {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        barWindow.wifiEnabled = !barWindow.wifiEnabled
                                        wifiToggleProc.command = ["nmcli", "radio", "wifi", barWindow.wifiEnabled ? "on" : "off"]
                                        wifiToggleProc.running = true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: barWindow.wifiEnabled ? "󰤨" : "󰤭"
                                        color: barWindow.wifiEnabled ? barWindow.pywalAccent : "#6c7185"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 18
                                    }
                                }

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiMenuProc.running = true

                                    ColumnLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "Wi-Fi"
                                            color: barWindow.pywalFg
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: barWindow.wifiSSID
                                            color: "#a6adc8"
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 130
                                        }
                                    }
                                }
                            }
                        }

                        // 2. BLUETOOTH TOGGLE & MENU
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.btEnabled ? barWindow.pywalCard : "#181825"
                            border.color: barWindow.btEnabled ? barWindow.pywalAccent : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MouseArea {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        barWindow.btEnabled = !barWindow.btEnabled
                                        btToggleProc.command = ["bluetoothctl", "power", barWindow.btEnabled ? "on" : "off"]
                                        btToggleProc.running = true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: barWindow.btEnabled ? "󰂯" : "󰂲"
                                        color: barWindow.btEnabled ? barWindow.pywalAccent : "#6c7185"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 18
                                    }
                                }

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btMenuProc.running = true

                                    ColumnLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "Bluetooth"
                                            color: barWindow.pywalFg
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: barWindow.btEnabled ? "On" : "Off"
                                            color: "#a6adc8"
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }

                        // 3. AUDIO OUTPUT / INPUT SELECTOR
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.pywalCard

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: "󰓃"
                                    color: barWindow.pywalAccent
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pavuControlProc.running = true

                                    ColumnLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "Audio Output"
                                            color: barWindow.pywalFg
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Speaker / Headphones"
                                            color: "#a6adc8"
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 130
                                        }
                                    }
                                }
                            }
                        }

                        // 4. WALLPAPER SELECTOR
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.pywalCard

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: "󰸉"
                                    color: barWindow.pywalAccent
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wallSelectProc.running = true

                                    ColumnLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "Wallpaper"
                                            color: barWindow.pywalFg
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Select Theme Image"
                                            color: "#a6adc8"
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }

                        // 5. TOGGLE LIGHT / DARK MODE
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.pywalCard

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: "󰔎"
                                    color: barWindow.pywalAccent
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleThemeProc.running = true

                                    ColumnLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "Toggle Theme"
                                            color: barWindow.pywalFg
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Switch Light/Dark"
                                            color: "#a6adc8"
                                            font.family: barWindow.customFontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }

                        // 6. DO NOT DISTURB MODE
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 14
                            color: barWindow.dndEnabled ? barWindow.pywalCard : "#181825"
                            border.color: barWindow.dndEnabled ? barWindow.pywalAccent : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        barWindow.dndEnabled = !barWindow.dndEnabled
                                        dndToggleProc.command = ["makoctl", "mode", "-t", "dnd"]
                                        dndToggleProc.running = true
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 10

                                        Text {
                                            text: "󰂛"
                                            color: barWindow.dndEnabled ? barWindow.pywalAccent : "#6c7185"
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 18
                                        }

                                        ColumnLayout {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: "Do Not Disturb"
                                                color: barWindow.pywalFg
                                                font.family: barWindow.customFontFamily
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            Text {
                                                text: barWindow.dndEnabled ? "Silence Active" : "Off"
                                                color: "#a6adc8"
                                                font.family: barWindow.customFontFamily
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ROW 2: INTERACTIVE SLIDERS (Brightness, Volume, Keyboard Brightness)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 130
                        radius: 16
                        color: barWindow.pywalCard

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // 1. BRIGHTNESS SLIDER
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "󰃠"
                                    color: barWindow.pywalAccent
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 16
                                }

                                Slider {
                                    id: brightSlider
                                    Layout.fillWidth: true
                                    from: 5
                                    to: 100
                                    value: barWindow.lastBrightVal > 0 ? barWindow.lastBrightVal : 50
                                    onMoved: {
                                        brightSetProc.command = ["brightnessctl", "set", Math.round(value) + "%"]
                                        brightSetProc.running = true
                                    }

                                    background: Rectangle {
                                        x: brightSlider.leftPadding
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: brightSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: barWindow.pywalBg

                                        Rectangle {
                                            width: brightSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: barWindow.pywalAccent
                                            radius: 3
                                        }
                                    }

                                    handle: Rectangle {
                                        x: brightSlider.leftPadding + brightSlider.visualPosition * (brightSlider.availableWidth - width)
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: barWindow.pywalFg
                                    }
                                }
                            }

                            // 2. VOLUME SLIDER
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: barWindow.lastVolMuted ? "󰝟" : "󰕾"
                                    color: barWindow.lastVolMuted ? "#6c7185" : barWindow.pywalAccent
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 16
                                }

                                Slider {
                                    id: volSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: barWindow.lastVolVal >= 0 ? barWindow.lastVolVal : 50
                                    onMoved: {
                                        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value) + "%"]
                                        volSetProc.running = true
                                    }

                                    background: Rectangle {
                                        x: volSlider.leftPadding
                                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: volSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: barWindow.pywalBg

                                        Rectangle {
                                            width: volSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: barWindow.lastVolMuted ? "#6c7185" : barWindow.pywalAccent
                                            radius: 3
                                        }
                                    }

                                    handle: Rectangle {
                                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: barWindow.pywalFg
                                    }
                                }
                            }

                            // 3. KEYBOARD BRIGHTNESS SLIDER
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "󰌌"
                                    color: "#6c7185"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 16
                                }

                                Slider {
                                    id: kbdSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: 50
                                    enabled: true
                                    onMoved: {
                                        kbdSetProc.command = ["brightnessctl", "-d", "*kbd*", "set", Math.round(value) + "%"]
                                        kbdSetProc.running = true
                                    }

                                    background: Rectangle {
                                        x: kbdSlider.leftPadding
                                        y: kbdSlider.topPadding + kbdSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: kbdSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: barWindow.pywalBg

                                        Rectangle {
                                            width: kbdSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: barWindow.pywalAccent
                                            radius: 3
                                        }
                                    }

                                    handle: Rectangle {
                                        x: kbdSlider.leftPadding + kbdSlider.visualPosition * (kbdSlider.availableWidth - width)
                                        y: kbdSlider.topPadding + kbdSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: barWindow.pywalFg
                                    }
                                }
                            }
                        }
                    }

                    // ROW 3: MEDIA PLAYER CARD (MPRIS Integration)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: 16
                        color: barWindow.pywalCard

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Text {
                                text: "󰎈"
                                color: barWindow.pywalAccent
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: barWindow.mediaTitle
                                    color: barWindow.pywalFg
                                    font.family: barWindow.customFontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 220
                                }

                                Text {
                                    text: barWindow.mediaArtist
                                    color: "#a6adc8"
                                    font.family: barWindow.customFontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 220
                                }
                            }

                            // Controls (Prev, Play/Pause, Next)
                            RowLayout {
                                spacing: 8

                                MouseArea {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        mediaPrevProc.command = ["nix-shell", "-p", "playerctl", "--run", "playerctl previous"]
                                        mediaPrevProc.running = true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒮"
                                        color: barWindow.pywalFg
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 16
                                    }
                                }

                                MouseArea {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        mediaPlayProc.command = ["nix-shell", "-p", "playerctl", "--run", "playerctl play-pause"]
                                        mediaPlayProc.running = true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 16
                                        color: barWindow.pywalAccent

                                        Text {
                                            anchors.centerIn: parent
                                            text: barWindow.mediaPlaying ? "󰏤" : "󰐊"
                                            color: barWindow.calcReadableColor(barWindow.pywalAccent)
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 16
                                        }
                                    }
                                }

                                MouseArea {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        mediaNextProc.command = ["nix-shell", "-p", "playerctl", "--run", "playerctl next"]
                                        mediaNextProc.running = true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒞"
                                        color: barWindow.pywalFg
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 16
                                    }
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
    Process { id: wifiToggleProc; command: [] }
    Process { id: wifiMenuProc; command: ["kitty", "--class", "floating-tui", "-e", "nmtui"] }
    Process { id: btToggleProc; command: [] }
    Process { id: btMenuProc; command: ["kitty", "--class", "floating-tui", "-e", "bluetuith"] }
    Process { id: pavuControlProc; command: ["pavucontrol"] }
    Process { id: dndToggleProc; command: [] }
    Process { id: volSetProc; command: [] }
    Process { id: brightSetProc; command: [] }
    Process { id: kbdSetProc; command: [] }
    Process { id: mediaPlayProc; command: [] }
    Process { id: mediaPrevProc; command: [] }
    Process { id: mediaNextProc; command: [] }
    Process { id: themeSetProc; command: [] }
    Process { id: hyprBorderProc; command: [] }
}
