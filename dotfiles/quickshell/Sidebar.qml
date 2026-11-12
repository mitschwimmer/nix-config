import Quickshell
import Quickshell.Wayland
import QtQuick
import "SidebarLogic.js" as Logic

Scope {
    id: root
    required property var palette

    readonly property int drawerWidth: 280
    readonly property int animationDuration: 220
    readonly property int dwellDuration: 150
    readonly property int leaveDuration: 350
    readonly property int inactivityDuration: 15000
    readonly property var edges: Logic.edgeSegments(Quickshell.screens)

    property string outputName: ""
    property string side: "right"
    property bool showing: false
    property real progress: showing ? 1 : 0
    property string hoveredEdge: ""
    property string blockedEdge: ""

    Behavior on progress {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }

    function offsetFor(name) {
        return name === outputName ? (side === "left" ? 1 : -1) * drawerWidth * progress : 0
    }

    function reveal(name, edge) {
        if (progress > 0 || blockedEdge === name + ":" + edge)
            return
        outputName = name
        side = edge
        showing = true
        activity()
    }

    function activity() {
        leaveTimer.stop()
        if (showing) inactivityTimer.restart()
    }

    function leave() {
        if (showing) leaveTimer.restart()
    }

    function dismiss() {
        showing = false
        leaveTimer.stop()
        inactivityTimer.stop()
    }

    onEdgesChanged: {
        // Clear stale output references and close on any layout/hotplug change.
        dismiss()
        hoveredEdge = ""
        blockedEdge = ""
    }

    Timer { id: leaveTimer; interval: root.leaveDuration; onTriggered: root.dismiss() }
    Timer {
        id: inactivityTimer
        interval: root.inactivityDuration
        onTriggered: {
            // A pointer parked at the edge must leave before it can reopen us.
            root.blockedEdge = root.hoveredEdge
            root.dismiss()
        }
    }

    DesktopStatus { id: desktopStatus }
    AudioState { id: audioState }

    Variants {
        model: root.edges
        PanelWindow {
            id: sensor
            required property var modelData
            readonly property string edgeKey: modelData.screen.name + ":" + modelData.side
            screen: modelData.screen
            color: "transparent"
            implicitWidth: 2
            implicitHeight: modelData.height
            anchors { top: true; left: sensor.modelData.side === "left"; right: sensor.modelData.side === "right" }
            margins.top: modelData.top
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-sidebar-edge"

            MouseArea {
                id: edgeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    root.hoveredEdge = sensor.edgeKey
                    if (root.showing) root.activity()
                    else if (root.blockedEdge !== sensor.edgeKey) dwellTimer.restart()
                }
                onExited: {
                    dwellTimer.stop()
                    if (root.hoveredEdge === sensor.edgeKey) root.hoveredEdge = ""
                    if (root.blockedEdge === sensor.edgeKey) root.blockedEdge = ""
                    root.leave()
                }
                onPositionChanged: { if (root.showing) root.activity() }
            }
            Timer {
                id: dwellTimer
                interval: root.dwellDuration
                onTriggered: {
                    if (edgeMouse.containsMouse)
                        root.reveal(sensor.modelData.screen.name, sensor.modelData.side)
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        SidebarWindow {
            sidebar: root
            palette: root.palette
            status: desktopStatus
            audio: audioState
        }
    }
}
