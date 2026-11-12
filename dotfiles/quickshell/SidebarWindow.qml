import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

PanelWindow {
    id: root
    required property var modelData
    required property var sidebar
    required property var palette
    required property var status
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

        Rectangle {
            width: 1
            height: parent.height
            x: root.sidebar.side === "left" ? parent.width - 1 : 0
            color: root.palette.line
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 28
            contentHeight: content.y + content.height + 28
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: content
                width: parent.width
                y: Math.max(20, Math.min(68, drawer.height * 0.08))
                spacing: 12

                Row {
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
                Text {
                    text: Qt.formatDateTime(clock.date, "dd MMMM yyyy").toUpperCase()
                    width: parent.width
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.foreground
                    wrapMode: Text.Wrap
                }
                Item { width: 1; height: 8 }
                DotClock {
                    width: parent.width
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.palette.foreground
                }
                Item { width: 1; height: Math.max(28, drawer.height * 0.14) }

                Repeater {
                    model: [
                        { icon: "M 2 6 L 19 6 L 19 17 L 2 17 Z M 21 9 L 21 14", label: "BATTERY", value: root.status.batteryValue,
                            detail: root.status.batteryDetail, battery: true },
                        { icon: "M 1 7 Q 12 -1 23 7 M 5 11 Q 12 5 19 11 M 9 15 Q 12 12 15 15 M 12 19 L 12 20", label: "WI-FI", value: root.status.wifiValue,
                            detail: root.status.wifiDetail, battery: false },
                        { icon: "M 11 1 L 18 7 L 6 17 M 11 1 L 11 23 L 18 17 L 6 7", label: "BLUETOOTH", value: root.status.bluetoothValue,
                            detail: root.status.bluetoothDetail, battery: false }
                    ]
                    Column {
                        required property var modelData
                        width: content.width
                        spacing: 16
                        RowLayout {
                            width: parent.width
                            spacing: 14
                            Shape {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                ShapePath {
                                    strokeColor: root.palette.foreground
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: modelData.icon }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: modelData.label
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: root.palette.muted
                                }
                                Text {
                                    text: modelData.value
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: root.palette.font
                                    font.pixelSize: 16
                                    color: root.palette.foreground
                                }
                                Text {
                                    text: modelData.detail
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    color: root.palette.muted
                                }
                                Row {
                                    visible: modelData.battery && root.status.hasBattery
                                    spacing: 3
                                    Repeater {
                                        model: 12
                                        Rectangle {
                                            required property int index
                                            width: 11
                                            height: 3
                                            color: index < Math.round(root.status.batteryLevel * 12)
                                                ? root.palette.foreground : root.palette.line
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: root.palette.line }
                        Item { width: 1; height: 2 }
                    }
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
