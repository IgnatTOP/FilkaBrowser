import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Filka

// UpdateBanner — slide-down banner that offers a new Filka version.
// Appears at the top of the window below the chrome when an update is found.
Rectangle {
    id: root
    visible: UpdateChecker.updateAvailable && !UpdateChecker.dismissed
    height: visible ? 52 : 0
    clip: true
    radius: Theme.radiusLg
    color: Theme.bgRaised
    border.width: 1
    border.color: Theme.accent

    Behavior on height { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        spacing: Theme.s2

        Icon {
            iconName: "arrow-up-circle"
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
            width: dlRow.width + Theme.s3 * 2
            height: 30
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
                    iconName: "download"
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
            width: 22; height: 22; radius: 11
            color: closeHover.hovered ? Theme.glassMed : "transparent"
            Icon { anchors.centerIn: parent; iconName: "x"; size: 11; color: Theme.textMuted }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: UpdateChecker.dismissed = true }
        }
    }
}
