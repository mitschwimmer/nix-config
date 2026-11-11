import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property var workspaces: []
    property bool overviewOpen: false
    readonly property string focusedOutput: {
        const focused = workspaces.find(workspace => workspace.is_focused)
        return focused ? focused.output : ""
    }

    function patchWorkspace(id, values) {
        workspaces = workspaces.map(workspace =>
            workspace.id === id ? Object.assign({}, workspace, values) : workspace)
    }

    function handleNiriEvent(line) {
        if (!line.trim())
            return

        let event
        try {
            event = JSON.parse(line)
        } catch (error) {
            console.warn("Ignoring malformed niri event: " + error)
            return
        }

        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces
            return
        }

        if (event.WorkspaceActiveWindowChanged) {
            const change = event.WorkspaceActiveWindowChanged
            patchWorkspace(change.workspace_id, {
                active_window_id: change.active_window_id
            })
            return
        }

        if (event.WorkspaceActivated) {
            const activation = event.WorkspaceActivated
            const active = workspaces.find(workspace => workspace.id === activation.id)
            if (!active)
                return

            workspaces = workspaces.map(workspace => Object.assign({}, workspace, {
                is_active: workspace.output === active.output
                    ? workspace.id === activation.id : workspace.is_active,
                is_focused: activation.focused
                    ? workspace.id === activation.id : workspace.is_focused
            }))
            return
        }

        if (event.OverviewOpenedOrClosed)
            overviewOpen = event.OverviewOpenedOrClosed.is_open
    }

    function activeWorkspaceHasWindow(outputName) {
        const active = workspaces.find(workspace =>
            workspace.output === outputName && workspace.is_active)
        return active !== undefined
            && active.active_window_id !== null
            && active.active_window_id !== undefined
    }

    Process {
        id: niriEvents
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => root.handleNiriEvent(data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("niri event stream: " + data)
        }

        onExited: {
            console.warn("niri event stream stopped; reconnecting")
            reconnectTimer.restart()
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: niriEvents.running = true
    }

}
