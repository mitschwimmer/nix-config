import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    width: 1024
    height: 768
    color: "#000000"

    // An image-free, OLED-black login surface. Keep the Polkit palette and
    // typography, but leave the form unframed and left of center.
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

    Item {
        id: login
        width: Math.min(440, root.width - 72)
        height: content.implicitHeight
        x: Math.max(36, Math.min(root.width * 0.16, root.width - width - 36))
        y: Math.max(36, (root.height - height) / 2)

        ColumnLayout {
            id: content
            anchors.fill: parent
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
                Layout.topMargin: 24
                text: "Welcome back."
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.width < 760 ? 30 : 40
                font.bold: true
                font.letterSpacing: -1
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 12
                text: "Sign in to " + sddm.hostName
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 52
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
                implicitHeight: 46
                leftPadding: 0
                rightPadding: 0
                bottomPadding: 8
                verticalAlignment: TextInput.AlignVCenter
                text: userModel.lastUser
                color: root.foreground
                selectionColor: root.red
                selectedTextColor: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 16
                onAccepted: password.forceActiveFocus()

                background: Item {
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: username.activeFocus ? root.red : root.line
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 24
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
                implicitHeight: 46
                leftPadding: 0
                rightPadding: 0
                bottomPadding: 8
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "▪"
                passwordMaskDelay: 0
                color: root.foreground
                selectionColor: root.red
                selectedTextColor: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 4
                enabled: !root.authenticating
                onAccepted: root.submitLogin()
                onTextChanged: {
                    if (root.errorMessage !== "")
                        root.errorMessage = ""
                }

                background: Item {
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: password.activeFocus ? root.red : root.line
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: root.red
                font.family: root.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 26

                DialogButton {
                    colors: root
                    primary: true
                    text: root.authenticating ? "SIGNING IN" : "SIGN IN"
                    enabled: !root.authenticating
                    onClicked: root.submitLogin()
                }

                Item { Layout.fillWidth: true }
            }

            ComboBox {
                id: sessionPicker
                Layout.fillWidth: true
                Layout.topMargin: 46
                Layout.preferredHeight: 36
                visible: sessionModel.count > 1
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex >= 0
                    ? sessionModel.lastIndex : 0
                font.family: root.fontFamily
                font.pixelSize: 11

                background: Item {
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: sessionPicker.activeFocus ? root.red : root.line
                    }
                }
                contentItem: Text {
                    leftPadding: 0
                    rightPadding: 24
                    text: sessionPicker.displayText
                    font: sessionPicker.font
                    color: root.muted
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    text: "⌄"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 3
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
                        color: parent.highlighted ? root.line : "#161616"
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
                        color: "#161616"
                        border.width: 1
                        border.color: root.line
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: sessionPicker.visible ? 22 : 42
                spacing: 26

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

                Item { Layout.fillWidth: true }
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
