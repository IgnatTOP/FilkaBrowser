import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// BrowserView — the full browsing shell (M3 + M4). Owns the WorkspaceModel;
// each workspace keeps its own live WebPane (tab stack), so switching is instant
// and never reloads. The body uses explicit anchoring (sidebar + content) for a
// predictable master-detail layout instead of fragile nested Qt Layouts.
Item {
    id: root

    property bool verticalTabs: true
    readonly property int sidebarWidth: 248
    signal toggleVpn()
    signal toggleAi()

    property bool showHistory: false
    property bool showSettings: false
    property bool showDownloads: false
    property bool showTranslator: false

    // Live download requests (newest first). Their progress properties are
    // bindable, so the panel updates without any extra model plumbing.
    property var downloads: []

    WorkspaceModel { id: workspaces }

    // Active pane (per workspace) and its active web view.
    property Item activePane: null
    property Item activeView: activePane ? activePane.activeView : null

    // Null-safe helpers for the active view.
    readonly property bool canGoBack: activeView ? activeView.canGoBack : false
    readonly property bool canGoForward: activeView ? activeView.canGoForward : false
    readonly property bool isLoading: activeView ? activeView.loading : false
    readonly property real loadProgress: activeView ? activeView.loadProgress / 100 : 0
    readonly property bool isSecure: activeView
                                    ? activeView.url.toString().startsWith("https://") : false
    readonly property string currentUrl: activeView && activeView.url != "about:blank"
                                         ? activeView.url : ""
    // True when the active tab sits on the start page (no real web content).
    readonly property bool atHome: !activeView || activeView.url == "about:blank"

    property bool showDevTools: false
    property bool showFind: false
    property var pendingPermission: null
    property bool fullScreen: false
    readonly property real zoomFactor: activeView ? activeView.zoomFactor : 1.0
    readonly property bool translatorWaitingForPage: showTranslator && !PageTranslator.translating

    // Whether the current page is bookmarked (kept in sync with BookmarkModel).
    property bool bookmarked: false
    function refreshBookmark() {
        bookmarked = currentUrl.length > 0 && BookmarkModel.contains(currentUrl)
    }
    onCurrentUrlChanged: refreshBookmark()
    Connections {
        target: BookmarkModel
        function onChanged() { root.refreshBookmark() }
    }
    function toggleBookmark() {
        if (!activeView || currentUrl.length === 0) return
        BookmarkModel.toggle(activeView.url, activeView.title ? activeView.title : currentUrl)
    }

    // Resolve raw text (URL or search query) and load it in the active tab.
    function navigateActive(text) {
        if (!activeView) return
        var url = addressBar.resolve(text)
        if (url.length) activeView.url = url
    }

    function syncPane() { activePane = paneRep.itemAt(workspaces.activeIndex) }
    Component.onCompleted: syncPane()
    Connections {
        target: workspaces
        function onActiveIndexChanged() { root.syncPane() }
    }

    // ===== Tab / navigation actions (shared by toolbar + keyboard shortcuts) =====
    function newTab() {
        if (workspaces.activeTabs) workspaces.activeTabs.addTab()   // opens the start page
    }
    function closeCurrentTab() {
        var t = workspaces.activeTabs
        if (t) t.closeTab(t.activeIndex)
    }
    function cycleTab(dir) {
        var t = workspaces.activeTabs
        if (!t || t.count === 0) return
        t.activeIndex = (t.activeIndex + dir + t.count) % t.count
    }
    function selectTab(i) {                 // i === -1 selects the last tab
        var t = workspaces.activeTabs
        if (!t || t.count === 0) return
        t.activeIndex = (i === -1) ? t.count - 1 : Math.min(i, t.count - 1)
    }
    function zoomBy(delta) {
        if (activeView)
            activeView.zoomFactor = Math.max(0.25, Math.min(5.0, activeView.zoomFactor + delta))
    }
    function resetZoom() { if (activeView) activeView.zoomFactor = 1.0 }

    function reportTranslatorDebug(hypothesisId, location, msg, data) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:7777/event")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({
            sessionId: "page-translation-bug",
            runId: "pre-fix",
            hypothesisId: hypothesisId,
            location: location,
            msg: "[DEBUG] " + msg,
            data: data || {},
            ts: Date.now()
        }))
    }

    // Extract page text BEFORE the content is hidden (runJavaScript may not
    // return results on a hidden WebEngineView).  Called when the translator
    // button is clicked so the text is ready by the time the panel opens.
    function extractForTranslation() {
        // #region debug-point A:extract-start
        reportTranslatorDebug("A", "BrowserView.extractForTranslation", "Extract requested", {
            hasActiveView: !!activeView,
            isLoading: isLoading,
            showTranslator: showTranslator,
            url: currentUrl
        })
        // #endregion
        if (!activeView || isLoading) return
        var view = activeView
        var pageTitle = view.title || ""
        view.runJavaScript(
            "document.body ? document.body.innerText : ''",
            function(text) {
                // #region debug-point A:extract-finished
                reportTranslatorDebug("A", "BrowserView.extractForTranslation.callback", "Extract completed", {
                    hasText: !!(text && text.trim().length > 0),
                    textLength: text ? text.length : 0,
                    pageTitleLength: pageTitle.length,
                    showTranslator: showTranslator
                })
                // #endregion
                if (text && text.trim().length > 0)
                    PageTranslator.setCachedText(text, pageTitle, view.url ? view.url.toString() : "")
            })
    }

    function resetTranslatorState(reason) {
        // #region debug-point E:reset
        reportTranslatorDebug("E", "BrowserView.resetTranslatorState", "Translator state reset", {
            reason: reason,
            showTranslator: showTranslator,
            url: currentUrl
        })
        // #endregion
        PageTranslator.clear()
    }

    // ===== Top chrome: optional horizontal tab bar + toolbar =====
    ColumnLayout {
        id: chrome
        visible: !root.fullScreen
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 0

        // Horizontal tab bar (only when tabs are on top).
        TabPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: root.verticalTabs ? 0 : 48
            visible: !root.verticalTabs
            vertical: false
            workspaces: workspaces
        }

        // Navigation toolbar (operates on the active view).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s3
                spacing: Theme.s2

                IconButton {
                    iconName: "chevron-left"; size: 34
                    enabled: root.canGoBack
                    opacity: enabled ? 1 : 0.4
                    Accessible.name: "Back"
                    onClicked: root.activeView.goBack()
                }
                IconButton {
                    iconName: "chevron-right"; size: 34
                    enabled: root.canGoForward
                    opacity: enabled ? 1 : 0.4
                    Accessible.name: "Forward"
                    onClicked: root.activeView.goForward()
                }
                IconButton {
                    iconName: root.isLoading ? "x" : "rotate-cw"
                    size: 34
                    Accessible.name: root.isLoading ? "Stop" : "Reload"
                    onClicked: {
                        if (!root.activeView) return
                        root.isLoading ? root.activeView.stop() : root.activeView.reload()
                    }
                }
                IconButton {
                    iconName: "house"; size: 34
                    Accessible.name: "Home"
                    onClicked: if (root.activeView) root.activeView.url = AppSettings.homePage
                }

                AddressBar {
                    id: addressBar
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    displayUrl: root.currentUrl
                    secure: root.isSecure
                    loading: root.isLoading
                    progress: root.loadProgress
                    onNavigate: (text) => { if (root.activeView) root.activeView.url = text }
                }

                IconButton {
                    iconName: "bookmark"; size: 34
                    enabled: root.currentUrl.length > 0
                    opacity: enabled ? 1 : 0.4
                    active: root.bookmarked
                    Accessible.name: "Bookmark"
                    onClicked: root.toggleBookmark()
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    visible: Math.abs(root.zoomFactor - 1) > 0.01
                    implicitWidth: zoomText.implicitWidth + Theme.s3
                    implicitHeight: 28
                    radius: Theme.radiusPill
                    color: zoomHover.hovered ? Theme.glassHigh : Theme.glassLow
                    border.width: 1; border.color: Theme.glassStroke
                    Text {
                        id: zoomText
                        anchors.centerIn: parent
                        text: Math.round(root.zoomFactor * 100) + "%"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
                    }
                    HoverHandler { id: zoomHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.resetZoom() }
                }

                IconButton {
                    iconName: root.verticalTabs ? "panel-left" : "panel-top"; size: 34
                    Accessible.name: "Toggle tab bar position"
                    onClicked: root.verticalTabs = !root.verticalTabs
                }
                IconButton {
                    iconName: "history"; size: 34
                    active: root.showHistory
                    Accessible.name: "History"
                    onClicked: { root.showSettings = false; root.showDownloads = false; root.showTranslator = false; root.showHistory = !root.showHistory }
                }
                IconButton {
                    iconName: "download"; size: 34
                    active: root.showDownloads
                    Accessible.name: "Downloads"
                    onClicked: { root.showHistory = false; root.showSettings = false; root.showTranslator = false; root.showDownloads = !root.showDownloads }
                }
                IconButton {
                    iconName: "languages"; size: 34
                    active: root.showTranslator
                    Accessible.name: "Translator"
                    onClicked: {
                        if (!root.showTranslator) root.extractForTranslation()
                        root.showHistory = false; root.showSettings = false; root.showDownloads = false
                        root.showTranslator = !root.showTranslator
                    }
                }
                IconButton {
                    iconName: Theme.dark ? "moon" : "sun"; size: 34
                    Accessible.name: "Toggle theme"
                    onClicked: AppSettings.darkMode = !AppSettings.darkMode
                }
                IconButton {
                    iconName: "settings"; size: 34
                    active: root.showSettings
                    Accessible.name: "Settings"
                    onClicked: { root.showHistory = false; root.showDownloads = false; root.showTranslator = false; root.showSettings = !root.showSettings }
                }
            }
        }

        // Saved-page chips under the toolbar.
        BookmarksBar {
            Layout.fillWidth: true
            onNavigate: (url) => { if (root.activeView) root.activeView.url = url }
        }

        // In-page search bar (Ctrl+F) — collapsed to 0 height when inactive.
        FindBar {
            id: findBar
            Layout.fillWidth: true
            view: root.activeView
            active: root.showFind
            onClosed: root.showFind = false
        }

        // Site permission prompt (camera/mic/location) — chrome-level so it
        // renders above web content.
        PermissionBar {
            Layout.fillWidth: true
            permission: root.pendingPermission
            onDecided: root.pendingPermission = null
        }
    }

    // ===== Body: sidebar (vertical mode) + web content =====
    Item {
        id: body
        anchors {
            top: root.fullScreen ? parent.top : chrome.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
        }

        // Vertical sidebar: workspace switcher on top, tabs below.
        Item {
            id: sidebar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: (root.verticalTabs && !root.fullScreen) ? root.sidebarWidth : 0
            visible: width > 0
            clip: true
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

            ColumnLayout {
                anchors.fill: parent
                width: root.sidebarWidth     // keep content width stable while collapsing
                spacing: 0

                WorkspaceSwitcher {
                    workspaces: workspaces
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s3
                    Layout.rightMargin: Theme.s3
                    Layout.preferredHeight: 1
                    color: Theme.glassHairline
                }
                TabStrip {
                    tabs: workspaces.activeTabs
                    vertical: true
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        // Web content: one live pane per workspace, crossfaded on switch.
        // Hidden while a slide-over panel is open: Qt's WebEngineView composites
        // above QML, so leaving it visible would punch through the panel/scrim.
        // Hiding only toggles visibility — pages keep their state and never reload.
        Item {
            id: content
            visible: !root.showHistory && !root.showSettings && !root.showDownloads && !root.showTranslator
            anchors {
                left: sidebar.right; right: parent.right
                top: parent.top; bottom: parent.bottom
                leftMargin: root.fullScreen ? 0 : Theme.s3
                rightMargin: root.fullScreen ? 0 : Theme.s3
                bottomMargin: root.fullScreen ? 0 : Theme.s3
            }

            Repeater {
                id: paneRep
                model: workspaces
                onItemAdded: root.syncPane()

                delegate: WebPane {
                    anchors.fill: parent
                    tabsModel: model.tabs
                    showWeb: !root.atHome
                    onDevToolsRequested: root.showDevTools = true
                    onFullScreenRequested: (on) => root.fullScreen = on
                    onPermissionRequested: (p) => root.pendingPermission = p
                    opacity: index === workspaces.activeIndex ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                }
            }

            // Start / new-tab surface — overlays the (hidden) web view at home.
            StartPage {
                anchors.fill: parent
                visible: root.atHome
                onNavigate: (text) => root.navigateActive(text)
            }
        }
    }

    // ===== Slide-over panels =====
    HistoryPanel {
        open: root.showHistory
        onRequestClose: root.showHistory = false
        onNavigate: (url) => { if (root.activeView) root.activeView.url = url }
    }
    SettingsPanel {
        open: root.showSettings
        onRequestClose: root.showSettings = false
    }
    DownloadsPanel {
        open: root.showDownloads
        downloads: root.downloads
        onRequestClose: root.showDownloads = false
        onClearList: root.downloads = []
    }
    TranslatorPanel {
        id: translatorBar
        open: root.showTranslator
        activeView: root.activeView
        visible: open && !root.showHistory && !root.showSettings && !root.showDownloads
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s3
        width: Math.min(520, parent.width - Theme.s4)
        z: 300
        onRequestClose: root.showTranslator = false
    }

    // Cancel translator when the active tab or page changes.
    Connections {
        target: root
        function onActiveViewChanged() {
            // #region debug-point E:active-view
            root.reportTranslatorDebug("E", "BrowserView.onActiveViewChanged", "Active view changed", {
                showTranslator: root.showTranslator,
                isLoading: root.isLoading,
                url: root.currentUrl
            })
            // #endregion
            root.resetTranslatorState("active-view-changed")
            if (root.showTranslator && root.activeView && !root.isLoading)
                root.extractForTranslation()
        }
    }

    Connections {
        target: root.activeView
        ignoreUnknownSignals: true

        function onLoadingChanged(loadRequest) {
            // #region debug-point E:loading-changed
            root.reportTranslatorDebug("E", "BrowserView.activeView.onLoadingChanged", "Active view loading changed", {
                loading: root.activeView ? root.activeView.loading : false,
                status: loadRequest ? loadRequest.status : -1,
                url: root.currentUrl,
                showTranslator: root.showTranslator
            })
            // #endregion
            if (!root.activeView)
                return
            if (root.activeView.loading) {
                root.resetTranslatorState("page-loading")
                return
            }
            if (root.showTranslator)
                root.extractForTranslation()
        }

        function onUrlChanged() {
            // #region debug-point E:url-changed
            root.reportTranslatorDebug("E", "BrowserView.activeView.onUrlChanged", "Active view URL changed", {
                url: root.currentUrl,
                showTranslator: root.showTranslator
            })
            // #endregion
            root.resetTranslatorState("url-changed")
        }
    }

    // ===== Keyboard shortcuts =====
    // Window-wide browser accelerators. WebEngineView keeps its own in-page
    // shortcuts; these cover chrome-level actions (tabs, navigation, zoom).
    Shortcut { sequence: "Ctrl+T"; onActivated: root.newTab() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.closeCurrentTab() }
    Shortcut { sequences: ["Ctrl+L", "Ctrl+K", "Alt+D"]; onActivated: addressBar.focusInput() }
    Shortcut { sequences: [StandardKey.Refresh, "Ctrl+R"]
               onActivated: if (root.activeView) root.activeView.reload() }
    Shortcut { sequence: StandardKey.Back
               onActivated: if (root.canGoBack) root.activeView.goBack() }
    Shortcut { sequence: StandardKey.Forward
               onActivated: if (root.canGoForward) root.activeView.goForward() }
    Shortcut { sequence: "Ctrl+Tab";       onActivated: root.cycleTab(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: root.cycleTab(-1) }
    Shortcut { sequence: "Ctrl+PgDown";    onActivated: root.cycleTab(1) }
    Shortcut { sequence: "Ctrl+PgUp";      onActivated: root.cycleTab(-1) }
    Shortcut { sequences: [StandardKey.ZoomIn, "Ctrl+="]; onActivated: root.zoomBy(0.1) }
    Shortcut { sequence: StandardKey.ZoomOut; onActivated: root.zoomBy(-0.1) }
    Shortcut { sequence: "Ctrl+0";         onActivated: root.resetZoom() }

    Shortcut { sequences: ["F12", "Ctrl+Shift+I"]; onActivated: root.showDevTools = !root.showDevTools }
    Shortcut { sequence: StandardKey.Find; onActivated: { root.showFind = true; findBar.openBar() } }
    Shortcut { sequence: "Ctrl+Shift+T"
               onActivated: {
                   if (!root.showTranslator) root.extractForTranslation()
                   root.showHistory = false; root.showSettings = false; root.showDownloads = false
                   root.showTranslator = !root.showTranslator
               } }
    Shortcut { sequence: "Escape"; enabled: root.fullScreen
               onActivated: if (root.activeView) root.activeView.triggerWebAction(WebEngineView.ExitFullScreen) }

    // Ctrl+1..8 jump to that tab; Ctrl+9 jumps to the last tab (browser convention).
    Instantiator {
        model: 9
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            onActivated: root.selectTab(index === 8 ? -1 : index)
        }
    }

    // ===== Downloads ===== accept to the configured folder and track progress.
    Connections {
        target: filkaProfile
        function onDownloadRequested(download) {
            download.accept()
            root.downloads = [download].concat(root.downloads)
            root.showDownloads = true
        }
    }

    // ===== Developer tools ===== a detachable inspector for the active tab.
    // The heavy WebEngineView is created lazily the first time it's opened.
    Window {
        id: devWindow
        width: 1000; height: 680
        visible: root.showDevTools
        title: "Filka — Инструменты разработчика"
        color: "#1e1e1e"
        onClosing: root.showDevTools = false

        Loader {
            anchors.fill: parent
            active: root.showDevTools
            sourceComponent: WebEngineView {
                profile: filkaProfile
                inspectedView: root.activeView
            }
        }
    }
}
