import QtQuick
import Filka

// BookmarksBar — a thin strip of saved-page chips under the toolbar. Lives in
// the chrome (above web content). Tap a chip to open it; the × on hover removes
// it. Collapses to 0 height when there are no bookmarks.
Item {
    id: root
    signal navigate(string url)

    implicitHeight: (BookmarkModel.count > 0) ? 36 : 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Theme.glassHairline
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.leftMargin: Theme.s2
            anchors.rightMargin: Theme.s2
            orientation: ListView.Horizontal
            spacing: Theme.s2
            model: BookmarkModel
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Chips pop in/out and shuffle aside smoothly.
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
                NumberAnimation { property: "scale"; from: 0.8; to: 1; duration: Motion.base; easing.type: Motion.emphasized }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.exit }
                NumberAnimation { property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Motion.exit }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Motion.base; easing.type: Motion.emphasized }
            }

                delegate: Rectangle {
                    id: chip
                    required property string title
                    required property string url
                    required property int index

                    width: Math.min(190, Math.max(92, row.implicitWidth + Theme.s4))
                    height: 28
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    radius: Theme.radiusSm
                    color: chipHover.hovered ? Theme.hoverFill : "transparent"
                    border.width: activeFocus ? Theme.focusWidth : 1
                    border.color: activeFocus ? Theme.focusRing : Theme.outline
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: chip.title
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        id: row
                        anchors { left: parent.left; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "globe"; size: 13; color: Theme.textMuted
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.title
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                            width: Math.min(120, implicitWidth)
                            rightPadding: chipHover.hovered || chip.activeFocus ? 18 : 0
                            Behavior on rightPadding { NumberAnimation { duration: Motion.fast } }
                        }
                    }
                    // Remove affordance on hover/focus.
                    IconButton {
                        anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                        size: 18
                        iconName: "x"
                        iconSize: 11
                        iconColor: Theme.textMuted
                        hoverColor: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
                        visible: chipHover.hovered || chip.activeFocus || activeFocus
                        Accessible.name: qsTr("Удалить закладку")
                        onClicked: BookmarkModel.removeAt(chip.index)
                    }

                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.navigate(chip.url)
                    }
                    Keys.onReturnPressed: root.navigate(chip.url)
                    Keys.onEnterPressed: root.navigate(chip.url)
                    Keys.onSpacePressed: root.navigate(chip.url)
                }
        }
    }
}
