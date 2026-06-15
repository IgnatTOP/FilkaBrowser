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

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.s3 }
            spacing: Theme.s2

            Repeater {
                model: BookmarkModel
                delegate: Rectangle {
                    id: chip
                    required property string title
                    required property string url
                    required property int index

                    height: 26
                    width: Math.min(180, row.implicitWidth + Theme.s3)
                    radius: Theme.radiusSm
                    color: chipHover.hovered ? Theme.glassMed : Theme.glassLow
                    border.width: 1; border.color: Theme.glassStroke
                    scale: chipHover.hovered ? 1.04 : 1.0
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }

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
                            width: Math.min(110, implicitWidth)
                            rightPadding: chipHover.hovered ? 18 : 0
                            Behavior on rightPadding { NumberAnimation { duration: Motion.fast } }
                        }
                    }
                    // Remove affordance on hover.
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                        width: 16; height: 16; radius: 8
                        visible: chipHover.hovered
                        color: closeHover.hovered ? Theme.danger : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            name: "x"; size: 11
                            color: closeHover.hovered ? "white" : Theme.textMuted
                        }
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: BookmarkModel.removeAt(chip.index) }
                    }

                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.navigate(chip.url)
                    }
                }
            }
        }
    }
}
