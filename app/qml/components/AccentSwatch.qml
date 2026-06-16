import QtQuick
import Filka

// AccentSwatch — a circular colour choice for accent pickers. Lifts on hover and
// shows a ring + check when selected. Shared by Settings and the welcome dialog.
Item {
    id: root

    property color swatchColor: Theme.accent
    property bool selected: false
    signal clicked()

    implicitWidth: 34
    implicitHeight: 34
    activeFocusOnTab: true

    Accessible.role: Accessible.RadioButton
    Accessible.name: qsTr("Акцент") + " " + swatchColor
    Accessible.checkable: true
    Accessible.checked: selected

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.swatchColor
        scale: hover.hovered ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
    }

    Rectangle {   // selection ring
        anchors.centerIn: parent
        width: parent.width + 8
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.swatchColor
        opacity: (root.selected || root.activeFocus) ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.selected
        name: "shield-check"
        size: Math.round(root.width * 0.47)
        color: "white"
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
