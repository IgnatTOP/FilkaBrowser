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
    signal inspectRequested()

    width: 250
    padding: 6
    overlap: 0

    // Themed, rounded container.
    background: Rectangle {
        implicitWidth: 250
        radius: Theme.radiusMd
        color: Theme.bgRaised
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
        onTriggered: if (menu.tabsModel) menu.tabsModel.addTab(menu.request.linkUrl, false)
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

    // ---- Tools ----
    MSep {}
    MItem {
        text: "Исследовать элемент"
        onTriggered: menu.inspectRequested()
    }
}
