import Quickshell
import Quickshell.Services.Notifications

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

        NotificationWindow {
            notices: root.notices
            targetScreen: root.targetScreen
            palette: root.palette
        }
    }
}
