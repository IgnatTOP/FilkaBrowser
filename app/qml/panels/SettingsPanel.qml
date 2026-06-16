import QtQuick
import QtQuick.Controls.Basic
import Filka

// SettingsPanel — appearance, default search engine and the start page. Every
// control binds to the persistent AppSettings singleton, so changes save
// immediately. Built from the shared primitives (SectionLabel, Chip,
// ToggleSwitch) so the look stays consistent and new settings drop in cleanly.
SidePanel {
    id: root
    title: qsTr("Настройки")

    // Full-width glass container for a single setting block.
    component Card: Rectangle {
        radius: Theme.radiusMd
        color: Theme.glassLow
        border.width: 1
        border.color: Theme.glassStroke
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: parent.width
            spacing: Theme.s5

            // ---- Appearance ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Внешний вид") }
                Row {
                    spacing: Theme.s2
                    Repeater {
                        model: [ { label: qsTr("Светлая"), dark: false }, { label: qsTr("Тёмная"), dark: true } ]
                        delegate: Chip {
                            required property var modelData
                            width: 120; height: 38; radius: Theme.radiusMd
                            iconName: modelData.dark ? "moon" : "sun"
                            label: modelData.label
                            selected: AppSettings.darkMode === modelData.dark
                            onClicked: AppSettings.darkMode = modelData.dark
                        }
                    }
                }
            }

            // ---- Accent colour ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Акцентный цвет") }
                Row {
                    spacing: Theme.s3
                    Repeater {
                        model: ["#FF6A4D", "#FFA63D", "#FF5C7A", "#9B5CF6", "#22D3EE", "#34D399", "#2E7CF6"]
                        delegate: AccentSwatch {
                            required property string modelData
                            swatchColor: modelData
                            selected: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                            onClicked: AppSettings.accentColor = modelData
                        }
                    }
                }
            }

            // ---- Start-page backdrop toggle ----
            Card {
                width: parent.width; height: 52
                Column {
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text {
                        text: qsTr("Анимация фона")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                    }
                    Text {
                        text: qsTr("Переливающееся сияние на стартовой странице")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                }
                ToggleSwitch {
                    anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    checked: AppSettings.startPageAurora
                    onToggled: AppSettings.startPageAurora = !AppSettings.startPageAurora
                }
            }

            // ---- Search engine ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Поисковая система") }
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: AppSettings.searchEngines()
                        delegate: Card {
                            required property string modelData
                            readonly property bool selected: AppSettings.searchEngine === modelData
                            width: parent.width; height: 42
                            color: hover.hovered ? Theme.glassMed : Theme.glassLow
                            border.color: selected ? Theme.accent : Theme.glassStroke
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: AppSettings.searchEngine = modelData }
                            Text {
                                anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                                text: modelData
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                            }
                            Icon {
                                anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                                visible: parent.selected
                                name: "shield-check"; size: 16; color: Theme.accent
                            }
                        }
                    }
                }
            }

            // ---- Home page ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Стартовая страница") }
                Card {
                    width: parent.width; height: 42
                    color: home.activeFocus ? Theme.glassHigh : Theme.glassLow
                    border.color: home.activeFocus ? Theme.accent : Theme.glassStroke
                    TextField {
                        id: home
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s3
                        verticalAlignment: TextInput.AlignVCenter
                        text: AppSettings.homePage
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                        selectByMouse: true
                        background: null
                    placeholderText: "https://..."
                        placeholderTextColor: Theme.textMuted
                        onEditingFinished: AppSettings.homePage = text.trim()
                    }
                }
                Text {
                    text: qsTr("Открывается по кнопке «Домой». Новые вкладки открывают стартовую страницу Filka.")
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                    width: parent.width
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                }
            }

            // ---- Privacy ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Конфиденциальность") }

                // A destructive action row: trash icon, label, optional trailing
                // hint, runs `act()` on tap. Reused for history/cache/cookies.
                component ClearRow: Card {
                    id: clearRow
                    property string label: ""
                    property string hint: ""
                    property var act: (function() {})
                    width: parent.width; height: 44
                    color: rowHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16)
                                            : Theme.glassLow
                    border.color: rowHover.hovered ? Theme.danger : Theme.glassStroke
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        spacing: Theme.s2
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "trash-2"; size: 16
                            color: rowHover.hovered ? Theme.danger : Theme.textSecondary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: clearRow.label
                            color: rowHover.hovered ? Theme.danger : Theme.textPrimary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        text: clearRow.hint
                        visible: clearRow.hint.length > 0
                        color: Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: clearRow.act() }
                }

                ClearRow {
                    label: qsTr("Очистить историю посещений")
                    hint: HistoryModel.count + " " + Theme.plural(HistoryModel.count, qsTr("запись"), qsTr("записи"), qsTr("записей"))
                    act: (function() { HistoryModel.clear() })
                }
                ClearRow {
                    label: qsTr("Очистить кэш")
                    act: (function() { filkaPrivacy.clearCache() })
                }
                ClearRow {
                    label: qsTr("Очистить cookie и данные сайтов")
                    hint: qsTr("выход со всех сайтов")
                    act: (function() { filkaPrivacy.clearCookies() })
                }
            }

            // ---- Updates ----
            Column {
                width: parent.width
                spacing: Theme.s2
                SectionLabel { text: qsTr("Обновления") }
                Card {
                    width: parent.width
                    height: updCol.height + Theme.s3 * 2
                    border.color: UpdateChecker.updateAvailable ? Theme.accent : Theme.glassStroke

                    Column {
                        id: updCol
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  margins: Theme.s3 }
                        spacing: Theme.s2

                        Row {
                            width: parent.width
                            spacing: Theme.s2
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: UpdateChecker.updateAvailable ? "sparkles" : "shield-check"
                                size: 18
                                color: UpdateChecker.updateAvailable ? Theme.accent : Theme.textSecondary
                            }
                            Column {
                                width: parent.width - 18 - checkBtn.width - Theme.s2 * 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: "Filka " + UpdateChecker.currentVersion
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                    font.weight: Font.Medium
                                }
                                Text {
                                    width: parent.width
                                    text: UpdateChecker.checking
                                          ? qsTr("Проверяем наличие обновлений...")
                                          : UpdateChecker.updateAvailable
                                            ? qsTr("Доступна версия %1").arg(UpdateChecker.latestVersion)
                                            : UpdateChecker.upToDate
                                              ? qsTr("У вас актуальная версия")
                                              : qsTr("Нажмите, чтобы проверить обновления")
                                    color: UpdateChecker.updateAvailable ? Theme.accent : Theme.textMuted
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }
                            Pill {
                                id: checkBtn
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: 32
                                fillColor: hovered ? Theme.glassHigh : Theme.glassMed
                                onClicked: if (!UpdateChecker.checking) UpdateChecker.checkForUpdates()
                                Text {
                                    text: UpdateChecker.checking ? qsTr("Проверка...") : qsTr("Проверить")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Rectangle {
                            visible: UpdateChecker.updateAvailable
                            width: parent.width; height: 40
                            radius: Theme.radiusMd
                            color: Theme.accent
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.s2
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "download"; size: 14; color: "white" }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Скачать обновление")
                                    color: "white"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: UpdateChecker.openDownload() }
                        }
                    }
                }
            }
        }
    }
}
