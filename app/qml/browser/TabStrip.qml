import QtQuick
import QtQuick.Controls.Basic
import Filka

// TabStrip — renders the TabModel as either a vertical sidebar (Arc-style) or a
// horizontal bar. Hosts the "new tab" button as a footer so it trails the list
// in both orientations.
//
// In horizontal mode tabs shrink to share the available width (Chrome-style):
// they never run off the edge, and collapse to icon-only chips when space is
// tight so the "+" button stays reachable no matter how many tabs are open.
Item {
    id: root
    property var tabs                 // TabModel
    property bool vertical: true

    readonly property int tabH: 38
    readonly property int tabW: 200
    readonly property int minTabW: 40      // icon-only chip
    readonly property int footerW: tabH + Theme.s2

    readonly property int tabCount: tabs ? tabs.count : 0

    // Width of one horizontal tab: split the free space evenly, clamped between
    // the icon-only minimum and the comfortable maximum.
    readonly property real slotW: {
        if (vertical || tabCount <= 0)
            return tabW
        var spacing = 6
        var avail = width - footerW - Theme.s2 * 2 - spacing * tabCount
        return Math.max(minTabW, Math.min(tabW, avail / tabCount))
    }
    // Hide the label once a tab gets too thin to read it.
    readonly property bool horizontalCompact: !vertical && slotW < 78

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.s2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        spacing: root.vertical ? 4 : 6
        clip: true
        model: root.tabs
        boundsBehavior: Flickable.StopAtBounds

        delegate: TabItem {
            width: root.vertical ? list.width : root.slotW
            height: root.vertical ? root.tabH : list.height
            compact: root.horizontalCompact
            title: model.title
            iconUrl: model.iconUrl
            loading: model.loading
            pinned: model.pinned
            active: index === root.tabs.activeIndex
            onActivated: root.tabs.activeIndex = index
            onClosed: root.tabs.closeTab(index)
        }

        footer: Item {
            width: root.vertical ? list.width : root.footerW
            height: root.vertical ? root.tabH : list.height
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: root.vertical ? parent.left : undefined
                anchors.leftMargin: root.vertical ? 2 : 0
                anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                iconName: "plus"; size: 30
                onClicked: root.tabs.addTab()   // opens the start page
            }
        }
    }
}
