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
    implicitWidth: 420
    implicitHeight: content.implicitHeight + 56
    color: "transparent"

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

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.palette.surface
        border.width: 1
        border.color: root.palette.line
    }

    ColumnLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 28
        }
        spacing: 0

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
                text: "SYSTEM AUTHORIZATION"
                color: root.palette.muted
                font.family: root.palette.font
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 18
            text: "Authentication required"
            color: root.palette.foreground
            font.family: root.palette.font
            font.pixelSize: 20
            font.bold: true
            wrapMode: Text.Wrap
        }

        // Preserve the complete reason supplied by Polkit.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            text: root.flow ? root.flow.message : ""
            textFormat: Text.PlainText
            color: root.palette.foreground
            font.family: root.palette.font
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: text.length > 0
            text: root.flow ? root.flow.actionId : ""
            textFormat: Text.PlainText
            color: root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 20
            color: root.palette.line
        }

        ComboBox {
            id: identities
            Layout.fillWidth: true
            Layout.topMargin: 18
            implicitHeight: 40
            visible: root.flow && root.flow.identities.length > 1
            model: root.flow ? root.flow.identities : []
            textRole: "displayName"
            font.family: root.palette.font
            font.pixelSize: 12
            onActivated: index => {
                if (root.flow)
                    root.flow.selectedIdentity = root.flow.identities[index]
            }

            background: Rectangle {
                radius: 5
                color: root.palette.tile
                border.width: 1
                border.color: root.palette.line
            }

            contentItem: Text {
                leftPadding: 12
                rightPadding: 30
                text: identities.displayText
                font: identities.font
                color: root.palette.foreground
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 18
            text: root.flow && root.flow.inputPrompt
                ? root.flow.inputPrompt.toUpperCase() : "PASSWORD"
            textFormat: Text.PlainText
            color: root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 11
            font.letterSpacing: 1
        }

        TextField {
            id: response
            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: 48
            leftPadding: 16
            rightPadding: 16
            topPadding: 12
            bottomPadding: 12
            verticalAlignment: TextInput.AlignVCenter
            enabled: root.flow ? root.flow.isResponseRequired : false
            echoMode: root.flow && root.flow.responseVisible
                ? TextInput.Normal : TextInput.Password
            passwordCharacter: "▪"
            passwordMaskDelay: 0
            placeholderText: ""
            color: root.palette.foreground
            selectionColor: root.palette.red
            selectedTextColor: root.palette.foreground
            font.family: root.palette.font
            font.pixelSize: echoMode === TextInput.Password ? 18 : 14
            font.letterSpacing: echoMode === TextInput.Password ? 4 : 0
            onAccepted: root.submitResponse()
            Keys.onEscapePressed: root.cancel()

            background: Rectangle {
                radius: 5
                color: root.palette.tile
                border.width: 1
                border.color: response.activeFocus
                    ? root.palette.red : root.palette.line
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            visible: text.length > 0
            text: root.flow ? root.flow.supplementaryMessage : ""
            textFormat: Text.PlainText
            color: root.flow && root.flow.supplementaryIsError
                ? root.palette.red : root.palette.muted
            font.family: root.palette.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.flow ? root.flow.failed : false
            text: "Authentication failed — try again"
            color: root.palette.red
            font.family: root.palette.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 24
            spacing: 10

            Item { Layout.fillWidth: true }

            DialogButton {
                colors: root.palette
                text: "CANCEL"
                onClicked: root.cancel()
            }

            DialogButton {
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

        implicitWidth: primary ? 124 : 104
        implicitHeight: 36
        font.family: colors.font
        font.pixelSize: 11

        background: Rectangle {
            radius: 5
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
            opacity: button.enabled ? 1 : 0.6
        }
    }
}
