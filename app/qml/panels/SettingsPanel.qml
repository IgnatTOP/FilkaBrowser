import QtQuick
import QtQuick.Controls.Basic
import Filka

// SettingsPanel — the small set of preferences a browser must remember:
// appearance, default search engine and the page new tabs open. Everything is
// bound to the persistent AppSettings singleton, so changes save immediately.
SidePanel {
    id: root
    title: "Настройки"

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
                Text {
                    text: "Внешний вид"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Row {
                    spacing: Theme.s2
                    Repeater {
                        model: [ { label: "Светлая", dark: false }, { label: "Тёмная", dark: true } ]
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool selected: AppSettings.darkMode === modelData.dark
                            width: 120; height: 38
                            radius: Theme.radiusMd
                            color: selected ? Theme.accentSoft : Theme.glassLow
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.glassStroke
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.s2
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: chip.modelData.dark ? "moon" : "sun"; size: 15
                                    color: chip.selected ? Theme.accent : Theme.textSecondary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                }
                            }
                            TapHandler { onTapped: AppSettings.darkMode = chip.modelData.dark }
                        }
                    }
                }
            }

            // ---- Accent colour ----
            Column {
                width: parent.width
                spacing: Theme.s2
                Text {
                    text: "Акцентный цвет"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Row {
                    spacing: Theme.s3
                    Repeater {
                        model: ["#2E7CF6", "#8B5CF6", "#22D3EE", "#34D399", "#FBBF24", "#F87171", "#EC4899"]
                        delegate: Rectangle {
                            id: swatch
                            required property string modelData
                            readonly property bool selected: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                            width: 34; height: 34; radius: 17
                            color: modelData
                            scale: swHover.hovered ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
                            Rectangle {   // selection ring
                                anchors.centerIn: parent
                                width: parent.width + 8; height: width; radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: swatch.modelData
                                opacity: swatch.selected ? 0.9 : 0
                                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: swatch.selected
                                name: "shield-check"; size: 16; color: "white"
                            }
                            HoverHandler { id: swHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: AppSettings.accentColor = swatch.modelData }
                        }
                    }
                }
            }

            // ---- Start-page backdrop toggle ----
            Rectangle {
                width: parent.width; height: 52
                radius: Theme.radiusMd
                color: Theme.glassLow
                border.width: 1; border.color: Theme.glassStroke
                Column {
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text {
                        text: "Анимация фона"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                    }
                    Text {
                        text: "Переливающееся сияние на стартовой странице"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                }
                // Toggle switch.
                Rectangle {
                    id: track
                    anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    width: 46; height: 26; radius: 13
                    readonly property bool on: AppSettings.startPageAurora
                    color: on ? Theme.accent : Theme.glassMed
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: track.on ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
                    }
                    TapHandler { onTapped: AppSettings.startPageAurora = !AppSettings.startPageAurora }
                }
            }

            // ---- Search engine ----
            Column {
                width: parent.width
                spacing: Theme.s2
                Text {
                    text: "Поисковая система"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: AppSettings.searchEngines()
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool selected: AppSettings.searchEngine === modelData
                            width: parent.width; height: 42
                            radius: Theme.radiusMd
                            color: hover.hovered ? Theme.glassMed : Theme.glassLow
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.glassStroke
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            HoverHandler { id: hover }
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
                Text {
                    text: "Стартовая страница"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Rectangle {
                    width: parent.width; height: 42
                    radius: Theme.radiusMd
                    color: home.activeFocus ? Theme.glassHigh : Theme.glassLow
                    border.width: 1
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
                        placeholderText: "https://…"
                        placeholderTextColor: Theme.textMuted
                        onEditingFinished: AppSettings.homePage = text.trim()
                    }
                }
                Text {
                    text: "Открывается по кнопке «Домой». Новые вкладки открывают стартовую страницу Filka."
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
                Text {
                    text: "Конфиденциальность"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Rectangle {
                    width: parent.width; height: 44
                    radius: Theme.radiusMd
                    color: clearHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16)
                                              : Theme.glassLow
                    border.width: 1
                    border.color: clearHover.hovered ? Theme.danger : Theme.glassStroke
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        spacing: Theme.s2
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "trash-2"; size: 16
                            color: clearHover.hovered ? Theme.danger : Theme.textSecondary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Очистить историю посещений"
                            color: clearHover.hovered ? Theme.danger : Theme.textPrimary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        text: HistoryModel.count + " " + Theme.plural(HistoryModel.count, "запись", "записи", "записей")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: HistoryModel.clear() }
                }
            }

            // ---- Updates ----
            Column {
                width: parent.width
                spacing: Theme.s2
                Text {
                    text: "Обновления"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
                }
                Rectangle {
                    width: parent.width
                    height: updCol.height + Theme.s3 * 2
                    radius: Theme.radiusMd
                    color: Theme.glassLow
                    border.width: 1
                    border.color: UpdateChecker.updateAvailable ? Theme.accent : Theme.glassStroke
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

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
                                          ? "Проверяем наличие обновлений…"
                                          : UpdateChecker.updateAvailable
                                            ? "Доступна версия " + UpdateChecker.latestVersion
                                            : UpdateChecker.upToDate
                                              ? "У вас актуальная версия"
                                              : "Нажмите, чтобы проверить обновления"
                                    color: UpdateChecker.updateAvailable ? Theme.accent : Theme.textMuted
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                id: checkBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: checkLbl.implicitWidth + Theme.s4; height: 32
                                radius: Theme.radiusPill
                                color: checkHover.hovered ? Theme.glassHigh : Theme.glassMed
                                border.width: 1; border.color: Theme.glassStroke
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Text {
                                    id: checkLbl
                                    anchors.centerIn: parent
                                    text: UpdateChecker.checking ? "Проверка…" : "Проверить"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Medium
                                }
                                HoverHandler { id: checkHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: if (!UpdateChecker.checking) UpdateChecker.checkForUpdates() }
                            }
                        }

                        Rectangle {
                            visible: UpdateChecker.updateAvailable
                            width: parent.width; height: 40
                            radius: Theme.radiusMd
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.electricBlue }
                                GradientStop { position: 1.0; color: Theme.auroraPurple }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.s2
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: "download"; size: 14; color: "white" }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Скачать обновление"
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
