import QtQuick
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// WebContextMenu — Filka's own glass right-click menu for web content, shown in
// place of Chromium's bare default. Items adapt to what was clicked (link,
// image, selection, editable field). Driven by a WebEngineContextMenuRequest.
Menu {
    id: menu

    property var view: null
    property var request: null
    property var tabsModel: null
    property var browser: null
    signal inspectRequested()
    signal pictureInPictureRequested()
    signal openLinkInNewWindowRequested(url linkUrl)

    function openLinkInTab(activate) {
        if (!menu.tabsModel || !menu.request)
            return
        var url = menu.request.linkUrl
        if (menu.tabsModel.addTabAfter)
            menu.tabsModel.addTabAfter(menu.tabsModel.activeIndex, url, activate)
        else
            menu.tabsModel.addTab(url, activate)
    }

    width: 250
    padding: 6
    overlap: 0

    // Quick fade + lift on open so the menu feels light, not stamped down.
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
    }

    // Themed, rounded container.
    background: Rectangle {
        implicitWidth: 250
        radius: Theme.radiusMd
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.glassStroke
    }

    // Shared item look — accent-tinted hover, comfortable height.
    component MItem: MenuItem {
        id: mi
        implicitHeight: visible ? 34 : 0
        horizontalPadding: Theme.s3
        contentItem: Text {
            text: mi.text
            color: mi.enabled ? Theme.textPrimary : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSm
            color: mi.highlighted ? Theme.accentSoft : "transparent"
        }
    }

    component MSep: MenuSeparator {
        padding: 4
        contentItem: Rectangle { implicitHeight: 1; color: Theme.glassHairline }
    }

    // ---- Navigation ----
    MItem {
        text: "Назад"
        enabled: menu.view && menu.view.canGoBack
        onTriggered: menu.view.goBack()
    }
    MItem {
        text: "Вперёд"
        enabled: menu.view && menu.view.canGoForward
        onTriggered: menu.view.goForward()
    }
    MItem {
        text: "Обновить"
        onTriggered: if (menu.view) menu.view.reload()
    }

    // ---- Link actions ----
    MSep { visible: menu.request && menu.request.linkUrl.toString().length > 0 }
    MItem {
        text: "Открыть ссылку в новой вкладке"
        visible: menu.request && menu.request.linkUrl.toString().length > 0
        onTriggered: menu.openLinkInTab(true)
    }
    MItem {
        text: "Открыть ссылку в фоновой вкладке"
        visible: menu.request && menu.request.linkUrl.toString().length > 0
        onTriggered: menu.openLinkInTab(false)
    }
    MItem {
        text: "Открыть в новом окне"
        visible: menu.request && menu.request.linkUrl.toString().length > 0
        onTriggered: menu.openLinkInNewWindowRequested(menu.request.linkUrl)
    }
    MItem {
        text: "Копировать адрес ссылки"
        visible: menu.request && menu.request.linkUrl.toString().length > 0
        onTriggered: menu.view.triggerWebAction(WebEngineView.CopyLinkToClipboard)
    }

    // ---- Image actions ----
    MSep { visible: menu.request && menu.request.mediaType === WebEngineContextMenuRequest.MediaTypeImage }
    MItem {
        text: "Сохранить изображение"
        visible: menu.request && menu.request.mediaType === WebEngineContextMenuRequest.MediaTypeImage
        onTriggered: menu.view.triggerWebAction(WebEngineView.DownloadImageToDisk)
    }
    MItem {
        text: "Копировать изображение"
        visible: menu.request && menu.request.mediaType === WebEngineContextMenuRequest.MediaTypeImage
        onTriggered: menu.view.triggerWebAction(WebEngineView.CopyImageToClipboard)
    }

    // ---- Media actions ----
    MSep { visible: menu.request && menu.request.mediaType === WebEngineContextMenuRequest.MediaTypeVideo }
    MItem {
        text: qsTr("Открыть в Picture-in-Picture")
        visible: menu.request && menu.request.mediaType === WebEngineContextMenuRequest.MediaTypeVideo
        onTriggered: menu.pictureInPictureRequested()
    }

    // ---- Editing ----
    MSep { visible: (menu.request && menu.request.selectedText.length > 0) || (menu.request && menu.request.isContentEditable) }
    MItem {
        text: "Копировать"
        visible: menu.request && menu.request.selectedText.length > 0
        onTriggered: menu.view.triggerWebAction(WebEngineView.Copy)
    }
    MItem {
        text: "Вырезать"
        visible: menu.request && menu.request.isContentEditable && menu.request.selectedText.length > 0
        onTriggered: menu.view.triggerWebAction(WebEngineView.Cut)
    }
    MItem {
        text: "Вставить"
        visible: menu.request && menu.request.isContentEditable
        onTriggered: menu.view.triggerWebAction(WebEngineView.Paste)
    }

    // ---- Page tools ----
    MSep {}
    MItem {
        text: "Печать / Сохранить как PDF"
        onTriggered: {
            if (menu.browser)
                menu.browser.printViewToPdf(menu.view)
        }
    }
    MItem {
        text: "Исследовать элемент"
        onTriggered: menu.inspectRequested()
    }
}
