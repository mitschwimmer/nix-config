import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel

Scope {
    id: root

    // ---- User settings ----------------------------------------------------
    readonly property string wallpaperDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property int rotationInterval: 5 * 60 * 1000
    readonly property int crossfadeDuration: 1500

    readonly property real occupiedSaturation: -1 // -1 is monochrome
    readonly property real occupiedBlur: 0.65        // 0..1, scaled by blurMax
    readonly property int blurMax: 32                // pixels; keep constant
    readonly property real occupiedDarkness: 0.30    // black overlay opacity

    readonly property int darkenDuration: 180
    readonly property int lightenDuration: 450
    readonly property int desaturateDuration: 350
    readonly property int resaturateDuration: 700
    readonly property int blurDuration: 700
    readonly property int sharpenDuration: 300
    // -----------------------------------------------------------------------

    property var workspaces: []
    property bool overviewOpen: false

    property var wallpaperOrder: []
    property int wallpaperIndex: 0
    property url wallpaperA: ""
    property url wallpaperB: ""
    property bool showB: false
    property bool wallpapersInitialized: false

    function shuffled(values) {
        const result = [...values]
        for (let i = result.length - 1; i > 0; --i) {
            const j = Math.floor(Math.random() * (i + 1))
            const temporary = result[i]
            result[i] = result[j]
            result[j] = temporary
        }
        return result
    }

    function initializeWallpapers() {
        if (wallpapersInitialized || wallpaperFiles.status !== FolderListModel.Ready)
            return

        const files = []
        for (let i = 0; i < wallpaperFiles.count; ++i)
            files.push(wallpaperFiles.get(i, "fileUrl"))

        wallpaperOrder = shuffled(files)
        wallpapersInitialized = true

        if (wallpaperOrder.length === 0) {
            console.warn("No wallpapers found in " + wallpaperDirectory)
            return
        }

        wallpaperA = wallpaperOrder[0]
        wallpaperB = wallpaperOrder[wallpaperOrder.length > 1 ? 1 : 0]
    }

    function advanceWallpaper() {
        if (wallpaperOrder.length < 2)
            return

        const nextIndex = (wallpaperIndex + 1) % wallpaperOrder.length

        // The hidden image is already preloaded; reassigning is harmless and
        // also keeps this correct if the timer fires unusually late.
        if (showB)
            wallpaperA = wallpaperOrder[nextIndex]
        else
            wallpaperB = wallpaperOrder[nextIndex]

        wallpaperIndex = nextIndex
        showB = !showB
        preloadTimer.restart()
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

            workspaces = workspaces.map(workspace =>
                workspace.output === active.output
                    ? Object.assign({}, workspace, { is_active: workspace.id === activation.id })
                    : workspace)
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

    FolderListModel {
        id: wallpaperFiles
        folder: "file://" + root.wallpaperDirectory
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif"]
        caseSensitive: false
        showDirs: false
        showOnlyReadable: true
        onStatusChanged: root.initializeWallpapers()
    }

    Component.onCompleted: initializeWallpapers()

    Timer {
        interval: root.rotationInterval
        running: root.wallpaperOrder.length > 1
        repeat: true
        onTriggered: root.advanceWallpaper()
    }

    Timer {
        id: preloadTimer
        interval: root.crossfadeDuration + 100
        onTriggered: {
            const next = root.wallpaperOrder[(root.wallpaperIndex + 1) % root.wallpaperOrder.length]
            if (root.showB)
                root.wallpaperA = next
            else
                root.wallpaperB = next
        }
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaper
            required property var modelData
            readonly property bool muted: root.overviewOpen
                || root.activeWorkspaceHasWindow(modelData.name)

            screen: modelData
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {} // Do not consume pointer input on empty workspaces.

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-niri-wallpaper"

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: wallpaper.muted ? root.occupiedSaturation : 0
                    blurEnabled: true
                    blur: wallpaper.muted ? root.occupiedBlur : 0
                    blurMax: root.blurMax
                    autoPaddingEnabled: false

                    Behavior on saturation {
                        NumberAnimation {
                            duration: wallpaper.muted
                                ? root.desaturateDuration
                                : root.resaturateDuration
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on blur {
                        NumberAnimation {
                            duration: wallpaper.muted
                                ? root.blurDuration
                                : root.sharpenDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.wallpaperA
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: root.showB ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.crossfadeDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.wallpaperB
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: root.showB ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.crossfadeDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: wallpaper.muted ? root.occupiedDarkness : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: wallpaper.muted
                            ? root.darkenDuration
                            : root.lightenDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
