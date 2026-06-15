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
    property Item activeView: null

    // When false (start page is showing) the active web view is hidden so the
    // QML start surface isn't punched through by Chromium's native compositing.
    property bool showWeb: true

    // Raised when the user picks "Inspect" so the shell can open dev tools.
    signal devToolsRequested()
    // A page asked to enter/leave HTML fullscreen (video players, slideshows).
    signal fullScreenRequested(bool on)
    // A page wants a permission (camera, mic, geolocation, notifications…).
    signal permissionRequested(var permission)

    function syncActive() {
        activeView = (tabsModel && tabsModel.activeIndex >= 0)
                     ? rep.itemAt(tabsModel.activeIndex) : null
    }
    Component.onCompleted: syncActive()
    Connections {
        target: root.tabsModel
        function onActiveIndexChanged() { root.syncActive() }
        function onCountChanged() { root.syncActive() }
    }

    Rectangle {
        id: clipFrame
        anchors.fill: parent
        radius: Theme.radiusLg
        color: root.showWeb ? "white" : "transparent"
        clip: true

        Repeater {
            id: rep
            model: root.tabsModel
            onItemAdded: root.syncActive()
            onItemRemoved: root.syncActive()

            delegate: WebEngineView {
                id: webView
                anchors.fill: parent
                profile: filkaProfile
                visible: index === root.tabsModel.activeIndex && root.showWeb
                z: visible ? 1 : 0
                // Force offscreen rendering so the parent's rounded-clip actually
                // applies. Without this, WebEngineView composites above QML and
                // ignores the parent's clip/radius.
                layer.enabled: true
                Component.onCompleted: url = model.url
                onUrlChanged: root.tabsModel.updateUrl(index, url)
                onTitleChanged: root.tabsModel.updateTitle(index, title)
                onIconChanged: root.tabsModel.updateIcon(index, icon)
                onLoadingChanged: function(info) {
                    root.tabsModel.updateLoading(index, loading)
                    if (info.status === WebEngineView.LoadSucceededStatus)
                        HistoryModel.recordVisit(info.url, title)
                }
                // Links/scripts that request a new tab or window (target=_blank,
                // middle-click, window.open) would otherwise be dead. Open them
                // as a real tab. Popups with no URL (OAuth sign-in flows) need
                // the request handed a live view via openIn(), or the login
                // never completes — so always create the tab, then bind it.
                onNewWindowRequested: function(request) {
                    var i = root.tabsModel.addTab(request.requestedUrl, true)
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
                    root.fullScreenRequested(request.toggleOn)
                }
                onPdfPrintingFinished: function(path, success) {
                    if (!success) console.warn("Filka: PDF print failed for", path)
                }
            }
        }
    }

    WebContextMenu {
        id: ctxMenu
        tabsModel: root.tabsModel
        onInspectRequested: root.devToolsRequested()
    }
}
