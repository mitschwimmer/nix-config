import QtQuick
import QtQuick.Controls

Button {
    id: button
    required property var colors
    property bool primary: false

    implicitWidth: primary ? 138 : 98
    implicitHeight: 36
    font.family: colors.fontFamily
    font.pixelSize: primary ? 14 : 11
    font.bold: primary
    font.letterSpacing: primary ? 1.5 : 0.75

    background: Item {}

    contentItem: Text {
        text: button.text
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        font: button.font
        color: button.primary ? button.colors.red : button.colors.muted
        opacity: button.enabled ? 1 : 0.45
    }
}
