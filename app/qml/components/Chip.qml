import QtQuick
import Filka

// Chip — a selectable rounded label with an optional leading icon. One look for
// every "pick one of these" surface: theme/search-engine rows, language and
// accent choices. Selected state lights up with the accent; hover lifts the
// glass fill. Emits `clicked`.
Item {
    id: root

    property string label: ""
    property string iconName: ""
    property bool selected: false
    property color accentColor: Theme.accent
    property real radius: Theme.radiusPill
    property real hPadding: Theme.s3
    property real spacing: Theme.s1
    property real fontSize: Theme.fontSizeXs
    property int iconSize: 14

    signal clicked()

    implicitHeight: Theme.controlSm
    implicitWidth: contentRow.implicitWidth + hPadding * 2
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.46
    Accessible.role: Accessible.Button
    Accessible.name: root.label

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.selected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
             : hover.hovered ? Theme.hoverFill : Theme.surfaceAlt
        border.width: root.activeFocus ? Theme.focusWidth : 1
        border.color: root.activeFocus ? Theme.focusRing : (root.selected ? root.accentColor : Theme.outline)
        scale: press.pressed ? 0.96 : (hover.hovered ? 1.015 : 1.0)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName.length > 0
            name: root.iconName
            size: root.iconSize
            color: root.selected ? root.accentColor : Theme.textSecondary
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label.length > 0
            text: root.label
            color: root.selected ? root.accentColor : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Font.Medium
        }
    }

    HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: press; enabled: root.enabled; onTapped: root.clicked() }
    Keys.onReturnPressed: if (root.enabled) root.clicked()
    Keys.onEnterPressed: if (root.enabled) root.clicked()
    Keys.onSpacePressed: if (root.enabled) root.clicked()
}
