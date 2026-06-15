import QtQuick
import Filka

// WorkspaceSwitcher — a row of workspace pills. The active pill expands to show
// its name and lights up with the workspace accent; others collapse to a glyph.
Item {
    id: root
    property var workspaces
    implicitHeight: 46
    implicitWidth: pillRow.width + Theme.s2 * 2

    Row {
        id: pillRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.workspaces

            delegate: Rectangle {
                id: pill
                required property int index
                required property string name
                required property string glyph
                required property color accent

                readonly property bool active: index === root.workspaces.activeIndex

                height: 34
                width: active ? labelRow.implicitWidth + 26 : 34
                radius: Theme.radiusPill
                color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                       : hover.hovered ? Theme.glassMed : Theme.glassLow
                border.width: 1
                border.color: active ? accent : Theme.glassStroke

                Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                HoverHandler { id: hover }
                TapHandler { onTapped: root.workspaces.activeIndex = pill.index }

                Row {
                    id: labelRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    spacing: 7

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: pill.glyph
                        size: 16
                        color: pill.active ? pill.accent : Theme.textSecondary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.active
                        text: pill.name
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
