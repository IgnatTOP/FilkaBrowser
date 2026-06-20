import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Filka

// WelcomeDialog — first-run onboarding as a two-pane guided wizard over a dimmed
// backdrop: a left rail lists the steps (welcome → appearance → search & tabs →
// import → done) with the current one lit and finished ones checked; the right
// pane holds the active step, crossfading and sliding between them. Flat,
// gradient-free surfaces. "Открыть Filka" flips AppSettings.onboarded; the rail
// and "Пропустить" let the user jump or leave at any time.
Item {
    id: root
    anchors.fill: parent
    z: 1000

    readonly property int stepCount: 5
    property int step: 0

    readonly property var steps: [
        { icon: "sparkles",  title: qsTr("Знакомство"),       hint: qsTr("Пара слов о Filka") },
        { icon: "palette",   title: qsTr("Внешний вид"),       hint: qsTr("Тема и акцент") },
        { icon: "search",    title: qsTr("Поиск и вкладки"),   hint: qsTr("Движок и раскладка") },
        { icon: "import",    title: qsTr("Перенос данных"),    hint: qsTr("Из другого браузера") },
        { icon: "check",     title: qsTr("Готово"),            hint: qsTr("Можно начинать") }
    ]

    function next() { if (step < stepCount - 1) { step++ } else { finish() } }
    function back() { if (step > 0) { step-- } }
    function finish() { AppSettings.onboarded = true }
    function greetingName() {
        var n = AppSettings.displayName.trim()
        return n.length > 0 ? n : qsTr("друг")
    }

    // Dimmed backdrop.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        TapHandler {}   // swallow clicks behind the card
    }

    // Entrance.
    opacity: 0
    Component.onCompleted: inAnim.start()
    ParallelAnimation {
        id: inAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
        NumberAnimation { target: card; property: "scale"; from: 0.95; to: 1; duration: Motion.slow; easing.type: Motion.emphasized }
    }

    // ---- Reusable bits ----------------------------------------------------

    // One wizard page: stacked, only the active one is shown and interactive.
    component WizardPage: Item {
        property int index: 0
        anchors.fill: parent
        visible: opacity > 0.01
        enabled: root.step === index
        opacity: root.step === index ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
        transform: Translate {
            x: (index - root.step) * 28
            Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
        }
    }

    component Heading: ColumnLayout {
        property string title: ""
        property string subtitle: ""
        Layout.fillWidth: true
        spacing: 5
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXl; font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: parent.subtitle
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
            lineHeight: 1.25
        }
    }

    GlassPanel {
        id: card
        level: 2
        radius: Theme.radiusLg
        width: Math.min(760, root.width - Theme.s5 * 2)
        height: Math.min(540, root.height - Theme.s5 * 2)
        anchors.centerIn: parent

        Rectangle {   // flat opaque base — no gradient glassmorphism
            anchors.fill: parent
            radius: Theme.radiusLg
            color: Theme.modalSurface
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ===== Left rail: brand + step list =====
            Rectangle {
                Layout.preferredWidth: 244
                Layout.fillHeight: true
                color: Theme.surfaceAlt
                topLeftRadius: Theme.radiusLg
                bottomLeftRadius: Theme.radiusLg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    spacing: Theme.s2

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.s2
                        spacing: Theme.s2
                        Image {
                            source: "qrc:/qt/qml/Filka/assets/logo.png"
                            sourceSize: Qt.size(72, 72)
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34
                            fillMode: Image.PreserveAspectFit
                            smooth: true; mipmap: true
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "Filka"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold
                            }
                            Text {
                                text: qsTr("Настройка")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                            }
                        }
                    }

                    Repeater {
                        model: root.steps
                        delegate: Rectangle {
                            id: rail
                            required property int index
                            required property var modelData
                            readonly property bool current: root.step === index
                            readonly property bool done: root.step > index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMd
                            color: current ? Theme.accentSoft
                                  : (railHover.hovered ? Theme.hoverFill : "transparent")
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.s2
                                anchors.rightMargin: Theme.s2
                                spacing: Theme.s2

                                Rectangle {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Theme.radiusSm
                                    color: rail.current || rail.done
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                           : Theme.surface
                                    border.width: 1
                                    border.color: rail.current ? Theme.accent : Theme.outline
                                    Icon {
                                        anchors.centerIn: parent
                                        name: rail.done ? "check" : rail.modelData.icon
                                        size: 15
                                        color: rail.current || rail.done ? Theme.accent : Theme.textMuted
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: rail.modelData.title
                                        color: rail.current ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: rail.current ? Font.DemiBold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: rail.modelData.hint
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            HoverHandler { id: railHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.step = rail.index }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Всё это можно изменить позже в настройках.")
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                }

                Rectangle {   // rail divider
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Theme.glassHairline
                }
            }

            // ===== Right pane: active step + footer =====
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.s4
                    Layout.bottomMargin: 0
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: root.step < root.stepCount - 1
                        text: qsTr("Пропустить")
                        color: skipHover.hovered ? Theme.textPrimary : Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                        HoverHandler { id: skipHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.finish() }
                    }
                }

                Item {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Theme.s5
                    Layout.rightMargin: Theme.s5
                    clip: true

                    // Step 0 — Welcome
                    WizardPage {
                        index: 0
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.s4
                            Item { Layout.preferredHeight: Theme.s2 }
                            Heading {
                                title: qsTr("Добро пожаловать в Filka")
                                subtitle: qsTr("Быстрый браузер с рабочими пространствами, приватностью и аккуратной анимацией. Пройдём настройку за пару шагов.")
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.s2
                                spacing: Theme.s2
                                Repeater {
                                    model: [
                                        { icon: "layout-grid", text: qsTr("Рабочие пространства для разных задач") },
                                        { icon: "languages",   text: qsTr("Встроенный перевод страниц") },
                                        { icon: "shield",       text: qsTr("Приватные окна и блокировка рекламы") }
                                    ]
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: Theme.s2
                                        Icon {
                                            Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                            name: modelData.icon; size: 16; color: Theme.accent
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.text
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                        }
                                    }
                                }
                            }
                            SectionLabel { text: qsTr("Как к вам обращаться?"); Layout.topMargin: Theme.s2; color: Theme.textMuted }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: Theme.radiusMd
                                color: nameField.activeFocus ? Theme.surface : Theme.surfaceAlt
                                border.width: 1
                                border.color: nameField.activeFocus ? Theme.accent : Theme.outline
                                TextField {
                                    id: nameField
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s3
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                    selectByMouse: true
                                    background: null
                                    placeholderText: qsTr("Имя (необязательно)")
                                    placeholderTextColor: Theme.textMuted
                                    text: AppSettings.displayName
                                    onTextChanged: AppSettings.displayName = text
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Step 1 — Appearance
                    WizardPage {
                        index: 1
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.s4
                            Item { Layout.preferredHeight: Theme.s2 }
                            Heading {
                                title: qsTr("Внешний вид")
                                subtitle: qsTr("Выберите тему и фирменный акцент. Это можно сменить в любой момент.")
                            }
                            SectionLabel { text: qsTr("Тема"); Layout.topMargin: Theme.s2; color: Theme.textMuted }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.s2
                                Repeater {
                                    model: [ { label: qsTr("Светлая"), dark: false }, { label: qsTr("Тёмная"), dark: true } ]
                                    delegate: Chip {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        radius: Theme.radiusMd
                                        fontSize: Theme.fontSizeSm
                                        iconSize: 15
                                        iconName: modelData.dark ? "moon" : "sun"
                                        label: modelData.label
                                        selected: AppSettings.darkMode === modelData.dark
                                        onClicked: AppSettings.darkMode = modelData.dark
                                    }
                                }
                            }
                            SectionLabel { text: qsTr("Акцент"); color: Theme.textMuted }
                            Flow {
                                Layout.fillWidth: true
                                spacing: Theme.s3
                                Repeater {
                                    model: ["#8B5CF6", "#C4B5FD", "#38BDF8", "#34D399", "#F87171", "#FBBF24", "#2E7CF6"]
                                    delegate: AccentSwatch {
                                        required property string modelData
                                        width: 34; height: 34
                                        swatchColor: modelData
                                        selected: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                                        onClicked: AppSettings.accentColor = modelData
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.s2
                                spacing: Theme.s3
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: qsTr("Живой фон на стартовой")
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: qsTr("Плавная заставка за начальным экраном")
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                                    }
                                }
                                ToggleSwitch {
                                    accessibleName: qsTr("Живой фон")
                                    checked: AppSettings.startPageAurora
                                    onToggled: AppSettings.startPageAurora = !AppSettings.startPageAurora
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Step 2 — Search & tabs
                    WizardPage {
                        index: 2
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.s4
                            Item { Layout.preferredHeight: Theme.s2 }
                            Heading {
                                title: qsTr("Поиск и вкладки")
                                subtitle: qsTr("Поисковая система по умолчанию и где расположить вкладки.")
                            }
                            SectionLabel { text: qsTr("Поиск"); Layout.topMargin: Theme.s2; color: Theme.textMuted }
                            Flow {
                                Layout.fillWidth: true
                                spacing: Theme.s2
                                Repeater {
                                    model: AppSettings.searchEngines()
                                    delegate: Chip {
                                        required property string modelData
                                        height: 36
                                        fontSize: Theme.fontSizeSm
                                        label: modelData
                                        selected: AppSettings.searchEngine === modelData
                                        onClicked: AppSettings.searchEngine = modelData
                                    }
                                }
                            }
                            SectionLabel { text: qsTr("Расположение вкладок"); color: Theme.textMuted }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.s2
                                Repeater {
                                    model: [ { label: qsTr("Сбоку"), vertical: true, icon: "panel-left" },
                                             { label: qsTr("Сверху"), vertical: false, icon: "panel-top" } ]
                                    delegate: Chip {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        radius: Theme.radiusMd
                                        fontSize: Theme.fontSizeSm
                                        iconSize: 15
                                        iconName: modelData.icon
                                        label: modelData.label
                                        selected: AppSettings.verticalTabs === modelData.vertical
                                        onClicked: AppSettings.verticalTabs = modelData.vertical
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Step 3 — Import
                    WizardPage {
                        id: importPage
                        index: 3
                        property var browsers: []
                        property string importNote: ""
                        onEnabledChanged: if (enabled) browsers = BrowserImporter.detectInstalled()

                        function importAll(id) {
                            var bm = BrowserImporter.importBookmarks(id)
                            var bmResult = BookmarkModel.importEntries(bm)
                            var hs = BrowserImporter.importHistory(id)
                            var hsResult = HistoryModel.importEntries(hs)
                            importNote = qsTr("Перенесено: %1 закладок, %2 записей истории. Пропущено дублей: %3, ошибок: %4.")
                                .arg(bmResult.added)
                                .arg(hsResult.added)
                                .arg(bmResult.skippedDuplicates + hsResult.skippedDuplicates)
                                .arg(bmResult.errors + hsResult.errors)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.s3
                            Item { Layout.preferredHeight: Theme.s2 }
                            Heading {
                                title: qsTr("Перенос данных")
                                subtitle: qsTr("Заберите закладки и историю из другого браузера — или пропустите этот шаг.")
                            }
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: importCol.implicitHeight
                                clip: true
                                ColumnLayout {
                                    id: importCol
                                    width: parent.width
                                    spacing: Theme.s2
                                    Repeater {
                                        model: importPage.browsers
                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 60
                                            radius: Theme.radiusMd
                                            color: Theme.surfaceAlt
                                            border.width: 1
                                            border.color: Theme.outline
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.s3
                                                spacing: Theme.s3
                                                Icon {
                                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22
                                                    name: modelData.family === "firefox" ? "globe" : "circle-user"
                                                    size: 20; color: Theme.accent
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                GlassButton {
                                                    text: qsTr("Перенести")
                                                    enabled: !BrowserImporter.busy
                                                    onClicked: importPage.importAll(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 96
                                        visible: importPage.browsers.length === 0
                                        radius: Theme.radiusMd
                                        color: Theme.surfaceAlt
                                        border.width: 1
                                        border.color: Theme.outline
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            width: parent.width - Theme.s5 * 2
                                            spacing: Theme.s1
                                            Icon { Layout.alignment: Qt.AlignHCenter; name: "import"; size: 22; color: Theme.textMuted }
                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTr("Установленные браузеры не найдены — этот шаг можно пропустить.")
                                                color: Theme.textMuted
                                                wrapMode: Text.WordWrap
                                                horizontalAlignment: Text.AlignHCenter
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: importPage.importNote.length > 0
                                text: importPage.importNote
                                color: Theme.positive
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                            }
                        }
                    }

                    // Step 4 — Done
                    WizardPage {
                        index: 4
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: Theme.s4
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 84; height: 84; radius: 42
                                color: Qt.rgba(Theme.positive.r, Theme.positive.g, Theme.positive.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(Theme.positive.r, Theme.positive.g, Theme.positive.b, 0.5)
                                Icon { anchors.centerIn: parent; name: "check"; size: 38; color: Theme.positive }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: qsTr("Всё готово, %1!").arg(root.greetingName())
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXl; font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: qsTr("Адрес и действия со страницей — наверху, пространства и вкладки — слева. Командная палитра по Ctrl+Shift+P найдёт что угодно.")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                lineHeight: 1.25
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.glassHairline
                }

                // Footer: back + progress text + primary action.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.s4
                    spacing: Theme.s2

                    GlassButton {
                        text: qsTr("Назад")
                        visible: root.step > 0
                        onClicked: root.back()
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("Шаг %1 из %2").arg(root.step + 1).arg(root.stepCount)
                        color: Theme.textMuted
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                    Item { Layout.fillWidth: true }
                    GlassButton {
                        accentVariant: true
                        text: root.step < root.stepCount - 1 ? qsTr("Далее") : qsTr("Открыть Filka")
                        font.weight: Font.DemiBold
                        onClicked: root.next()
                    }
                }
            }
        }
    }

    // Enter advances; Esc skips the wizard.
    Keys.onReturnPressed: root.next()
    Keys.onEnterPressed: root.next()
    Keys.onEscapePressed: root.finish()
    focus: true
}
