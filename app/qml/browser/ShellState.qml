pragma ComponentBehavior: Bound
import QtQuick

// ShellState — the single source of truth for the browser shell's transient UI
// state. Replaces the scattered showHistory/showSettings/showDownloads/
// showTranslator booleans (which each button had to reset by hand) with one
// mutually-exclusive `activePanel`, so two panels can never be open at once and
// adding a panel touches exactly one place.
//
// Not a singleton: state is per-window. BrowserView instantiates one and passes
// it down to NavigationBar / PanelHost / BrowserShortcuts.
QtObject {
    id: shell

    // "" | "history" | "downloads" | "translator" | "settings"
    property string activePanel: ""

    // Chrome-level toggles that used to live on the BrowserView god-object.
    property bool fullScreen: false
    property bool showFind: false
    property bool showDevTools: false

    // Live, model-less UI state surfaced to panels.
    property var pendingPermission: null
    property var downloads: []

    readonly property bool anyPanelOpen: activePanel.length > 0

    // Open `name`, or close it if it is already the active panel (button acts as
    // a toggle). Passing "" closes whatever is open.
    function togglePanel(name) {
        activePanel = (activePanel === name) ? "" : name
    }

    function closePanels() { activePanel = "" }

    function isPanelOpen(name) { return activePanel === name }
}
