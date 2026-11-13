import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

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

        Rectangle {
            width: 1
            height: parent.height
            x: root.sidebar.side === "left" ? parent.width - 1 : 0
            color: root.palette.line
        }

        // Keep session access visible even when the content must scroll.
        SidebarSession {
            id: session
            width: parent.width - 40
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

                Grid {
                    id: tiles
                    width: parent.width
                    columns: 2
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "BATTERY", value: root.status.batteryValue,
                                detail: root.status.batteryDetail },
                            { label: "WI-FI", value: root.status.wifiValue,
                                detail: root.status.wifiDetail },
                            { label: "BLUETOOTH", value: root.status.bluetoothValue,
                                detail: root.status.bluetoothDetail },
                            { label: "OUTPUT", value: root.audio.output
                                ? (root.audio.output.description || root.audio.output.nickname || root.audio.output.name)
                                : "Unavailable",
                                detail: root.audio.outputReady
                                    ? (root.audio.muted ? "Muted" : Math.round(root.audio.volume * 100) + "% volume")
                                    : "No audio device" }
                        ]
                        Rectangle {
                            id: tile
                            required property var modelData
                            width: (tiles.width - tiles.spacing) / 2
                            height: 90
                            radius: 8
                            color: root.palette.tile

                            Column {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 8
                                Text {
                                    width: parent.width
                                    text: tile.modelData.label
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.5
                                    color: root.palette.muted
                                }
                                Text {
                                    width: parent.width
                                    text: tile.modelData.value
                                    elide: Text.ElideRight
                                    font.family: root.palette.font
                                    font.pixelSize: 13
                                    color: root.palette.foreground
                                }
                                Text {
                                    width: parent.width
                                    text: tile.modelData.detail
                                    elide: Text.ElideRight
                                    font.family: root.palette.font
                                    font.pixelSize: 10
                                    color: root.palette.muted
                                }
                            }
                            HoverHandler { id: tileHover }
                            ToolTip.visible: tileHover.hovered
                            ToolTip.delay: 650
                            ToolTip.text: tile.modelData.label + ": " + tile.modelData.value
                                + " · " + tile.modelData.detail
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
