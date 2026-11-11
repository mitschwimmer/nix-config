import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    required property var modelData
    required property var palette
    required property string targetScreen
    required property bool showing
    required property string heading
    required property string valueText
    required property real level
    required property bool showLevel

    screen: modelData
    visible: showing && modelData.name === targetScreen
    width: 360
    height: 112
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {} // An OSD must never eat pointer input.

    anchors { bottom: true }
    margins { bottom: 56 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    Rectangle {
        anchors.fill: parent
        color: root.palette.surface
        border.color: root.palette.line
        border.width: 1
        radius: 12

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                width: parent.width
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 1
                    color: root.palette.red
                }

                Text {
                    text: root.heading
                    font.family: root.palette.font
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    color: root.palette.muted
                }

                Text {
                    Layout.fillWidth: true
                    text: root.valueText
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    font.family: root.palette.font
                    font.bold: true
                    font.pixelSize: 15
                    color: root.palette.foreground
                }
            }

            Row {
                visible: root.showLevel
                spacing: 4

                Repeater {
                    model: 24
                    Rectangle {
                        width: 9
                        height: 18
                        radius: 1
                        color: index < Math.round(root.level * 24)
                            ? root.palette.red : root.palette.line
                    }
                }
            }

            Text {
                visible: !root.showLevel
                text: "▶  MPRIS"
                font.family: root.palette.font
                font.pixelSize: 11
                color: root.palette.muted
            }
        }
    }
}
