import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var notification
    required property var palette

    height: content.implicitHeight + 28
    radius: 12
    color: palette.surface
    border.width: 1
    border.color: palette.line

    Timer {
        interval: root.notification.expireTimeout > 0
            ? Math.round(root.notification.expireTimeout * 1000) : 6000
        running: root.notification.expireTimeout !== 0
            && root.notification.urgency !== NotificationUrgency.Critical
        onTriggered: root.notification.expire()
    }

    Column {
        id: content
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 9

        RowLayout {
            width: parent.width
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 1
                color: root.palette.red
            }

            Text {
                Layout.fillWidth: true
                text: root.notification.appName.toUpperCase() || "NOTIFICATION"
                font.family: root.palette.font
                font.pixelSize: 11
                font.letterSpacing: 1
                color: root.palette.muted
                elide: Text.ElideRight
            }

            Text {
                text: "×"
                font.family: root.palette.font
                font.pixelSize: 17
                color: root.palette.muted

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.notification.dismiss()
                }
            }
        }

        Text {
            width: parent.width
            text: root.notification.summary
            textFormat: Text.PlainText
            font.family: root.palette.font
            font.bold: true
            font.pixelSize: 15
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: root.palette.foreground
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification.body
            textFormat: Text.PlainText
            font.family: root.palette.font
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            color: root.palette.muted
        }

        Flow {
            width: parent.width
            visible: root.notification.actions.length > 0
            spacing: 7
            height: visible ? implicitHeight : 0

            Repeater {
                model: root.notification.actions

                ActionButton {
                    palette: root.palette
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property var modelData
        required property var palette

        width: actionLabel.implicitWidth + 20
        height: 28
        radius: 5
        color: palette.tile
        border.color: palette.line
        border.width: 1

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: button.modelData.text.toUpperCase()
            color: button.palette.foreground
            font.family: button.palette.font
            font.pixelSize: 10
        }

        MouseArea {
            anchors.fill: parent
            onClicked: button.modelData.invoke()
        }
    }
}
