import Quickshell
import Quickshell.Services.Greetd
import QtQuick

Scope {
    id: root

    property string prompt: "Waiting for authentication"
    property string errorMessage: ""
    property bool responseRequired: false
    property bool responseVisible: false

    function begin() {
        if (!Greetd.available) {
            errorMessage = "greetd is not available"
            return
        }
        Greetd.createSession("henner")
    }

    Palette {
        id: colors
        syncWithDesktop: false
    }

    Component.onCompleted: root.begin()

    Timer {
        id: retry
        interval: 500
        onTriggered: root.begin()
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.prompt = message
            root.responseRequired = responseRequired
            root.responseVisible = echoResponse
            if (error)
                root.errorMessage = message
            else if (responseRequired)
                root.errorMessage = ""
        }

        function onAuthFailure(message) {
            root.errorMessage = message
            root.responseRequired = false
            retry.restart()
        }

        function onReadyToLaunch() {
            Greetd.launch(["/run/current-system/sw/bin/niri-session"])
        }

        function onError(message) {
            root.errorMessage = message
            root.responseRequired = false
        }
    }

    // Cage presents this sole xdg-toplevel as a maximized login screen.
    FloatingWindow {
        color: colors.surface
        title: "Login"
        implicitWidth: 900
        implicitHeight: 600

        AuthPanel {
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight

            palette: colors
            mode: "WELCOME BACK"
            userName: "henner"
            prompt: root.prompt
            errorMessage: root.errorMessage
            responseRequired: root.responseRequired
            responseVisible: root.responseVisible

            onSubmitted: response => {
                if (!root.responseRequired)
                    return
                root.responseRequired = false
                Greetd.respond(response)
            }
        }
    }
}
