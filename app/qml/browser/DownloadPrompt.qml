pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    required property ShellState shell
    required property bool privateMode
    property bool open: false

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    z: 510
    focus: open
    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

    function close() {
        shell.activeOverlay = ""
    }

    function cancelDownload() {
        const download = shell.pendingDownload
        if (download && typeof download.cancel === "function")
            download.cancel()
        shell.pendingDownload = null
        close()
    }

    function suggestedName() {
        return shell.pendingDownload && shell.pendingDownload.suggestedFileName
             ? shell.pendingDownload.suggestedFileName : qsTr("download")
    }

    function saveDownload() {
        if (!shell.pendingDownload)
            return
        DownloadModel.acceptDownload(shell.pendingDownload, directory.text, fileName.text, root.privateMode)
        shell.pendingDownload = null
        shell.activePanel = "downloads"
        close()
    }

    onOpenChanged: {
        if (open) {
            fileName.text = suggestedName()
            directory.text = AppSettings.downloadPath
            fileName.forceActiveFocus()
            fileName.selectAll()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        TapHandler { onTapped: root.cancelDownload() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - Theme.s6)
        height: form.implicitHeight + Theme.s4 * 2
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            id: form
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Icon {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    name: "download"
                    size: 20
                    color: Theme.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Сохранить файл")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.DemiBold
                }
                IconButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    iconName: "x"
                    size: 28
                    iconSize: 13
                    Accessible.name: qsTr("Отмена")
                    onClicked: root.cancelDownload()
                }
            }

            TextField {
                id: fileName
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("Имя файла")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: fileName.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: fileName.activeFocus ? Theme.accent : Theme.outline
                }
                onAccepted: root.saveDownload()
            }

            TextField {
                id: directory
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("Папка")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: directory.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: directory.activeFocus ? Theme.accent : Theme.outline
                }
                onAccepted: root.saveDownload()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Item { Layout.fillWidth: true }
                Pill {
                    implicitHeight: 34
                    accessibleName: qsTr("Отменить загрузку")
                    onClicked: root.cancelDownload()
                    Text {
                        text: qsTr("Отмена")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Pill {
                    id: saveBtn
                    implicitHeight: 34
                    accessibleName: qsTr("Сохранить загрузку")
                    fillColor: Theme.accent
                    strokeWidth: 0
                    onClicked: root.saveDownload()
                    Text {
                        text: qsTr("Сохранить")
                        color: Theme.accentForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.cancelDownload()
}
