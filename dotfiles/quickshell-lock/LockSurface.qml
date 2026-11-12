import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

WlSessionLockSurface {
    id: root
    required property var auth
    required property string status
    required property string background
    signal retryRequested()

    color: "#000000"
    readonly property color foreground: "#F2F2F2"
    readonly property color muted: "#B0B0B0"
    readonly property color red: "#D71921"
    readonly property string typeface: "JetBrainsMono Nerd Font"

    function submit() {
        if (auth.responseRequired) {
            const value = response.text
            response.clear()
            auth.respond(value)
        } else if (!auth.active) {
            response.clear()
            retryRequested()
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // The raw image is never painted. Every frame has an opaque black base;
    // loading errors and newly attached outputs therefore remain black.
    Image {
        id: snapshot
        anchors.fill: parent
        source: root.background
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: snapshot
        visible: snapshot.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        blurMultiplier: 1.0
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 64)
        spacing: 0

        DotClock {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.foreground
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 24
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: root.foreground
            font.family: root.typeface
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 64
            text: root.auth.responseRequired ? root.auth.message : "LOCKED"
            textFormat: Text.PlainText
            color: root.muted
            font.family: root.typeface
            font.pixelSize: 11
            font.letterSpacing: 1.5
            wrapMode: Text.Wrap
        }
        TextField {
            id: response
            Layout.fillWidth: true
            Layout.topMargin: 12
            implicitHeight: 48
            padding: 8
            focus: true
            readOnly: !root.auth.responseRequired
            echoMode: root.auth.responseRequired && root.auth.responseVisible
                ? TextInput.Normal : TextInput.Password
            passwordCharacter: "▪"
            passwordMaskDelay: 0
            color: root.foreground
            selectionColor: root.red
            selectedTextColor: root.foreground
            font.family: root.typeface
            font.pixelSize: 20
            font.letterSpacing: echoMode === TextInput.Password ? 4 : 0
            onAccepted: root.submit()
            Keys.onEscapePressed: clear()
            background: Rectangle {
                color: "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: root.status ? root.red : root.muted
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            text: root.status || (root.auth.active && !root.auth.responseRequired
                ? "Authenticating…" : "Enter to unlock")
            textFormat: Text.PlainText
            color: root.status ? root.red : root.muted
            font.family: root.typeface
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }

    Connections {
        target: root.auth
        function onResponseRequiredChanged() {
            response.clear()
            if (root.auth.responseRequired)
                response.forceActiveFocus()
        }
        function onCompleted() { response.clear() }
    }
}
