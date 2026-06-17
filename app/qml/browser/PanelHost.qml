import QtQuick
import Filka

// PanelHost — owns the shell's slide-over panels and the floating translator
// bar, all driven by `shell.activePanel`. Panels are stateless about openness:
// they bind `open` to ShellState and only emit requestClose/navigate, so the
// open/closed state has a single owner and two panels can never disagree.
Item {
    id: root

    required property var browser
    required property ShellState shell

    anchors.fill: parent

    HistoryPanel {
        open: root.shell.activePanel === "history"
        onRequestClose: root.shell.closePanels()
        onNavigate: (url) => { root.browser.navigate(url); root.shell.closePanels() }
    }

    DownloadsPanel {
        open: root.shell.activePanel === "downloads"
        privateMode: root.browser.privateMode
        onRequestClose: root.shell.closePanels()
        onClearList: DownloadModel.clearCompleted(root.browser.privateMode)
    }

    BookmarksPanel {
        open: root.shell.activePanel === "bookmarks"
        onRequestClose: root.shell.closePanels()
        onNavigate: (url) => { root.browser.navigate(url); root.shell.closePanels() }
    }

    SettingsPanel {
        open: root.shell.activePanel === "settings"
        profile: root.browser.profile
        onRequestClose: root.shell.closePanels()
    }

    TranslatorPopover {
        open: root.shell.activePanel === "translator"
        activeView: root.browser.activeView
        anchors.fill: parent
        anchorX: root.browser.sidebarWidth + Theme.s3
        anchorY: 92
        z: 300
        onRequestClose: root.shell.closePanels()
        onRequestSettings: root.shell.activePanel = "settings"
    }

    CommandPalette {
        anchors.fill: parent
        open: root.shell.activeOverlay === "commandPalette"
        browser: root.browser
        shell: root.shell
    }

    SiteInfoPopup {
        anchors.fill: parent
        open: root.shell.activeOverlay === "siteInfo"
        browser: root.browser
        shell: root.shell
    }

    DownloadPrompt {
        anchors.fill: parent
        open: root.shell.activeOverlay === "downloadPrompt"
        shell: root.shell
        privateMode: root.browser.privateMode
    }
}
