import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

PanelWindow {
    id: root
    required property var modelData
    required property var sidebar
    required property var palette
    required property var status
    required property var audio
    readonly property bool isTargetOutput: sidebar.outputName === modelData.name

    screen: modelData
    visible: isTargetOutput && sidebar.progress > 0
    color: "transparent"
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-sidebar"
    mask: Region { item: drawer }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        id: drawer
        width: root.sidebar.drawerWidth
        height: parent.height
        x: root.sidebar.side === "left"
            ? -width * (1 - root.sidebar.progress)
            : parent.width - width * root.sidebar.progress
        color: root.palette.dark ? "#000000" : root.palette.surface
        clip: true

        // Keep session access visible even when the content must scroll.
        SidebarSession {
            id: session
            width: parent.width - 56
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            palette: root.palette
            sidebar: root.sidebar
        }

        Flickable {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: session.top
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.topMargin: 20
            anchors.bottomMargin: 12
            contentHeight: content.y + content.height + 12
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: content
                width: parent.width
                y: Math.max(8, Math.min(32, drawer.height * 0.05))
                spacing: 12

                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Rectangle { width: 7; height: 7; y: 4; color: root.palette.red }
                        Text {
                            text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                            font.family: root.palette.font
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            color: root.palette.muted
                        }
                    }

                    Button {
                        id: appearance
                        width: 34
                        height: 34
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.palette.dark ? "☀" : "☾"
                        Accessible.name: root.palette.dark ? "Switch to light mode" : "Switch to dark mode"
                        onClicked: { root.palette.setDark(!root.palette.dark); root.sidebar.activity() }
                        background: Rectangle {
                            radius: 8
                            color: appearance.hovered || appearance.down ? root.palette.line : root.palette.tile
                        }
                        contentItem: Text {
                            text: appearance.text
                            font.family: root.palette.font
                            font.pixelSize: 20
                            color: root.palette.foreground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "dd MMMM yyyy").toUpperCase()
                    width: parent.width
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.foreground
                    wrapMode: Text.Wrap
                }
                Item { width: 1; height: 4 }
                // Preserve the current clock's full size and dot-matrix rendering.
                DotClock {
                    width: parent.width
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.palette.foreground
                }
                Item { width: 1; height: 8 }

                // Full-width status rows keep long network and device details readable.
                Repeater {
                    model: [
                        { icon: "M 2 6 L 19 6 L 19 17 L 2 17 Z M 21 9 L 21 14",
                            label: "BATTERY", value: root.status.batteryValue,
                            detail: root.status.batteryDetail },
                        { icon: "M 1 7 Q 12 -1 23 7 M 5 11 Q 12 5 19 11 M 9 15 Q 12 12 15 15 M 12 19 L 12 20",
                            label: "WI-FI", value: root.status.wifiValue,
                            detail: root.status.wifiDetail },
                        { icon: "M 11 1 L 18 7 L 6 17 M 11 1 L 11 23 L 18 17 L 6 7",
                            label: "BLUETOOTH", value: root.status.bluetoothValue,
                            detail: root.status.bluetoothDetail }
                    ]

                    Column {
                        id: statusRow
                        required property var modelData
                        width: content.width
                        spacing: 12

                        RowLayout {
                            width: parent.width
                            spacing: 14

                            Shape {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                ShapePath {
                                    strokeColor: root.palette.muted
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: statusRow.modelData.icon }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: statusRow.modelData.label
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: root.palette.muted
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: statusRow.modelData.value
                                    textFormat: Text.PlainText
                                    wrapMode: Text.WrapAnywhere
                                    font.family: root.palette.font
                                    font.pixelSize: 16
                                    color: root.palette.foreground
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: statusRow.modelData.detail
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    color: root.palette.muted
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.palette.line
                        }
                    }
                }

                Item { width: 1; height: 4 }
                SidebarAudio {
                    width: parent.width
                    palette: root.palette
                    audio: root.audio
                    sidebar: root.sidebar
                }
            }
        }

        // Observe hover without stealing wheel/touch events from the Flickable.
        HoverHandler {
            onHoveredChanged: {
                if (hovered) root.sidebar.activity()
                else root.sidebar.leave()
            }
            onPointChanged: { if (hovered) root.sidebar.activity() }
        }
    }
}
