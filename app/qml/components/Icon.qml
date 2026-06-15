import QtQuick
import QtQuick.Effects
import Filka

// Icon — renders a (white) Lucide SVG tinted to any theme color. One consistent
// icon system across the whole UI: same stroke weight, same grid, crisp on
// high-DPI, animated color transitions.
Item {
    id: root
    property string name: ""
    property color color: Theme.textSecondary
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? "qrc:/qt/qml/Filka/assets/icons/" + root.name + ".svg" : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.color
        Behavior on colorizationColor { ColorAnimation { duration: Motion.fast } }
    }
}
