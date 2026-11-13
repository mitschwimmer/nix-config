import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Column {
    id: root
    required property var palette
    required property var sidebar
    property bool expanded: false
    spacing: 8

    readonly property var actions: [
        { label: "Lock", icon: "M 5 10 L 19 10 L 19 21 L 5 21 Z M 8 10 L 8 7 A 4 4 0 0 1 16 7 L 16 10",
            command: ["workstation-lock"] },
        { label: "Lock & suspend", icon: "M 20 15 A 9 9 0 0 1 9 3 A 9 9 0 1 0 20 15 Z",
            command: ["workstation-suspend"] },
        { label: "Restart", icon: "M 3 11 A 9 9 0 1 1 5 18 M 3 4 L 3 11 L 10 11",
            command: ["systemctl", "reboot"] },
        { label: "Power off", icon: "M 12 2 L 12 12 M 6 5.5 A 9 9 0 1 0 18 5.5",
            command: ["systemctl", "poweroff"] }
    ]

    function invoke(command) {
        expanded = false
        sidebar.dismiss()
        Quickshell.execDetached(command)
    }

    Connections {
        target: root.sidebar
        function onShowingChanged() {
            if (!root.sidebar.showing)
                root.expanded = false
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.palette.line
    }

    // An accessible click target without a permanent button-shaped surface.
    Button {
        id: disclosure
        width: parent.width
        implicitHeight: 40
        text: "SESSION"
        Accessible.name: root.expanded ? "Hide session actions" : "Show session actions"
        onClicked: { root.expanded = !root.expanded; root.sidebar.activity() }
        background: Rectangle {
            radius: 8
            color: disclosure.hovered || disclosure.down
                ? root.palette.tile : "transparent"
        }
        contentItem: RowLayout {
            spacing: 10
            Shape {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                ShapePath {
                    strokeColor: root.palette.muted
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M 8 2 L 8 8 M 4 4.5 A 6 6 0 1 0 12 4.5" }
                }
            }
            Text {
                Layout.fillWidth: true
                text: disclosure.text
                font.family: root.palette.font
                font.pixelSize: 10
                font.letterSpacing: 1
                color: root.palette.foreground
            }
            Shape {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                ShapePath {
                    strokeColor: root.palette.muted
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: root.expanded
                            ? "M 3 6 L 8 11 L 13 6"
                            : "M 3 10 L 8 5 L 13 10"
                    }
                }
            }
        }
    }

    Grid {
        id: actionGrid
        width: parent.width
        columns: 2
        spacing: 8
        visible: root.expanded

        Repeater {
            model: root.actions
            Button {
                id: actionButton
                required property var modelData
                width: (actionGrid.width - actionGrid.spacing) / 2
                implicitHeight: 72
                leftPadding: 8
                rightPadding: 8
                Accessible.name: modelData.label
                onClicked: root.invoke(modelData.command)
                background: Rectangle {
                    radius: 8
                    color: actionButton.hovered || actionButton.down
                        ? root.palette.line : root.palette.tile
                }
                // Center inside the button's padded content area, not in
                // a contentItem whose own geometry is being managed by Button.
                contentItem: Item {
                    Column {
                        width: parent.width
                        anchors.centerIn: parent
                        spacing: 7

                        Shape {
                            width: 24
                            height: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            ShapePath {
                                strokeColor: actionButton.modelData.label === "Power off"
                                    ? root.palette.red : root.palette.foreground
                                strokeWidth: 1.5
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                PathSvg { path: actionButton.modelData.icon }
                            }
                        }
                        Text {
                            width: parent.width
                            text: actionButton.modelData.label
                            font.family: root.palette.font
                            font.pixelSize: 9
                            color: actionButton.modelData.label === "Power off"
                                ? root.palette.red : root.palette.foreground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
