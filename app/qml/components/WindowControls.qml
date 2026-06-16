import QtQuick
import QtQuick.Window
import Filka

// WindowControls — minimize / maximize / close for the frameless window.
Row {
    id: root
    property Window target
    spacing: 2

    IconButton {
        iconName: "minus"; size: 30; iconSize: 15
        Accessible.name: qsTr("Свернуть")
        onClicked: if (root.target) root.target.showMinimized()
    }
    IconButton {
        iconName: root.target && root.target.visibility === Window.Maximized ? "copy" : "square"
        size: 30; iconSize: 13
        Accessible.name: root.target && root.target.visibility === Window.Maximized ? qsTr("Восстановить") : qsTr("Развернуть")
        onClicked: if (root.target) {
            root.target.visibility === Window.Maximized
                ? root.target.showNormal() : root.target.showMaximized()
        }
    }
    IconButton {
        iconName: "x"; size: 30; iconSize: 15
        hoverColor: Theme.danger
        Accessible.name: qsTr("Закрыть")
        onClicked: if (root.target) root.target.close()
    }
}
