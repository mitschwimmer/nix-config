import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    required property var niriState
    required property var palette

    // Popups only: no persistent notification center.
    property var notices: []
    readonly property int maxVisible: 3
    readonly property string targetScreen: niriState.focusedOutput !== ""
        ? niriState.focusedOutput
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    function forget(notice) {
        notices = notices.filter(item => item !== notice)
    }

    function receive(notice) {
        notice.tracked = true
        notice.closed.connect(() => root.forget(notice))

        if (notices.length >= maxVisible)
            notices[0].expire()

        notices = notices.concat([notice]).slice(-maxVisible)
    }

    NotificationServer {
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        keepOnReload: true
        onNotification: notice => root.receive(notice)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popup
            required property var modelData
            screen: modelData
            visible: root.notices.length > 0 && modelData.name === root.targetScreen
            width: 400
            height: stack.implicitHeight + 20
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; right: true }
            margins { top: 24; right: 24 }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-notifications"

            Column {
                id: stack
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 10

                Repeater {
                    model: root.notices

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property var notice: modelData
                        width: stack.width
                        height: content.implicitHeight + 28
                        radius: 12
                        color: root.palette.surface
                        border.width: 1
                        border.color: root.palette.line

                        Timer {
                            interval: card.notice.expireTimeout > 0
                                ? Math.round(card.notice.expireTimeout * 1000) : 6000
                            running: card.notice.expireTimeout !== 0
                                && card.notice.urgency !== NotificationUrgency.Critical
                            onTriggered: card.notice.expire()
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
                                    text: card.notice.appName.toUpperCase() || "NOTIFICATION"
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
                                        onClicked: card.notice.dismiss()
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: card.notice.summary
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
                                text: card.notice.body
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
                                visible: card.notice.actions.length > 0
                                spacing: 7
                                height: visible ? implicitHeight : 0

                                Repeater {
                                    model: card.notice.actions

                                    Rectangle {
                                        id: actionButton
                                        required property var modelData
                                        width: actionLabel.implicitWidth + 20
                                        height: 28
                                        radius: 5
                                        color: root.palette.tile
                                        border.color: root.palette.line
                                        border.width: 1

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: actionButton.modelData.text.toUpperCase()
                                            color: root.palette.foreground
                                            font.family: root.palette.font
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: actionButton.modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
