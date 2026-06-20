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
    property bool confirmClear: false
    property var pendingDeletedEntry: null

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
            Timer {
                id: clearConfirmTimer
                interval: 2200
                onTriggered: root.confirmClear = false
            }
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: HistoryModel.count + " " + Theme.plural(HistoryModel.count, qsTr("запись"), qsTr("записи"), qsTr("записей"))
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
            }
            IconButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                iconName: "trash-2"; size: 30; iconSize: 15
                enabled: HistoryModel.count > 0
                opacity: enabled ? 1 : 0.4
                iconColor: Theme.danger
                active: root.confirmClear
                Accessible.name: root.confirmClear ? qsTr("Подтвердить очистку истории") : qsTr("Очистить историю")
                onClicked: {
                    if (!root.confirmClear) {
                        root.confirmClear = true
                        clearConfirmTimer.restart()
                        return
                    }
                    clearConfirmTimer.stop()
                    root.confirmClear = false
                    HistoryModel.clear()
                }
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
                    Accessible.name: qsTr("Удалить запись")
                    onClicked: {
                        root.pendingDeletedEntry = {
                            index: row.index,
                            title: row.title,
                            url: row.url,
                            lastVisit: row.lastVisit
                        }
                        HistoryModel.removeEntry(row.index)
                        undoToast.open()
                    }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                }
            }
        }
    }

    Popup {
        id: undoToast
        parent: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - Theme.s6
        padding: Theme.s2
        implicitWidth: toastBody.implicitWidth
        implicitHeight: toastBody.implicitHeight

        Timer {
            id: undoToastTimer
            interval: 5000
            onTriggered: undoToast.close()
        }

        onOpened: undoToastTimer.restart()
        onClosed: undoToastTimer.stop()

        background: Rectangle {
            radius: Theme.radiusPill
            color: Theme.bgRaised
            border.width: 1
            border.color: Theme.glassStroke
        }

        contentItem: Row {
            id: toastBody
            spacing: Theme.s2
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "trash-2"
                size: 15
                color: Theme.textMuted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Запись удалена")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
            }

            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Отменить")
                onClicked: {
                    if (root.pendingDeletedEntry) {
                        HistoryModel.restoreEntry(root.pendingDeletedEntry.index,
                                                  root.pendingDeletedEntry.title,
                                                  root.pendingDeletedEntry.url,
                                                  root.pendingDeletedEntry.lastVisit)
                        root.pendingDeletedEntry = null
                    }
                    undoToast.close()
                }
            }
        }
    }
}
