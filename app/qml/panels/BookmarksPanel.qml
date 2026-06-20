import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

SidePanel {
    id: root

    title: qsTr("Закладки")
    signal navigate(string url)

    property bool confirmClear: false
    property var undoSnapshot: []

    function clearWithUndo() {
        root.undoSnapshot = BookmarkModel.all()
        BookmarkModel.clear()
        undoToast.message = qsTr("Закладки очищены")
        undoToast.open()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.s2

        Item {
            id: toolbar
            width: parent.width
            height: 30
            Timer {
                id: clearConfirmTimer
                interval: 2200
                onTriggered: root.confirmClear = false
            }
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
                active: root.confirmClear
                tooltip: root.confirmClear ? qsTr("Подтвердить") : qsTr("Очистить закладки")
                Accessible.name: root.confirmClear ? qsTr("Подтвердить очистку закладок") : qsTr("Очистить закладки")
                onClicked: {
                    if (!root.confirmClear) {
                        root.confirmClear = true
                        clearConfirmTimer.restart()
                        return
                    }
                    clearConfirmTimer.stop()
                    root.confirmClear = false
                    root.clearWithUndo()
                }
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
            height: parent.height - toolbar.height - Theme.s2
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
                    Accessible.name: qsTr("Удалить закладку")
                    onClicked: BookmarkModel.removeAt(row.index)
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.navigate(row.url) }
                Keys.onReturnPressed: root.navigate(row.url)
                Keys.onEnterPressed: root.navigate(row.url)
                Keys.onSpacePressed: root.navigate(row.url)
            }
        }
    }

    Popup {
        id: undoToast
        property string message: ""
        parent: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - Theme.s6
        padding: 0
        implicitWidth: toastBody.implicitWidth
        implicitHeight: toastBody.implicitHeight
        Timer {
            id: undoToastTimer
            interval: 5000
            onTriggered: undoToast.close()
        }
        onOpened: undoToastTimer.restart()
        onClosed: root.undoSnapshot = []
        background: Rectangle {
            radius: Theme.radiusPill
            color: Theme.bgRaised
            border.width: 1
            border.color: Theme.glassStroke
        }
        contentItem: RowLayout {
            id: toastBody
            spacing: Theme.s2
            anchors.margins: Theme.s2
            Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                name: "bookmark"
                size: 15
                color: Theme.accent
            }
            Text {
                text: undoToast.message
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
            }
            GlassButton {
                text: qsTr("Отменить")
                Accessible.name: qsTr("Восстановить очищенные закладки")
                onClicked: {
                    BookmarkModel.restore(root.undoSnapshot)
                    undoToast.close()
                }
            }
        }
    }
}
