import QtQuick
import Filka

// ToggleSwitch — a compact on/off switch bound to `checked`. The host owns the
// state (typically an AppSettings property); the switch just renders it and
// emits `toggled` on tap so the binding stays one-way and loop-free.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 50
    implicitHeight: 28
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: root.checked

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : (hover.hovered ? Theme.glassHigh : Theme.glassMed)
        border.width: root.activeFocus ? Theme.focusWidth : 1
        border.color: root.activeFocus ? Theme.focusRing : Theme.glassStroke
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

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

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled() }
    Keys.onReturnPressed: root.toggled()
    Keys.onEnterPressed: root.toggled()
    Keys.onSpacePressed: root.toggled()
}
