import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: root
    required property var palette
    required property var audio
    required property var sidebar
    spacing: 12

    component DeviceSelector: Column {
        id: selector
        required property string heading
        required property var devices
        required property var current
        signal selected(var node)
        property bool expanded: false
        width: root.width
        spacing: 6

        Text {
            text: selector.heading
            font.family: root.palette.font
            font.pixelSize: 10
            font.letterSpacing: 1
            color: root.palette.muted
        }
        Button {
            id: toggle
            width: parent.width
            implicitHeight: Math.max(44, contentItem.implicitHeight + 20)
            enabled: selector.devices.length > 0
            text: selector.current
                ? selector.current.description || selector.current.nickname || selector.current.name
                : selector.devices.length ? "Select a device" : "No devices available"
            Accessible.name: selector.heading + ": " + text
            onClicked: { selector.expanded = !selector.expanded; root.sidebar.activity() }
            background: Rectangle {
                radius: 8
                color: toggle.hovered || toggle.down ? root.palette.line : root.palette.tile
                border.width: selector.expanded ? 1 : 0
                border.color: root.palette.foreground
            }
            contentItem: RowLayout {
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: toggle.text
                    wrapMode: Text.Wrap
                    font.family: root.palette.font
                    font.pixelSize: 11
                    color: toggle.enabled ? root.palette.foreground : root.palette.muted
                }
                Text {
                    text: selector.expanded ? "−" : "+"
                    font.family: root.palette.font
                    font.pixelSize: 16
                    color: root.palette.muted
                }
            }
        }
        // Expand inside the drawer so its input region and scrolling contain
        // the whole list, including on small or fractionally scaled outputs.
        Column {
            width: parent.width
            visible: selector.expanded
            spacing: 4
            Repeater {
                model: selector.devices
                Button {
                    id: deviceButton
                    required property var modelData
                    readonly property bool current: selector.current === modelData
                    width: selector.width
                    implicitHeight: Math.max(40, contentItem.implicitHeight + 16)
                    text: modelData.description || modelData.nickname || modelData.name
                    Accessible.name: selector.heading + ": " + text + (current ? ", selected" : "")
                    onClicked: {
                        selector.selected(modelData)
                        selector.expanded = false
                        root.sidebar.activity()
                    }
                    background: Rectangle {
                        radius: 6
                        color: deviceButton.hovered || deviceButton.down ? root.palette.tile : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 5; height: 5; radius: 3
                            color: deviceButton.current ? root.palette.red : root.palette.line
                        }
                        Text {
                            Layout.fillWidth: true
                            text: deviceButton.text
                            wrapMode: Text.Wrap
                            font.family: root.palette.font
                            font.pixelSize: 11
                            color: root.palette.foreground
                        }
                    }
                }
            }
        }
    }

    DeviceSelector {
        id: outputSelector
        heading: "OUTPUT"
        devices: root.audio.outputs
        current: root.audio.output
        onSelected: node => root.audio.selectOutput(node)
    }
    RowLayout {
        width: parent.width
        Button {
            id: mute
            text: root.audio.muted ? "Unmute" : "Mute"
            enabled: root.audio.outputReady
            font.family: root.palette.font
            font.pixelSize: 10
            Accessible.name: text + " output"
            onClicked: { root.audio.toggleMute(); root.sidebar.activity() }
            background: Rectangle {
                radius: 6
                color: mute.hovered || mute.down ? root.palette.line : root.palette.tile
            }
            contentItem: Text {
                text: mute.text
                font: mute.font
                color: mute.enabled ? root.palette.foreground : root.palette.muted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.audio.outputReady ? Math.round(root.audio.volume * 100) + "%" : "—"
            font.family: root.palette.font
            font.pixelSize: 12
            color: root.audio.muted ? root.palette.muted : root.palette.foreground
        }
    }
    Slider {
        id: volume
        width: parent.width
        from: 0; to: 1; stepSize: 0.01
        enabled: root.audio.outputReady
        value: root.audio.volume
        implicitHeight: 32
        Accessible.name: "Output volume"
        onMoved: { root.audio.setVolume(value); root.sidebar.activity() }
        background: Rectangle {
            x: volume.leftPadding
            y: volume.topPadding + volume.availableHeight / 2 - height / 2
            width: volume.availableWidth
            height: 4; radius: 2
            color: root.palette.line
            Rectangle {
                width: volume.visualPosition * parent.width
                height: parent.height; radius: 2
                color: root.audio.muted || !volume.enabled ? root.palette.muted : root.palette.foreground
            }
        }
        handle: Rectangle {
            x: volume.leftPadding + volume.visualPosition * (volume.availableWidth - width)
            y: volume.topPadding + volume.availableHeight / 2 - height / 2
            width: 16; height: 16; radius: 8
            color: volume.enabled ? root.palette.foreground : root.palette.muted
            border.width: volume.pressed ? 2 : 0
            border.color: root.palette.red
        }
    }
    DeviceSelector {
        id: inputSelector
        heading: "INPUT"
        devices: root.audio.inputs
        current: root.audio.input
        onSelected: node => root.audio.selectInput(node)
    }

    Connections {
        target: root.sidebar
        function onShowingChanged() {
            if (!root.sidebar.showing) {
                outputSelector.expanded = false
                inputSelector.expanded = false
            }
        }
    }
}
