pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// NavigationBar — the page bar that sits above the web content. It drives the
// active tab: history nav, reload/home, a wide address pill, and a tidy cluster
// of page actions (bookmark, translate, screenshot, find) plus the command
// palette and an overflow menu. The overflow gives a visible home to every
// feature that used to live only behind a keyboard shortcut (print, PiP, zoom,
// dev tools, tab-position, theme) and to the panel destinations. State lives on
// `browser` (BrowserView) and `shell` (ShellState).
Item {
    id: root

    required property var browser
    required property ShellState shell

    implicitHeight: Theme.toolbarHeight

    // Rounded opaque card, matching the tab strip and web frame so the whole
    // top chrome reads as a consistent stack of rounded surfaces.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.bgRaised      // opaque — never let the page show through
        border.width: 1
        border.color: Theme.glassHairline
    }

    // Let the host pull keyboard focus into the address input (Ctrl+L / Ctrl+K).
    function focusAddress() { addressBar.focusInput() }
    function resolve(text) { return addressBar.resolve(text) }

    function showPopoverAt(popover, item) {
        if (!popover || !item)
            return
        const point = item.mapToItem(popover.parent, 0, item.height + Theme.s1)
        popover.x = Math.min(popover.parent.width - popover.implicitWidth - Theme.s2,
                             Math.max(Theme.s2, point.x + item.width - popover.implicitWidth))
        popover.y = Math.min(popover.parent.height - popover.implicitHeight - Theme.s2,
                             Math.max(Theme.s2, point.y))
        popover.open()
    }
    function currentHostLabel() {
        const raw = String(root.browser.currentUrl || "")
        if (raw.length === 0)
            return qsTr("Текущий сайт")
        try {
            const parsed = new URL(raw)
            return parsed.hostname.replace(/^www\./, "") || qsTr("Текущий сайт")
        } catch (e) {
            return raw.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "")
                      .split(/[/?#]/)[0]
                      .replace(/^www\./, "") || qsTr("Текущий сайт")
        }
    }
    function tabWorkspace(tabId) { return tabId && tabId.workspaceIndex !== undefined ? tabId.workspaceIndex : 0 }
    function tabIndex(tabId) { return tabId && tabId.index !== undefined ? tabId.index : tabId }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s2
        anchors.rightMargin: Theme.s2
        spacing: Theme.s1

        // ===== History / reload / home =====
        IconButton {
            iconName: "chevron-left"; size: Theme.controlMd
            enabled: root.browser.canGoBack
            opacity: enabled ? 1 : 0.4
            tooltip: qsTr("Назад"); Accessible.name: qsTr("Назад")
            onClicked: if (root.browser.activeView) root.browser.activeView.goBack()
        }
        IconButton {
            iconName: "chevron-right"; size: Theme.controlMd
            enabled: root.browser.canGoForward
            opacity: enabled ? 1 : 0.4
            tooltip: qsTr("Вперёд"); Accessible.name: qsTr("Вперёд")
            onClicked: if (root.browser.activeView) root.browser.activeView.goForward()
        }
        IconButton {
            iconName: root.browser.isLoading ? "x" : "rotate-cw"
            size: Theme.controlMd
            tooltip: root.browser.isLoading ? qsTr("Остановить") : qsTr("Обновить")
            Accessible.name: tooltip
            onClicked: {
                if (!root.browser.activeView) return
                root.browser.isLoading ? root.browser.activeView.stop()
                                       : root.browser.activeView.reload()
            }
        }
        IconButton {
            iconName: "house"; size: Theme.controlMd
            active: root.browser.atHome
            tooltip: qsTr("Главная"); Accessible.name: qsTr("Главная")
            onClicked: if (root.browser.activeView) root.browser.activeView.url = "about:blank"
        }

        // ===== Address =====
        AddressBar {
            id: addressBar
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            displayUrl: root.browser.currentUrl
            secure: root.browser.isSecure
            loading: root.browser.isLoading
            progress: root.browser.loadProgress
            privateMode: root.browser.privateMode
            onNavigate: (text) => { if (root.browser.activeView) root.browser.activeView.url = text }
            onSecurityClicked: if (root.browser.currentUrl.length > 0) root.shell.toggleOverlay("siteInfo")
        }

        // ===== Page actions =====
        IconButton {
            id: adBlockButton
            readonly property bool siteAllowed: AdBlockManager.allowedSites.length >= 0
                                                && root.browser.currentUrl.length > 0
                                                && AdBlockManager.isSiteAllowed(root.browser.currentUrl)
            iconName: AdBlockManager.enabled && !siteAllowed ? "shield-check" : "shield"
            size: Theme.controlMd
            enabled: root.browser.currentUrl.length > 0
            opacity: enabled ? 1 : 0.4
            active: adBlockPopover.opened || (AdBlockManager.enabled && !siteAllowed)
            tooltip: siteAllowed
                     ? qsTr("Блокировка выключена для этого сайта")
                     : qsTr("%1 · заблокировано %2").arg(AdBlockManager.statusText).arg(AdBlockManager.blockedRequests)
            Accessible.name: tooltip
            onClicked: root.showPopoverAt(adBlockPopover, adBlockButton)
        }

        // Zoom badge — only while zoomed; tap resets to 100%.
        Pill {
            id: zoomPill
            accessibleName: qsTr("Сбросить масштаб")
            readonly property bool shown: Math.abs(root.browser.zoomFactor - 1) > 0.01
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: shown ? implicitWidth : 0
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            clip: true
            onClicked: root.browser.resetZoom()
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
            Text {
                text: Math.round(root.browser.zoomFactor * 100) + "%"
                color: Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
            }
        }

        // Media controls — only when a tab is making sound.
        IconButton {
            id: mediaButton
            readonly property bool shown: root.browser.audibleTabs && root.browser.audibleTabs.length > 0
            iconName: "music"; size: Theme.controlMd
            Layout.preferredWidth: shown ? size : 0
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            clip: true
            tooltip: qsTr("Медиа"); Accessible.name: qsTr("Медиа")
            onClicked: root.showPopoverAt(mediaPopover, mediaButton)
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
        }

        IconButton {
            iconName: "bookmark"; size: Theme.controlMd
            enabled: root.browser.currentUrl.length > 0
            opacity: enabled ? 1 : 0.4
            active: root.browser.bookmarked
            tooltip: qsTr("Закладка"); Accessible.name: qsTr("Закладка")
            onClicked: root.browser.toggleBookmark()
        }
        IconButton {
            iconName: "languages"; size: Theme.controlMd
            enabled: !root.browser.atHome
            opacity: enabled ? 1 : 0.4
            active: root.shell.activePanel === "translator"
            tooltip: qsTr("Перевести страницу"); Accessible.name: qsTr("Перевести страницу")
            onClicked: root.shell.togglePanel("translator")
        }
        IconButton {
            id: screenshotButton
            iconName: "camera"; size: Theme.controlMd
            tooltip: qsTr("Скриншот"); Accessible.name: qsTr("Скриншот")
            onClicked: screenshotPrompt.showAt(screenshotButton)
        }
        IconButton {
            iconName: "search"; size: Theme.controlMd
            enabled: !root.browser.atHome
            opacity: enabled ? 1 : 0.4
            active: root.shell.showFind
            tooltip: qsTr("Найти на странице"); Accessible.name: qsTr("Найти на странице")
            onClicked: root.browser.openFind()
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            color: Theme.glassHairline
        }

        IconButton {
            iconName: "command"; size: Theme.controlMd
            active: root.shell.activeOverlay === "commandPalette"
            tooltip: qsTr("Командная палитра"); Accessible.name: qsTr("Командная палитра")
            onClicked: root.browser.openCommandPalette()
        }
        IconButton {
            id: overflowButton
            iconName: "ellipsis"; size: Theme.controlMd
            active: overflowMenu.opened
            tooltip: qsTr("Ещё"); Accessible.name: qsTr("Ещё")
            onClicked: overflowMenu.popup(overflowButton, 0, overflowButton.height + Theme.s1)
        }
    }

    Popup {
        id: adBlockPopover

        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        padding: 0
        implicitWidth: 370

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
        }

        background: Rectangle {
            radius: Theme.radiusLg
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.glassStroke
        }

        contentItem: ColumnLayout {
            id: adBlockBody

            implicitWidth: adBlockPopover.implicitWidth
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.s4
                spacing: Theme.s3

                Item {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMd
                        color: AdBlockManager.enabled && !adBlockButton.siteAllowed
                               ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: 1
                        border.color: AdBlockManager.enabled && !adBlockButton.siteAllowed
                                      ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
                                      : Theme.glassHairline
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: AdBlockManager.enabled && !adBlockButton.siteAllowed ? "shield-check" : "shield"
                        size: 18
                        color: AdBlockManager.enabled && !adBlockButton.siteAllowed ? Theme.accent : Theme.textSecondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Блокировщик рекламы")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: adBlockButton.siteAllowed
                              ? qsTr("Выключен для %1").arg(root.currentHostLabel())
                              : AdBlockManager.statusText
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    Layout.preferredWidth: size
                    Layout.preferredHeight: size
                    iconName: "x"
                    size: Theme.controlMd
                    Accessible.name: qsTr("Закрыть")
                    onClicked: adBlockPopover.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.s3
                columns: 2
                columnSpacing: Theme.s2
                rowSpacing: Theme.s2

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.radiusMd
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.glassHairline

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s3
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: AdBlockManager.blockedRequests
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Font.DemiBold
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("заблокировано")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.radiusMd
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.glassHairline

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s3
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: AdBlockManager.rulesCount
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Font.DemiBold
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("правил")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s3
                Layout.rightMargin: Theme.s3
                Layout.topMargin: Theme.s2
                Layout.bottomMargin: Theme.s2
                spacing: Theme.s1

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    spacing: Theme.s3

                    Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        name: AdBlockManager.enabled ? "shield-check" : "shield"
                        size: 18
                        color: AdBlockManager.enabled ? Theme.accent : Theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Блокировка")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: AdBlockManager.enabled ? qsTr("Сетевые и косметические правила активны")
                                                         : qsTr("Все правила временно выключены")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        accessibleName: qsTr("Блокировка рекламы")
                        checked: AdBlockManager.enabled
                        onToggled: AdBlockManager.enabled = !AdBlockManager.enabled
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    spacing: Theme.s3

                    Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        name: "globe"
                        size: 18
                        color: adBlockButton.siteAllowed ? Theme.warning : Theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.currentHostLabel()
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: adBlockButton.siteAllowed ? qsTr("Сайт в исключениях") : qsTr("Блокировка применяется к сайту")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        accessibleName: qsTr("Выключить блокировку для текущего сайта")
                        checked: !adBlockButton.siteAllowed
                        onToggled: AdBlockManager.setSiteAllowed(root.browser.currentUrl, !adBlockButton.siteAllowed)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    spacing: Theme.s3

                    Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        name: "skip-forward"
                        size: 18
                        color: AdBlockManager.sponsorBlockEnabled ? Theme.accent : Theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("YouTube SponsorBlock")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: AdBlockManager.sponsorBlockEnabled
                                  ? qsTr("Пропускает sponsor, self-promo, intro и outro")
                                  : qsTr("Сегменты YouTube не пропускаются")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        accessibleName: qsTr("YouTube SponsorBlock")
                        checked: AdBlockManager.sponsorBlockEnabled
                        onToggled: AdBlockManager.sponsorBlockEnabled = !AdBlockManager.sponsorBlockEnabled
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: Theme.s3

                    Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        name: "gauge"
                        size: 18
                        color: Theme.textSecondary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Режим защиты")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.Medium
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Row {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.controlSm
                        spacing: Theme.s1

                        Chip {
                            label: qsTr("Стандарт")
                            iconName: "shield"
                            selected: AdBlockManager.mode === "standard"
                            hPadding: Theme.s2
                            onClicked: AdBlockManager.mode = "standard"
                        }

                        Chip {
                            label: qsTr("Агрессивный")
                            iconName: "zap"
                            selected: AdBlockManager.mode === "aggressive"
                            hPadding: Theme.s2
                            onClicked: AdBlockManager.mode = "aggressive"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.s3
                spacing: Theme.s2

                GlassButton {
                    Layout.fillWidth: true
                    text: AdBlockManager.updating ? qsTr("Обновляем...") : qsTr("Обновить списки")
                    enabled: !AdBlockManager.updating
                    onClicked: AdBlockManager.refreshLists()
                }

                GlassButton {
                    Layout.fillWidth: true
                    text: qsTr("Настройки")
                    onClicked: {
                        adBlockPopover.close()
                        root.shell.activePanel = "settings"
                    }
                }
            }
        }
    }

    // ===== Overflow menu — a visible home for every action =====
    Menu {
        id: overflowMenu
        width: 268
        padding: 6
        overlap: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
        }

        background: Rectangle {
            implicitWidth: 268
            radius: Theme.radiusMd
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.glassStroke
        }

        component MItem: MenuItem {
            id: mi
            property string iconName: ""
            property string shortcut: ""
            implicitHeight: visible ? 36 : 0
            horizontalPadding: Theme.s2
            contentItem: RowLayout {
                spacing: Theme.s2
                Icon {
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                    name: mi.iconName
                    size: 15
                    color: mi.highlighted ? Theme.accent : Theme.textSecondary
                }
                Text {
                    Layout.fillWidth: true
                    text: mi.text
                    color: mi.enabled ? Theme.textPrimary : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                Text {
                    visible: mi.shortcut.length > 0
                    text: mi.shortcut
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                }
            }
            background: Rectangle {
                radius: Theme.radiusSm
                color: mi.highlighted ? Theme.accentSoft : "transparent"
            }
        }
        component MSep: MenuSeparator {
            padding: 4
            contentItem: Rectangle { implicitHeight: 1; color: Theme.glassHairline }
        }

        MItem {
            text: qsTr("Новая вкладка"); iconName: "plus"; shortcut: "Ctrl+T"
            onTriggered: root.browser.newTab()
        }
        MItem {
            text: qsTr("Найти вкладку"); iconName: "layout-grid"; shortcut: "Ctrl+Shift+F"
            onTriggered: root.browser.openTabSearch()
        }

        MSep {}
        MItem {
            text: qsTr("История"); iconName: "history"
            onTriggered: root.shell.togglePanel("history")
        }
        MItem {
            text: qsTr("Загрузки"); iconName: "download"
            onTriggered: root.shell.togglePanel("downloads")
        }
        MItem {
            text: qsTr("Закладки"); iconName: "bookmark"
            onTriggered: root.shell.togglePanel("bookmarks")
        }

        MSep {}
        MItem {
            text: qsTr("Картинка в картинке"); iconName: "picture-in-picture"; shortcut: "Ctrl+Alt+P"
            enabled: !root.browser.atHome
            onTriggered: root.browser.openPictureInPicture()
        }
        MItem {
            text: qsTr("Сохранить как PDF"); iconName: "copy"; shortcut: "Ctrl+P"
            enabled: !root.browser.atHome
            onTriggered: root.browser.printPage()
        }
        MItem {
            text: qsTr("Увеличить"); iconName: "plus"; shortcut: "Ctrl++"
            onTriggered: root.browser.zoomBy(0.1)
        }
        MItem {
            text: qsTr("Уменьшить"); iconName: "minus"; shortcut: "Ctrl+-"
            onTriggered: root.browser.zoomBy(-0.1)
        }
        MItem {
            text: qsTr("Сбросить масштаб"); iconName: "search"; shortcut: "Ctrl+0"
            enabled: Math.abs(root.browser.zoomFactor - 1) > 0.01
            onTriggered: root.browser.resetZoom()
        }

        MSep {}
        MItem {
            text: root.browser.verticalTabs ? qsTr("Вкладки сверху") : qsTr("Вкладки сбоку")
            iconName: root.browser.verticalTabs ? "panel-top" : "panel-left"
            onTriggered: AppSettings.verticalTabs = !AppSettings.verticalTabs
        }
        MItem {
            text: Theme.dark ? qsTr("Светлая тема") : qsTr("Тёмная тема")
            iconName: Theme.dark ? "sun" : "moon"
            onTriggered: AppSettings.darkMode = !AppSettings.darkMode
        }
        MItem {
            text: qsTr("Инструменты разработчика"); iconName: "code"; shortcut: "F12"
            onTriggered: root.shell.showDevTools = !root.shell.showDevTools
        }
        MItem {
            text: qsTr("Настройки"); iconName: "settings"
            onTriggered: root.shell.togglePanel("settings")
        }
    }

    ScreenshotPrompt {
        id: screenshotPrompt
        onCaptureFull: (copyToClipboard) => root.browser.captureVisible(copyToClipboard)
        onSelectArea: (copyToClipboard) => root.browser.startAreaScreenshot(copyToClipboard)
    }

    MediaControlsPopover {
        id: mediaPopover
        mediaTabs: root.browser.audibleTabs ? root.browser.audibleTabs : []
        currentUrl: root.browser.currentUrl
        currentTitle: root.browser.activeView && root.browser.activeView.title ? root.browser.activeView.title : ""
        onRequestActivate: (tabId) => root.browser.activateWorkspaceTab(root.tabWorkspace(tabId), root.tabIndex(tabId))
        onRequestMute: (tabId, muted) => root.browser.muteWorkspaceTab(root.tabWorkspace(tabId), root.tabIndex(tabId), muted)
        onRequestPlayPause: (tabId) => root.browser.toggleTabMedia(root.tabWorkspace(tabId), root.tabIndex(tabId))
        onRequestPauseAll: root.browser.toggleGlobalMedia()
    }
}
