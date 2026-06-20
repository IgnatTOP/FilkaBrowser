import QtQuick
import QtQuick.Controls.Basic
import Filka

SidePanel {
    id: root

    title: qsTr("Закладки")
    signal navigate(string url)

    property var undoStack: []

    function deleteBookmark(index, title, url) {
        undoStack = undoStack.concat([{ "index": index, "title": title, "url": url }])
        BookmarkModel.removeAt(index)
        undoTimer.restart()
        snackbar.visible = true
    }

    function undoDelete() {
        if (undoStack.length === 0)
            return

        var stack = undoStack.slice()
        var entry = stack.pop()
        undoStack = stack
        BookmarkModel.insertAt(entry.index, entry.url, entry.title)
        if (undoStack.length === 0) {
            undoTimer.stop()
            snackbar.visible = false
        } else {
            undoTimer.restart()
        }
    }

    Timer {
        id: undoTimer
        interval: 5000
        onTriggered: {
            root.undoStack = []
            snackbar.visible = false
        }
    }

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
            IconButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                iconName: "trash-2"
                size: 30
                iconSize: 15
                enabled: BookmarkModel.count > 0
                opacity: enabled ? 1 : 0.4
                iconColor: Theme.danger
                tooltip: qsTr("Очистить закладки")
                Accessible.name: qsTr("Очистить закладки")
                onClicked: BookmarkModel.clear()
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
                    tooltip: row.confirmKeyboardDelete ? qsTr("Нажмите Delete ещё раз") : qsTr("Удалить закладку")
                    Accessible.name: row.confirmKeyboardDelete ? qsTr("Подтвердить удаление закладки") : qsTr("Удалить закладку")
                    onClicked: root.deleteBookmark(row.index, row.title, row.url)
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.navigate(row.url) }
                property bool confirmKeyboardDelete: false
                Timer {
                    id: keyboardDeleteConfirmTimer
                    interval: 2200
                    onTriggered: row.confirmKeyboardDelete = false
                }
                Keys.onReturnPressed: root.navigate(row.url)
                Keys.onEnterPressed: root.navigate(row.url)
                Keys.onSpacePressed: root.navigate(row.url)
                Keys.onDeletePressed: {
                    if (!row.confirmKeyboardDelete) {
                        row.confirmKeyboardDelete = true
                        keyboardDeleteConfirmTimer.restart()
                        return
                    }
                    keyboardDeleteConfirmTimer.stop()
                    row.confirmKeyboardDelete = false
                    root.deleteBookmark(row.index, row.title, row.url)
                }
            }
        }
    }

    Rectangle {
        id: snackbar
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Theme.s5
        }
        visible: false
        opacity: visible ? 1 : 0
        width: Math.min(parent.width - Theme.s4, snackbarContent.implicitWidth + Theme.s4)
        height: snackbarContent.implicitHeight + Theme.s3
        radius: Theme.radiusPill
        color: Theme.bgRaised
        border.width: 1
        border.color: Theme.glassStroke
        z: 20
        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

        Row {
            id: snackbarContent
            anchors.centerIn: parent
            spacing: Theme.s3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Закладка удалена")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
            }

            GlassButton {
                text: qsTr("Отменить")
                enabled: root.undoStack.length > 0
                onClicked: root.undoDelete()
            }
        }
    }
}
