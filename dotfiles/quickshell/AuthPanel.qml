import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var palette
    property string mode: "LOGIN"
    property string userName: "henner"
    property string prompt: "Password"
    property string errorMessage: ""
    property bool responseRequired: false
    property bool responseVisible: false

    signal submitted(string response)

    implicitWidth: 440
    implicitHeight: 320

    function clear() {
        input.clear()
    }

    function focusPrompt() {
        Qt.callLater(() => {
            if (root.responseRequired)
                input.forceActiveFocus()
        })
    }

    function submit() {
        if (!responseRequired)
            return
        const value = input.text
        input.clear()
        submitted(value)
    }

    onResponseRequiredChanged: {
        clear()
        if (responseRequired)
            focusPrompt()
    }

    Component.onCompleted: focusPrompt()

    Rectangle {
        anchors.fill: parent
        color: root.palette.tile
        border.width: 1
        border.color: root.palette.line
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 1
                    color: root.palette.red
                }

                Text {
                    Layout.fillWidth: true
                    text: root.mode
                    color: root.palette.muted
                    font.family: root.palette.font
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.userName.toUpperCase()
                color: root.palette.foreground
                font.family: root.palette.font
                font.bold: true
                font.pixelSize: 28
                font.letterSpacing: 2
            }

            Text {
                Layout.fillWidth: true
                text: root.prompt || "Password"
                textFormat: Text.PlainText
                color: root.palette.muted
                font.family: root.palette.font
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            TextField {
                id: input
                Layout.fillWidth: true
                implicitHeight: 44
                enabled: root.responseRequired
                echoMode: root.responseVisible
                    ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhNoPredictiveText
                placeholderText: root.responseRequired ? "Enter response" : "Authenticating…"
                color: root.palette.foreground
                selectionColor: root.palette.red
                selectedTextColor: root.palette.foreground
                font.family: root.palette.font
                font.pixelSize: 14
                onAccepted: root.submit()

                background: Rectangle {
                    radius: 6
                    color: root.palette.surface
                    border.width: 1
                    border.color: input.activeFocus
                        ? root.palette.red : root.palette.line
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.errorMessage
                textFormat: Text.PlainText
                color: root.palette.red
                font.family: root.palette.font
                font.pixelSize: 11
                wrapMode: Text.Wrap
                visible: text.length > 0
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 130
                Layout.preferredHeight: 36
                color: root.palette.red
                radius: 5
                opacity: root.responseRequired ? 1 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "CONTINUE"
                    color: "#FFFFFF"
                    font.family: root.palette.font
                    font.bold: true
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.responseRequired
                    onClicked: root.submit()
                }
            }
        }
    }
}
