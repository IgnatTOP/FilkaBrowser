import QtQuick
import QtQuick.Controls.Basic
import Filka

// FilkaScrollBar — the app-wide scrollbar look: a thin, rounded, auto-hiding
// handle with no track, tinted from the theme. Works for both orientations.
// Drop it in anywhere a ScrollBar is expected:
//   ScrollBar.vertical: FilkaScrollBar {}
ScrollBar {
    id: control

    policy: ScrollBar.AsNeeded
    minimumSize: 0.08
    padding: 2
    implicitWidth: 11
    implicitHeight: 11

    // Fade the whole bar in while scrolling or hovering, out when idle.
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: width / 2
        color: control.pressed ? Theme.textSecondary
             : control.hovered ? Theme.textMuted
                               : Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.55)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    background: null
}
