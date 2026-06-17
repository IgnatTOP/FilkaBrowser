import QtQuick
import Filka

// SidePanel — a glass drawer that slides in from the right edge over the
// browsing surface, dimming everything behind it. Used for Settings and
// History. Set `open` to toggle; tapping the scrim (or pressing Esc) closes it.
Item {
    id: root

    property bool open: false
    property string title: ""
    property bool large: false
    property bool centered: false
    property real preferredWidth: 460
    signal requestClose()
    default property alias content: bodyArea.data

    anchors.fill: parent
    z: 200
    visible: root.centered ? (open || panelWrap.opacity > 0.01)
                           : (open || panelWrap.x < root.width)
    focus: open

    // Dimming scrim — click anywhere outside the panel to dismiss.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.open ? (root.centered ? (Theme.dark ? 0.46 : 0.26)
                                            : (Theme.dark ? 0.28 : 0.16)) : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
        TapHandler { onTapped: root.requestClose() }
    }

    // The drawer itself (no horizontal anchor so x can be animated).
    Item {
        id: panelWrap
        width: root.centered
               ? Math.min(1080, Math.max(760, root.width - Theme.s7 * 2))
               : root.large
                 ? Math.min(Math.max(760, root.width * 0.72), root.width - Theme.s6)
               : Math.min(root.preferredWidth, Math.max(320, root.width - Theme.s5))
        height: root.centered ? Math.min(760, root.height - Theme.s7)
                              : root.height - Theme.s6
        y: root.centered ? Math.round((root.height - height) / 2) : Theme.s3
        x: root.open
           ? (root.centered ? Math.round((root.width - width) / 2)
                            : root.width - width - Theme.s3)
           : (root.centered ? Math.round((root.width - width) / 2)
                            : root.width + Theme.s4)
        opacity: root.open ? 1 : 0
        scale: root.centered ? (root.open ? 1 : 0.985) : 1
        Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
        Behavior on opacity { OpacityAnimator { duration: Motion.base; easing.type: Motion.standard } }
        Behavior on scale { ScaleAnimator { duration: Motion.base; easing.type: Motion.emphasized } }

        GlassPanel {
            anchors.fill: parent
            level: 2
            radius: root.centered ? Theme.radiusXl : Theme.radiusMd

            // Opaque base so panel content stays readable over busy page chrome
            // (the glass fill alone is too translucent for dense text/lists).
            Rectangle {
                anchors.fill: parent
                radius: root.centered ? Theme.radiusXl : Theme.radiusMd
                color: Theme.surface
                opacity: 1
            }

            // Header: title + close button.
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors.margins: Theme.s2
                height: 44

                Text {
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    text: root.title
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.DemiBold
                }
                IconButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    iconName: "x"; size: Theme.controlMd
                    Accessible.name: qsTr("Закрыть")
                    onClicked: root.requestClose()
                }
            }

            Rectangle {
                id: divider
                anchors { top: header.bottom; left: parent.left; right: parent.right
                          leftMargin: Theme.s3; rightMargin: Theme.s3 }
                height: 1
                color: Theme.glassHairline
            }

            // Content slot fills the remaining space.
            Item {
                id: bodyArea
                anchors { top: divider.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.margins: Theme.s3
            }
        }
    }

    // Swallow clicks that land on the panel so they don't reach the scrim.
    Keys.onEscapePressed: root.requestClose()
}
