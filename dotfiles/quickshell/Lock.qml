import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

Scope {
    id: root
    required property var palette

    property bool engaged: false
    property bool responseRequired: false
    property string prompt: "Password"
    property string errorMessage: ""

    function lock() {
        if (engaged)
            return
        prompt = "Password"
        errorMessage = ""
        responseRequired = false
        engaged = true
    }

    function respond(value) {
        if (engaged && pam.responseRequired) {
            responseRequired = false
            pam.respond(value)
        }
    }

    PamContext {
        id: pam
        config: "quickshell"

        onPamMessage: {
            root.responseRequired = pam.responseRequired
            if (pam.messageIsError)
                root.errorMessage = pam.message
            else
                root.prompt = pam.message
        }

        onCompleted: result => {
            root.responseRequired = false
            if (result === PamResult.Success) {
                root.engaged = false
                root.errorMessage = ""
            } else if (root.engaged) {
                root.errorMessage = "Authentication failed — try again"
                retry.restart()
            }
        }

        onError: error => {
            console.warn("Locker PAM error: " + error)
        }
    }

    Timer {
        id: retry
        interval: 600
        onTriggered: {
            if (root.engaged && !pam.active)
                pam.start()
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.engaged

        onSecureChanged: {
            // Begin authentication only once the compositor has covered all screens.
            if (secure && root.engaged && !pam.active)
                pam.start()
        }

        LockSurface {
            palette: root.palette
            prompt: root.prompt
            errorMessage: root.errorMessage
            responseRequired: root.responseRequired
            responseVisible: pam.responseVisible
            onSubmitted: response => root.respond(response)
        }
    }
}
