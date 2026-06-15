import QtQuick
import Filka

// TabItem — a single tab chip. Layout-agnostic: the TabStrip sizes it for the
// vertical sidebar or the horizontal bar. Shows favicon (or a spinner while
// loading), elided title and a close button on hover/active.
Rectangle {
    id: root

    property string title: "New Tab"
    property url iconUrl: ""
    property bool loading: false
    property bool active: false
    property bool pinned: false
    property bool compact: false      // icon-only (pinned / narrow)

    signal activated()
    signal closed()

    // Whether the close affordance should be offered right now.
    readonly property bool showClose: !root.pinned && (hover.hovered || root.active)
    // In compact mode the close button replaces the favicon on hover/active.
    readonly property bool compactClose: root.compact && showClose

    radius: Theme.radiusMd
    color: active ? Theme.glassHigh
          : hover.hovered ? Theme.glassMed : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.glassStroke
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    // Accent rail on the active tab — Arc-like identity.
    Rectangle {
        visible: root.active && !root.compact
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
        width: 3; height: parent.height * 0.5; radius: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.electricBlue }
            GradientStop { position: 1.0; color: Theme.cyan }
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: root.activated() }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.compact ? undefined : parent.left
        anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
        anchors.right: root.compact ? undefined : parent.right
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s2
        spacing: Theme.s2
        visible: !root.compactClose

        // Favicon, or a spinning loader while the page loads.
        Item {
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: root.iconUrl
                visible: !root.loading && root.iconUrl != ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !root.loading && root.iconUrl == ""
                name: "globe"; size: 14; color: Theme.textMuted
            }
            Icon {
                id: spinner
                anchors.centerIn: parent
                visible: root.loading
                name: "loader-circle"; size: 14; color: Theme.accent
                RotationAnimator on rotation {
                    running: spinner.visible; loops: Animation.Infinite
                    from: 0; to: 360; duration: 700
                }
            }
        }

        Text {
            visible: !root.compact
            width: Math.max(0, root.width - 70)
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.active ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // Close button. In the roomy layout it sits at the trailing edge; in the
    // compact layout it takes the favicon's place (centred) on hover/active.
    IconButton {
        visible: root.showClose
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.compact ? undefined : parent.right
        anchors.rightMargin: 4
        anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
        iconName: "x"; size: 22; iconSize: 12
        Accessible.name: "Close tab"
        onClicked: root.closed()
    }
}
