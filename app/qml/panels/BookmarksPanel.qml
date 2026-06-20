import QtQuick
import QtQuick.Controls.Basic
import Filka

SidePanel {
    id: root

    title: qsTr("Закладки")
    signal navigate(string url)

    Column {
        anchors.fill: parent
        spacing: Theme.s2

        Item {
            width: parent.width
            height: 30
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: BookmarkModel.count + " " + Theme.plural(BookmarkModel.count, qsTr("закладка"), qsTr("закладки"), qsTr("закладок"))
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
            }
            ConfirmActionButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                iconName: "trash-2"
                size: 30
                iconSize: 15
                enabled: BookmarkModel.count > 0
                opacity: enabled ? 1 : 0.4
                idleAccessibleName: qsTr("Очистить все закладки")
                confirmAccessibleName: qsTr("Подтвердить очистку всех закладок")
                idleTooltip: qsTr("Очистить закладки")
                confirmTooltip: qsTr("Нажмите ещё раз, чтобы очистить закладки")
                onConfirmed: BookmarkModel.clear()
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.s3
            visible: BookmarkModel.count === 0
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "bookmark"
                size: 40
                color: Theme.textMuted
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Закладок пока нет")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 38
            visible: BookmarkModel.count > 0
            clip: true
            spacing: 3
            model: BookmarkModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FilkaScrollBar {}

            delegate: Rectangle {
                id: row
                required property int index
                required property string title
                required property string url

                width: ListView.view.width
                height: 56
                radius: Theme.radiusSm
                color: hover.hovered ? Theme.hoverFill : "transparent"
                border.width: activeFocus ? Theme.focusWidth : 0
                border.color: Theme.focusRing
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: row.title
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Icon {
                    id: glyph
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: "bookmark"
                    size: 16
                    color: Theme.accent
                }

                Column {
                    anchors { left: glyph.right; right: removeBtn.left; verticalCenter: parent.verticalCenter
                              leftMargin: Theme.s3; rightMargin: Theme.s2 }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.title
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: row.url
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        elide: Text.ElideMiddle
                    }
                }

                IconButton {
                    id: removeBtn
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    opacity: hover.hovered || row.activeFocus ? 1 : 0
                    visible: opacity > 0.01
                    iconName: "x"
                    size: 26
                    iconSize: 13
                    tooltip: qsTr("Удалить закладку")
                    Accessible.name: qsTr("Удалить закладку %1").arg(row.title)
                    onClicked: {
                        var removed = { title: row.title, url: row.url }
                        BookmarkModel.removeAt(row.index)
                        undoToast.show(qsTr("Закладка удалена"), function() {
                            BookmarkModel.add(removed.url, removed.title)
                        })
                    }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.navigate(row.url) }
                Keys.onReturnPressed: root.navigate(row.url)
                Keys.onEnterPressed: root.navigate(row.url)
                Keys.onSpacePressed: root.navigate(row.url)
            }
        }

        UndoToast {
            id: undoToast
            parent: Overlay.overlay
        }
    }
}
