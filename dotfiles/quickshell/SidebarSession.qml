import Quickshell
import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var palette
    required property var sidebar
    property int pendingIndex: -1
    spacing: 12

    readonly property var actions: [
        { label: "Log out", question: "Log out of Niri?",
            command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { label: "Restart", question: "Restart the system?",
            command: ["systemctl", "reboot"] },
        { label: "Power off", question: "Power off the system?",
            command: ["systemctl", "poweroff"] }
    ]

    function confirm() {
        if (pendingIndex < 0)
            return
        const command = actions[pendingIndex].command
        pendingIndex = -1
        sidebar.dismiss()
        Quickshell.execDetached(command)
    }

    Connections {
        target: root.sidebar
        function onShowingChanged() {
            if (!root.sidebar.showing)
                root.pendingIndex = -1
        }
    }

    Text {
        text: "SESSION"
        font.family: root.palette.font
        font.pixelSize: 10
        font.letterSpacing: 1
        color: root.palette.muted
    }

    Repeater {
        model: root.actions
        Button {
            id: actionButton
            required property int index
            required property var modelData
            width: root.width
            implicitHeight: 40
            visible: root.pendingIndex < 0
            text: modelData.label
            Accessible.name: text
            onClicked: {
                root.pendingIndex = index
                root.sidebar.activity()
            }
            background: Rectangle {
                radius: 8
                color: actionButton.hovered || actionButton.down
                    ? root.palette.line : root.palette.tile
            }
            contentItem: Text {
                text: actionButton.text
                font.family: root.palette.font
                font.pixelSize: 12
                color: root.palette.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Column {
        width: root.width
        spacing: 12
        visible: root.pendingIndex >= 0

        Text {
            width: parent.width
            text: root.pendingIndex >= 0 ? root.actions[root.pendingIndex].question : ""
            font.family: root.palette.font
            font.pixelSize: 12
            color: root.palette.foreground
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: "Unsaved work may be lost."
            font.family: root.palette.font
            font.pixelSize: 10
            color: root.palette.muted
            wrapMode: Text.Wrap
        }
        Row {
            width: parent.width
            spacing: 8

            Button {
                id: cancelButton
                width: (parent.width - 8) / 2
                implicitHeight: 40
                text: "Cancel"
                onClicked: { root.pendingIndex = -1; root.sidebar.activity() }
                background: Rectangle {
                    radius: 8
                    color: cancelButton.hovered || cancelButton.down
                        ? root.palette.line : root.palette.tile
                }
                contentItem: Text {
                    text: cancelButton.text
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                id: confirmButton
                width: (parent.width - 8) / 2
                implicitHeight: 40
                text: "Confirm"
                onClicked: root.confirm()
                background: Rectangle {
                    radius: 8
                    color: confirmButton.hovered || confirmButton.down
                        ? root.palette.line : root.palette.tile
                }
                contentItem: Text {
                    text: confirmButton.text
                    font.family: root.palette.font
                    font.pixelSize: 12
                    color: root.palette.red
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
