import Quickshell
import QtQuick
import QtQuick.Controls
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
        { label: "Log out", icon: "M 10 4 L 5 4 L 5 20 L 10 20 M 14 8 L 18 12 L 14 16 M 18 12 L 8 12",
            command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
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

    Button {
        id: disclosure
        width: parent.width
        implicitHeight: 38
        text: "SESSION"
        Accessible.name: root.expanded ? "Hide session actions" : "Show session actions"
        onClicked: { root.expanded = !root.expanded; root.sidebar.activity() }
        background: Rectangle {
            radius: 8
            color: disclosure.hovered || disclosure.down ? root.palette.line : root.palette.tile
        }
        contentItem: Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: disclosure.text
                font.family: root.palette.font
                font.pixelSize: 10
                font.letterSpacing: 1
                color: root.palette.foreground
            }
            Text {
                text: root.expanded ? "−" : "+"
                font.family: root.palette.font
                font.pixelSize: 14
                color: root.palette.muted
            }
        }
    }

    Row {
        width: parent.width
        spacing: 6
        visible: root.expanded
        Repeater {
            model: root.actions
            Button {
                id: actionButton
                required property var modelData
                width: (root.width - 18) / 4
                implicitHeight: 64
                Accessible.name: modelData.label
                onClicked: root.invoke(modelData.command)
                background: Rectangle {
                    radius: 8
                    color: actionButton.hovered || actionButton.down
                        ? root.palette.line : root.palette.tile
                }
                contentItem: Column {
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
                        text: actionButton.modelData.label
                        width: actionButton.width
                        font.family: root.palette.font
                        font.pixelSize: 9
                        color: actionButton.modelData.label === "Power off"
                            ? root.palette.red : root.palette.foreground
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
