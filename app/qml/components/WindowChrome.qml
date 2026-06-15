import QtQuick
import QtQuick.Window
import Filka

// WindowChrome — draggable top bar for the frameless window. Hosts arbitrary
// content (left slot) and the window controls (right). Double-click toggles
// maximize; press-drag moves the window via the platform compositor.
Item {
    id: root
    property Window target
    property alias leftContent: leftSlot.data
    property alias centerContent: centerSlot.data
    implicitHeight: 44

    // Drag-to-move handled by the compositor for smooth, native behaviour.
    DragHandler {
        target: null
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: if (active && root.target) root.target.startSystemMove()
    }
    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onDoubleTapped: {
            if (!root.target) return
            root.target.visibility === Window.Maximized
                ? root.target.showNormal() : root.target.showMaximized()
        }
    }

    Item {
        id: leftSlot
        anchors { left: parent.left; verticalCenter: parent.verticalCenter
                  leftMargin: Theme.s4 }
        height: parent.height
    }

    Item {
        id: centerSlot
        anchors.centerIn: parent
        height: parent.height
    }

    WindowControls {
        target: root.target
        anchors { right: parent.right; verticalCenter: parent.verticalCenter
                  rightMargin: Theme.s2 }
    }
}
