import QtQuick
import QtQuick.Controls.Basic
import Filka
import "OmniboxHelper.js" as Omnibox

// AddressBar — glass pill that doubles as URL input and search box. Shows a
// security glyph on the left and a thin loading bar along the bottom edge. While
// the user is typing it drops a suggestions panel fed from history + bookmarks
// (plus a "search the web" / "open site" affordance), with full keyboard nav.
FocusScope {
    id: root

    property string displayUrl: ""
    property bool secure: false
    property bool loading: false
    property real progress: 0          // 0..1
    signal navigate(string text)       // emitted with raw user text
    signal securityClicked()

    implicitHeight: Theme.controlMd
    activeFocusOnTab: true

    // Pull keyboard focus into the input and pre-select its text, so the user
    // can immediately type a new address (Ctrl+L / Ctrl+K).
    function focusInput() {
        field.forceActiveFocus()
        field.selectAll()
    }

    function resolve(text) { return Omnibox.resolve(text, AppSettings) }
    function looksLikeUrl(text) { return Omnibox.looksLikeUrl(text) }

    // ---- Suggestions ----
    property var suggestions: []       // [{ kind, title, url, label }]
    property int highlight: -1
    readonly property bool suggesting: field.activeFocus && suggestions.length > 0

    // Live web suggestions (from the search engine's autocomplete service),
    // fetched on a debounce and cached against the text they belong to.
    property var netPhrases: []
    property string netQuery: ""

    function rebuildSuggestions() {
        suggestions = Omnibox.buildSuggestions({
            text: field.text,
            appSettings: AppSettings,
            bookmarkModel: BookmarkModel,
            historyModel: HistoryModel,
            includeQuickLinks: false,
            networkEnabled: AppSettings.networkSuggestionsEnabled,
            netPhrases: root.netPhrases,
            netQuery: root.netQuery,
            goLabel: qsTr("Перейти на сайт"),
            searchLabel: qsTr("Искать в сети"),
            suggestLabel: qsTr("Поиск"),
            maxCount: 9,
            bookmarkLimit: 3,
            historyLimit: 5
        })
        highlight = -1
    }

    // Debounce typing before hitting the network so we don't fire a request per
    // keystroke; the call is cheap but rate-limiting it keeps things snappy.
    Timer {
        id: netDebounce
        interval: 180
        onTriggered: root.fetchSuggestions(field.text.trim())
    }

    function fetchSuggestions(t) {
        if (!AppSettings.networkSuggestionsEnabled || t.length < 2 || root.looksLikeUrl(t))
            return
        var req = new XMLHttpRequest()
        // Google's "firefox" client returns clean JSON: ["query", ["s1","s2",...]].
        var url = "https://www.google.com/complete/search?client=firefox&q="
                + encodeURIComponent(t)
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE || req.status !== 200)
                return
            try {
                var data = JSON.parse(req.responseText)
                if (Array.isArray(data) && Array.isArray(data[1])
                    && ("" + data[0]).toLowerCase() === t.toLowerCase()) {
                    root.netPhrases = data[1]
                    root.netQuery = t.toLowerCase()
                    // Only refresh the panel if the user is still on this text.
                    if (field.text.trim() === t)
                        root.rebuildSuggestions()
                }
            } catch (e) { /* ignore malformed responses */ }
        }
        req.open("GET", url)
        req.send()
    }

    function moveHighlight(delta) {
        if (suggestions.length === 0) return
        var n = suggestions.length
        // -1 acts as "no selection" between the two ends.
        highlight = highlight + delta
        if (highlight < -1) highlight = n - 1
        else if (highlight >= n) highlight = -1
    }

    function acceptSuggestion(i) {
        if (i >= 0 && i < suggestions.length) {
            root.navigate(suggestions[i].url)
        } else {
            var url = root.resolve(field.text)
            if (url.length) root.navigate(url)
        }
        suggestions = []
        highlight = -1
        field.focus = false
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radiusMd
        color: field.activeFocus ? Theme.surface : Theme.surfaceAlt
        border.width: 1
        border.color: field.activeFocus ? Theme.accent : Theme.outline
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Icon {  // security indicator
            id: lock
            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            name: root.secure ? "lock" : "globe"
            size: 15
            color: root.secure ? Theme.positive : Theme.textMuted
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.securityClicked()
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        TextField {
        id: field
            anchors { left: lock.right; right: parent.right; verticalCenter: parent.verticalCenter
                      leftMargin: Theme.s2; rightMargin: Theme.s3 }
            focus: false
            text: root.displayUrl
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: qsTr("Поиск в сети или адрес сайта")
            placeholderTextColor: Theme.textMuted
            background: null
            Accessible.name: qsTr("Адресная строка")

            onActiveFocusChanged: {
                if (activeFocus) selectAll()
                else { root.suggestions = []; root.highlight = -1 }
            }
            // textEdited fires only on user input, not on the displayUrl binding,
            // so suggestions never pop up while pages navigate on their own.
            onTextEdited: {
                root.rebuildSuggestions()
                if (AppSettings.networkSuggestionsEnabled)
                    netDebounce.restart()
                else
                    netDebounce.stop()
            }
            onAccepted: root.acceptSuggestion(root.highlight)
            Keys.onEscapePressed: {
                if (root.suggestions.length > 0) { root.suggestions = []; root.highlight = -1 }
                else { text = root.displayUrl; focus = false }
            }
            Keys.onDownPressed: root.moveHighlight(1)
            Keys.onUpPressed: root.moveHighlight(-1)
        }

        // Thin loading progress along the bottom.
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 2; bottomMargin: 2 }
            height: 2
            radius: 1
            width: (parent.width - 4) * root.progress
            visible: root.loading
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
        }
    }

    // ---- Suggestions panel ----
    OmniboxSuggestionsPopup {
        id: popup
        anchorHeight: root.height
        suggestions: root.suggesting ? root.suggestions : []
        highlight: root.highlight
        onAccepted: function(index) { root.acceptSuggestion(index) }
    }

    Keys.onReturnPressed: root.focusInput()
    Keys.onEnterPressed: root.focusInput()
}
