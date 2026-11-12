import QtQuick

// A small fixed bitmap alphabet avoids a font dependency and stays sharp at scale.
Item {
    id: root
    required property string text
    required property color color
    readonly property var glyphs: ({
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
        ":": ["0", "1", "1", "0", "1", "1", "0"]
    })
    readonly property real pitch: width / 26
    implicitHeight: pitch * 7

    Row {
        spacing: root.pitch
        Repeater {
            model: root.text.split("")
            Item {
                id: character
                required property string modelData
                readonly property var rows: root.glyphs[modelData] || root.glyphs["0"]
                width: (modelData === ":" ? 1 : 5) * root.pitch
                height: root.height
                Repeater {
                    model: character.rows.join("").split("")
                    Rectangle {
                        required property int index
                        required property string modelData
                        readonly property int columns: character.rows[0].length
                        x: (index % columns) * root.pitch
                        y: Math.floor(index / columns) * root.pitch
                        width: root.pitch * 0.60
                        height: width
                        radius: width / 2
                        color: root.color
                        visible: modelData === "1"
                    }
                }
            }
        }
    }
}
