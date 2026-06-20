import QtQuick
import QtQuick.Controls.Basic
import Filka

// HistoryPanel — lists visited pages (most recent first) from the shared
// HistoryModel. Clicking an entry navigates the active tab; the trash button
// in the toolbar clears everything.
SidePanel {
    id: root
    title: qsTr("История")

    signal navigate(string url)

    // Human-friendly relative time ("5 мин назад", "вчера", or a date).
    function relTime(dt) {
        if (!dt || isNaN(dt.getTime())) return ""
        var diff = (Date.now() - dt.getTime()) / 1000
        if (diff < 60)    return qsTr("только что")
        if (diff < 3600)  return qsTr("%1 мин назад").arg(Math.floor(diff / 60))
        if (diff < 86400) return qsTr("%1 ч назад").arg(Math.floor(diff / 3600))
        if (diff < 172800) return qsTr("вчера")
        return Qt.formatDateTime(dt, "d MMM yyyy")
    }

    Column {
        anchors.fill: parent
        spacing: Theme.s2

        // Toolbar: count + clear-all.
        Item {
            id: toolbar
            width: parent.width
            height: 30
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: HistoryModel.count + " " + Theme.plural(HistoryModel.count, qsTr("запись"), qsTr("записи"), qsTr("записей"))
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
            }
            ConfirmActionButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                iconName: "trash-2"; size: 30; iconSize: 15
                enabled: HistoryModel.count > 0
                opacity: enabled ? 1 : 0.4
                idleAccessibleName: qsTr("Очистить всю историю")
                confirmAccessibleName: qsTr("Подтвердить очистку всей истории")
                idleTooltip: qsTr("Очистить историю")
                confirmTooltip: qsTr("Нажмите ещё раз, чтобы очистить историю")
                onConfirmed: HistoryModel.clear()
            }
        }

        // Empty state.
        Text {
            visible: HistoryModel.count === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.s6
            text: qsTr("Здесь пока пусто.\nОткрытые страницы появятся в истории.")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            wrapMode: Text.WordWrap
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - toolbar.height - Theme.s2
            clip: true
            spacing: 2
            model: HistoryModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FilkaScrollBar {}

            // Entries slide+fade as they're added/removed; the rest reflow.
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
                NumberAnimation { property: "x"; from: 16; to: 0; duration: Motion.base; easing.type: Motion.emphasized }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.exit }
                NumberAnimation { property: "x"; to: 24; duration: Motion.fast; easing.type: Motion.exit }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Motion.base; easing.type: Motion.standard }
            }

            delegate: Rectangle {
                id: row
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

                required property int index
                required property string title
                required property string url
                required property var lastVisit
                required property int visitCount

                HoverHandler { id: hover }
                TapHandler { onTapped: root.navigate(row.url) }
                Keys.onReturnPressed: root.navigate(row.url)
                Keys.onEnterPressed: root.navigate(row.url)
                Keys.onSpacePressed: root.navigate(row.url)

                Icon {
                    id: glyph
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: "globe"; size: 16; color: Theme.textMuted
                }

                Column {
                    anchors { left: glyph.right; right: del.left; verticalCenter: parent.verticalCenter
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
                        text: row.url + "  ·  " + root.relTime(row.lastVisit)
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    id: del
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                    opacity: (hover.hovered || row.activeFocus) ? 1 : 0
                    visible: opacity > 0.01
                    iconName: "x"; size: 26; iconSize: 13
                    Accessible.name: qsTr("Удалить запись истории %1").arg(row.title)
                    onClicked: {
                        var removed = { title: row.title, url: row.url, lastVisit: row.lastVisit, visitCount: row.visitCount }
                        HistoryModel.removeEntry(row.index)
                        undoToast.show(qsTr("Запись удалена"), function() {
                            HistoryModel.restoreEntry(removed.url, removed.title, removed.lastVisit, removed.visitCount)
                        })
                    }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                }
            }
        }

        UndoToast {
            id: undoToast
            parent: Overlay.overlay
        }
    }
}
