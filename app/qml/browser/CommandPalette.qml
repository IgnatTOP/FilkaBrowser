pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    required property var browser
    required property ShellState shell
    property bool open: false

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    z: 500
    focus: open
    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

    onOpenChanged: {
        if (open) {
            query.text = ""
            rebuild()
            query.forceActiveFocus()
        }
    }

    function close() {
        shell.closeOverlays()
    }

    function command(icon, title, subtitle, keys, run) {
        return { kind: "command", icon: icon, title: title, subtitle: subtitle, keys: keys, run: run }
    }

    function rebuild() {
        var q = query.text.trim()
        var lower = q.toLowerCase()
        var out = []
        var cmds = [
            command("plus", qsTr("Новая вкладка"), qsTr("Открыть стартовую страницу"), "Ctrl+T", function() { browser.newTab() }),
            command("circle-user", qsTr("Новое приватное окно"), qsTr("Временный профиль без истории"), "Ctrl+Shift+N", function() { browser.newPrivateWindow() }),
            command("search", qsTr("Фокус на адресную строку"), qsTr("Начать поиск или открыть сайт"), "Ctrl+L", function() { browser.focusAddress() }),
            command("history", qsTr("Открыть историю"), qsTr("Посещенные страницы"), "", function() { shell.togglePanel("history") }),
            command("download", qsTr("Открыть загрузки"), qsTr("Файлы и прогресс"), "", function() { shell.togglePanel("downloads") }),
            command("bookmark", qsTr("Добавить закладку"), qsTr("Сохранить текущую страницу"), "", function() { browser.toggleBookmark() }),
            command("languages", qsTr("Переводчик страницы"), qsTr("Показать панель перевода"), "Ctrl+Alt+T", function() { shell.togglePanel("translator") }),
            command("settings", qsTr("Открыть настройки"), qsTr("Поведение браузера"), "", function() { shell.togglePanel("settings") }),
            command("panel-left", qsTr("Переключить вкладки сбоку/сверху"), qsTr("Изменить расположение вкладок"), "", function() { AppSettings.verticalTabs = !AppSettings.verticalTabs }),
            command("sun", qsTr("Сменить тему"), qsTr("Светлая или темная"), "", function() { AppSettings.darkMode = !AppSettings.darkMode }),
            command("code", qsTr("Инструменты разработчика"), qsTr("Открыть инспектор"), "F12", function() { shell.showDevTools = !shell.showDevTools })
        ]

        for (var i = 0; i < cmds.length; ++i) {
            var c = cmds[i]
            if (lower.length === 0 || c.title.toLowerCase().indexOf(lower) >= 0
                    || c.subtitle.toLowerCase().indexOf(lower) >= 0) {
                out.push(c)
            }
        }

        var tabs = browser.activeTabs ? browser.activeTabs.entries(q, 8) : []
        for (var t = 0; t < tabs.length; ++t) {
            const tab = tabs[t]
            out.push({
                kind: "tab", icon: "globe", title: tab.title,
                subtitle: tab.url, keys: qsTr("Вкладка"),
                run: function(idx) { return function() { browser.activeTabs.activeIndex = idx } }(tab.index)
            })
        }

        var bookmarks = BookmarkModel.search(q, 6)
        for (var b = 0; b < bookmarks.length; ++b) {
            const bm = bookmarks[b]
            out.push({
                kind: "bookmark", icon: "bookmark", title: bm.title,
                subtitle: bm.url, keys: qsTr("Закладка"),
                run: function(url) { return function() { browser.navigate(url) } }(bm.url)
            })
        }

        var links = QuickLinkModel.search(q, 6)
        for (var l = 0; l < links.length; ++l) {
            const link = links[l]
            out.push({
                kind: "quick", icon: "zap", title: link.title,
                subtitle: link.url, keys: qsTr("Быстрая ссылка"),
                run: function(url) { return function() { browser.navigate(url) } }(link.url)
            })
        }

        if (q.length > 0) {
            var history = HistoryModel.search(q, 6)
            for (var h = 0; h < history.length; ++h) {
                const hist = history[h]
                out.push({
                    kind: "history", icon: "history", title: hist.title,
                    subtitle: hist.url, keys: qsTr("История"),
                    run: function(url) { return function() { browser.navigate(url) } }(hist.url)
                })
            }
        }

        results = out.slice(0, 18)
        list.currentIndex = results.length > 0 ? 0 : -1
    }

    property var results: []

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(60, parent.height * 0.14)
        width: Math.min(720, parent.width - Theme.s6)
        height: Math.min(560, parent.height - y - Theme.s6)
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusMd
                color: query.activeFocus ? Theme.surfaceAlt : Theme.card
                border.width: 1
                border.color: query.activeFocus ? Theme.accent : Theme.outline

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: "search"; size: 16; color: Theme.textMuted
                }
                TextField {
                    id: query
                    anchors { left: searchIcon.right; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: Theme.s2; rightMargin: Theme.s3 }
                    background: null
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    placeholderText: qsTr("Команда, вкладка, закладка или сайт")
                    placeholderTextColor: Theme.textMuted
                    Accessible.name: qsTr("Командная палитра")
                    onTextEdited: root.rebuild()
                    onAccepted: {
                        if (list.currentIndex >= 0 && list.currentIndex < root.results.length) {
                            root.results[list.currentIndex].run()
                            root.close()
                        }
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: list.currentIndex = Math.min(root.results.length - 1, list.currentIndex + 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: FilkaScrollBar {}

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    height: 48
                    radius: Theme.radiusSm
                    color: row.index === list.currentIndex ? Theme.activeFill
                          : hover.hovered ? Theme.hoverFill : "transparent"

                    Icon {
                        id: rowIcon
                        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        name: row.modelData.icon
                        size: 16
                        color: row.index === list.currentIndex ? Theme.accent : Theme.textMuted
                    }
                    Column {
                        anchors { left: rowIcon.right; right: keyLabel.left; verticalCenter: parent.verticalCenter
                                  leftMargin: Theme.s3; rightMargin: Theme.s2 }
                        spacing: 1
                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.subtitle
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        id: keyLabel
                        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        text: row.modelData.keys
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                    HoverHandler { id: hover }
                    TapHandler {
                        onTapped: {
                            list.currentIndex = row.index
                            row.modelData.run()
                            root.close()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.results.length === 0
                text: qsTr("Ничего не найдено")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
