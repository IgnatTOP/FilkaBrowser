import QtQuick
import QtQuick.Controls.Basic
import Filka

Popup {
    id: popup

    property var suggestions: []
    property int highlight: -1
    property real anchorHeight: 0
    signal accepted(int index)

    y: anchorHeight + 6
    x: 0
    width: parent ? parent.width : implicitWidth
    padding: 6
    visible: suggestions.length > 0
    closePolicy: Popup.NoAutoClose
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
        NumberAnimation { property: "y"; from: popup.anchorHeight - 2; to: popup.anchorHeight + 6; duration: Motion.base; easing.type: Motion.emphasized }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant }
    }
    background: Rectangle {
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
    }

    contentItem: Column {
        spacing: 2
        Repeater {
            model: popup.suggestions
            delegate: Rectangle {
                id: srow
                required property int index
                required property var modelData
                width: parent ? parent.width : 0
                height: 38
                radius: Theme.radiusSm
                color: (srow.index === popup.highlight || rowHover.hovered) ? Theme.activeFill : "transparent"

                Icon {
                    id: kindIcon
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: srow.modelData.kind === "search" || srow.modelData.kind === "suggest" ? "search"
                        : srow.modelData.kind === "bookmark" ? "bookmark"
                        : srow.modelData.kind === "quicklink" ? "zap"
                        : srow.modelData.kind === "go" ? "globe" : "history"
                    size: 16
                    color: srow.modelData.kind === "search" || srow.modelData.kind === "go" || srow.modelData.kind === "suggest"
                           ? Theme.accent : Theme.textMuted
                }
                Column {
                    anchors { left: kindIcon.right; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: srow.modelData.title
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: srow.modelData.label
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: popup.accepted(srow.index) }
            }
        }
    }
}
