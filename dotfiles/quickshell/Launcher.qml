import Quickshell
import Quickshell.Io
import QtQuick
import "LauncherLogic.js" as Logic

Scope {
    id: root
    required property var niriState
    required property var palette
    required property var sidebar

    // Escape hatches for mislabelled desktop files and an icon-free appearance.
    property var excludedIds: []
    property bool showIcons: true
    property bool showing: false
    property string outputName: ""
    property string query: ""
    property int selectedIndex: 0
    readonly property var results: Logic.applications(
        DesktopEntries.applications.values, query, excludedIds)

    function open() {
        const screens = Quickshell.screens
        const output = screens.find(screen => screen.name === niriState.focusedOutput)
            || screens[0]
        if (!output) return
        query = ""
        selectedIndex = 0
        outputName = output.name
        sidebar.dismiss()
        showing = true
    }

    function dismiss() {
        showing = false
        query = ""
        selectedIndex = 0
    }

    function toggle() {
        if (showing) dismiss()
        else open()
    }

    function moveSelection(delta) {
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta))
    }

    function launch(index) {
        const entry = results[index]
        if (!entry) return
        // Use the parsed desktop command and its working directory, never a shell.
        dismiss()
        entry.execute()
    }

    onResultsChanged: selectedIndex = 0

    Connections {
        target: Quickshell
        function onScreensChanged() { root.dismiss() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.dismiss() }
    }

    Variants {
        model: Quickshell.screens
        LauncherWindow {
            launcher: root
            palette: root.palette
        }
    }
}
