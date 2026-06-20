import QtQuick
import QtQuick.Layouts
import Filka

// TabPanel — reusable workspace + tab strip combo. Adapts to horizontal or
// vertical orientation. Extracted from BrowserView to eliminate duplication.
Item {
    id: root
    property var workspaces
    property bool vertical: true

    implicitHeight: vertical ? 48 : 48

    WorkspaceSwitcher {
        id: switcher
        workspaces: root.workspaces
        anchors.left: parent.left
        anchors.leftMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: implicitWidth
    }

    TabStrip {
        tabs: root.workspaces.activeTabs
        workspaceModel: root.workspaces
        vertical: root.vertical
        anchors { left: switcher.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        anchors.leftMargin: Theme.s1
    }
}
