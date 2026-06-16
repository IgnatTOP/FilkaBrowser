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

    // When false (start page is showing) the active web view is hidden so the
    // QML start surface isn't punched through by Chromium's native compositing.
    property bool showWeb: true

    // Raised when the user picks "Inspect" so the shell can open dev tools.
    signal devToolsRequested()
    // A page asked to enter/leave HTML fullscreen (video players, slideshows).
    signal fullScreenRequested(bool on)
    // A page wants a permission (camera, mic, geolocation, notifications...).
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
                profile: root.profile
                settings.pluginsEnabled: true
                settings.pdfViewerEnabled: true
                settings.localStorageEnabled: true
                settings.javascriptEnabled: true
                visible: index === root.tabsModel.activeIndex && root.showWeb
                z: visible ? 1 : 0
                // Force offscreen rendering so the parent's rounded-clip actually
                // applies. Without this, WebEngineView composites above QML and
                // ignores the parent's clip/radius.
                layer.enabled: true

                // Per-tab mute, driven from the model (tab context menu). Report
                // audio activity back so the strip can show a speaker glyph.
                audioMuted: model.muted
                onRecentlyAudibleChanged: root.tabsModel.updateAudible(index, recentlyAudible)

                // Whether the *last* navigation failed — surfaces the error page.
                property bool failed: false
                property string failedUrl: ""

                Component.onCompleted: url = model.url
                onUrlChanged: root.tabsModel.updateUrl(index, url)
                onTitleChanged: root.tabsModel.updateTitle(index, title)
                onIconChanged: root.tabsModel.updateIcon(index, icon)
                onLoadingChanged: function(info) {
                    root.tabsModel.updateLoading(index, loading)
                    if (info.status === WebEngineView.LoadStartedStatus) {
                        failed = false
                    } else if (info.status === WebEngineView.LoadSucceededStatus) {
                        failed = false
                        HistoryModel.recordVisit(info.url, title)
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: retryText.implicitWidth + Theme.s6 * 2
                    height: Theme.controlMd
                    radius: Theme.radiusPill
                    color: retryHover.hovered ? Theme.accent : Theme.accentSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Text {
                        id: retryText
                        anchors.centerIn: parent
                        text: qsTr("Повторить")
                        color: retryHover.hovered ? "white" : Theme.accent
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                    }
                    HoverHandler { id: retryHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (root.activeView) root.activeView.reload() }
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
