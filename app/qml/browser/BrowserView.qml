pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import QtWebEngine
import Filka

// BrowserView — the browsing shell. A thin orchestrator: it owns the workspace
// model and the live web panes, and wires them to the focused chrome pieces
// (NavigationBar, PanelHost, BrowserShortcuts). All transient UI state lives on
// the ShellState controller, so this file stays about layout and data flow —
// not the tangle of panel booleans and translator plumbing it used to hold.
Item {
    id: root

    readonly property bool verticalTabs: AppSettings.verticalTabs
    property bool privateMode: false
    property bool handleProfileDownloads: true
    readonly property int sidebarWidth: 274
    property var profile
    property var windowTarget: null

    // Fullscreen is part of shell state; alias keeps Main.qml's binding intact.
    property alias fullScreen: shell.fullScreen

    // Raised on Ctrl+N — the host window opens another top-level Filka window.
    signal newWindowRequested()
    signal newPrivateWindowRequested()
    function newWindow() { newWindowRequested() }
    function newPrivateWindow() { newPrivateWindowRequested() }

    WorkspaceModel { id: workspaces }
    ShellState { id: shell }

    // ===== Active pane / view resolution =====
    property Item activePane: null
    property Item activeView: activePane ? activePane.activeView : null
    property var fullScreenOwner: null

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
    readonly property var activeTabs: workspaces.activeTabs
    readonly property var audibleTabs: workspaces.audibleTabs

    function syncPane() { activePane = paneRep.itemAt(workspaces.activeIndex) }
    Component.onCompleted: syncPane()
    onActiveViewChanged: {
        if (shell.fullScreen && fullScreenOwner && activeView !== fullScreenOwner)
            exitFullScreen()
    }
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

    // ===== Navigation actions (shared by sidebar, home and shortcuts) =====
    function resolve(text) {
        var t = ("" + text).trim()
        if (t.length === 0) return ""
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t)) return t
        if (/^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(t)) return "http://" + t
        if (!/\s/.test(t) && /^[^\s]+\.[^\s]{2,}/.test(t)) return "https://" + t
        return AppSettings.searchUrl(t)
    }

    function navigate(text) {
        if (!activeView) return
        var url = resolve(text)
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
    function sanitizedPdfName(title) {
        var name = (title && title.length ? title : "Filka")
                   .replace(/[\/\\:*?"<>|\x00-\x1F]+/g, "_")
                   .replace(/^[\s.]+|[\s.]+$/g, "")
                   .slice(0, 80)
        return name.length ? name : "Filka"
    }
    function pdfPathForView(view) {
        return AppSettings.downloadPath + "/"
                + sanitizedPdfName(view && view.title ? view.title : "Filka") + ".pdf"
    }
    function openPdfFile(path) {
        Qt.openUrlExternally("file://" + path)
    }
    function finishPrintToPdf(path, success) {
        if (success) {
            pdfToast.savedPath = path
            pdfToast.message = qsTr("PDF сохранён")
            pdfToast.open()
            openPdfFile(path)
        } else {
            pdfToast.savedPath = ""
            pdfToast.message = qsTr("Не удалось сохранить PDF")
            pdfToast.open()
            console.warn("Filka: PDF print failed for", path)
        }
    }
    // Save a web view as a PDF into the downloads folder. Toolbar, shortcut and
    // web context menu all route through this helper so path, filename cleanup,
    // toast/status and opening behavior stay identical.
    function printViewToPdf(view) {
        if (!view) return
        view.printToPdf(pdfPathForView(view))
    }
    function printPage() {
        if (!activeView || atHome) return
        printViewToPdf(activeView)
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
    function focusAddress() { pageBar.focusAddress() }
    function openFind() { shell.showFind = true; findBar.openBar() }
    function closeFind() { findBar.closeBar() }
    function openCommandPalette() { shell.activeOverlay = "commandPalette" }
    function openTabSearch() { shell.activeOverlay = "tabSearch" }
    function captureTitle() {
        return activeView && activeView.title && activeView.title.length
                ? activeView.title : (workspaces.activeName.length ? workspaces.activeName : "Filka")
    }
    function captureVisible(copyToClipboard) {
        if (!activeView && !content)
            return
        var target = activeView || content
        var output = ScreenshotHelper.makePath(AppSettings.downloadPath, captureTitle())
        target.grabToImage(function(result) {
            var path = copyToClipboard ? ScreenshotHelper.temporaryPath() : output
            if (!result.saveToFile(path))
                return
            if (copyToClipboard)
                ScreenshotHelper.copyImageFile(path)
            screenshotToast.savedPath = copyToClipboard ? "" : path
            screenshotToast.message = copyToClipboard ? qsTr("Скриншот скопирован") : qsTr("Скриншот сохранён")
            screenshotToast.open()
        })
    }
    function captureArea(rect, copyToClipboard) {
        if (!content || rect.width < 8 || rect.height < 8)
            return
        var output = ScreenshotHelper.makePath(AppSettings.downloadPath, captureTitle())
        var temp = ScreenshotHelper.temporaryPath()
        content.grabToImage(function(result) {
            if (!result.saveToFile(temp))
                return
            if (!ScreenshotHelper.cropImageFile(temp, output, rect, Qt.size(content.width, content.height)))
                return
            if (copyToClipboard)
                ScreenshotHelper.copyImageFile(output)
            screenshotToast.savedPath = copyToClipboard ? "" : output
            screenshotToast.message = copyToClipboard ? qsTr("Фрагмент скопирован") : qsTr("Скриншот сохранён")
            screenshotToast.open()
        })
    }
    function screenshotTab(tabIndex) {
        if (!workspaces.activeTabs)
            return
        workspaces.activeTabs.activeIndex = tabIndex
        Qt.callLater(function() { root.captureVisible(false) })
    }
    function startAreaScreenshot(copyToClipboard) { screenshotOverlay.start(copyToClipboard) }
    function toggleGlobalMedia() {
        var audible = workspaces.audibleTabs
        for (var i = 0; i < audible.length; ++i)
            pauseTabMedia(audible[i].workspaceIndex, audible[i].index)
    }
    function activateWorkspaceTab(workspaceIndex, tabIndex) {
        workspaces.activateTab(workspaceIndex, tabIndex)
    }
    function muteWorkspaceTab(workspaceIndex, tabIndex, muted) {
        workspaces.setTabMuted(workspaceIndex, tabIndex, muted)
    }
    function runMediaScript(workspaceIndex, tabIndex, script) {
        var pane = paneRep.itemAt(workspaceIndex)
        var view = pane && pane.viewAt ? pane.viewAt(tabIndex) : null
        if (view)
            view.runJavaScript(script)
    }
    function pauseTabMedia(workspaceIndex, tabIndex) {
        runMediaScript(workspaceIndex, tabIndex,
            "(function(){document.querySelectorAll('video,audio').forEach(function(m){m.pause();});})();")
    }
    function toggleTabMedia(workspaceIndex, tabIndex) {
        runMediaScript(workspaceIndex, tabIndex,
            "(function(){var m=document.querySelector('video,audio');if(!m)return;if(m.paused)m.play();else m.pause();})();")
    }
    function openPictureInPicture() {
        if (!activeView || atHome)
            return
        pipWindow.sourceUrl = activeView.url
        pipWindow.title = activeView.title && activeView.title.length ? activeView.title : qsTr("Картинка в картинке")
        activeView.runJavaScript("(async function(){const v=document.querySelector('video');if(v&&document.pictureInPictureEnabled){try{if(document.pictureInPictureElement){await document.exitPictureInPicture();}else{await v.requestPictureInPicture();}}catch(e){}}})();")
        pipWindow.open()
    }
    function setFullScreen(on, view) {
        if (on) {
            fullScreenOwner = view
            shell.fullScreen = true
            return
        }
        if (!view || view === fullScreenOwner) {
            fullScreenOwner = null
            shell.fullScreen = false
        }
    }
    function exitFullScreen() {
        const owner = fullScreenOwner || activeView
        fullScreenOwner = null
        shell.fullScreen = false
        if (owner)
            owner.triggerWebAction(WebEngineView.ExitFullScreen)
    }
    function handleDownload(download) {
        var name = download.downloadFileName && download.downloadFileName.length > 0
                ? download.downloadFileName : download.suggestedFileName
        if (AppSettings.askDownloadLocation) {
            shell.pendingDownload = download
            shell.activeOverlay = "downloadPrompt"
            return
        }
        DownloadModel.acceptDownload(download, AppSettings.downloadPath, name, root.privateMode)
        shell.activePanel = "downloads"
    }

    // ===== Body: sidebar (vertical mode) + web content =====
    Item {
        id: body
        anchors.fill: parent

        // Content rail — shown only in the side-tabs layout. In the top-tabs
        // layout it collapses to zero so the page bar + tab strip own the chrome
        // (workspaces move into the tab strip), Chrome-style.
        Item {
            id: sidebar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: (!shell.fullScreen && root.verticalTabs) ? root.sidebarWidth : 0
            visible: width > 0
            clip: true
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

            PremiumSidebar {
                id: premiumSidebar
                anchors.fill: parent
                browser: root
                shell: shell
                workspaces: workspaces
                windowTarget: root.windowTarget
            }
        }

        // Web content: one live pane per workspace, crossfaded on switch.
        // The web views render into a layer texture (see WebPane), so QML panels
        // and the translator bar composite cleanly above them — the page stays
        // live and visible while a panel is open (no blank-out, and in-page
        // translation keeps working because the view is never hidden).
        Item {
            id: content
            // Insets are constant (driven only by fullscreen), so the page bar
            // and tab strip never shift when navigating between the start page
            // and a website — the chrome stays put, only the surface beneath it
            // changes.
            anchors {
                left: sidebar.right; right: parent.right
                top: parent.top; bottom: parent.bottom
                leftMargin: shell.fullScreen ? 0 : Theme.s2
                rightMargin: shell.fullScreen ? 0 : Theme.s2
                topMargin: shell.fullScreen ? 0 : Theme.s2
                bottomMargin: shell.fullScreen ? 0 : Theme.s2
            }

            // Total height occupied by the page bar + (optional) top tab strip,
            // so the web view, start page and floating bars all sit beneath them.
            readonly property real chromeInset:
                (pageBar.visible ? pageBar.height : 0)
                + (topTabBar.visible ? topTabBar.height + Theme.s1 : 0)

            // Page bar — navigation, address and the page-action cluster. Always
            // present except in fullscreen, in both tab layouts.
            // In the top-tabs layout the tab strip is the very top row and the
            // page bar sits beneath it (Chrome/Safari order); in side-tabs the
            // strip is hidden and the page bar owns the top.
            GlassPanel {
                id: topTabBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 44
                visible: !root.verticalTabs && !shell.fullScreen
                z: 520
                level: 1
                fillColor: Theme.bgRaised      // opaque — no page bleed-through
                radius: Theme.radiusMd
                shadow: false

                // Double-tap the strip to (un)maximize, mirroring the sidebar
                // header — the frameless window has no native title bar.
                TapHandler {
                    gesturePolicy: TapHandler.DragThreshold
                    onDoubleTapped: {
                        if (!root.windowTarget)
                            return
                        root.windowTarget.visibility === Window.Maximized
                            ? root.windowTarget.showNormal() : root.windowTarget.showMaximized()
                    }
                }

                // Workspaces live here in the top-tabs layout (no sidebar), with
                // the tab strip filling the rest of the row. Window controls move
                // up here too, since the sidebar that normally hosts them is gone.
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s2
                    anchors.rightMargin: Theme.s1
                    spacing: Theme.s2

                    WindowControls {
                        Layout.alignment: Qt.AlignVCenter
                        target: root.windowTarget
                    }
                    WorkspaceSwitcher {
                        Layout.alignment: Qt.AlignVCenter
                        workspaces: workspaces
                    }
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.glassHairline
                    }
                    TabStrip {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tabs: workspaces.activeTabs
                        vertical: false
                        onScreenshotRequested: (tabIndex) => root.screenshotTab(tabIndex)
                    }
                }
            }

            NavigationBar {
                id: pageBar
                anchors {
                    left: parent.left; right: parent.right
                    top: topTabBar.visible ? topTabBar.bottom : parent.top
                    topMargin: topTabBar.visible ? Theme.s1 : 0
                }
                height: implicitHeight
                visible: !shell.fullScreen
                z: 540
                browser: root
                shell: shell
            }

            Repeater {
                id: paneRep
                model: workspaces
                onItemAdded: root.syncPane()

                delegate: WebPane {
                    required property int index
                    required property var model
                    anchors.fill: parent
                    anchors.topMargin: content.chromeInset + Theme.s1
                    profile: root.profile
                    tabsModel: model.tabs
                    recordHistory: !root.privateMode
                    defaultZoom: AppSettings.defaultZoom
                    showWeb: !root.atHome
                    roundedWebClip: !shell.fullScreen   // rounded page card
                    browser: root
                    onDevToolsRequested: shell.showDevTools = true
                    onPictureInPictureRequested: root.openPictureInPicture()
                    onFullScreenRequested: (on, view) => root.setFullScreen(on, view)
                    onPermissionRequested: (permission) => shell.pendingPermission = permission
                    onPdfPrintingFinished: (path, success) => root.finishPrintToPdf(path, success)
                    opacity: index === workspaces.activeIndex ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                }
            }

            // Start / new-tab surface — overlays the (hidden) web view at home.
            StartPage {
                anchors {
                    fill: parent
                    topMargin: content.chromeInset
                }
                visible: root.atHome
                privateMode: root.privateMode
                workspaceName: workspaces.activeName
                tabCount: workspaces.activeTabs ? workspaces.activeTabs.count : 0
                onNavigate: (text) => root.navigate(text)
                onOpenPanel: (panel) => shell.togglePanel(panel)
            }

            FindBar {
                id: findBar
                z: 500
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: content.chromeInset + Theme.s3
                }
                width: Math.min(620, parent.width - Theme.s6)
                view: root.activeView
                active: shell.showFind
                onClosed: shell.showFind = false
            }

            PermissionBar {
                z: 500
                anchors {
                    top: findBar.active ? findBar.bottom : parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: findBar.active ? Theme.s3 : content.chromeInset + Theme.s3
                }
                width: Math.min(760, parent.width - Theme.s6)
                permission: shell.pendingPermission
                onDecided: shell.pendingPermission = null
                onSiteSettingsRequested: shell.activeOverlay = "siteInfo"
            }

            Item {
                id: translationWash
                anchors.fill: parent
                anchors.topMargin: content.chromeInset
                visible: PageTranslator.activeJobs > 0 || PageTranslator.translating
                opacity: visible ? 1 : 0
                z: 430
                Behavior on opacity { OpacityAnimator { duration: Motion.base; easing.type: Motion.standard } }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.045)
                }
                Rectangle {
                    id: scanLine
                    visible: !Motion.reducedMotion
                    width: parent.width * 0.34
                    height: 2
                    radius: 1
                    y: 0
                    color: Theme.accent
                    opacity: 0.75
                    XAnimator on x {
                        running: translationWash.visible && !Motion.reducedMotion
                        loops: Animation.Infinite
                        from: -scanLine.width
                        to: translationWash.width
                        duration: 1400
                        easing.type: Motion.standard
                    }
                }
            }

            TabSearchOverlay {
                id: tabSearchOverlay
                anchors.fill: parent
                workspaceModel: workspaces
                tabModel: workspaces.activeTabs
                currentWorkspace: workspaces.activeIndex
                currentTabId: workspaces.activeTabs ? workspaces.activeTabs.activeIndex : -1
                onOpenedChanged: {
                    if (!opened && shell.activeOverlay === "tabSearch")
                        shell.activeOverlay = ""
                }
                onRequestActivate: (workspaceId, tabId) => {
                    root.activateWorkspaceTab(workspaceId, tabId)
                    shell.closeOverlays()
                }
                onRequestClose: (tabId) => {
                    workspaces.closeTab(requestedWorkspaceId, tabId)
                }
            }

            Connections {
                target: shell
                function onActiveOverlayChanged() {
                    if (shell.activeOverlay === "tabSearch")
                        tabSearchOverlay.open()
                    else if (tabSearchOverlay.opened)
                        tabSearchOverlay.close()
                }
            }

            ScreenshotOverlay {
                id: screenshotOverlay
                anchors.fill: parent
                onAccepted: (selection, copyToClipboard) => root.captureArea(selection, copyToClipboard)
                onCancelled: {}
            }

            Popup {
                id: pdfToast
                property string message: ""
                property string savedPath: ""
                parent: Overlay.overlay
                modal: false
                focus: false
                closePolicy: Popup.NoAutoClose
                x: Math.round((parent.width - width) / 2)
                y: parent.height - height - Theme.s6
                padding: 0
                implicitWidth: pdfToastBody.implicitWidth
                implicitHeight: pdfToastBody.implicitHeight
                Timer {
                    id: pdfToastTimer
                    interval: 3000
                    onTriggered: pdfToast.close()
                }
                onOpened: pdfToastTimer.restart()
                background: Rectangle {
                    radius: Theme.radiusPill
                    color: Theme.bgRaised
                    border.width: 1
                    border.color: Theme.glassStroke
                }
                contentItem: RowLayout {
                    id: pdfToastBody
                    spacing: Theme.s2
                    anchors.margins: Theme.s2
                    Icon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        name: pdfToast.savedPath.length > 0 ? "check" : "x"
                        size: 15
                        color: pdfToast.savedPath.length > 0 ? Theme.positive : Theme.danger
                    }
                    Text {
                        text: pdfToast.message
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                    GlassButton {
                        visible: pdfToast.savedPath.length > 0
                        text: qsTr("Открыть")
                        onClicked: root.openPdfFile(pdfToast.savedPath)
                    }
                }
            }

            Popup {
                id: screenshotToast
                property string message: ""
                property string savedPath: ""
                parent: Overlay.overlay
                modal: false
                focus: false
                closePolicy: Popup.NoAutoClose
                x: Math.round((parent.width - width) / 2)
                y: parent.height - height - Theme.s6
                padding: 0
                implicitWidth: toastBody.implicitWidth
                implicitHeight: toastBody.implicitHeight
                Timer {
                    id: toastTimer
                    interval: 3000
                    onTriggered: screenshotToast.close()
                }
                onOpened: toastTimer.restart()
                background: Rectangle {
                    radius: Theme.radiusPill
                    color: Theme.bgRaised
                    border.width: 1
                    border.color: Theme.glassStroke
                }
                contentItem: RowLayout {
                    id: toastBody
                    spacing: Theme.s2
                    anchors.margins: Theme.s2
                    Icon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        name: "check"
                        size: 15
                        color: Theme.positive
                    }
                    Text {
                        text: screenshotToast.message
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                    GlassButton {
                        visible: screenshotToast.savedPath.length > 0
                        text: qsTr("Открыть")
                        onClicked: ScreenshotHelper.revealFile(screenshotToast.savedPath)
                    }
                }
            }
        }
    }

    PictureInPictureWindow {
        id: pipWindow
    }

    // ===== Slide-over panels + floating translator bar =====
    PanelHost {
        z: 900
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
        target: root.handleProfileDownloads ? root.profile : null
        function onDownloadRequested(download) { root.handleDownload(download) }
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
