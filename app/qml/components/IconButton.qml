import QtQuick
import QtQuick.Controls.Basic
import Filka

// IconButton — square glass control wrapping a single themed Icon. Consistent
// sizing, hover/press motion and an optional active accent state.
Button {
    id: control

    property string iconName: ""
    property color iconColor: Theme.textSecondary
    property color hoverColor: Theme.hoverFill
    property real size: Theme.controlMd
    property real iconSize: Math.round(size * 0.52)
    property bool active: false
    property string tooltip: Accessible.name

    implicitWidth: size
    implicitHeight: size
    focusPolicy: Qt.TabFocus
    Accessible.role: Accessible.Button
    ToolTip.text: tooltip
    ToolTip.visible: enabled && hovered && tooltip.length > 0
    ToolTip.delay: 520

    // Enable/disable dimming and show/hide fades glide instead of snapping.
    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

    contentItem: Icon {
        name: control.iconName
        size: control.iconSize
        color: control.active ? Theme.accent
             : !control.enabled ? Theme.textMuted
             : (control.hovered ? Theme.textPrimary : control.iconColor)
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: !control.enabled ? "transparent"
             : control.pressed ? Theme.glassHigh
             : (control.hovered || control.active) ? control.hoverColor : "transparent"
        border.width: control.activeFocus ? Theme.focusWidth : (control.active ? 1 : 0)
        border.color: control.activeFocus ? Theme.focusRing : Theme.glassStroke
        scale: control.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }
}
