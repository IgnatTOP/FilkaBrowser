import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Filka

// UpdateBanner — slide-down banner that offers a new Filka version.
// Appears at the top of the window below the chrome when an update is found.
Rectangle {
    id: root
    visible: UpdateChecker.updateAvailable && !UpdateChecker.dismissed
    // In a ColumnLayout the explicit `height` is ignored — the layout sizes
    // children by their implicitHeight. Drive that instead so the banner (and
    // its background) actually gets a height when shown.
    implicitHeight: visible ? 52 : 0
    clip: true
    radius: Theme.radiusLg
    color: Theme.bgRaised
    border.width: 1
    border.color: Theme.accent

    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        spacing: Theme.s2

        Icon {
            name: "sparkles"
            size: 20
            color: Theme.accent
        }

        Column {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: "Доступно обновление: Filka " + UpdateChecker.latestVersion
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
            }
            Text {
                text: UpdateChecker.releaseNotes.length > 120
                      ? UpdateChecker.releaseNotes.substring(0, 120) + "…"
                      : UpdateChecker.releaseNotes
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                elide: Text.ElideRight
                width: parent.width
                visible: text.length > 0
            }
        }

        Rectangle {
            Layout.preferredWidth: dlRow.width + Theme.s3 * 2
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusPill
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.electricBlue }
                GradientStop { position: 1.0; color: Theme.auroraPurple }
            }
            Row {
                id: dlRow
                anchors.centerIn: parent
                spacing: Theme.s1
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "download"
                    size: 13
                    color: "white"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Скачать"
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: UpdateChecker.openDownload() }
        }

        Rectangle {
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 11
            color: closeHover.hovered ? Theme.glassMed : "transparent"
            Icon { anchors.centerIn: parent; name: "x"; size: 11; color: Theme.textMuted }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: UpdateChecker.dismissed = true }
        }
    }
}
