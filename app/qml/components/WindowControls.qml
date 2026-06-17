import QtQuick
import QtQuick.Window
import Filka

// WindowControls — macOS-style traffic lights for the frameless window.
Row {
    id: root

    property Window target
    spacing: 8

    component ControlDot: Rectangle {
        id: dot
        property color dotColor: "#FFFFFF"
        property string iconName: "x"
        property string label: ""
        signal triggered()

        width: 13
        height: 13
        radius: 7
        color: hover.hovered || activeFocus ? dotColor : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.86)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.18)
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        Icon {
            anchors.centerIn: parent
            name: dot.iconName
            size: 8
            color: Qt.rgba(0, 0, 0, 0.58)
            opacity: hover.hovered || dot.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: dot.triggered() }
        Keys.onReturnPressed: dot.triggered()
        Keys.onEnterPressed: dot.triggered()
        Keys.onSpacePressed: dot.triggered()
    }

    ControlDot {
        dotColor: "#FF5F57"
        iconName: "x"
        label: qsTr("Закрыть")
        onTriggered: if (root.target) root.target.close()
    }
    ControlDot {
        dotColor: "#FFBD2E"
        iconName: "minus"
        label: qsTr("Свернуть")
        onTriggered: if (root.target) root.target.showMinimized()
    }
    ControlDot {
        dotColor: "#28C840"
        iconName: root.target && root.target.visibility === Window.Maximized ? "copy" : "square"
        label: root.target && root.target.visibility === Window.Maximized ? qsTr("Восстановить") : qsTr("Развернуть")
        onTriggered: if (root.target) {
            root.target.visibility === Window.Maximized
                ? root.target.showNormal() : root.target.showMaximized()
        }
    }
}
