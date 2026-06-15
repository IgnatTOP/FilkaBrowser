import QtQuick
import QtQuick.Effects
import Filka

// GlassPanel — the core Liquid Glass surface. A translucent, rounded, stroked
// rectangle with a soft drop shadow and a subtle top highlight that sells the
// "polished glass" depth. Use `level` to pick a depth (0..2).
Item {
    id: root

    property int level: 1                  // 0 low, 1 medium, 2 high
    property real radius: Theme.radiusLg
    property color fillColor: level === 0 ? Theme.glassLow
                            : level === 1 ? Theme.glassMed
                                          : Theme.glassHigh
    property color strokeColor: Theme.glassStroke
    property real strokeWidth: 1
    property bool shadow: true
    default property alias content: contentItem.data

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.color: root.strokeColor
        border.width: root.strokeWidth

        // Top inner highlight — the glints that make glass feel real.
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 1
            height: parent.height * 0.5
            radius: root.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Item {
            id: contentItem
            anchors.fill: parent
        }
    }

    layer.enabled: root.shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowBlur: 1.0
        shadowVerticalOffset: Theme.shadowY
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
    }
}
