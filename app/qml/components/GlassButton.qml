import QtQuick
import QtQuick.Controls.Basic
import Filka

// GlassButton — pill-shaped glass control with hover/press motion and an
// optional accent (filled) variant for primary actions.
Button {
    id: control

    property bool accentVariant: false
    property color accentColor: Theme.accent

    implicitHeight: 36
    leftPadding: 18
    rightPadding: 18
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSm
    font.weight: Font.Medium

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.accentVariant ? "white" : Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusPill
        color: control.accentVariant
               ? (control.pressed ? Qt.darker(control.accentColor, 1.15) : control.accentColor)
               : (control.pressed ? Theme.glassHigh
                  : control.hovered ? Theme.glassMed : Theme.glassLow)
        border.width: control.accentVariant ? 0 : 1
        border.color: Theme.glassStroke

        scale: control.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
}
