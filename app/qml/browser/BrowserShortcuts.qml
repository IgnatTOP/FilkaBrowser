pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// BrowserShortcuts — window-wide chrome accelerators (tabs, navigation, zoom,
// find, dev tools). Extracted from BrowserView so the shell stays a thin
// orchestrator. All actions are delegated to `browser` (BrowserView) and
// `shell` (ShellState); WebEngineView keeps its own in-page shortcuts.
Item {
    id: root

    required property var browser
    required property ShellState shell

    Shortcut { sequence: "Ctrl+N"; onActivated: root.browser.newWindow() }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: root.browser.newPrivateWindow() }
    Shortcut { sequence: "Ctrl+T"; onActivated: root.browser.newTab() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.browser.closeCurrentTab() }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: root.browser.reopenClosedTab() }
    Shortcut { sequence: "Ctrl+P"; onActivated: root.browser.printPage() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: root.browser.captureVisible(false) }
    Shortcut { sequence: "Ctrl+Shift+Alt+S"; onActivated: root.browser.startAreaScreenshot(false) }
    Shortcut { sequences: ["Ctrl+L", "Ctrl+K", "Alt+D"]; onActivated: root.browser.focusAddress() }
    Shortcut { sequences: [StandardKey.Refresh, "Ctrl+R"]
               onActivated: if (root.browser.activeView) root.browser.activeView.reload() }
    Shortcut { sequences: [StandardKey.Back]
               onActivated: if (root.browser.canGoBack) root.browser.activeView.goBack() }
    Shortcut { sequences: [StandardKey.Forward]
               onActivated: if (root.browser.canGoForward) root.browser.activeView.goForward() }
    Shortcut { sequence: "Ctrl+Tab";       onActivated: root.browser.cycleTab(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: root.browser.cycleTab(-1) }
    Shortcut { sequence: "Ctrl+PgDown";    onActivated: root.browser.cycleTab(1) }
    Shortcut { sequence: "Ctrl+PgUp";      onActivated: root.browser.cycleTab(-1) }
    Shortcut { sequences: [StandardKey.ZoomIn, "Ctrl+="]; onActivated: root.browser.zoomBy(0.1) }
    Shortcut { sequence: StandardKey.ZoomOut; onActivated: root.browser.zoomBy(-0.1) }
    Shortcut { sequence: "Ctrl+0";         onActivated: root.browser.resetZoom() }

    Shortcut { sequences: ["F12", "Ctrl+Shift+I"]; onActivated: root.shell.showDevTools = !root.shell.showDevTools }
    Shortcut { sequence: StandardKey.Find; onActivated: root.browser.openFind() }
    Shortcut { sequence: "Ctrl+Alt+T"; onActivated: root.shell.togglePanel("translator") }
    Shortcut { sequence: "Ctrl+Shift+P"; onActivated: root.browser.openCommandPalette() }
    Shortcut { sequence: "Ctrl+Shift+F"; onActivated: root.browser.openTabSearch() }
    Shortcut { sequence: "Ctrl+Shift+M"; onActivated: root.browser.toggleGlobalMedia() }
    Shortcut { sequence: "Ctrl+Alt+P"; onActivated: root.browser.openPictureInPicture() }
    Shortcut {
        sequence: "Escape"
        enabled: root.shell.fullScreen || root.shell.showFind
                 || root.shell.anyOverlayOpen || root.shell.anyPanelOpen || root.shell.showDevTools
        onActivated: {
            if (root.shell.fullScreen) {
                root.browser.exitFullScreen()
            } else if (root.shell.showFind) {
                root.browser.closeFind()
            } else if (root.shell.anyOverlayOpen) {
                root.shell.closeOverlays()
            } else if (root.shell.anyPanelOpen) {
                root.shell.closePanels()
            } else if (root.shell.showDevTools) {
                root.shell.showDevTools = false
            }
        }
    }

    // Ctrl+1..8 jump to that tab; Ctrl+9 jumps to the last tab.
    Instantiator {
        model: 9
        delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            onActivated: root.browser.selectTab(index === 8 ? -1 : index)
        }
    }
}
