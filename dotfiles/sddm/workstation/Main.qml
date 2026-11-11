import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    width: 1024
    height: 768
    color: "#090909"

    // Match the Quickshell PolkitDialog and Palette. The greeter runs outside
    // the user session, so keep this palette self-contained.
    readonly property color surface: "#0E0E0E"
    readonly property color tile: "#1A1A1A"
    readonly property color line: "#2A2A2A"
    readonly property color muted: "#8C8C8C"
    readonly property color foreground: "#F2F2F2"
    readonly property color red: "#D71921"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property bool authenticating: false
    property string errorMessage: ""

    function submitLogin() {
        const user = username.text.trim()
        if (user.length === 0) {
            errorMessage = "Enter your username"
            username.forceActiveFocus()
            return
        }
        if (sessionPicker.count === 0) {
            errorMessage = "No desktop session available"
            return
        }
        if (authenticating)
            return

        errorMessage = ""
        authenticating = true
        sddm.login(user, password.text, sessionPicker.currentIndex)
        password.clear()
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.authenticating = false
            root.errorMessage = "Authentication failed — try again"
            password.clear()
            password.forceActiveFocus()
        }

        function onLoginSucceeded() {
            password.clear()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(420, root.width - 40)
        height: content.implicitHeight + 56
        radius: 10
        color: root.surface
        border.width: 1
        border.color: root.line

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
                    color: root.red
                }

                Text {
                    Layout.fillWidth: true
                    text: "SYSTEM LOGIN"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 18
                text: "Welcome back"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                text: "Sign in to " + sddm.hostName
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 20
                color: root.line
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 18
                text: "USERNAME"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            TextField {
                id: username
                Layout.fillWidth: true
                Layout.topMargin: 8
                implicitHeight: 48
                leftPadding: 16
                rightPadding: 16
                verticalAlignment: TextInput.AlignVCenter
                text: userModel.lastUser
                color: root.foreground
                selectionColor: root.red
                selectedTextColor: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 14
                onAccepted: password.forceActiveFocus()

                background: Rectangle {
                    radius: 5
                    color: root.tile
                    border.width: 1
                    border.color: username.activeFocus ? root.red : root.line
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 18
                text: "PASSWORD"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            TextField {
                id: password
                Layout.fillWidth: true
                Layout.topMargin: 8
                implicitHeight: 48
                leftPadding: 16
                rightPadding: 16
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "▪"
                passwordMaskDelay: 0
                color: root.foreground
                selectionColor: root.red
                selectedTextColor: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 4
                enabled: !root.authenticating
                onAccepted: root.submitLogin()
                onTextChanged: {
                    if (root.errorMessage !== "")
                        root.errorMessage = ""
                }

                background: Rectangle {
                    radius: 5
                    color: root.tile
                    border.width: 1
                    border.color: password.activeFocus ? root.red : root.line
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: root.red
                font.family: root.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24

                Item { Layout.fillWidth: true }

                DialogButton {
                    colors: root
                    primary: true
                    text: root.authenticating ? "SIGNING IN" : "SIGN IN"
                    enabled: !root.authenticating
                    onClicked: root.submitLogin()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 24
                color: root.line
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 10

                ComboBox {
                    id: sessionPicker
                    Layout.preferredWidth: 168
                    Layout.preferredHeight: 36
                    visible: sessionModel.count > 1
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex >= 0
                        ? sessionModel.lastIndex : 0
                    font.family: root.fontFamily
                    font.pixelSize: 11

                    background: Rectangle {
                        radius: 5
                        color: root.tile
                        border.width: 1
                        border.color: sessionPicker.activeFocus ? root.red : root.line
                    }
                    contentItem: Text {
                        leftPadding: 12
                        rightPadding: 24
                        text: sessionPicker.displayText
                        font: sessionPicker.font
                        color: root.foreground
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    indicator: Text {
                        text: "⌄"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    delegate: ItemDelegate {
                        width: sessionPicker.width
                        text: model.name
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        contentItem: Text {
                            text: parent.text
                            color: root.foreground
                            font: parent.font
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.highlighted ? root.line : root.tile
                        }
                    }
                    popup: Popup {
                        y: sessionPicker.height - 1
                        width: sessionPicker.width
                        implicitHeight: Math.min(contentItem.implicitHeight, 240)
                        padding: 1
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: sessionPicker.popup.visible
                                ? sessionPicker.delegateModel : null
                            currentIndex: sessionPicker.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                        background: Rectangle {
                            radius: 5
                            color: root.tile
                            border.width: 1
                            border.color: root.line
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                DialogButton {
                    colors: root
                    text: "RESTART"
                    visible: sddm.canReboot
                    onClicked: sddm.reboot()
                }

                DialogButton {
                    colors: root
                    text: "POWER OFF"
                    visible: sddm.canPowerOff
                    onClicked: sddm.powerOff()
                }
            }
        }
    }

    Component.onCompleted: {
        if (username.text.length > 0)
            password.forceActiveFocus()
        else
            username.forceActiveFocus()
    }
}
