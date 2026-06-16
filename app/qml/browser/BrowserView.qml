pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtWebEngine
import Filka

// BrowserView — the browsing shell. A thin orchestrator: it owns the workspace
// model and the live web panes, and wires them to the focused chrome pieces
// (NavigationBar, PanelHost, BrowserShortcuts). All transient UI state lives on
// the ShellState controller, so this file stays about layout and data flow —
// not the tangle of panel booleans and translator plumbing it used to hold.
Item {
    id: root

    property bool verticalTabs: true
    readonly property int sidebarWidth: 248
    property var profile

    // Fullscreen is part of shell state; alias keeps Main.qml's binding intact.
    property alias fullScreen: shell.fullScreen

    // Raised on Ctrl+N — the host window opens another top-level Filka window.
    signal newWindowRequested()
    function newWindow() { newWindowRequested() }

    WorkspaceModel { id: workspaces }
    ShellState { id: shell }

    // ===== Active pane / view resolution =====
    property Item activePane: null
    property Item activeView: activePane ? activePane.activeView : null

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
    readonly property real zoomFactor: activeView ? activeView.zoomFactor : 1.0

    function syncPane() { activePane = paneRep.itemAt(workspaces.activeIndex) }
    Component.onCompleted: syncPane()
    Connections {
        target: workspaces
        function onActiveIndexChanged() { root.syncPane() }
    }

    // ===== Bookmark state (kept in sync with BookmarkModel) =====
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

    // ===== Navigation actions (shared by toolbar + shortcuts) =====
    // Resolve raw text (URL or search query) and load it in the active tab.
    function navigate(text) {
        if (!activeView) return
        var url = navBar.resolve(text)
        if (url.length) activeView.url = url
    }
    function newTab() {
        if (workspaces.activeTabs) workspaces.activeTabs.addTab()
    }
    function closeCurrentTab() {
        var t = workspaces.activeTabs
        if (t) t.closeTab(t.activeIndex)
    }
    function reopenClosedTab() {
        var t = workspaces.activeTabs
        if (t) t.reopenClosedTab()
    }
    function duplicateCurrentTab() {
        var t = workspaces.activeTabs
        if (t) t.duplicateTab(t.activeIndex)
    }
    // Save the current page as a PDF into the downloads folder, then reveal it.
    function printPage() {
        if (!activeView || atHome) return
        var name = (activeView.title && activeView.title.length ? activeView.title : "Filka")
                   .replace(/[\/\\:*?"<>|]+/g, "_").slice(0, 80)
        var path = AppSettings.downloadDir() + "/" + name + ".pdf"
        activeView.printToPdf(path)
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
    function focusAddress() { navBar.focusAddress() }
    function openFind() { shell.showFind = true; findBar.openBar() }

    // ===== Top chrome: optional horizontal tab bar + toolbar =====
    ColumnLayout {
        id: chrome
        visible: !shell.fullScreen
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

        NavigationBar {
            id: navBar
            Layout.fillWidth: true
            browser: root
            shell: shell
        }

        // Saved-page chips under the toolbar.
        BookmarksBar {
            Layout.fillWidth: true
            onNavigate: (url) => root.navigate(url)
        }

        // In-page search (Ctrl+F) — collapses to 0 height when inactive.
        FindBar {
            id: findBar
            Layout.fillWidth: true
            view: root.activeView
            active: shell.showFind
            onClosed: shell.showFind = false
        }

        // Site permission prompt — chrome-level so it renders above web content.
        PermissionBar {
            Layout.fillWidth: true
            permission: shell.pendingPermission
            onDecided: shell.pendingPermission = null
        }
    }

    // ===== Body: sidebar (vertical mode) + web content =====
    Item {
        id: body
        anchors {
            top: shell.fullScreen ? parent.top : chrome.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
        }

        // Vertical sidebar: workspace switcher on top, tabs below.
        Item {
            id: sidebar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: (root.verticalTabs && !shell.fullScreen) ? root.sidebarWidth : 0
            visible: width > 0
            clip: true
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

            // Faint tint + right hairline set the tab column apart from content.
            Rectangle {
                anchors.fill: parent
                color: Theme.glassLow
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Theme.glassHairline
                }
            }

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
        // The web views render into a layer texture (see WebPane), so QML panels
        // and the translator bar composite cleanly above them — the page stays
        // live and visible while a panel is open (no blank-out, and in-page
        // translation keeps working because the view is never hidden).
        Item {
            id: content
            anchors {
                left: sidebar.right; right: parent.right
                top: parent.top; bottom: parent.bottom
                leftMargin: shell.fullScreen ? 0 : Theme.s3
                rightMargin: shell.fullScreen ? 0 : Theme.s3
                bottomMargin: shell.fullScreen ? 0 : Theme.s3
            }

            Repeater {
                id: paneRep
                model: workspaces
                onItemAdded: root.syncPane()

                delegate: WebPane {
                    required property int index
                    required property var model
                    anchors.fill: parent
                    profile: root.profile
                    tabsModel: model.tabs
                    showWeb: !root.atHome
                    onDevToolsRequested: shell.showDevTools = true
                    onFullScreenRequested: (on) => shell.fullScreen = on
                    onPermissionRequested: (permission) => shell.pendingPermission = permission
                    opacity: index === workspaces.activeIndex ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                }
            }

            // Start / new-tab surface — overlays the (hidden) web view at home.
            StartPage {
                anchors.fill: parent
                visible: root.atHome
                onNavigate: (text) => root.navigate(text)
            }
        }
    }

    // ===== Slide-over panels + floating translator bar =====
    PanelHost {
        browser: root
        shell: shell
    }

    // ===== Keyboard shortcuts =====
    BrowserShortcuts {
        browser: root
        shell: shell
    }

    // ===== Downloads ===== accept to the configured folder and track progress.
    Connections {
        target: root.profile
        function onDownloadRequested(download) {
            download.downloadDirectory = AppSettings.downloadDir()
            download.accept()
            shell.downloads = [download].concat(shell.downloads)
            shell.activePanel = "downloads"
        }
    }

    // ===== Developer tools ===== a detachable inspector for the active tab.
    // The heavy WebEngineView is created lazily the first time it's opened.
    Window {
        id: devWindow
        width: 1000; height: 680
        visible: shell.showDevTools
        title: "Filka — Инструменты разработчика"
        color: "#1e1e1e"
        onClosing: shell.showDevTools = false

        Loader {
            anchors.fill: parent
            active: shell.showDevTools
                sourceComponent: WebEngineView {
                    profile: root.profile
                    inspectedView: root.activeView
                }
        }
    }
}
