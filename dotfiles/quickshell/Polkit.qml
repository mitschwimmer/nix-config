import Quickshell
import Quickshell.Services.Polkit

Scope {
    id: root
    required property var palette

    PolkitAgent {
        id: agent
    }

    PolkitDialog {
        palette: root.palette
        flow: agent.flow
    }
}
