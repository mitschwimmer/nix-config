import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    readonly property var backgrounds: JSON.parse(Quickshell.env("WORKSTATION_LOCK_BACKGROUNDS") || "{}")
    property string message: ""
    property bool notified: false

    function retry() {
        if (!pam.active) {
            message = ""
            if (!pam.start())
                message = "Authentication unavailable. Try again."
        }
    }

    // A response to a lock request is only successful after compositor acknowledgement.
    Process {
        id: ready
        command: [Quickshell.env("WORKSTATION_LOCK_NOTIFY"), "--ready"]
    }

    PamContext {
        id: pam
        config: "quickshell-lock"
        onCompleted: result => {
            if (result === PamResult.Success) {
                lock.locked = false
                Quickshell.quit()
            } else {
                root.message = result === PamResult.Error
                    ? "Authentication unavailable. Try again."
                    : "Authentication failed. Try again."
                retryDelay.restart()
            }
        }
    }

    Timer {
        id: retryDelay
        interval: 500
        onTriggered: {
            if (!pam.active && !pam.start())
                root.message = "Authentication unavailable. Press Enter to retry."
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        onSecureChanged: {
            if (secure && !root.notified) {
                root.notified = true
                ready.running = true
                root.retry()
            }
        }

        LockSurface {
            auth: pam
            status: root.message
            background: screen ? (root.backgrounds[screen.name] || "") : ""
            onRetryRequested: root.retry()
        }
    }
}
