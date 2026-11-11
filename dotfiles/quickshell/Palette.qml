import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    readonly property string colorSchemeKey: "/org/gnome/desktop/interface/color-scheme"
    property bool dark: true

    readonly property color surface: dark ? "#0E0E0E" : "#FFFFFF"
    readonly property color tile: dark ? "#1A1A1A" : "#F1F1F1"
    readonly property color line: dark ? "#2A2A2A" : "#D9D9D9"
    readonly property color muted: dark ? "#8C8C8C" : "#4A4A4A"
    readonly property color foreground: dark ? "#F2F2F2" : "#1A1A1A"
    readonly property color red: "#D71921"
    readonly property string font: "JetBrainsMono Nerd Font"

    function setDark(value) {
        dark = value
        Quickshell.execDetached([
            "dconf", "write", colorSchemeKey,
            value ? "'prefer-dark'" : "'prefer-light'"
        ])
    }

    function refresh() {
        if (!schemeRead.running)
            schemeRead.running = true
    }

    IpcHandler {
        target: "theme"
        function toggle(): void { root.setDark(!root.dark) }
        function light(): void { root.setDark(false) }
        function dark(): void { root.setDark(true) }
    }

    // Follow the same setting that GTK applications and the existing aliases use.
    Process {
        id: schemeRead
        command: ["dconf", "read", root.colorSchemeKey]
        running: true
        stdout: SplitParser {
            onRead: line => root.dark = !line.includes("prefer-light")
        }
    }

    Process {
        command: ["dconf", "watch", root.colorSchemeKey]
        running: true
        stdout: SplitParser {
            onRead: line => root.refresh()
        }
    }
}
