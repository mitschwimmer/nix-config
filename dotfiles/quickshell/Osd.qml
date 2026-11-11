import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

Scope {
    id: root
    required property var niriState
    required property var palette

    property bool showing: false
    property string heading: ""
    property string valueText: ""
    property real level: 0
    property bool showLevel: true
    property int pendingBrightness: 0

    readonly property string targetScreen: niriState.focusedOutput !== ""
        ? niriState.focusedOutput
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    function present(title, value, fraction, withLevel) {
        heading = title
        valueText = value
        level = Math.max(0, Math.min(1, fraction))
        showLevel = withLevel
        showing = true
        hideTimer.restart()
    }

    function volumeChange(delta) {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio)
            return
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta))
        if (delta > 0)
            sink.audio.muted = false
        present("VOLUME", sink.audio.muted ? "MUTED" : Math.round(sink.audio.volume * 100) + "%",
                sink.audio.volume, true)
    }

    function volumeMute() {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio)
            return
        sink.audio.muted = !sink.audio.muted
        present("VOLUME", sink.audio.muted ? "MUTED" : Math.round(sink.audio.volume * 100) + "%",
                sink.audio.volume, true)
    }

    function micMute() {
        const source = Pipewire.defaultAudioSource
        if (!source || !source.audio)
            return
        source.audio.muted = !source.audio.muted
        present("MICROPHONE", source.audio.muted ? "MUTED" : "ACTIVE",
                source.audio.muted ? 0 : source.audio.volume, true)
    }

    function media(action) {
        const players = Mpris.players.values
        const player = players.find(p => p.isPlaying) || players[0]
        if (!player)
            return

        if (action === "toggle" && player.canTogglePlaying)
            player.togglePlaying()
        else if (action === "stop" && player.canControl)
            player.stop()
        else if (action === "previous" && player.canGoPrevious)
            player.previous()
        else if (action === "next" && player.canGoNext)
            player.next()
        else
            return

        present("MEDIA", player.trackTitle || player.identity, 0, false)
    }

    function brightnessChange(direction) {
        pendingBrightness += direction
        flushBrightness()
    }

    function flushBrightness() {
        if (pendingBrightness === 0 || brightnessProcess.running)
            return
        const steps = pendingBrightness
        pendingBrightness = 0
        const amount = Math.min(100, Math.abs(steps) * 3)
        brightnessProcess.command = ["brightnessctl", "-m", "set",
            steps > 0 ? "+" + amount + "%" : amount + "%-"]
        brightnessProcess.running = true
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Process {
        id: brightnessProcess
        running: false
        stdout: SplitParser {
            onRead: line => {
                const match = line.match(/(\d+)%/)
                if (match)
                    root.present("BRIGHTNESS", match[1] + "%", Number(match[1]) / 100, true)
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn("brightnessctl: " + line)
        }
        onExited: root.flushBrightness()
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.showing = false
    }

    IpcHandler {
        target: "osd"
        function volumeUp(): void { root.volumeChange(0.05) }
        function volumeDown(): void { root.volumeChange(-0.05) }
        function volumeMute(): void { root.volumeMute() }
        function micMute(): void { root.micMute() }
        function mediaPlayPause(): void { root.media("toggle") }
        function mediaStop(): void { root.media("stop") }
        function mediaPrevious(): void { root.media("previous") }
        function mediaNext(): void { root.media("next") }
        function brightnessUp(): void { root.brightnessChange(1) }
        function brightnessDown(): void { root.brightnessChange(-1) }
    }

    Variants {
        model: Quickshell.screens

        OsdWindow {
            required property var modelData
            palette: root.palette
            targetScreen: root.targetScreen
            showing: root.showing
            heading: root.heading
            valueText: root.valueText
            level: root.level
            showLevel: root.showLevel
        }
    }
}
