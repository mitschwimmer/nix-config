import Quickshell.Wayland
import QtQuick

WlSessionLockSurface {
    id: root

    required property var palette
    required property string prompt
    required property string errorMessage
    required property bool responseRequired
    required property bool responseVisible

    signal submitted(string response)

    color: palette.surface

    AuthPanel {
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight

        palette: root.palette
        mode: "SESSION LOCKED"
        userName: "henner"
        prompt: root.prompt
        errorMessage: root.errorMessage
        responseRequired: root.responseRequired
        responseVisible: root.responseVisible
        onSubmitted: response => root.submitted(response)
    }
}
