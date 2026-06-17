import QtQuick
import QtQuick.Layouts
import Filka

// UpdateBanner — compact system strip offering a new Filka version.
Rectangle {
    id: root
    visible: UpdateChecker.updateAvailable && !UpdateChecker.dismissed
    // In a ColumnLayout the explicit height is ignored; drive implicitHeight so
    // the banner gets a height (and collapses to 0) when toggled.
    implicitHeight: visible ? 44 : 0
    clip: true
    radius: Theme.radiusMd
    color: Theme.surface
    border.width: 1
    border.color: Theme.glassStroke

    readonly property string notesPreview: UpdateChecker.releaseNotes.length > 96
                                           ? UpdateChecker.releaseNotes.substring(0, 96) + "..."
                                           : UpdateChecker.releaseNotes

    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        radius: 2
        color: Theme.accent
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s4
        anchors.rightMargin: Theme.s2
        spacing: Theme.s2

        Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: "sparkles"
            size: 18
            color: Theme.accent
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            Layout.alignment: Qt.AlignVCenter
            text: root.notesPreview.length > 0
                  ? qsTr("Доступно обновление: Filka %1 · %2").arg(UpdateChecker.latestVersion).arg(root.notesPreview)
                  : qsTr("Доступно обновление: Filka %1").arg(UpdateChecker.latestVersion)
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Pill {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 30
            accessibleName: qsTr("Скачать обновление")
            strokeWidth: 0
            fillColor: Theme.accent
            onClicked: UpdateChecker.openDownload()
            Row {
                spacing: Theme.s1
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "download"; size: 13; color: Theme.accentForeground }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Скачать")
                    color: Theme.accentForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            iconName: "x"; size: 30; iconSize: 13
            Accessible.name: qsTr("Скрыть")
            onClicked: UpdateChecker.dismissed = true
        }
    }
}
