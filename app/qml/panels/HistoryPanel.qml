import QtQuick
import QtQuick.Controls.Basic
import Filka

// HistoryPanel — lists visited pages (most recent first) from the shared
// HistoryModel. Clicking an entry navigates the active tab; the trash button
// in the toolbar clears everything.
SidePanel {
    id: root
    title: "История"

    signal navigate(string url)

    // Human-friendly relative time ("5 мин назад", "вчера", or a date).
    function relTime(dt) {
        if (!dt || isNaN(dt.getTime())) return ""
        var diff = (Date.now() - dt.getTime()) / 1000
        if (diff < 60)    return "только что"
        if (diff < 3600)  return Math.floor(diff / 60) + " мин назад"
        if (diff < 86400) return Math.floor(diff / 3600) + " ч назад"
        if (diff < 172800) return "вчера"
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
                text: HistoryModel.count + " записей"
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
                Accessible.name: "Очистить историю"
                onClicked: HistoryModel.clear()
            }
        }

        // Empty state.
        Text {
            visible: HistoryModel.count === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.s6
            text: "Здесь пока пусто.\nОткрытые страницы появятся в истории."
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
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: row
                width: ListView.view.width
                height: 50
                radius: Theme.radiusMd
                color: hover.hovered ? Theme.glassMed : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                required property int index
                required property string title
                required property string url
                required property var lastVisit

                HoverHandler { id: hover }
                TapHandler { onTapped: { root.navigate(row.url); root.open = false } }

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
                    visible: hover.hovered
                    iconName: "x"; size: 26; iconSize: 13
                    Accessible.name: "Удалить запись"
                    onClicked: HistoryModel.removeEntry(row.index)
                }
            }
        }
    }
}
