import QtQuick
import QtQuick.Controls.Basic
import Filka

// TabContextMenu — Filka's glass right-click menu for a tab. Pure TabModel
// operations (duplicate / pin / mute / close variants); the TabStrip sets the
// target index and its current pinned/muted state before popping it up.
Menu {
    id: menu

    property var tabsModel: null
    property int tabIndex: -1
    property bool tabPinned: false
    property bool tabMuted: false

    width: 230
    padding: 6
    overlap: 0

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
    }

    background: Rectangle {
        implicitWidth: 230
        radius: Theme.radiusMd
        color: Theme.bgRaised
        border.width: 1
        border.color: Theme.glassStroke
    }

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

    MItem {
        text: qsTr("Новая вкладка")
        onTriggered: if (menu.tabsModel) menu.tabsModel.addTabAfter(menu.tabIndex)
    }
    MItem {
        text: qsTr("Дублировать вкладку")
        onTriggered: if (menu.tabsModel) menu.tabsModel.duplicateTab(menu.tabIndex)
    }

    MSep {}
    MItem {
        text: menu.tabPinned ? qsTr("Открепить вкладку") : qsTr("Закрепить вкладку")
        onTriggered: if (menu.tabsModel) menu.tabsModel.setPinned(menu.tabIndex, !menu.tabPinned)
    }
    MItem {
        text: menu.tabMuted ? qsTr("Включить звук") : qsTr("Выключить звук")
        onTriggered: if (menu.tabsModel) menu.tabsModel.setMuted(menu.tabIndex, !menu.tabMuted)
    }

    MSep {}
    MItem {
        text: qsTr("Закрыть вкладку")
        onTriggered: if (menu.tabsModel) menu.tabsModel.closeTab(menu.tabIndex)
    }
    MItem {
        text: qsTr("Закрыть другие вкладки")
        enabled: menu.tabsModel && menu.tabsModel.count > 1
        onTriggered: if (menu.tabsModel) menu.tabsModel.closeOthers(menu.tabIndex)
    }
    MItem {
        text: qsTr("Закрыть вкладки справа")
        enabled: menu.tabsModel && menu.tabIndex < menu.tabsModel.count - 1
        onTriggered: if (menu.tabsModel) menu.tabsModel.closeToRight(menu.tabIndex)
    }
}
