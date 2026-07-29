import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
    WlrLayershell.exclusiveZone: 38

    implicitHeight: 38
    color: "transparent"

    Rectangle {
        width: barWindow.width
        height: 38
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        color: "#1e1e2e"
        radius: 8
        border.color: "#89b4fa"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16

            Text {
                text: "❄ NixOS"
                color: "#89b4fa"
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: "Hyprland"
                color: "#a6adc8"
                font.pixelSize: 13
            }

            Item {
                Layout.fillWidth: true
            }

            // Indicateur de Volume (via wpctl - ultra fiable)
            MouseArea {
                id: volWidget
                property int volVal: 0
                property bool isMuted: false

                implicitWidth: volContent.implicitWidth
                implicitHeight: volContent.implicitHeight
                cursorShape: Qt.PointingHandCursor

                function updateVol() {
                    volGetProc.running = true
                }

                Component.onCompleted: updateVol()

                Process {
                    id: volGetProc
                    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                    stdout: SplitParser {
                        onRead: data => {
                            // Format: "Volume: 0.45 [MUTED]" ou "Volume: 0.75"
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
                    spacing: 6

                    Text {
                        text: {
                            if (volWidget.isMuted || volWidget.volVal === 0) return "🔇"
                            if (volWidget.volVal < 33) return "🔈"
                            if (volWidget.volVal < 66) return "🔉"
                            return "🔊"
                        }
                        color: (volWidget.isMuted || volWidget.volVal === 0) ? "#f38ba8" : "#89b4fa"
                        font.pixelSize: 14
                    }

                    Text {
                        text: volWidget.isMuted ? "Muted" : volWidget.volVal + "%"
                        color: "#cdd6f4"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            // Indicateur de Batterie (UPower)
            RowLayout {
                spacing: 6

                Text {
                    id: batIcon
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
                    font.pixelSize: 14
                }

                Text {
                    property var displayBat: UPower.displayDevice
                    text: displayBat ? Math.round(displayBat.percentage * 100) + "%" : "N/A"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            // Horloge
            Text {
                id: clockText
                text: Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
                color: "#cdd6f4"
                font.pixelSize: 13
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
