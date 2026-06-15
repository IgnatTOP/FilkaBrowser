import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// TranslatorBar — compact floating toolbar for in-page translation.
// Translates in chunks so large pages don't block for too long.
Item {
    id: root

    property var activeView: null
    property bool open: false
    property bool pageTranslated: false
    property string translatedUrl: ""
    property bool extracting: false
    signal requestClose()

    readonly property var targetLangs: ["Русский", "English", "Deutsch", "Français",
                                        "Español", "中文", "日本語", "Português"]
    readonly property bool isLoading: activeView ? activeView.loading : false
    readonly property string currentUrl: activeView ? activeView.url.toString() : ""

    // Reset translation state when navigating to a different page.
    onCurrentUrlChanged: {
        if (currentUrl !== translatedUrl && pageTranslated) {
            pageTranslated = false
        }
    }

    onOpenChanged: {
        if (!open && PageTranslator.translating)
            PageTranslator.cancel()
    }

    // ---- JavaScript: collect text nodes as JSON array ----
    readonly property string jsCollect: "(function(){var s={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};var n=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){var p=x.parentElement;if(!p||s[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;return NodeFilter.FILTER_ACCEPT}});var nd;while(nd=w.nextNode())n.push(nd.textContent);return JSON.stringify(n)})()"

    // ---- JavaScript: inject translated chunks ----
    // Expects global arrays _m (indices) and _t (translations)
    readonly property string jsInject: "(function(){var s={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};var n=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){var p=x.parentElement;if(!p||s[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;return NodeFilter.FILTER_ACCEPT}});var nd;while(nd=w.nextNode())n.push(nd);var m={};for(var i=0;i<_m.length;i++)m[_m[i]]=_t[i];var r=0;for(var j=0;j<n.length;j++){if(m.hasOwnProperty(j)&&m[j]){n[j].textContent=m[j];r++}}return r})()"

    // ---- JavaScript: revert translations ----
    readonly property string jsRevert: "(function(){var s={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};var n=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){var p=x.parentElement;if(!p||s[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;return NodeFilter.FILTER_ACCEPT}});var nd;while(nd=w.nextNode())n.push(nd);for(var j=0;j<n.length&&j<_ot.length;j++)n[j].textContent=_ot[j];return n.length})()"

    property var originalTexts: []
    property int totalChunks: 0
    property int doneChunks: 0
    property string pendingInjected: ""

    function startInPageTranslation() {
        if (!activeView || PageTranslator.translating || extracting) return
        extracting = true

        activeView.runJavaScript(jsCollect, function(json) {
            root.extracting = false
            var texts
            try { texts = JSON.parse(json) } catch(e) { return }
            if (!texts || texts.length === 0) return

            root.originalTexts = texts
            root.pageTranslated = false
            root.doneChunks = 0

            // Split into chunks of ~4000 chars each
            var chunks = []
            var current = []
            var currentLen = 0
            for (var i = 0; i < texts.length; i++) {
                var seg = '[' + i + ']' + texts[i]
                if (currentLen + seg.length > 4000 && current.length > 0) {
                    chunks.push(current.join(' '))
                    current = []
                    currentLen = 0
                }
                current.push(seg)
                currentLen += seg.length
            }
            if (current.length > 0) chunks.push(current.join(' '))

            root.totalChunks = chunks.length
            root.pendingInjected = ""

            // Translate each chunk sequentially
            root.translateChunkChain(chunks, 0)
        })
    }

    function translateChunkChain(chunks, idx) {
        if (idx >= chunks.length) {
            root.doneChunks = root.totalChunks
            return
        }
        PageTranslator.translateBatch(chunks[idx])
        // Connection handles next chunk via batchReady
        root._nextChunkIndex = idx + 1
        root._pendingChunks = chunks
    }

    property int _nextChunkIndex: 0
    property var _pendingChunks: []

    Connections {
        target: PageTranslator
        function onBatchReady(result) {
            if (!root.activeView || !result || result.length === 0) {
                root.doneChunks = root.totalChunks
                return
            }

            // Parse markers and inject this chunk
            var segments = []
            var regex = /\[(\d+)\]/g
            var match
            var indices = []
            while ((match = regex.exec(result)) !== null) {
                indices.push({ idx: parseInt(match[1]), pos: match.index, end: regex.lastIndex })
            }
            for (var i = 0; i < indices.length; i++) {
                var start = indices[i].end
                var end = (i + 1 < indices.length) ? indices[i + 1].pos : result.length
                segments.push({ key: indices[i].idx, text: result.substring(start, end).trim() })
            }

            if (segments.length > 0) {
                var jsData = "var _m=" + JSON.stringify(segments.map(function(s){ return s.key })) + ";"
                           + "var _t=" + JSON.stringify(segments.map(function(s){ return s.text })) + ";"
                root.activeView.runJavaScript(jsData + root.jsInject, function(replaced) {
                    root.doneChunks++
                    root.pageTranslated = root.doneChunks > 0
                    root.translatedUrl = root.currentUrl
                    // Translate next chunk
                    if (root._nextChunkIndex < root._pendingChunks.length) {
                        root.translateChunkChain(root._pendingChunks, root._nextChunkIndex)
                    }
                })
            } else {
                root.doneChunks++
                if (root._nextChunkIndex < root._pendingChunks.length)
                    root.translateChunkChain(root._pendingChunks, root._nextChunkIndex)
            }
        }
    }

    function revertTranslation() {
        if (!activeView || originalTexts.length === 0) return
        var jsData = "var _ot=" + JSON.stringify(originalTexts) + ";"
        activeView.runJavaScript(jsData + root.jsRevert, function() {
            root.pageTranslated = false
            root.originalTexts = []
        })
    }

    // ---- Floating bar UI ----
    visible: open

    // Glass background
    Rectangle {
        anchors.fill: barRow
        anchors.margins: -Theme.s3
        radius: Theme.radiusPill
        color: Theme.bgRaised
        border.width: 1
        border.color: Theme.glassStroke
        // Subtle shadow
        layer.enabled: true
        layer.effect: null
    }

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: Theme.s2

        // Language selector
        Rectangle {
            width: langRow.width + Theme.s3; height: 28
            radius: Theme.radiusPill
            color: langHover.hovered ? Theme.glassMed : Theme.glassLow
            border.width: 1; border.color: Theme.glassStroke
            Row {
                id: langRow; anchors.centerIn: parent; spacing: Theme.s1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: PageTranslator.targetLanguage
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
                }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevron-down"; size: 10; color: Theme.textMuted }
            }
            HoverHandler { id: langHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: langPopup.visible = !langPopup.visible }
        }

        // Progress (while translating)
        Row {
            visible: PageTranslator.translating || root.extracting
            spacing: Theme.s2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.extracting ? "Извлекаем…" : (root.totalChunks > 1 ? "Перевод " + root.doneChunks + "/" + root.totalChunks : "Перевод…")
                color: Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
            }
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: 5; height: 5; radius: 2.5; color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: PageTranslator.translating || root.extracting
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 140 }
                        NumberAnimation { to: 0.3; duration: 250 }
                        NumberAnimation { to: 1.0;  duration: 250 }
                        PauseAnimation { duration: (2 - index) * 140 }
                    }
                }
            }
            // Tap to cancel
            Item { width: 16; height: 16
                TapHandler { onTapped: PageTranslator.cancel() }
            }
        }

        // Translate button
        Rectangle {
            width: trRow.width + Theme.s3; height: 28
            radius: Theme.radiusPill
            visible: !PageTranslator.translating && !root.extracting && !root.pageTranslated
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.electricBlue }
                GradientStop { position: 1.0; color: Theme.auroraPurple }
            }
            Row {
                id: trRow; anchors.centerIn: parent; spacing: Theme.s1
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "languages"; size: 12; color: "white" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Перевести"
                    color: "white"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.startInPageTranslation() }
        }

        // Done badge
        Row {
            visible: root.pageTranslated && !PageTranslator.translating && !root.extracting
            spacing: Theme.s1
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "shield-check"; size: 12; color: Theme.positive }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Готово"
                color: Theme.positive
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
            }
        }

        // Revert button
        Rectangle {
            width: revRow.width + Theme.s3; height: 28
            radius: Theme.radiusPill
            visible: root.pageTranslated && !PageTranslator.translating && !root.extracting
            color: revHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16)
                                   : Theme.glassLow
            border.width: 1; border.color: revHover.hovered ? Theme.danger : Theme.glassStroke
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Row {
                id: revRow; anchors.centerIn: parent; spacing: Theme.s1
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "rotate-cw"; size: 11;
                       color: revHover.hovered ? Theme.danger : Theme.textSecondary }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Оригинал"
                    color: revHover.hovered ? Theme.danger : Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                }
            }
            HoverHandler { id: revHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.revertTranslation() }
        }

        // Close
        Rectangle {
            width: 22; height: 22; radius: 11
            color: closeHover.hovered ? Theme.glassMed : "transparent"
            Icon { anchors.centerIn: parent; name: "x"; size: 11; color: Theme.textMuted }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { root.open = false; root.requestClose() } }
        }
    }

    // ---- Language popup ----
    Rectangle {
        id: langPopup
        visible: false
        anchors.top: barRow.bottom
        anchors.topMargin: Theme.s1
        anchors.left: barRow.left
        width: langFlow.width + Theme.s4
        height: langFlow.height + Theme.s3
        radius: Theme.radiusMd
        color: Theme.bgRaised
        border.width: 1; border.color: Theme.glassStroke
        z: 301

        Flow {
            id: langFlow
            anchors { top: parent.top; left: parent.left; margins: Theme.s2 }
            spacing: Theme.s1
            Repeater {
                model: root.targetLangs
                delegate: Rectangle {
                    id: lChip
                    required property string modelData
                    readonly property bool sel: PageTranslator.targetLanguage === modelData
                    width: lLbl.implicitWidth + Theme.s3; height: 24
                    radius: Theme.radiusPill
                    color: sel ? Theme.accentSoft : Theme.glassLow
                    border.width: 1; border.color: sel ? Theme.accent : Theme.glassStroke
                    Text {
                        id: lLbl; anchors.centerIn: parent; text: lChip.modelData
                        color: lChip.sel ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            PageTranslator.targetLanguage = lChip.modelData
                            langPopup.visible = false
                        }
                    }
                }
            }
        }
    }

    // Close lang popup when bar closes
    Connections {
        target: root
        function onOpenChanged() { langPopup.visible = false }
    }
}
