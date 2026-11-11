import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    required property var modelData
    required property var notices
    required property string targetScreen
    required property var palette

    screen: modelData
    visible: root.notices.length > 0 && modelData.name === targetScreen
    width: 400
    height: stack.implicitHeight + 20
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; right: true }
    margins { top: 24; right: 24 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    Column {
        id: stack
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 10

        Repeater {
            model: root.notices

            NotificationCard {
                required property var modelData
                notification: modelData
                palette: root.palette
                width: stack.width
            }
        }
    }
}
