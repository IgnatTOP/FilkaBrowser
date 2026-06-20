import QtQuick
import QtQuick.Controls.Basic
import Filka

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

    // Decide whether the input is a URL or a search query.
    function resolve(text) {
        var t = text.trim()
        if (t.length === 0) return ""
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t)) return t        // has scheme
        if (/^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(t)) return "http://" + t
        if (!/\s/.test(t) && /^[^\s]+\.[^\s]{2,}/.test(t)) return "https://" + t
        return AppSettings.searchUrl(t)
    }

    // True when the typed text resolves to a real URL (vs. a web search) — drives
    // the leading "open site" / "search" hint in the suggestions panel.
    function looksLikeUrl(t) {
        var s = t.trim()
        return /^[a-z][a-z0-9+.-]*:\/\//i.test(s)
            || /^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(s)
            || (!/\s/.test(s) && /^[^\s]+\.[^\s]{2,}/.test(s))
    }

    // ---- Suggestions ----
    property var suggestions: []       // [{ kind, title, url, label }]
    property int highlight: -1
    readonly property bool suggesting: field.activeFocus && suggestions.length > 0

    // Live web suggestions (from the search engine's autocomplete service),
    // fetched on a debounce and cached against the text they belong to.
    property var netPhrases: []
    property string netQuery: ""

    function rebuildSuggestions() {
        var t = field.text.trim()
        if (t.length === 0) { suggestions = []; highlight = -1; return }

        var out = []
        // Leading action: navigate straight to a URL, or search the web.
        if (root.looksLikeUrl(t))
            out.push({ kind: "go", title: t, url: root.resolve(t),
                       label: qsTr("Перейти на сайт") })
        else
            out.push({ kind: "search", title: t, url: root.resolve(t),
                       label: qsTr("Искать в сети") })

        // History + bookmarks, de-duplicated by URL against what we already have.
        var seen = {}
        seen[out[0].url] = true
        var bm = BookmarkModel.search(t, 3)
        for (var i = 0; i < bm.length; ++i) {
            if (seen[bm[i].url]) continue
            seen[bm[i].url] = true
            out.push({ kind: "bookmark", title: bm[i].title, url: bm[i].url, label: bm[i].url })
        }
        var hist = HistoryModel.search(t, 5)
        for (var j = 0; j < hist.length && out.length < 7; ++j) {
            if (seen[hist[j].url]) continue
            seen[hist[j].url] = true
            out.push({ kind: "history", title: hist[j].title, url: hist[j].url, label: hist[j].url })
        }

        // Web autocomplete phrases — only when they still match the typed text
        // and the input isn't itself a URL. Each becomes a search action.
        if (AppSettings.networkSuggestionsEnabled && AppSettings.networkSuggestionsSupported
                && !root.looksLikeUrl(t) && root.netQuery === t.toLowerCase()) {
            var seenPhrase = {}
            seenPhrase[t.toLowerCase()] = true
            for (var k = 0; k < root.netPhrases.length && out.length < 9; ++k) {
                var p = ("" + root.netPhrases[k])
                var key = p.toLowerCase()
                if (seenPhrase[key]) continue
                seenPhrase[key] = true
                out.push({ kind: "suggest", title: p, url: AppSettings.searchUrl(p),
                           label: qsTr("Поиск") })
            }
        }

        suggestions = out
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
        if (!AppSettings.networkSuggestionsEnabled || !AppSettings.networkSuggestionsSupported
                || t.length < 2 || root.looksLikeUrl(t))
            return
        var url = AppSettings.suggestUrl(t)
        if (url.length === 0)
            return

        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE || req.status !== 200)
                return
            try {
                var phrases = root.parseSuggestionResponse(req.responseText, t)
                if (phrases.length > 0) {
                    root.netPhrases = phrases
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

    function parseSuggestionResponse(text, t) {
        var data = JSON.parse(text)
        var parser = AppSettings.suggestParser()
        if (parser === "firefox-array") {
            if (Array.isArray(data) && Array.isArray(data[1])
                    && ("" + data[0]).toLowerCase() === t.toLowerCase())
                return data[1]
        } else if (parser === "duckduckgo") {
            if (!Array.isArray(data))
                return []
            var phrases = []
            for (var i = 0; i < data.length; ++i) {
                if (data[i] && data[i].phrase)
                    phrases.push(data[i].phrase)
            }
            return phrases
        }
        return []
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
                if (AppSettings.networkSuggestionsEnabled && AppSettings.networkSuggestionsSupported)
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
    Popup {
        id: popup
        y: root.height + 6
        x: 0
        width: root.width
        padding: 6
        visible: root.suggesting
        closePolicy: Popup.NoAutoClose       // focus changes drive open/close
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
            NumberAnimation { property: "y"; from: root.height - 2; to: root.height + 6; duration: Motion.base; easing.type: Motion.emphasized }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant }
        }
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
        }

        contentItem: Column {
            spacing: 2
            Repeater {
                model: root.suggestions
                delegate: Rectangle {
                    id: srow
                    required property int index
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: 38
                    radius: Theme.radiusSm
                    color: (srow.index === root.highlight || rowHover.hovered)
                           ? Theme.activeFill : "transparent"

                    Icon {
                        id: kindIcon
                        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        name: srow.modelData.kind === "search" ? "search"
                            : srow.modelData.kind === "bookmark" ? "bookmark"
                            : srow.modelData.kind === "go" ? "globe" : "history"
                        size: 16
                        color: srow.modelData.kind === "search" || srow.modelData.kind === "go"
                               ? Theme.accent : Theme.textMuted
                    }
                    Column {
                        anchors { left: kindIcon.right; right: parent.right
                                  leftMargin: Theme.s3; rightMargin: Theme.s3
                                  verticalCenter: parent.verticalCenter }
                        spacing: 1
                        Text {
                            width: parent.width
                            text: srow.modelData.title
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: srow.modelData.label
                            color: Theme.textMuted
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.acceptSuggestion(srow.index) }
                }
            }
        }
    }

    Keys.onReturnPressed: root.focusInput()
    Keys.onEnterPressed: root.focusInput()
}
