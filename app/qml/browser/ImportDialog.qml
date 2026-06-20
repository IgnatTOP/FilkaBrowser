import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Popup {
    id: root

    parent: Overlay.overlay
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0
    width: Math.min(620, parent ? parent.width - Theme.s6 : 620)
    height: Math.min(560, parent ? parent.height - Theme.s6 : 560)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property var browsers: []
    property string resultText: ""
    property string importMode: "skipDuplicates"

    function refresh() {
        resultText = ""
        BrowserImporter.startDetection()
    }

    function importBookmarks(browserId) {
        resultText = ""
        BrowserImporter.startImportBookmarks(browserId)
    }

    function importHistory(browserId) {
        resultText = ""
        BrowserImporter.startImportHistory(browserId)
    }

    function formatResult(kind, result) {
        const label = kind === "bookmarks" ? qsTr("закладок") : qsTr("записей истории")
        return qsTr("Импорт %1 завершён: добавлено %2, пропущено дублей %3, ошибок %4.")
            .arg(label)
            .arg(result.added || 0)
            .arg(result.skippedDuplicates || result.skipped || 0)
            .arg(result.errors || 0)
    }

    onOpened: refresh()

    Connections {
        target: BrowserImporter
        function onBrowsersChanged() {
            root.browsers = BrowserImporter.browsers
        }
        function onBookmarksReady(entries) {
            const result = BookmarkModel.importEntries(entries, root.importMode)
            root.resultText = root.formatResult("bookmarks", result)
            BrowserImporter.finishImportResult(result, "bookmarks")
        }
        function onHistoryReady(entries) {
            const result = HistoryModel.importEntries(entries, root.importMode)
            root.resultText = root.formatResult("history", result)
            BrowserImporter.finishImportResult(result, "history")
        }
    }

    background: Rectangle {
        radius: Theme.radiusXl
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s4
        spacing: Theme.s3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            Icon {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                name: "import"
                size: 22
                color: Theme.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Импорт данных")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Перенос закладок и истории из установленных браузеров.")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
                }
            }
            IconButton {
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                iconName: "x"
                size: Theme.controlMd
                Accessible.name: qsTr("Закрыть импорт")
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.glassHairline
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Theme.radiusMd
            color: Theme.glassLow
            border.width: 1
            border.color: Theme.outline

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s3
                spacing: Theme.s2

                Text {
                    Layout.fillWidth: true
                    text: BrowserImporter.status.length > 0 ? BrowserImporter.status : qsTr("Готово")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                }
                GlassButton {
                    text: qsTr("Обновить")
                    enabled: !BrowserImporter.busy
                    onClicked: root.refresh()
                }
                GlassButton {
                    text: qsTr("Отмена")
                    visible: BrowserImporter.busy
                    onClicked: BrowserImporter.cancel()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Repeater {
                model: [
                    { key: "detection", label: qsTr("Detection") },
                    { key: "reading", label: qsTr("Reading") },
                    { key: "parsing", label: qsTr("Parsing") },
                    { key: "importing", label: qsTr("Importing") }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: Theme.radiusPill
                    color: BrowserImporter.stage === modelData.key ? Theme.accent : Theme.glassLow
                    border.width: 1
                    border.color: Theme.outline
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: BrowserImporter.stage === modelData.key ? Theme.accentForeground : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            visible: BrowserImporter.busy || BrowserImporter.progress > 0
            from: 0
            to: 1
            value: BrowserImporter.progress
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2

            Text {
                text: qsTr("Режим импорта")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
            }

            ComboBox {
                id: importModeBox
                Layout.fillWidth: true
                model: [
                    { text: qsTr("Пропускать дубли"), value: "skipDuplicates" },
                    { text: qsTr("Обновлять существующие"), value: "updateExisting" },
                    { text: qsTr("Импортировать всё"), value: "importAll" }
                ]
                textRole: "text"
                valueRole: "value"
                currentIndex: 0
                onActivated: root.importMode = currentValue
            }
        }

        ListView {
            id: browserList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.browsers
            clip: true
            spacing: Theme.s2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FilkaScrollBar {}

            delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 104
                radius: Theme.radiusLg
                color: Theme.card
                border.width: 1
                border.color: Theme.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s3

                    Icon {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        name: row.modelData.family === "firefox" ? "globe" : "circle-user"
                        size: 24
                        color: Theme.accent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.profilePath
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideMiddle
                        }
                        Row {
                            spacing: Theme.s2
                            GlassButton {
                                text: qsTr("Закладки")
                                enabled: row.modelData.bookmarksAvailable && !BrowserImporter.busy
                                onClicked: root.importBookmarks(row.modelData.id)
                            }
                            GlassButton {
                                text: qsTr("История")
                                enabled: row.modelData.historyAvailable && !BrowserImporter.busy
                                onClicked: root.importHistory(row.modelData.id)
                            }
                            GlassButton {
                                text: qsTr("Пароли")
                                enabled: false
                                ToolTip.text: qsTr("В Filka пока нет защищённого хранилища паролей")
                                ToolTip.visible: hovered
                                ToolTip.delay: 400
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.browsers.length === 0
            text: qsTr("Chrome, Chromium, Brave, Opera или Firefox не найдены в стандартных папках профилей.")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: root.resultText.length > 0
            text: root.resultText
            color: Theme.positive
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
