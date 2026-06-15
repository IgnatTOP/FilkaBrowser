import QtQuick
import Filka

// SidePanel — a glass drawer that slides in from the right edge over the
// browsing surface, dimming everything behind it. Used for Settings and
// History. Set `open` to toggle; tapping the scrim (or pressing Esc) closes it.
Item {
    id: root

    property bool open: false
    property string title: ""
    signal requestClose()
    default property alias content: bodyArea.data

    anchors.fill: parent
    z: 200
    visible: open || panelWrap.x < root.width   // stay mounted during the close slide

    // Dimming scrim — click anywhere outside the panel to dismiss.
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.min(root.width, Math.max(0, panelWrap.x))
        color: "black"
        opacity: root.open ? 0.5 : 0
        visible: opacity > 0.001 && width > 0
        Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
        TapHandler { onTapped: root.requestClose() }
    }

    // The drawer itself (no horizontal anchor so x can be animated).
    Item {
        id: panelWrap
        width: Math.min(460, root.width - Theme.s5)
        anchors { top: parent.top; bottom: parent.bottom
                  topMargin: Theme.s3; bottomMargin: Theme.s3 }
        x: root.open ? (root.width - width - Theme.s3) : (root.width + Theme.s4)
        Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

        GlassPanel {
            anchors.fill: parent
            level: 2
            radius: Theme.radiusXl

            // Opaque base so panel content stays readable over busy page chrome
            // (the glass fill alone is too translucent for dense text/lists).
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXl
                color: Theme.bgRaised
                opacity: 0.94
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
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }
                IconButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    iconName: "x"; size: 32
                    Accessible.name: "Close"
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
