import QtQuick
import QtQuick.Controls.Basic
import Filka

// IconButton — square glass control wrapping a single themed Icon. Consistent
// sizing, hover/press motion and an optional active accent state.
Button {
    id: control

    property string iconName: ""
    property color iconColor: Theme.textSecondary
    property color hoverColor: Theme.glassMed
    property real size: 34
    property real iconSize: Math.round(size * 0.52)
    property bool active: false

    implicitWidth: size
    implicitHeight: size

    contentItem: Icon {
        name: control.iconName
        size: control.iconSize
        color: control.active ? Theme.accent
             : !control.enabled ? Theme.textMuted
             : (control.hovered ? Theme.textPrimary : control.iconColor)
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.pressed ? Theme.glassHigh
             : (control.hovered || control.active) ? control.hoverColor : "transparent"
        scale: control.pressed ? 0.9 : (control.hovered ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
}
