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
        downloads: root.shell.downloads
        onRequestClose: root.shell.closePanels()
        onClearList: root.shell.downloads = []
    }

    SettingsPanel {
        open: root.shell.activePanel === "settings"
        onRequestClose: root.shell.closePanels()
    }

    TranslatorPanel {
        open: root.shell.activePanel === "translator"
        activeView: root.browser.activeView
        visible: open
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s3
        width: Math.min(520, parent.width - Theme.s4)
        z: 300
        onRequestClose: root.shell.closePanels()
    }
}
