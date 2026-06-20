import QtQuick
import QtWebEngine
import QtQuick.Effects
import Filka

// WebPane — the live web-view stack for ONE workspace. One WebEngineView per
// tab; only the active tab is shown. All panes stay instantiated so switching
// workspaces never reloads pages. `activeView` exposes the current tab's view.
Item {
    id: root
    property var tabsModel
    property var profile
    property Item activeView: null
    property bool recordHistory: true
    property real defaultZoom: 1.0
    property bool roundedWebClip: false

    // When false (start page is showing) the active web view is hidden so the
    // QML start surface isn't punched through by Chromium's native compositing.
    property bool showWeb: true

    // ===== Custom web-page scrollbars =====
    // Inject a thin, themed ::-webkit-scrollbar style into every page so the
    // scrollbars inside web content match the app's own (FilkaScrollBar). The
    // <style> is idempotent (re-run on theme change) and falls back to the
    // document element when <head> isn't ready yet.
    readonly property string _sbThumb: Theme.dark ? "rgba(255,255,255,0.22)" : "rgba(15,19,27,0.22)"
    readonly property string _sbHover: Theme.dark ? "rgba(255,255,255,0.42)" : "rgba(15,19,27,0.42)"
    function scrollbarScript() {
        var css = "::-webkit-scrollbar{width:12px;height:12px}"
                + "::-webkit-scrollbar-track{background:transparent}"
                + "::-webkit-scrollbar-thumb{background-color:" + _sbThumb
                + ";border-radius:8px;border:3px solid transparent;background-clip:content-box}"
                + "::-webkit-scrollbar-thumb:hover{background-color:" + _sbHover + "}"
                + "::-webkit-scrollbar-corner{background:transparent}"
        return "(function(){var id='__filka_scrollbar__';var s=document.getElementById(id);"
             + "if(!s){s=document.createElement('style');s.id=id;"
             + "(document.head||document.documentElement).appendChild(s);}"
             + "s.textContent=" + JSON.stringify(css) + ";})();"
    }
    function urlHost(value) {
        try {
            return new URL(value && value.toString ? value.toString() : value).hostname.toLowerCase()
        } catch (e) {
            return ""
        }
    }
    function isCompatibilityBypassUrl(value) {
        const host = urlHost(value)
        return host === "music.yandex.ru" || host.endsWith(".music.yandex.ru")
    }

    // Raised when the user picks "Inspect" so the shell can open dev tools.
    signal devToolsRequested()
    signal pictureInPictureRequested()
    signal openLinkInNewWindowRequested(url linkUrl)
    // A page asked to enter/leave HTML fullscreen (video players, slideshows).
    signal fullScreenRequested(bool on, var view)
    // A page wants a permission (camera, mic, geolocation, notifications...).
    signal permissionRequested(var permission)

    function syncActive() {
        activeView = (tabsModel && tabsModel.activeIndex >= 0)
                     ? rep.itemAt(tabsModel.activeIndex) : null
    }
    function viewAt(index) { return rep.itemAt(index) }
    Component.onCompleted: syncActive()
    Connections {
        target: root.tabsModel
        function onActiveIndexChanged() { root.syncActive() }
        function onCountChanged() { root.syncActive() }
    }

    // Rounded mask source — an opaque rounded rect on a transparent item. Its
    // alpha drives the MultiEffect mask below, so the page is clipped to actual
    // rounded corners (plain `clip` only clips to the bounding rectangle, which
    // is why the corners stayed sharp before).
    Item {
        id: webMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: "black"
        }
    }

    Rectangle {
        id: clipFrame
        anchors.fill: parent
        radius: root.roundedWebClip ? Theme.radiusMd : 0
        color: root.showWeb ? "white" : "transparent"

        // Round the whole web stack (page + failure overlay) to the mask shape.
        layer.enabled: root.roundedWebClip
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: webMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Repeater {
            id: rep
            model: root.tabsModel
            onItemAdded: root.syncActive()
            onItemRemoved: root.syncActive()

            delegate: WebEngineView {
                id: webView
                anchors.fill: parent
                profile: root.profile
                settings.pluginsEnabled: true
                settings.pdfViewerEnabled: true
                settings.localStorageEnabled: true
                settings.javascriptEnabled: true
                settings.javascriptCanOpenWindows: true
                settings.fullScreenSupportEnabled: true
                settings.screenCaptureEnabled: true
                settings.webGLEnabled: true
                settings.dnsPrefetchEnabled: true
                settings.printElementBackgrounds: true
                settings.scrollAnimatorEnabled: false
                visible: index === root.tabsModel.activeIndex && root.showWeb
                z: visible ? 1 : 0
                // Offscreen rendering is only needed when the shell explicitly wants
                // rounded clipping; keep the normal path on Chromium's native layer.
                layer.enabled: root.roundedWebClip

                // Per-tab mute, driven from the model (tab context menu). Report
                // audio activity back so the strip can show a speaker glyph.
                audioMuted: model.muted
                onRecentlyAudibleChanged: root.tabsModel.updateAudible(index, webView.recentlyAudible)

                // Whether the *last* navigation failed — surfaces the error page.
                property bool failed: false
                property string failedUrl: ""

                function runSponsorBlockSync() {
                    if (root.isCompatibilityBypassUrl(url))
                        return
                    const script = AdBlockManager.sponsorBlockEnabled
                                   ? AdBlockManager.sponsorBlockScriptForUrl(url.toString())
                                   : AdBlockManager.sponsorBlockDisableScript()
                    if (script.length > 0)
                        runJavaScript(script)
                }

                Connections {
                    target: AdBlockManager
                    function onSponsorBlockEnabledChanged() { webView.runSponsorBlockSync() }
                }

                // Restyle the page's scrollbars live when the app theme flips.
                Connections {
                    target: Theme
                    function onDarkChanged() { webView.runJavaScript(root.scrollbarScript()) }
                }

                Component.onCompleted: {
                    url = model.url
                    zoomFactor = root.defaultZoom
                }
                onUrlChanged: {
                    root.tabsModel.updateUrl(index, url)
                    runSponsorBlockSync()
                }
                onTitleChanged: root.tabsModel.updateTitle(index, title)
                onIconChanged: root.tabsModel.updateIcon(index, icon)
                onLoadingChanged: function(info) {
                    root.tabsModel.updateLoading(index, loading)
                    if (info.status === WebEngineView.LoadStartedStatus) {
                        failed = false
                        runJavaScript(root.scrollbarScript())
                        if (!root.isCompatibilityBypassUrl(info.url)) {
                            const earlyCosmeticScript = AdBlockManager.earlyCosmeticScript()
                            if (earlyCosmeticScript.length > 0)
                                runJavaScript(earlyCosmeticScript)
                        }
                    } else if (info.status === WebEngineView.LoadSucceededStatus) {
                        failed = false
                        runJavaScript(root.scrollbarScript())
                        if (root.recordHistory)
                            HistoryModel.recordVisit(info.url, title)
                        if (!root.isCompatibilityBypassUrl(info.url)) {
                            const earlyCosmeticScript = AdBlockManager.earlyCosmeticScript()
                            if (earlyCosmeticScript.length > 0)
                                runJavaScript(earlyCosmeticScript)
                            const cosmeticScript = AdBlockManager.cosmeticScriptForUrl(info.url)
                            if (cosmeticScript.length > 0)
                                runJavaScript(cosmeticScript)
                        }
                        runSponsorBlockSync()
                    } else if (info.status === WebEngineView.LoadFailedStatus) {
                        // Ignore user-initiated aborts (stop button, fast re-nav).
                        if (!/aborted/i.test(info.errorString || "")) {
                            failedUrl = info.url
                            failed = true
                        }
                    }
                }
                // Links/scripts that request a new tab or window (target=_blank,
                // middle-click, window.open) would otherwise be dead. Open them
                // as a real tab. Popups with no URL (OAuth sign-in flows) need
                // the request handed a live view via openIn(), or the login
                // never completes — so always create the tab, then bind it.
                onNewWindowRequested: function(request) {
                    var destination = request.destination
                    var inBackground = destination === WebEngineNewWindowRequest.InNewBackgroundTab
                    var i = root.tabsModel.addTabAfter(index, request.requestedUrl, !inBackground)
                    var view = rep.itemAt(i)
                    if (view)
                        request.openIn(view)
                }
                // Replace Chromium's bare default menu with our styled one.
                onContextMenuRequested: function(request) {
                    request.accepted = true
                    ctxMenu.view = webView
                    ctxMenu.request = request
                    ctxMenu.popup(request.position.x, request.position.y)
                }
                // HTML fullscreen (e.g. YouTube): accept and let the shell take
                // the window fullscreen + hide chrome around this view.
                onFullScreenRequested: function(request) {
                    request.accept()
                    root.fullScreenRequested(request.toggleOn, webView)
                }
                onPermissionRequested: function(permission) {
                    root.permissionRequested(permission)
                }
                onPdfPrintingFinished: function(path, success) {
                    if (success)
                        Qt.openUrlExternally("file://" + path)
                    else
                        console.warn("Filka: PDF print failed for", path)
                }
            }
        }

        // ===== Load-failure page ===== covers the active view when its last
        // navigation failed (no connection, DNS error, etc.). A retry reloads.
        Rectangle {
            anchors.fill: parent
            color: Theme.bgBase
            opacity: (root.showWeb && root.activeView && root.activeView.failed) ? 1 : 0
            visible: opacity > 0.01
            z: 5
            Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }

            Column {
                anchors.centerIn: parent
                width: Math.min(420, parent.width - Theme.s7 * 2)
                spacing: Theme.s4

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "globe"; size: 48; color: Theme.textMuted
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Не удалось открыть страницу")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: qsTr("Проверьте подключение к интернету и адрес сайта, затем попробуйте снова.")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.activeView ? root.activeView.failedUrl : ""
                    color: Theme.textMuted
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideMiddle
                }
                Rectangle {
                    id: retryButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: retryText.implicitWidth + Theme.s6 * 2
                    height: Theme.controlMd
                    radius: Theme.radiusPill
                    color: retryHover.hovered ? Theme.accent : Theme.accentSoft
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Повторить загрузку страницы")
                    function retry() {
                        if (root.activeView)
                            root.activeView.reload()
                    }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Text {
                        id: retryText
                        anchors.centerIn: parent
                        text: qsTr("Повторить")
                        color: retryHover.hovered ? Theme.accentForeground : Theme.accentSoftForeground
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                    }
                    HoverHandler { id: retryHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: retryButton.retry() }
                    Keys.onReturnPressed: retry()
                    Keys.onEnterPressed: retry()
                    Keys.onSpacePressed: retry()
                }
            }
        }
    }

    WebContextMenu {
        id: ctxMenu
        tabsModel: root.tabsModel
        onInspectRequested: root.devToolsRequested()
        onPictureInPictureRequested: root.pictureInPictureRequested()
        onOpenLinkInNewWindowRequested: (linkUrl) => root.openLinkInNewWindowRequested(linkUrl)
    }
}
