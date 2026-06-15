import QtQuick
import QtQuick.Controls.Basic
import Filka

// TabStrip — renders the TabModel as either a vertical sidebar (Arc-style) or a
// horizontal bar. Hosts the "new tab" button as a footer so it trails the list
// in both orientations.
Item {
    id: root
    property var tabs                 // TabModel
    property bool vertical: true

    readonly property int tabH: 38
    readonly property int tabW: 200

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
            width: root.vertical ? list.width : root.tabW
            height: root.vertical ? root.tabH : list.height
            title: model.title
            iconUrl: model.iconUrl
            loading: model.loading
            pinned: model.pinned
            active: index === root.tabs.activeIndex
            onActivated: root.tabs.activeIndex = index
            onClosed: root.tabs.closeTab(index)
        }

        footer: Item {
            width: root.vertical ? list.width : root.tabH + Theme.s2
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
