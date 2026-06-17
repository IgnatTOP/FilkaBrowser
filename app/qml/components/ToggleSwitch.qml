import QtQuick
import Filka

// ToggleSwitch — a compact on/off switch bound to `checked`. The host owns the
// state (typically an AppSettings property); the switch just renders it and
// emits `toggled` on tap so the binding stays one-way and loop-free.
Item {
    id: root

    property bool checked: false
    property string accessibleName: ""
    signal toggled()

    implicitWidth: 50
    implicitHeight: 28
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.42

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.checkable: true
    Accessible.checked: root.checked

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : (hover.hovered ? Theme.surface : Theme.surfaceAlt)
        border.width: root.activeFocus ? Theme.focusWidth : 1
        border.color: root.activeFocus ? Theme.focusRing : Theme.outline
        scale: press.pressed ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }

        Rectangle {
            id: knob
            width: 20
            height: 20
            radius: 10
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
        }
    }

    HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: press; enabled: root.enabled; onTapped: root.toggled() }
    Keys.onReturnPressed: if (root.enabled) root.toggled()
    Keys.onEnterPressed: if (root.enabled) root.toggled()
    Keys.onSpacePressed: if (root.enabled) root.toggled()
}
