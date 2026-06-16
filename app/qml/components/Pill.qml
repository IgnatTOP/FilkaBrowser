import QtQuick
import Filka

// Pill — stadium-shaped interactive glass surface with a centred content slot.
// The single reusable building block for small chips/buttons across the chrome
// (zoom badge, translator controls, banner actions). Set `active` for the
// selected look, or override `fillColor` for accent variants.
Item {
    id: root

    property bool interactive: true
    property bool active: false
    property real hPadding: Theme.s3
    property real radius: Theme.radiusPill

    // Fill resolves against state but can be overridden (e.g. accent gradient).
    property color fillColor: active ? Theme.accentSoft
                            : pressHandler.pressed ? Theme.glassHigh
                            : hover.hovered ? Theme.glassMed
                                            : Theme.glassLow
    property color strokeColor: active ? Theme.accent : Theme.glassStroke
    property real strokeWidth: 1

    readonly property bool hovered: hover.hovered
    default property alias content: slot.data
    signal clicked()

    implicitHeight: Theme.controlSm
    implicitWidth: slot.implicitWidth + hPadding * 2
    activeFocusOnTab: root.interactive
    Accessible.role: Accessible.Button

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.width: root.activeFocus ? Theme.focusWidth : root.strokeWidth
        border.color: root.activeFocus ? Theme.focusRing : root.strokeColor
        scale: pressHandler.pressed ? 0.96 : 1.0

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
    }

    Item {
        id: slot
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    HoverHandler { id: hover; enabled: root.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: pressHandler; enabled: root.interactive; onTapped: root.clicked() }
    Keys.onReturnPressed: if (root.interactive) root.clicked()
    Keys.onEnterPressed: if (root.interactive) root.clicked()
    Keys.onSpacePressed: if (root.interactive) root.clicked()
}
