pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Filka

// ListCard — a glass bento card that heads a short scrollable list (recent
// history, bookmarks) with an icon + caption and a graceful empty state. Each
// row carries a host-initial badge, title and host; activating one emits
// `activated(url)`. Used on the StartPage dashboard.
Rectangle {
    id: card

    property string iconName: ""
    property string title: ""
    property string emptyText: ""
    property var listModel: null
    property var hostFn: (u) => "" + u
    signal activated(string url)

    radius: Theme.radiusMd
    color: Theme.card
    border.width: 1
    border.color: Theme.outline
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s3
        spacing: Theme.s3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Icon { name: card.iconName; size: 15; color: Theme.accent }
            SectionLabel { Layout.fillWidth: true; text: card.title }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: card.listModel
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2

            delegate: Item {
                id: row
                required property string title
                required property string url
                width: ListView.view.width
                height: 38

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    radius: Theme.radiusSm
                    color: rowHover.hovered ? Theme.hoverFill : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s2
                        anchors.rightMargin: Theme.s2
                        spacing: Theme.s2

                        Favicon {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            host: card.hostFn(row.url)
                            fallbackText: card.hostFn(row.url).charAt(0).toUpperCase()
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.title.length ? row.title : card.hostFn(row.url)
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                        }
                        Text {
                            text: card.hostFn(row.url)
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                            Layout.maximumWidth: 110
                        }
                    }

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: card.activated(row.url) }
                }
            }
        }
    }

    // Empty state — centred caption when the model has no rows.
    Text {
        anchors.centerIn: parent
        visible: !card.listModel || card.listModel.count === 0
        text: card.emptyText
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
    }
}
