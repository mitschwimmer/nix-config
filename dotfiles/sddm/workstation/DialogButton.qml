import QtQuick
import QtQuick.Controls

Button {
    id: button
    required property var colors
    property bool primary: false

    implicitWidth: primary ? 124 : 104
    implicitHeight: 36
    font.family: colors.fontFamily
    font.pixelSize: 11

    background: Rectangle {
        radius: 5
        color: button.primary ? button.colors.red : button.colors.tile
        border.width: 1
        border.color: button.primary ? button.colors.red : button.colors.line
        opacity: button.enabled ? 1 : 0.45
    }

    contentItem: Text {
        text: button.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font: button.font
        color: button.primary ? "#FFFFFF" : button.colors.foreground
        opacity: button.enabled ? 1 : 0.6
    }
}
