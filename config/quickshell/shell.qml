import QtQuick
import QtQuick.Layouts
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
    WlrLayershell.exclusiveZone: 40

    implicitHeight: 40
    color: "transparent"

    // pywal dynamic theme colors
    property color pywalBg: "#11111b"
    property color pywalFg: "#ffffff"
    property color pywalAccent: "#89b4fa"
    property color pywalCard: "#1e1e2e"

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
                            
                            var rawHex = accVal.replace("#", "")
                            if (rawHex.length === 6) {
                                hyprBorderProc.command = ["hyprctl", "keyword", "general:col.active_border", "rgba(" + rawHex + "ff)"]
                                hyprBorderProc.running = true
                            }
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

    Process {
        id: hyprBorderProc
        command: []
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pywalCatProc.running = true
    }

    Component.onCompleted: pywalCatProc.running = true

    // main top bar
    Rectangle {
        id: mainBar
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 4
        height: 34
        color: barWindow.pywalBg
        radius: 16
        border.color: barWindow.pywalAccent
        border.width: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            // nixos logo badge
            Rectangle {
                implicitWidth: logoRow.implicitWidth + 14
                implicitHeight: 24
                color: barWindow.pywalAccent
                radius: 8

                RowLayout {
                    id: logoRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "❄"
                        color: barWindow.calcReadableColor(barWindow.pywalAccent)
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        text: "NixOS"
                        color: barWindow.calcReadableColor(barWindow.pywalAccent)
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // hyprland workspaces (1-4)
            RowLayout {
                spacing: 6

                Repeater {
                    model: [1, 2, 3, 4]

                    MouseArea {
                        required property int modelData
                        property var wsObj: Hyprland.workspaces.values.find(w => w.id === modelData)
                        property bool isFocused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === modelData : false
                        property bool isExists: wsObj !== undefined

                        implicitWidth: wsRect.implicitWidth
                        implicitHeight: 24
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            Hyprland.dispatch("workspace " + modelData)
                        }

                        Rectangle {
                            id: wsRect
                            implicitWidth: wsText.implicitWidth + 14
                            implicitHeight: 24
                            radius: 7
                            color: isFocused ? barWindow.pywalAccent : (isExists ? barWindow.pywalCard : "transparent")
                            border.color: isFocused ? barWindow.calcReadableColor(barWindow.pywalAccent) : "transparent"
                            border.width: 1

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: modelData
                                color: isFocused ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalFg
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // macbook pro m2 notch spacer
            Item {
                Layout.fillWidth: true
            }

            Item {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
            }

            Item {
                Layout.fillWidth: true
            }

            // system widgets (volume, battery, clock)
            
            // volume control
            MouseArea {
                id: volWidget
                property int volVal: 0
                property bool isMuted: false

                implicitWidth: volContent.implicitWidth + 12
                implicitHeight: 24
                cursorShape: Qt.PointingHandCursor

                Rectangle {
                    id: volBg
                    anchors.fill: parent
                    color: volWidget.containsMouse ? barWindow.pywalAccent : barWindow.pywalCard
                    radius: 8
                }

                function updateVol() {
                    volGetProc.running = true
                }

                Component.onCompleted: updateVol()

                Process {
                    id: volGetProc
                    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                    stdout: SplitParser {
                        onRead: data => {
                            var muted = data.indexOf("[MUTED]") !== -1
                            var parts = data.trim().split(" ")
                            if (parts.length >= 2) {
                                var v = parseFloat(parts[1])
                                volWidget.volVal = Math.round(v * 100)
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

                RowLayout {
                    id: volContent
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: {
                            if (volWidget.isMuted || volWidget.volVal === 0) return "🔇"
                            if (volWidget.volVal < 33) return "🔈"
                            if (volWidget.volVal < 66) return "🔉"
                            return "🔊"
                        }
                        color: volWidget.containsMouse ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalAccent
                        font.pixelSize: 12
                    }

                    Text {
                        text: volWidget.isMuted ? "Mute" : volWidget.volVal + "%"
                        color: volWidget.containsMouse ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalFg
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // brightness control
            MouseArea {
                id: brightWidget
                property int brightVal: 100

                implicitWidth: brightContent.implicitWidth + 12
                implicitHeight: 24
                cursorShape: Qt.PointingHandCursor

                Rectangle {
                    id: brightBg
                    anchors.fill: parent
                    color: brightWidget.containsMouse ? barWindow.pywalAccent : barWindow.pywalCard
                    radius: 8
                }

                function updateBright() {
                    brightGetProc.running = true
                }

                Component.onCompleted: updateBright()

                Process {
                    id: brightGetProc
                    command: ["brightnessctl", "info"]
                    stdout: SplitParser {
                        onRead: data => {
                            var match = data.match(/\((\d+)%\)/)
                            if (match && match.length >= 2) {
                                brightWidget.brightVal = parseInt(match[1])
                            }
                        }
                    }
                }

                Process {
                    id: brightSetProc
                    command: []
                    onExited: brightWidget.updateBright()
                }

                onWheel: (wheel) => {
                    var change = wheel.angleDelta.y > 0 ? "+5%" : "5%-"
                    brightSetProc.command = ["brightnessctl", "set", change]
                    brightSetProc.running = true
                }

                Timer {
                    interval: 2000
                    running: true
                    repeat: true
                    onTriggered: brightWidget.updateBright()
                }

                RowLayout {
                    id: brightContent
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "☀️"
                        color: brightWidget.containsMouse ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalAccent
                        font.pixelSize: 12
                    }

                    Text {
                        text: brightWidget.brightVal + "%"
                        color: brightWidget.containsMouse ? barWindow.calcReadableColor(barWindow.pywalAccent) : barWindow.pywalFg
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // battery indicator
            Rectangle {
                id: batBg
                implicitWidth: batContent.implicitWidth + 12
                implicitHeight: 24
                color: barWindow.pywalCard
                radius: 8

                RowLayout {
                    id: batContent
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        property var displayBat: UPower.displayDevice
                        property double pct: displayBat ? displayBat.percentage * 100 : 100
                        property int state: displayBat ? displayBat.state : UPowerDeviceState.Unknown

                        text: {
                            if (state === UPowerDeviceState.Charging) return "⚡"
                            if (pct <= 15) return "🪫"
                            return "🔋"
                        }
                        color: {
                            if (state === UPowerDeviceState.Charging) return "#a6e3a1"
                            if (pct <= 15) return "#f38ba8"
                            if (pct <= 30) return "#fab387"
                            return "#a6e3a1"
                        }
                        font.pixelSize: 12
                    }

                    Text {
                        property var displayBat: UPower.displayDevice
                        text: displayBat ? Math.round(displayBat.percentage * 100) + "%" : "100%"
                        color: barWindow.pywalFg
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // clock
            Rectangle {
                id: clockBg
                implicitWidth: clockText.implicitWidth + 14
                implicitHeight: 24
                color: barWindow.pywalCard
                radius: 8

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
                    color: barWindow.pywalFg
                    font.pixelSize: 11
                    font.bold: true

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
                    }
                }
            }
        }
    }
}
