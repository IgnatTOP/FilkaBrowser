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

    // Give the floating bar a real height so it sits as a proper pill above the
    // bottom edge instead of collapsing to a zero-height anchor line.
    implicitHeight: barRow.height + Theme.s5

    readonly property var targetLangs: [qsTr("Русский"), "English", "Deutsch", "Français",
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
    readonly property string jsCollect: "(function(){var a='data-filka-translate-id';var s={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};window.__filkaTranslateOriginals=window.__filkaTranslateOriginals||{};window.__filkaTranslateSeq=window.__filkaTranslateSeq||0;var n=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){var p=x.parentElement;if(!p||s[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;if(p.closest&&p.closest('['+a+']'))return NodeFilter.FILTER_REJECT;return NodeFilter.FILTER_ACCEPT}});var nd;while(nd=w.nextNode())n.push(nd);var out=[];for(var i=0;i<n.length;i++){var id='ft-'+Date.now().toString(36)+'-'+(++window.__filkaTranslateSeq).toString(36);var span=document.createElement('span');span.setAttribute(a,id);span.textContent=n[i].textContent;window.__filkaTranslateOriginals[id]=n[i].textContent;n[i].parentNode.replaceChild(span,n[i]);out.push({id:id,text:span.textContent})}return JSON.stringify(out)})()"

    // ---- JavaScript: inject translated chunks ----
    // Expects global arrays _m (stable translate ids) and _t (translations)
    readonly property string jsInject: "(function(){var a='data-filka-translate-id';var r=0;var missing=0;function find(id){var all=document.querySelectorAll('['+a+']');for(var j=0;j<all.length;j++){if(all[j].getAttribute(a)===id)return all[j]}return null}for(var i=0;i<_m.length;i++){var el=find(String(_m[i]));if(!el){missing++;continue}if(_t[i]){el.textContent=_t[i];r++}}return JSON.stringify({replaced:r,missing:missing,total:_m.length})})()"

    // ---- JavaScript: revert translations ----
    readonly property string jsRevert: "(function(){var a='data-filka-translate-id';var originals=window.__filkaTranslateOriginals||{};var restored=0;var missing=0;function find(id){var all=document.querySelectorAll('['+a+']');for(var j=0;j<all.length;j++){if(all[j].getAttribute(a)===id)return all[j]}return null}for(var i=0;i<_ot.length;i++){var item=_ot[i];var el=find(String(item.id));if(!el){missing++;continue}el.textContent=(originals[item.id]!==undefined)?originals[item.id]:item.text;restored++}return JSON.stringify({restored:restored,missing:missing,total:_ot.length})})()"

    property var originalTexts: []
    property int totalChunks: 0
    property int doneChunks: 0
    property string pendingInjected: ""

    function startInPageTranslation() {
        if (!activeView || !PageTranslator.hasApiKey || PageTranslator.translating || extracting) return
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
                var seg = '[' + texts[i].id + ']' + texts[i].text
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
            var regex = /\[([A-Za-z0-9_-]+)\]/g
            var match
            var indices = []
            while ((match = regex.exec(result)) !== null) {
                indices.push({ idx: match[1], pos: match.index, end: regex.lastIndex })
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

    // Glass background
    Rectangle {
        anchors.fill: barRow
        anchors.margins: -Theme.s3
        radius: Theme.radiusPill
        color: Theme.surface
        border.width: 1
        border.color: Theme.glassStroke
    }

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: Theme.s2

        // Leading mark — identifies the bar as the page translator.
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "languages"; size: 16; color: Theme.accent
        }

        // Language selector
        Pill {
            anchors.verticalCenter: parent.verticalCenter
            accessibleName: qsTr("Выбрать язык перевода")
            onClicked: langPopup.visible = !langPopup.visible
            Row {
                spacing: Theme.s1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                text: PageTranslator.targetLanguage
                color: Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
                }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevron-down"; size: 10; color: Theme.textMuted }
            }
        }

        // Progress (while translating)
        Row {
            visible: PageTranslator.translating || root.extracting
            spacing: Theme.s2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.extracting ? qsTr("Извлекаем...") : (root.totalChunks > 1 ? qsTr("Перевод %1/%2").arg(root.doneChunks).arg(root.totalChunks) : qsTr("Перевод..."))
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
                        running: (PageTranslator.translating || root.extracting) && !Motion.reducedMotion
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 140 }
                        NumberAnimation { to: 0.3; duration: 250 }
                        NumberAnimation { to: 1.0;  duration: 250 }
                        PauseAnimation { duration: (2 - index) * 140 }
                    }
                }
            }
            // Tap to cancel
            IconButton {
                width: 22
                height: 22
                iconName: "x"
                iconSize: 12
                Accessible.name: qsTr("Отменить перевод")
                onClicked: PageTranslator.cancel()
            }
        }

        Row {
            visible: !PageTranslator.hasApiKey
            spacing: Theme.s1
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "shield"; size: 12; color: Theme.warning
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Нужен API-ключ")
                color: Theme.warning
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
            }
        }

        // Translate button
        Pill {
            anchors.verticalCenter: parent.verticalCenter
            accessibleName: qsTr("Перевести страницу")
            visible: PageTranslator.hasApiKey && !PageTranslator.translating
                     && !root.extracting && !root.pageTranslated
            strokeWidth: 0
            fillColor: Theme.accent
            onClicked: root.startInPageTranslation()
            Row {
                spacing: Theme.s1
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "languages"; size: 12; color: Theme.accentForeground }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Перевести")
                    color: Theme.accentForeground
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
                }
            }
        }

        // Done badge
        Row {
            visible: root.pageTranslated && !PageTranslator.translating && !root.extracting
            spacing: Theme.s1
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "shield-check"; size: 12; color: Theme.positive }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Готово")
                color: Theme.positive
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
            }
        }

        // Revert button
        Pill {
            id: revertPill
            anchors.verticalCenter: parent.verticalCenter
            accessibleName: qsTr("Вернуть оригинал страницы")
            visible: root.pageTranslated && !PageTranslator.translating && !root.extracting
            fillColor: hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16)
                               : Theme.glassLow
            strokeColor: hovered ? Theme.danger : Theme.glassStroke
            onClicked: root.revertTranslation()
            Row {
                spacing: Theme.s1
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "rotate-cw"; size: 11;
                       color: revertPill.hovered ? Theme.danger : Theme.textSecondary }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Оригинал")
                    color: revertPill.hovered ? Theme.danger : Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                }
            }
        }

        // Close
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "x"; size: 24; iconSize: 12
            Accessible.name: qsTr("Закрыть переводчик")
            onClicked: root.requestClose()
        }
    }

    // ---- Language popup ----
    Rectangle {
        id: langPopup
        visible: false
        anchors.bottom: barRow.top
        anchors.bottomMargin: Theme.s2
        anchors.left: barRow.left
        width: langFlow.width + Theme.s4
        height: langFlow.height + Theme.s3
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1; border.color: Theme.glassStroke
        z: 301

        Flow {
            id: langFlow
            anchors { top: parent.top; left: parent.left; margins: Theme.s2 }
            spacing: Theme.s1
            Repeater {
                model: root.targetLangs
                delegate: Chip {
                    required property string modelData
                    height: 24
                    label: modelData
                    selected: PageTranslator.targetLanguage === modelData
                    onClicked: {
                        PageTranslator.targetLanguage = modelData
                        langPopup.visible = false
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
