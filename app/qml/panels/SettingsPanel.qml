import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Item {
    id: settingsRoot

    property bool open: false
    property var profile: null
    property string activeCategory: "appearance"
    property string query: ""
    property string adBlockListDraft: ""
    property string adBlockSiteDraft: ""
    signal requestClose()

    anchors.fill: parent
    z: 200
    visible: open || dialog.opacity > 0.01
    focus: open
    Keys.onEscapePressed: settingsRoot.requestClose()

    readonly property var categories: [
        { key: "appearance", icon: "palette", label: qsTr("Внешний вид") },
        { key: "home", icon: "house", label: qsTr("Главная") },
        { key: "search", icon: "search", label: qsTr("Поиск") },
        { key: "tabs", icon: "panel-left", label: qsTr("Вкладки") },
        { key: "downloads", icon: "download", label: qsTr("Загрузки") },
        { key: "translator", icon: "languages", label: qsTr("Переводчик") },
        { key: "privacy", icon: "shield", label: qsTr("Приватность") },
        { key: "updates", icon: "sparkles", label: qsTr("Обновления") },
        { key: "advanced", icon: "settings", label: qsTr("Дополнительно") }
    ]

    function inCategory(key) {
        return query.length > 0 || activeCategory === key
    }

    function matches(tags) {
        return query.length === 0 || tags.toLowerCase().indexOf(query) >= 0
    }

    component SettingsCard: Rectangle {
        property string searchTags: ""
        radius: Theme.radiusLg
        color: Theme.card
        border.width: 1
        border.color: Theme.outline
    }

    component CategoryItem: Rectangle {
        id: cat
        property string key: ""
        property string label: ""
        property string iconName: "settings"
        readonly property bool selected: settingsRoot.activeCategory === key && settingsRoot.query.length === 0
        signal triggered()

        implicitHeight: 38
        radius: Theme.radiusMd
        color: selected ? Theme.activeFill : (hover.hovered ? Theme.hoverFill : "transparent")
        border.width: activeFocus ? Theme.focusWidth : (selected ? 1 : 0)
        border.color: activeFocus ? Theme.focusRing : (selected ? Theme.accent : "transparent")
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s3
            spacing: Theme.s2
            Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                name: cat.iconName
                size: 17
                color: cat.selected ? Theme.accent : Theme.textSecondary
            }
            Text {
                Layout.fillWidth: true
                text: cat.label
                color: cat.selected ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: cat.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: cat.triggered() }
        Keys.onReturnPressed: cat.triggered()
        Keys.onEnterPressed: cat.triggered()
        Keys.onSpacePressed: cat.triggered()
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    component SettingRow: Rectangle {
        id: row
        property string label: ""
        property string hint: ""
        property string iconName: "settings"
        property bool showDivider: true
        default property alias trailing: trailingSlot.data

        implicitHeight: Math.max(58, textCol.implicitHeight + Theme.s4)
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s4
            anchors.rightMargin: Theme.s4
            spacing: Theme.s3
            Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                name: row.iconName
                size: 17
                color: Theme.textSecondary
            }
            ColumnLayout {
                id: textCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: row.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: row.hint.length > 0
                    text: row.hint
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    wrapMode: Text.WordWrap
                }
            }
            Item {
                id: trailingSlot
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: childrenRect.width
                Layout.preferredHeight: Math.max(childrenRect.height, 1)
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: Theme.s4; rightMargin: Theme.s4 }
            height: 1
            visible: row.showDivider
            color: Theme.glassHairline
        }
    }

    component FieldBox: Rectangle {
        id: fieldBox
        property alias text: input.text
        property alias placeholderText: input.placeholderText
        property alias echoMode: input.echoMode
        property string accessibleName: ""
        signal accepted(string value)

        implicitWidth: 310
        implicitHeight: 38
        radius: Theme.radiusMd
        color: input.activeFocus ? Theme.surface : Theme.glassLow
        border.width: 1
        border.color: input.activeFocus ? Theme.focusRing : Theme.outline

        TextField {
            id: input
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s3
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            color: Theme.textPrimary
            placeholderTextColor: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            background: null
            Accessible.name: fieldBox.accessibleName
            onAccepted: fieldBox.accepted(text.trim())
            onEditingFinished: fieldBox.accepted(text.trim())
        }

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    component SectionBlock: ColumnLayout {
        id: section
        property string title: ""
        property string subtitle: ""
        property string category: ""
        property string searchTags: ""
        visible: settingsRoot.inCategory(category) && settingsRoot.matches(searchTags + " " + title + " " + subtitle)
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        Layout.maximumHeight: visible ? 100000 : 0
        spacing: Theme.s2

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: section.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: section.subtitle.length > 0
                text: section.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                wrapMode: Text.WordWrap
            }
        }
    }

    component DangerRow: Rectangle {
        id: danger
        property string label: ""
        property string hint: ""
        property string iconName: "trash-2"
        property var act: (function() {})
        property bool armed: false

        implicitHeight: 54
        radius: Theme.radiusMd
        color: armed || hover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12)
                                      : Theme.glassLow
        border.width: activeFocus ? Theme.focusWidth : 1
        border.color: activeFocus ? Theme.focusRing
                                  : armed || hover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.45)
                                                           : Theme.outline
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: armed ? qsTr("Подтвердить: %1").arg(label) : label

        Timer {
            id: disarm
            interval: 2200
            onTriggered: danger.armed = false
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s3
            spacing: Theme.s3
            Icon {
                Layout.preferredWidth: 17
                Layout.preferredHeight: 17
                name: danger.iconName
                size: 17
                color: danger.armed || hover.hovered ? Theme.danger : Theme.textSecondary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: danger.armed ? qsTr("Нажмите ещё раз") : danger.label
                    color: danger.armed || hover.hovered ? Theme.danger : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    visible: danger.hint.length > 0
                    text: danger.hint
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
                }
            }
        }

        function trigger() {
            if (!armed) {
                armed = true
                disarm.restart()
                return
            }
            armed = false
            disarm.stop()
            act()
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: danger.trigger() }
        Keys.onReturnPressed: danger.trigger()
        Keys.onEnterPressed: danger.trigger()
        Keys.onSpacePressed: danger.trigger()
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    ImportDialog {
        id: importDialog
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: settingsRoot.open ? (Theme.dark ? 0.48 : 0.28) : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
    }

    GlassPanel {
        id: dialog
        width: Math.min(1180, settingsRoot.width - Theme.s6 * 2)
        height: Math.min(760, settingsRoot.height - Theme.s7)
        anchors.centerIn: parent
        radius: Theme.radiusXl
        level: 2
        shadow: true
        opacity: settingsRoot.open ? 1 : 0
        scale: settingsRoot.open ? 1 : 0.985
        Behavior on opacity { OpacityAnimator { duration: Motion.base; easing.type: Motion.standard } }
        Behavior on scale { ScaleAnimator { duration: Motion.base; easing.type: Motion.emphasized } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusXl
            color: Theme.surface
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: qsTr("Настройки")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }

                IconButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    iconName: "x"
                    size: Theme.controlMd
                    tooltip: qsTr("Закрыть")
                    Accessible.name: qsTr("Закрыть настройки")
                    onClicked: settingsRoot.requestClose()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

    RowLayout {
        anchors.fill: parent
        spacing: Theme.s4

        ColumnLayout {
            Layout.preferredWidth: 172
            Layout.maximumWidth: 172
            Layout.fillHeight: true
            spacing: Theme.s2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusPill
                color: searchField.activeFocus ? Theme.glassHigh : Theme.glassLow
                border.width: 1
                border.color: searchField.activeFocus ? Theme.focusRing : Theme.outline

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: "search"
                    size: 16
                    color: searchField.activeFocus ? Theme.accent : Theme.textMuted
                }
                TextField {
                    id: searchField
                    anchors { left: searchIcon.right; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: Theme.s2; rightMargin: Theme.s3 }
                    placeholderText: qsTr("Поиск")
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    selectByMouse: true
                    background: null
                    onTextChanged: settingsRoot.query = text.trim().toLowerCase()
                    Keys.onEscapePressed: {
                        text = ""
                        settingsRoot.query = ""
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: settingsRoot.categories
                    delegate: CategoryItem {
                        required property var modelData
                        Layout.fillWidth: true
                        key: modelData.key
                        label: modelData.label
                        iconName: modelData.icon
                        onTriggered: {
                            settingsRoot.activeCategory = key
                            searchField.text = ""
                            settingsRoot.query = ""
                            settingsFlick.contentY = 0
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                radius: Theme.radiusLg
                color: Theme.accentSofter
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s2
                    Icon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "shield-check"; size: 18; color: Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Filka %1").arg(UpdateChecker.currentVersion)
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Премиальное рабочее пространство")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.glassHairline
        }

        Flickable {
            id: settingsFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: settingsCol.implicitHeight + Theme.s2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FilkaScrollBar {}

            ColumnLayout {
                id: settingsCol
                width: settingsFlick.width
                spacing: Theme.s5

                SectionBlock {
                    category: "appearance"
                    title: qsTr("Внешний вид")
                    subtitle: qsTr("Цвет, движение и плотное стекло интерфейса.")
                    searchTags: "theme color accent wallpaper motion dark light"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: appearanceRows.implicitHeight
                        ColumnLayout {
                            id: appearanceRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Тема")
                                hint: qsTr("Переключение между светлой и тёмной оболочкой.")
                                iconName: AppSettings.darkMode ? "moon" : "sun"
                                Row {
                                    spacing: Theme.s2
                                    Chip { label: qsTr("Светлая"); iconName: "sun"; selected: !AppSettings.darkMode; onClicked: AppSettings.darkMode = false }
                                    Chip { label: qsTr("Тёмная"); iconName: "moon"; selected: AppSettings.darkMode; onClicked: AppSettings.darkMode = true }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Фирменный акцент")
                                hint: qsTr("Цвет подсветки активных элементов и фокуса.")
                                iconName: "palette"
                                Row {
                                    spacing: Theme.s2
                                    Repeater {
                                        model: ["#8B5CF6", "#C4B5FD", "#38BDF8", "#34D399", "#F87171", "#FBBF24", "#2E7CF6"]
                                        delegate: AccentSwatch {
                                            required property string modelData
                                            swatchColor: modelData
                                            selected: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                                            onClicked: AppSettings.accentColor = modelData
                                        }
                                    }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Обои главной")
                                hint: qsTr("Премиальный фон, который задаёт настроение стартовой страницы.")
                                iconName: "sparkles"
                                Row {
                                    spacing: Theme.s2
                                    Chip { label: qsTr("Побережье"); iconName: "sun"; selected: AppSettings.wallpaperPreset === "coast"; onClicked: AppSettings.wallpaperPreset = "coast" }
                                    Chip { label: qsTr("Космос"); iconName: "sparkles"; selected: AppSettings.wallpaperPreset === "space"; onClicked: AppSettings.wallpaperPreset = "space" }
                                    Chip { label: qsTr("Минимал"); iconName: "palette"; selected: AppSettings.wallpaperPreset === "minimal"; onClicked: AppSettings.wallpaperPreset = "minimal" }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Живые обои")
                                hint: qsTr("Показывать фон на домашней странице.")
                                iconName: "sparkles"
                                ToggleSwitch { accessibleName: qsTr("Живые обои"); checked: AppSettings.startPageAurora; onToggled: AppSettings.startPageAurora = !AppSettings.startPageAurora }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Меньше анимации")
                                hint: qsTr("Отключает декоративные переходы и движение.")
                                iconName: "gauge"
                                ToggleSwitch { accessibleName: qsTr("Меньше анимации"); checked: AppSettings.reducedMotion; onToggled: AppSettings.reducedMotion = !AppSettings.reducedMotion }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "home"
                    title: qsTr("Главная")
                    subtitle: qsTr("Приветствие, поиск, быстрые ссылки и спокойные умные карточки.")
                    searchTags: "home start page name subtitle smart cards quick links"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: homeRows.implicitHeight
                        ColumnLayout {
                            id: homeRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Имя")
                                hint: qsTr("Показывается в приветствии на главной.")
                                iconName: "circle-user"
                                FieldBox {
                                    text: AppSettings.displayName
                                    accessibleName: qsTr("Имя на главной")
                                    placeholderText: qsTr("Имя")
                                    onAccepted: (value) => AppSettings.displayName = value
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Подпись")
                                hint: qsTr("Короткая строка под приветствием.")
                                iconName: "sparkles"
                                FieldBox {
                                    text: AppSettings.homeSubtitle
                                    accessibleName: qsTr("Подпись на главной")
                                    placeholderText: qsTr("Готовы создать что-то великое сегодня?")
                                    onAccepted: (value) => AppSettings.homeSubtitle = value
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Умные карточки")
                                hint: qsTr("Показывать продолжение работы, состояние workspace и загрузки.")
                                iconName: "zap"
                                ToggleSwitch { accessibleName: qsTr("Умные карточки"); checked: AppSettings.homeSmartCards; onToggled: AppSettings.homeSmartCards = !AppSettings.homeSmartCards }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "search"
                    title: qsTr("Поиск")
                    subtitle: qsTr("Адресная строка, подсказки и стартовая страница по кнопке Домой.")
                    searchTags: "search engine suggestions homepage url duckduckgo google yandex"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: searchRows.implicitHeight
                        ColumnLayout {
                            id: searchRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Поисковая система")
                                hint: qsTr("Используется в адресной строке и на главной.")
                                iconName: "search"
                                Flow {
                                    width: 330
                                    spacing: Theme.s2
                                    Repeater {
                                        model: AppSettings.searchEngines()
                                        delegate: Chip {
                                            required property string modelData
                                            label: modelData
                                            selected: AppSettings.searchEngine === modelData
                                            onClicked: AppSettings.searchEngine = modelData
                                        }
                                    }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Сетевые подсказки")
                                hint: qsTr("Отправляет введённый текст сервису автодополнения.")
                                iconName: "sparkles"
                                ToggleSwitch { accessibleName: qsTr("Сетевые подсказки"); checked: AppSettings.networkSuggestionsEnabled; onToggled: AppSettings.networkSuggestionsEnabled = !AppSettings.networkSuggestionsEnabled }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Домашняя страница")
                                hint: qsTr("Открывается по кнопке Домой.")
                                iconName: "house"
                                FieldBox {
                                    text: AppSettings.homePage
                                    accessibleName: qsTr("Домашняя страница")
                                    placeholderText: qsTr("https://...")
                                    onAccepted: (value) => AppSettings.homePage = value
                                }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "tabs"
                    title: qsTr("Вкладки и пространства")
                    subtitle: qsTr("Поведение вертикальных вкладок, запуск и масштаб новых страниц.")
                    searchTags: "tabs workspace restore zoom startup vertical"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: tabRows.implicitHeight
                        ColumnLayout {
                            id: tabRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Вкладки сбоку")
                                hint: qsTr("Вертикальная панель вкладок в стиле workspace-браузера.")
                                iconName: "panel-left"
                                ToggleSwitch { accessibleName: qsTr("Вкладки сбоку"); checked: AppSettings.verticalTabs; onToggled: AppSettings.verticalTabs = !AppSettings.verticalTabs }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Восстанавливать сессию")
                                hint: qsTr("Открывать последнюю сохранённую сессию при запуске.")
                                iconName: "history"
                                ToggleSwitch { accessibleName: qsTr("Восстанавливать сессию"); checked: AppSettings.restoreSessionEnabled; onToggled: AppSettings.restoreSessionEnabled = !AppSettings.restoreSessionEnabled }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Масштаб новых вкладок")
                                hint: qsTr("%1%").arg(Math.round(AppSettings.defaultZoom * 100))
                                iconName: "gauge"
                                Row {
                                    spacing: Theme.s1
                                    IconButton { iconName: "minus"; size: 30; iconSize: 13; tooltip: qsTr("Уменьшить"); onClicked: AppSettings.defaultZoom = AppSettings.defaultZoom - 0.1 }
                                    IconButton { iconName: "plus"; size: 30; iconSize: 13; tooltip: qsTr("Увеличить"); onClicked: AppSettings.defaultZoom = AppSettings.defaultZoom + 0.1 }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Автовоспроизведение медиа")
                                hint: AppSettings.permissiveAutoplayEnabled
                                      ? qsTr("Разрешено везде. Изменение Chromium-флага полностью применится после перезапуска.")
                                      : qsTr("По умолчанию нужен жест пользователя; доверенные музыкальные домены разрешены отдельно.")
                                iconName: "music"
                                ToggleSwitch { accessibleName: qsTr("Разрешить автовоспроизведение везде"); checked: AppSettings.permissiveAutoplayEnabled; onToggled: AppSettings.permissiveAutoplayEnabled = !AppSettings.permissiveAutoplayEnabled }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "downloads"
                    title: qsTr("Загрузки")
                    subtitle: qsTr("Путь сохранения файлов и подтверждение перед загрузкой.")
                    searchTags: "downloads folder files location save"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: downloadRows.implicitHeight
                        ColumnLayout {
                            id: downloadRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Папка загрузок")
                                hint: qsTr("Используется для файлов и сохранения PDF.")
                                iconName: "download"
                                FieldBox {
                                    text: AppSettings.downloadPath
                                    accessibleName: qsTr("Папка загрузок")
                                    placeholderText: qsTr("/home/user/Downloads")
                                    onAccepted: (value) => AppSettings.downloadPath = value
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Спрашивать место загрузки")
                                hint: qsTr("Показывать имя файла и папку перед сохранением.")
                                iconName: "download"
                                ToggleSwitch { accessibleName: qsTr("Спрашивать место загрузки"); checked: AppSettings.askDownloadLocation; onToggled: AppSettings.askDownloadLocation = !AppSettings.askDownloadLocation }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "translator"
                    title: qsTr("Переводчик")
                    subtitle: qsTr("Быстрый popover у адресной зоны, языки и кэш переводов.")
                    searchTags: "translator translate language api key cache popover"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: translatorRows.implicitHeight
                        ColumnLayout {
                            id: translatorRows
                            anchors.fill: parent
                            spacing: 0
	                            SettingRow {
	                                Layout.fillWidth: true
	                                label: qsTr("API-ключ BotHub")
	                                hint: PageTranslator.hasApiKey
	                                      ? qsTr("Ключ сохранён локально. Введите новый, чтобы заменить его.")
	                                      : qsTr("Хранится локально в настройках пользователя.")
	                                iconName: "shield"
	                                Row {
	                                    spacing: Theme.s2
	                                    FieldBox {
	                                        text: ""
	                                        echoMode: TextInput.Password
	                                        accessibleName: qsTr("API-ключ переводчика")
	                                        placeholderText: PageTranslator.hasApiKey
	                                                         ? qsTr("Ключ сохранён")
	                                                         : qsTr("sk-...")
	                                        onAccepted: function(value) {
	                                            if (value.length > 0) {
	                                                PageTranslator.setApiKey(value)
	                                                text = ""
	                                            }
	                                        }
	                                    }
	                                    Pill {
	                                        visible: PageTranslator.hasApiKey
	                                        anchors.verticalCenter: parent.verticalCenter
	                                        radius: Theme.radiusSm
	                                        implicitHeight: 34
	                                        hPadding: Theme.s3
	                                        fillColor: hovered ? Theme.hoverFill : Theme.surfaceAlt
		                                        accessibleName: qsTr("Удалить API-ключ переводчика")
	                                        onClicked: PageTranslator.clearApiKey()
	                                        Text {
	                                            text: qsTr("Удалить")
	                                            color: Theme.textSecondary
	                                            font.family: Theme.fontFamily
	                                            font.pixelSize: Theme.fontSizeSm
	                                        }
	                                    }
	                                }
	                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Исходный язык")
                                hint: qsTr("Обычно лучше оставить автоопределение.")
                                iconName: "languages"
                                Row {
                                    spacing: Theme.s2
                                    Chip { label: qsTr("Авто"); selected: PageTranslator.sourceLanguage === qsTr("Автоопределение"); onClicked: PageTranslator.sourceLanguage = qsTr("Автоопределение") }
                                    Chip { label: qsTr("English"); selected: PageTranslator.sourceLanguage === "English"; onClicked: PageTranslator.sourceLanguage = "English" }
                                    Chip { label: qsTr("Русский"); selected: PageTranslator.sourceLanguage === qsTr("Русский"); onClicked: PageTranslator.sourceLanguage = qsTr("Русский") }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Целевой язык")
                                hint: qsTr("Язык, на который переводится страница.")
                                iconName: "languages"
                                Flow {
                                    width: 330
                                    spacing: Theme.s2
                                    Repeater {
                                        model: [qsTr("Русский"), "English", "Deutsch", "Français", "Español", "中文", "日本語"]
                                        delegate: Chip {
                                            required property string modelData
                                            label: modelData
                                            selected: PageTranslator.targetLanguage === modelData
                                            onClicked: PageTranslator.targetLanguage = modelData
                                        }
                                    }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Предлагать перевод")
                                hint: qsTr("Показывать быстрый popover, когда страница выглядит иностранной.")
                                iconName: "sparkles"
                                ToggleSwitch { accessibleName: qsTr("Предлагать перевод"); checked: AppSettings.translatorAutoOffer; onToggled: AppSettings.translatorAutoOffer = !AppSettings.translatorAutoOffer }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Кэшировать перевод")
                                hint: qsTr("Повторное открытие popover быстрее возвращает уже переведённые фрагменты.")
                                iconName: "zap"
                                ToggleSwitch { accessibleName: qsTr("Кэшировать перевод"); checked: AppSettings.translatorCacheEnabled; onToggled: AppSettings.translatorCacheEnabled = !AppSettings.translatorCacheEnabled }
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "privacy"
                    title: qsTr("Конфиденциальность")
                    subtitle: qsTr("Блокировка рекламы, очистка истории, кэша, cookie и разрешений сайтов.")
                    searchTags: "privacy adblock ads trackers filters sponsorblock youtube history cache cookies permissions clear"

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s2

                        SettingsCard {
                            Layout.fillWidth: true
                            implicitHeight: adBlockRows.implicitHeight
                            ColumnLayout {
                                id: adBlockRows
                                anchors.fill: parent
                                spacing: 0
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Мощный блокировщик рекламы")
                                    hint: AdBlockManager.statusText
                                    iconName: AdBlockManager.enabled ? "shield-check" : "shield"
                                    ToggleSwitch {
                                        accessibleName: qsTr("Блокировщик рекламы")
                                        checked: AdBlockManager.enabled
                                        onToggled: AdBlockManager.enabled = !AdBlockManager.enabled
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Режим защиты")
                                    hint: qsTr("Стандартный бережёт совместимость; агрессивный включает более жёсткие правила.")
                                    iconName: "gauge"
                                    Row {
                                        spacing: Theme.s2
                                        Chip {
                                            label: qsTr("Стандарт")
                                            iconName: "shield"
                                            selected: AdBlockManager.mode === "standard"
                                            onClicked: AdBlockManager.mode = "standard"
                                        }
                                        Chip {
                                            label: qsTr("Агрессивный")
                                            iconName: "zap"
                                            selected: AdBlockManager.mode === "aggressive"
                                            onClicked: AdBlockManager.mode = "aggressive"
                                        }
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Косметическая фильтрация")
                                    hint: qsTr("Скрывает рекламные блоки, которые приехали внутри страницы.")
                                    iconName: "sparkles"
                                    ToggleSwitch {
                                        accessibleName: qsTr("Косметическая фильтрация")
                                        checked: AdBlockManager.cosmeticFilteringEnabled
                                        onToggled: AdBlockManager.cosmeticFilteringEnabled = !AdBlockManager.cosmeticFilteringEnabled
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Трекеры")
                                    hint: qsTr("EasyPrivacy и дополнительные privacy-списки при следующем обновлении.")
                                    iconName: "shield-check"
                                    ToggleSwitch {
                                        accessibleName: qsTr("Блокировать трекеры")
                                        checked: AdBlockManager.trackingProtectionEnabled
                                        onToggled: AdBlockManager.trackingProtectionEnabled = !AdBlockManager.trackingProtectionEnabled
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Раздражающие элементы")
                                    hint: qsTr("Cookie-плашки, pop-up и вредоносные/навязчивые фильтры uBO.")
                                    iconName: "bell"
                                    ToggleSwitch {
                                        accessibleName: qsTr("Блокировать раздражающие элементы")
                                        checked: AdBlockManager.annoyanceBlockingEnabled
                                        onToggled: AdBlockManager.annoyanceBlockingEnabled = !AdBlockManager.annoyanceBlockingEnabled
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("YouTube SponsorBlock")
                                    hint: qsTr("Автоматически пропускает sponsor, self-promo, intro, outro и похожие сегменты.")
                                    iconName: "skip-forward"
                                    ToggleSwitch {
                                        accessibleName: qsTr("YouTube SponsorBlock")
                                        checked: AdBlockManager.sponsorBlockEnabled
                                        onToggled: AdBlockManager.sponsorBlockEnabled = !AdBlockManager.sponsorBlockEnabled
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Автообновление списков")
                                    hint: AdBlockManager.lastUpdateAt.length > 0
                                          ? qsTr("Последнее обновление: %1").arg(AdBlockManager.lastUpdateAt)
                                          : qsTr("Списки обновятся в фоне после запуска.")
                                    iconName: "rotate-cw"
                                    Row {
                                        spacing: Theme.s2
                                        ToggleSwitch {
                                            accessibleName: qsTr("Автообновление списков")
                                            checked: AdBlockManager.autoUpdate
                                            onToggled: AdBlockManager.autoUpdate = !AdBlockManager.autoUpdate
                                        }
                                        GlassButton {
                                            text: AdBlockManager.updating ? qsTr("Обновляем...") : qsTr("Обновить")
                                            enabled: !AdBlockManager.updating
                                            onClicked: AdBlockManager.refreshLists()
                                        }
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    label: qsTr("Пользовательские списки")
                                    hint: AdBlockManager.customLists.length + " "
                                          + Theme.plural(AdBlockManager.customLists.length, qsTr("список"), qsTr("списка"), qsTr("списков"))
                                    iconName: "bookmark"
                                    Column {
                                        width: 360
                                        spacing: Theme.s2
                                        Row {
                                            spacing: Theme.s2
                                            FieldBox {
                                                width: 250
                                                text: settingsRoot.adBlockListDraft
                                                accessibleName: qsTr("URL списка фильтров")
                                                placeholderText: qsTr("https://example.com/filter.txt")
                                                onAccepted: (value) => settingsRoot.adBlockListDraft = value
                                            }
                                            GlassButton {
                                                text: qsTr("Добавить")
                                                onClicked: {
                                                    AdBlockManager.addCustomList(settingsRoot.adBlockListDraft)
                                                    settingsRoot.adBlockListDraft = ""
                                                }
                                            }
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: Theme.s2
                                            visible: AdBlockManager.customLists.length > 0
                                            Repeater {
                                                model: AdBlockManager.customLists
                                                delegate: Chip {
                                                    required property string modelData
                                                    label: modelData
                                                    iconName: "x"
                                                    selected: true
                                                    onClicked: AdBlockManager.removeCustomList(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                                SettingRow {
                                    Layout.fillWidth: true
                                    showDivider: false
                                    label: qsTr("Сайты без блокировки")
                                    hint: qsTr("Для этих доменов сетевые и косметические правила не применяются.")
                                    iconName: "globe"
                                    Column {
                                        width: 360
                                        spacing: Theme.s2
                                        Row {
                                            spacing: Theme.s2
                                            FieldBox {
                                                width: 250
                                                text: settingsRoot.adBlockSiteDraft
                                                accessibleName: qsTr("Домен без блокировки")
                                                placeholderText: qsTr("example.com")
                                                onAccepted: (value) => settingsRoot.adBlockSiteDraft = value
                                            }
                                            GlassButton {
                                                text: qsTr("Добавить")
                                                onClicked: {
                                                    AdBlockManager.setSiteAllowed(settingsRoot.adBlockSiteDraft, true)
                                                    settingsRoot.adBlockSiteDraft = ""
                                                }
                                            }
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: Theme.s2
                                            visible: AdBlockManager.allowedSites.length > 0
                                            Repeater {
                                                model: AdBlockManager.allowedSites
                                                delegate: Chip {
                                                    required property string modelData
                                                    label: modelData
                                                    iconName: "x"
                                                    selected: true
                                                    onClicked: AdBlockManager.setSiteAllowed(modelData, false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        DangerRow {
                            Layout.fillWidth: true
                            label: qsTr("Очистить историю посещений")
                            hint: HistoryModel.count + " " + Theme.plural(HistoryModel.count, qsTr("запись"), qsTr("записи"), qsTr("записей"))
                            act: (function() { HistoryModel.clear() })
                        }
                        DangerRow {
                            Layout.fillWidth: true
	                            label: qsTr("Очистить кэш")
	                            act: (function() { BrowsingData.clearCache(settingsRoot.profile) })
	                        }
                        DangerRow {
                            Layout.fillWidth: true
	                            label: qsTr("Очистить cookie и данные сайтов")
	                            hint: qsTr("выход со всех сайтов")
	                            act: (function() { BrowsingData.clearAll(settingsRoot.profile) })
	                        }
                        DangerRow {
                            Layout.fillWidth: true
	                            label: qsTr("Сбросить разрешения сайтов")
	                            act: (function() { BrowsingData.clearPermissions(settingsRoot.profile) })
	                        }
                    }
                }

                SectionBlock {
                    category: "updates"
                    title: qsTr("Обновления")
                    subtitle: qsTr("Проверка новых версий Filka и быстрый переход к загрузке.")
                    searchTags: "updates version release download"

                    SettingsCard {
                        Layout.fillWidth: true
                        implicitHeight: updateRows.implicitHeight
                        ColumnLayout {
                            id: updateRows
                            anchors.fill: parent
                            spacing: 0
                            SettingRow {
                                Layout.fillWidth: true
                                label: qsTr("Текущая версия")
                                hint: UpdateChecker.checking
                                      ? qsTr("Проверяем наличие обновлений...")
                                      : UpdateChecker.updateAvailable
                                        ? qsTr("Доступна версия %1").arg(UpdateChecker.latestVersion)
                                        : UpdateChecker.upToDate
                                          ? qsTr("У вас актуальная версия")
                                          : qsTr("Проверяйте обновления вручную.")
                                iconName: UpdateChecker.updateAvailable ? "sparkles" : "shield-check"
                                Row {
                                    spacing: Theme.s2
                                    GlassButton {
                                        text: UpdateChecker.checking ? qsTr("Проверка...") : qsTr("Проверить")
                                        enabled: !UpdateChecker.checking
                                        onClicked: UpdateChecker.checkForUpdates()
                                    }
                                    GlassButton {
                                        visible: UpdateChecker.updateAvailable
                                        accentVariant: true
                                        text: qsTr("Скачать")
                                        onClicked: UpdateChecker.openDownload()
                                    }
                                }
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                showDivider: false
                                label: qsTr("Номер сборки")
                                hint: qsTr("Filka %1").arg(UpdateChecker.currentVersion)
                                iconName: "code"
                            }
                        }
                    }
                }

                SectionBlock {
                    category: "advanced"
                    title: qsTr("Дополнительно")
                    subtitle: qsTr("Импорт данных и служебные действия для восстановления привычного состояния.")
                    searchTags: "advanced import browser bookmarks history reset quick links defaults"

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s2
                        SettingsCard {
                            Layout.fillWidth: true
                            implicitHeight: importRows.implicitHeight
                            ColumnLayout {
                                id: importRows
                                anchors.fill: parent
                                spacing: 0
                                SettingRow {
                                    Layout.fillWidth: true
                                    showDivider: false
                                    label: qsTr("Импорт из другого браузера")
                                    hint: qsTr("Перенести закладки и историю из Chrome, Chromium, Opera, Brave или Firefox.")
                                    iconName: "import"
                                    GlassButton {
                                        text: qsTr("Открыть импорт")
                                        accentVariant: true
                                        onClicked: importDialog.open()
                                    }
                                }
                            }
                        }
                        DangerRow {
                            Layout.fillWidth: true
                            label: qsTr("Вернуть быстрые ссылки по умолчанию")
                            hint: qsTr("YouTube, GitHub, Wikipedia, Reddit")
                            iconName: "rotate-cw"
                            act: (function() { QuickLinkModel.resetDefaults() })
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: settingsRoot.query.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Конец результатов поиска")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                }
            }
        }
    }
            }
        }
    }
}
