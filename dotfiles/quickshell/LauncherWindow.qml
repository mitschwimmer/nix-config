import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

PanelWindow {
    id: root
    required property var modelData
    required property var launcher
    required property var palette

    screen: modelData
    visible: launcher.showing && launcher.outputName === modelData.name
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "#80000000"
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: root.contentItem }

    onVisibleChanged: {
        if (visible) Qt.callLater(() => {
            if (root.visible) search.forceActiveFocus()
        })
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.launcher.dismiss()
    }

    Rectangle {
        id: panel
        width: Math.min(448, Math.max(0, parent.width - 32))
        height: content.implicitHeight + 32
        anchors.centerIn: parent
        radius: 10
        color: root.palette.surface
        border.width: 1
        border.color: root.palette.line

        // Consume clicks in padding instead of dismissing through the backdrop.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 1
                    color: root.palette.red
                }
                Text {
                    Layout.fillWidth: true
                    text: "Applications"
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.foreground
                }
                Text {
                    text: "ESC"
                    font.family: root.palette.font
                    font.pixelSize: 10
                    color: root.palette.muted
                }
            }

            TextField {
                id: search
                Layout.fillWidth: true
                implicitHeight: 38
                leftPadding: 12
                rightPadding: 12
                text: root.launcher.query
                onTextEdited: root.launcher.query = text
                placeholderText: "Search applications…"
                placeholderTextColor: root.palette.muted
                color: root.palette.foreground
                selectionColor: root.palette.red
                selectedTextColor: "#FFFFFF"
                font.family: root.palette.font
                font.pixelSize: 12
                background: Rectangle {
                    color: root.palette.tile
                    radius: 5
                    border.width: 1
                    border.color: root.palette.line
                }
                onAccepted: root.launcher.launch(root.launcher.selectedIndex)
                Keys.onEscapePressed: root.launcher.dismiss()
                Keys.onDownPressed: root.launcher.moveSelection(1)
                Keys.onUpPressed: root.launcher.moveSelection(-1)
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.palette.line }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(264, Math.max(44, count * 44), Math.max(44, root.height - 190))
                clip: true
                model: root.launcher.results
                currentIndex: root.launcher.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.launcher.selectedIndex
                    width: results.width
                    height: 44
                    radius: 5
                    color: selected ? root.palette.tile : "transparent"

                    Rectangle {
                        width: 3
                        height: 32
                        radius: 1
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        visible: row.selected
                        color: root.palette.red
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                        spacing: 12

                        Item {
                            visible: root.launcher.showIcons
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Image {
                                id: icon
                                anchors.fill: parent
                                source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                                sourceSize: Qt.size(20, 20)
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: MultiEffect { saturation: -1 }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: icon.status !== Image.Ready
                                text: row.modelData.name.slice(0, 1).toUpperCase()
                                font.family: root.palette.font
                                font.pixelSize: 14
                                color: root.palette.muted
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                textFormat: Text.PlainText
                                font.family: root.palette.font
                                font.pixelSize: 12
                                color: root.palette.foreground
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: row.modelData.genericName || row.modelData.comment
                                textFormat: Text.PlainText
                                font.family: root.palette.font
                                font.pixelSize: 10
                                color: root.palette.muted
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            visible: row.selected
                            text: "↵"
                            font.family: root.palette.font
                            font.pixelSize: 12
                            color: root.palette.muted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.launcher.launch(row.index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: results.count === 0
                    text: "No applications found"
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.muted
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.palette.line }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: results.count + (results.count === 1 ? " application" : " applications")
                    font.family: root.palette.font
                    font.pixelSize: 10
                    color: root.palette.muted
                    elide: Text.ElideRight
                }
                Text {
                    text: "↑ ↓ Navigate   ↵ Open"
                    font.family: root.palette.font
                    font.pixelSize: 10
                    color: root.palette.muted
                }
            }
        }
    }
}
