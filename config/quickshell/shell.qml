import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: barWindow

    screen: Quickshell.screens[0]

    anchors {
        top: true
        left: true
        right: true
    }

    height: 38
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        color: "#181825"
        radius: 8
        border.color: "#313244"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

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
