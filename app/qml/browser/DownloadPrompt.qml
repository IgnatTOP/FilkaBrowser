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
    property string fileNameError: validateFileName(fileName.text)
    property string directoryCreationError: ""
    property string directoryError: directoryCreationError.length > 0 ? directoryCreationError : validateDirectory(directory.text)

    readonly property bool formValid: fileNameError.length === 0
                                      && directoryError.length === 0
                                      && DownloadModel.directoryExists(directory.text)

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

    function validateFileName(value) {
        const name = value.trim()
        if (name.length === 0)
            return qsTr("Укажите имя файла")
        if (/[\/\\:*?"<>|]/.test(name))
            return qsTr("Имя содержит недопустимые символы")
        return ""
    }

    function validateDirectory(value) {
        const path = value.trim()
        if (path.length === 0)
            return qsTr("Укажите папку")
        if (!DownloadModel.canNormalizeDirectory(path))
            return qsTr("Некорректный путь к папке")
        return ""
    }

    function saveDownload() {
        if (!shell.pendingDownload)
            return
        if (fileNameError.length > 0 || directoryError.length > 0)
            return
        if (!DownloadModel.directoryExists(directory.text))
            return
        DownloadModel.acceptDownload(shell.pendingDownload, DownloadModel.normalizedDirectoryPath(directory.text), fileName.text.trim(), root.privateMode)
        shell.pendingDownload = null
        shell.activePanel = "downloads"
        close()
    }

    onOpenChanged: {
        if (open) {
            fileName.text = suggestedName()
            directory.text = AppSettings.downloadPath
            directoryCreationError = ""
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
                onTextChanged: directoryCreationError = ""
                onAccepted: if (root.formValid) root.saveDownload()
            }

            Text {
                Layout.fillWidth: true
                visible: root.fileNameError.length > 0
                text: root.fileNameError
                color: Theme.warning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                wrapMode: Text.Wrap
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
                onTextChanged: directoryCreationError = ""
                onAccepted: if (root.formValid) root.saveDownload()
            }

            Text {
                Layout.fillWidth: true
                visible: root.directoryError.length > 0
                text: root.directoryError
                color: Theme.warning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.directoryError.length === 0 && !DownloadModel.directoryExists(directory.text)
                spacing: Theme.s2
                Icon { Layout.preferredWidth: 16; Layout.preferredHeight: 16; name: "shield"; size: 14; color: Theme.warning }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Папка не существует. Создать её?")
                    color: Theme.warning
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    wrapMode: Text.Wrap
                }
                Pill {
                    implicitHeight: 30
                    accessibleName: qsTr("Создать папку")
                    onClicked: {
                        if (DownloadModel.createDirectory(directory.text)) {
                            directory.text = DownloadModel.normalizedDirectoryPath(directory.text)
                            directoryCreationError = ""
                            root.saveDownload()
                        } else {
                            root.directoryCreationError = qsTr("Не удалось создать папку")
                        }
                    }
                    Text {
                        text: qsTr("Создать")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
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
                    interactive: root.formValid
                    opacity: root.formValid ? 1 : 0.45
                    fillColor: root.formValid ? Theme.accent : Theme.surfaceAlt
                    strokeWidth: root.formValid ? 0 : 1
                    onClicked: if (root.formValid) root.saveDownload()
                    Text {
                        text: qsTr("Сохранить")
                        color: root.formValid ? Theme.accentForeground : Theme.textMuted
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
