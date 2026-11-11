import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FloatingWindow {
    id: root
    required property var flow
    required property var palette

    title: "Authentication Required"
    visible: flow !== null && flow !== undefined
    implicitWidth: 440
    implicitHeight: 310
    color: palette.surface

    function submitResponse() {
        if (!flow || !flow.isResponseRequired)
            return

        const value = response.text
        response.clear()
        flow.submit(value)
    }

    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest()
        response.clear()
    }

    onClosed: cancel()
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                if (root.visible && root.flow && root.flow.isResponseRequired)
                    response.forceActiveFocus()
            })
        } else {
            response.clear()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        RowLayout {
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 1
                color: root.palette.red
            }

            Text {
                text: "AUTHENTICATION"
                color: root.palette.muted
                font.family: root.palette.font
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.flow ? root.flow.message : ""
            textFormat: Text.PlainText
            color: root.palette.foreground
            font.family: root.palette.font
            font.pixelSize: 15
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.flow ? root.flow.actionId : ""
            textFormat: Text.PlainText
            color: root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }

        Text {
            Layout.fillWidth: true
            text: root.flow ? root.flow.supplementaryMessage : ""
            textFormat: Text.PlainText
            color: root.flow && root.flow.supplementaryIsError
                ? root.palette.red : root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
            visible: text.length > 0
        }

        Text {
            Layout.fillWidth: true
            text: "AUTHENTICATION FAILED — TRY AGAIN"
            color: root.palette.red
            font.family: root.palette.font
            font.pixelSize: 11
            visible: root.flow ? root.flow.failed : false
        }

        ComboBox {
            Layout.fillWidth: true
            visible: root.flow && root.flow.identities.length > 1
            model: root.flow ? root.flow.identities : []
            textRole: "displayName"
            font.family: root.palette.font
            onActivated: index => {
                if (root.flow)
                    root.flow.selectedIdentity = root.flow.identities[index]
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.flow ? root.flow.inputPrompt : ""
            textFormat: Text.PlainText
            color: root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 11
            visible: text.length > 0
        }

        TextField {
            id: response
            Layout.fillWidth: true
            implicitHeight: 42
            enabled: root.flow ? root.flow.isResponseRequired : false
            echoMode: root.flow && root.flow.responseVisible
                ? TextInput.Normal : TextInput.Password
            color: root.palette.foreground
            selectionColor: root.palette.red
            selectedTextColor: root.palette.foreground
            placeholderText: "Response"
            font.family: root.palette.font
            font.pixelSize: 13
            onAccepted: root.submitResponse()

            background: Rectangle {
                radius: 6
                color: root.palette.tile
                border.color: response.activeFocus ? root.palette.red : root.palette.line
                border.width: 1
            }

            Keys.onEscapePressed: root.cancel()
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            DialogButton {
                Layout.fillWidth: true
                colors: root.palette
                text: "CANCEL"
                onClicked: root.cancel()
            }

            DialogButton {
                Layout.fillWidth: true
                colors: root.palette
                primary: true
                text: "AUTHORIZE"
                enabled: root.flow ? root.flow.isResponseRequired : false
                onClicked: root.submitResponse()
            }
        }
    }

    Connections {
        target: root.flow

        function onIsResponseRequiredChanged() {
            response.clear()
            if (root.flow && root.flow.isResponseRequired)
                response.forceActiveFocus()
        }

        function onAuthenticationFailed() {
            response.clear()
            response.forceActiveFocus()
        }
    }

    component DialogButton: Button {
        id: button
        required property var colors
        property bool primary: false

        implicitHeight: 36
        font.family: colors.font
        font.pixelSize: 11

        background: Rectangle {
            radius: 6
            color: button.primary ? button.colors.red : button.colors.tile
            border.width: 1
            border.color: button.primary ? button.colors.red : button.colors.line
            opacity: button.enabled ? 1 : 0.45
        }

        contentItem: Text {
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font: button.font
            color: button.primary ? "#FFFFFF" : button.colors.foreground
            opacity: button.enabled ? 1 : 0.45
        }
    }
}
