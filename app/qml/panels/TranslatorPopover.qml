import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Item {
    id: root

    required property var activeView
    property bool open: false
    property real anchorX: Theme.s3
    property real anchorY: Theme.s3
    property bool pageTranslated: false
    property string translatedUrl: ""
    property bool extracting: false
    property string errorText: ""
    property var originalTexts: []
    property int totalChunks: 0
    property int doneChunks: 0
    property int translatedFragments: 0
    readonly property string ownerId: "translator:" + Date.now() + ":" + Math.random().toString(36).slice(2)

    signal requestClose()
    signal requestSettings()

    visible: open
    focus: open

    readonly property var targetLangs: [
        qsTr("Русский"), "English", "Deutsch", "Français",
        "Español", "中文", "日本語", "Português"
    ]
    readonly property string currentUrl: activeView ? activeView.url.toString() : ""
    readonly property bool busy: extracting || PageTranslator.activeJobs > 0
    readonly property string cacheKey: currentUrl + "|" + PageTranslator.targetLanguage + "|"
                                       + originalTexts.length + "|" + originalTexts.join("").length

    property int _jobSeq: 1
    property int _nextChunkIndex: 0
    property int _inFlightJobs: 0
    property var _pendingChunks: []
    property var _jobMap: ({})
    property var _translatedSegments: []
    property var _translationCache: ({})

    readonly property string jsCollect:
        "(function(){var skip={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};"
        + "var out=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){"
        + "var p=x.parentElement;if(!p||skip[p.tagName])return NodeFilter.FILTER_REJECT;"
        + "var t=x.textContent.replace(/\\s+/g,' ').trim();if(t.length<2)return NodeFilter.FILTER_REJECT;"
        + "var st=getComputedStyle(p);if(st.display==='none'||st.visibility==='hidden'||Number(st.opacity)===0)return NodeFilter.FILTER_REJECT;"
        + "return NodeFilter.FILTER_ACCEPT}});var n;while((n=w.nextNode())&&out.length<1400)out.push(n.textContent);"
        + "return JSON.stringify(out)})()"

    readonly property string jsInject:
        "(function(){var skip={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};"
        + "var nodes=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){"
        + "var p=x.parentElement;if(!p||skip[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;"
        + "var st=getComputedStyle(p);if(st.display==='none'||st.visibility==='hidden'||Number(st.opacity)===0)return NodeFilter.FILTER_REJECT;"
        + "return NodeFilter.FILTER_ACCEPT}});var n;while(n=w.nextNode())nodes.push(n);"
        + "var map={};for(var i=0;i<_m.length;i++)map[_m[i]]=_t[i];var r=0;"
        + "for(var j=0;j<nodes.length;j++){if(map.hasOwnProperty(j)&&map[j]){nodes[j].textContent=map[j];r++}}return r})()"

    readonly property string jsRevert:
        "(function(){var skip={SCRIPT:1,STYLE:1,NOSCRIPT:1,CODE:1,PRE:1,TEXTAREA:1,INPUT:1,SELECT:1,SVG:1,MATH:1};"
        + "var nodes=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(x){"
        + "var p=x.parentElement;if(!p||skip[p.tagName]||!x.textContent.trim())return NodeFilter.FILTER_REJECT;return NodeFilter.FILTER_ACCEPT}});"
        + "var n;while(n=w.nextNode())nodes.push(n);for(var j=0;j<nodes.length&&j<_ot.length;j++)nodes[j].textContent=_ot[j];"
        + "return nodes.length})()"

    onCurrentUrlChanged: {
        if (currentUrl !== translatedUrl && pageTranslated)
            resetSessionState()
    }

    onOpenChanged: {
        if (!open)
            languageMenuOpen = false
    }

    property bool languageMenuOpen: false

    function resetSessionState() {
        pageTranslated = false
        translatedUrl = ""
        originalTexts = []
        totalChunks = 0
        doneChunks = 0
        translatedFragments = 0
        errorText = ""
        _pendingChunks = []
        _jobMap = ({})
        _translatedSegments = []
        _nextChunkIndex = 0
        _inFlightJobs = 0
    }

    function startInPageTranslation() {
        if (!activeView || busy)
            return
        errorText = ""
        if (!PageTranslator.hasApiKey) {
            errorText = qsTr("Добавьте API-ключ в настройках переводчика.")
            return
        }

        extracting = true
        activeView.runJavaScript(jsCollect, function(json) {
            root.extracting = false
            var texts = []
            try { texts = JSON.parse(json) } catch(e) { texts = [] }
            if (!texts || texts.length === 0) {
                root.errorText = qsTr("На странице не найден текст для перевода.")
                return
            }

            root.originalTexts = texts
            root.pageTranslated = false
            root.doneChunks = 0
            root.totalChunks = 0
            root.translatedFragments = 0
            root._translatedSegments = []

            var key = root.cacheKey
            if (AppSettings.translatorCacheEnabled && root._translationCache[key]) {
                root.injectSegments(root._translationCache[key], function(replaced) {
                    root.translatedFragments = replaced
                    root.pageTranslated = true
                    root.translatedUrl = root.currentUrl
                })
                return
            }

            var chunks = []
            var current = []
            var currentLen = 0
            for (var i = 0; i < texts.length; i++) {
                var normalized = ("" + texts[i]).replace(/\s+/g, " ").trim()
                if (normalized.length < 2)
                    continue
                var seg = "[" + i + "]" + normalized
                if (currentLen + seg.length > 6800 && current.length > 0) {
                    chunks.push(current.join("\n"))
                    current = []
                    currentLen = 0
                }
                current.push(seg)
                currentLen += seg.length
            }
            if (current.length > 0)
                chunks.push(current.join("\n"))

            if (chunks.length === 0) {
                root.errorText = qsTr("На странице не найден текст для перевода.")
                return
            }

            root.totalChunks = chunks.length
            root._pendingChunks = chunks
            root._nextChunkIndex = 0
            root._inFlightJobs = 0
            root._jobMap = ({})
            root.drainQueue()
        })
    }

    function drainQueue() {
        while (_inFlightJobs < 2 && _nextChunkIndex < _pendingChunks.length) {
            var jobId = _jobSeq++
            _jobMap[jobId] = _nextChunkIndex
            _inFlightJobs++
            PageTranslator.translateBatchJob(root.ownerId, jobId, _pendingChunks[_nextChunkIndex])
            _nextChunkIndex++
        }
    }

    function parseSegments(result) {
        var segments = []
        var regex = /\[(\d+)\]/g
        var match
        var indices = []
        while ((match = regex.exec(result)) !== null)
            indices.push({ idx: parseInt(match[1]), pos: match.index, end: regex.lastIndex })
        for (var i = 0; i < indices.length; i++) {
            var start = indices[i].end
            var end = (i + 1 < indices.length) ? indices[i + 1].pos : result.length
            var text = result.substring(start, end).trim()
            if (text.length > 0)
                segments.push({ key: indices[i].idx, text: text })
        }
        return segments
    }

    function injectSegments(segments, callback) {
        if (!activeView || segments.length === 0) {
            if (callback)
                callback(0)
            return
        }
        var jsData = "var _m=" + JSON.stringify(segments.map(function(s){ return s.key })) + ";"
                   + "var _t=" + JSON.stringify(segments.map(function(s){ return s.text })) + ";"
        activeView.runJavaScript(jsData + jsInject, callback)
    }

    function finishChunk(jobId, result) {
        if (!_jobMap.hasOwnProperty(jobId))
            return
        delete _jobMap[jobId]
        _inFlightJobs = Math.max(0, _inFlightJobs - 1)

        var segments = parseSegments(result)
        injectSegments(segments, function(replaced) {
            root.doneChunks++
            root.translatedFragments += replaced
            root._translatedSegments = root._translatedSegments.concat(segments)
            root.pageTranslated = root.doneChunks > 0
            root.translatedUrl = root.currentUrl

            if (root.doneChunks >= root.totalChunks && root._inFlightJobs === 0) {
                if (AppSettings.translatorCacheEnabled)
                    root._translationCache[root.cacheKey] = root._translatedSegments
                return
            }
            root.drainQueue()
        })
    }

    function failChunk(jobId, message) {
        if (!_jobMap.hasOwnProperty(jobId))
            return
        delete _jobMap[jobId]
        _inFlightJobs = Math.max(0, _inFlightJobs - 1)
        errorText = message
        PageTranslator.cancel()
    }

    function revertTranslation() {
        if (!activeView || originalTexts.length === 0)
            return
        var jsData = "var _ot=" + JSON.stringify(originalTexts) + ";"
        activeView.runJavaScript(jsData + jsRevert, function() {
            root.pageTranslated = false
            root.translatedFragments = 0
        })
    }

    Connections {
        target: PageTranslator
        function onBatchJobReady(ownerId, jobId, result) {
            if (ownerId === root.ownerId)
                root.finishChunk(jobId, result)
        }
        function onBatchJobFailed(ownerId, jobId, error) {
            if (ownerId === root.ownerId)
                root.failChunk(jobId, error)
        }
    }

    // Soft dim behind the anchored popover so page text never competes with it.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrimSoft
        opacity: root.open ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { OpacityAnimator { duration: Motion.base; easing.type: Motion.standard } }
        TapHandler { onTapped: root.requestClose() }
    }

    GlassPanel {
        id: panel
        width: Math.min(440, Math.max(340, root.width - Theme.s6))
        height: Math.min(root.height - Theme.s6, contentCol.implicitHeight + Theme.s5 * 2)
        x: Math.min(Math.max(Theme.s3, root.anchorX), root.width - width - Theme.s3)
        y: Math.min(Math.max(Theme.s3, root.anchorY), root.height - height - Theme.s3)
        radius: Theme.radiusXl
        level: 2
        fillColor: Theme.modalSurface
        shadow: true
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98
        Behavior on opacity { OpacityAnimator { duration: Motion.base; easing.type: Motion.standard } }
        Behavior on scale { ScaleAnimator { duration: Motion.base; easing.type: Motion.emphasized } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusXl
            color: Theme.modalSurface
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {}
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: Theme.s5
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: Theme.radiusMd
                    color: Theme.accentSoft
                    border.width: 1
                    border.color: Theme.glassStroke
                    Icon { anchors.centerIn: parent; name: "languages"; size: 18; color: Theme.accent }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Перевод страницы")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.busy ? qsTr("Работаем с текстом без блокировки страницы")
                                        : qsTr("Перевод рядом с адресной зоной")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    iconName: "settings"
                    size: 30
                    iconSize: 14
                    tooltip: qsTr("Настройки переводчика")
                    Accessible.name: qsTr("Настройки переводчика")
                    onClicked: root.requestSettings()
                }
                IconButton {
                    iconName: "x"
                    size: 30
                    iconSize: 14
                    tooltip: qsTr("Закрыть")
                    Accessible.name: qsTr("Закрыть переводчик")
                    onClicked: root.requestClose()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Pill {
                    id: languagePill
                    Layout.preferredHeight: 34
                    accessibleName: qsTr("Выбрать язык перевода")
                    fillColor: Theme.glassLow
                    onClicked: root.languageMenuOpen = !root.languageMenuOpen
                    Row {
                        spacing: Theme.s1
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "languages"; size: 13; color: Theme.accent }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: PageTranslator.targetLanguage
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Medium
                        }
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevron-down"; size: 11; color: Theme.textMuted }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busy ? qsTr("%1/%2").arg(root.doneChunks).arg(root.totalChunks)
                                    : root.pageTranslated ? qsTr("%1 фрагм.").arg(root.translatedFragments)
                                                          : qsTr("Готов")
                    color: root.pageTranslated ? Theme.positive : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.Medium
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.languageMenuOpen
                spacing: Theme.s2
                Repeater {
                    model: root.targetLangs
                    delegate: Chip {
                        required property string modelData
                        label: modelData
                        selected: PageTranslator.targetLanguage === modelData
                        onClicked: {
                            PageTranslator.targetLanguage = modelData
                            root.languageMenuOpen = false
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: Theme.radiusLg
                color: Theme.glassLow
                border.width: 1
                border.color: Theme.glassStroke
                visible: root.busy
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s3
                    Icon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "loader-circle"; size: 18; color: Theme.accent
                        RotationAnimator on rotation {
                            running: root.busy && !Motion.reducedMotion
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: root.extracting ? qsTr("Извлекаем текст страницы")
                                                   : qsTr("Переводим чанки параллельно")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Theme.surfaceAlt
                            Rectangle {
                                height: parent.height
                                radius: 2
                                width: parent.width * (root.totalChunks > 0 ? root.doneChunks / root.totalChunks : 0.18)
                                color: Theme.accent
                                Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
                            }
                        }
                    }
                    IconButton {
                        iconName: "x"
                        size: 30
                        iconSize: 13
                        tooltip: qsTr("Отменить")
                        Accessible.name: qsTr("Отменить перевод")
                        onClicked: {
                            PageTranslator.cancel()
                            root.extracting = false
                            root.errorText = qsTr("Перевод отменён.")
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: Theme.radiusLg
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.35)
                visible: !PageTranslator.hasApiKey
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s3
                    Icon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "shield"; size: 18; color: Theme.warning }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Нужен API-ключ для перевода страниц")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        wrapMode: Text.WordWrap
                    }
                    GlassButton {
                        text: qsTr("Открыть")
                        onClicked: root.requestSettings()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: errorText.length > 0 ? 50 : 0
                radius: Theme.radiusLg
                color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12)
                border.width: errorText.length > 0 ? 1 : 0
                border.color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35)
                visible: errorText.length > 0
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s2
                    Icon { Layout.preferredWidth: 16; Layout.preferredHeight: 16; name: "x"; size: 16; color: Theme.danger }
                    Text {
                        Layout.fillWidth: true
                        text: root.errorText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                GlassButton {
                    Layout.fillWidth: true
                    text: root.pageTranslated ? qsTr("Перевести заново") : qsTr("Перевести страницу")
                    accentVariant: true
                    enabled: PageTranslator.hasApiKey && !root.busy
                    opacity: enabled ? 1 : 0.5
                    onClicked: root.startInPageTranslation()
                }

                GlassButton {
                    visible: root.pageTranslated && !root.busy
                    text: qsTr("Оригинал")
                    onClicked: root.revertTranslation()
                }
            }
        }
    }

    Keys.onEscapePressed: root.requestClose()
}
