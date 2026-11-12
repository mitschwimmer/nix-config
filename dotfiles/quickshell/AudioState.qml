import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
    readonly property var output: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    readonly property bool outputReady: !!output && output.ready && !!output.audio
    readonly property real volume: outputReady ? output.audio.volume : 0
    readonly property bool muted: outputReady && output.audio.muted

    function selectOutput(node) {
        if (outputs.includes(node)) Pipewire.preferredDefaultAudioSink = node
    }

    function selectInput(node) {
        if (inputs.includes(node)) Pipewire.preferredDefaultAudioSource = node
    }

    function setVolume(value) {
        if (!outputReady || !Number.isFinite(value)) return
        output.audio.volume = Math.max(0, Math.min(1, value))
        if (value > 0) output.audio.muted = false
    }

    function toggleMute() {
        if (outputReady) output.audio.muted = !output.audio.muted
    }

    // Only the current devices need their live volume/mute properties bound.
    PwObjectTracker { objects: [root.output, root.input] }
}
