import QtQuick
import Filka

// TabItem — a single tab card. Layout-agnostic: the TabStrip sizes it for the
// vertical sidebar or the horizontal bar. Shows favicon (or a spinner while
// loading), elided title and close/audio controls on hover/active.
Rectangle {
    id: root

    property string title: "New Tab"
    property url iconUrl: ""
    property bool loading: false
    property bool active: false
    property bool pinned: false
    property bool muted: false
    property bool audible: false
    property bool compact: false      // icon-only (pinned / narrow)

    signal activated()
    signal closed()
    signal muteToggled()
    signal contextRequested(real px, real py)

    // The speaker affordance shows when a tab plays audio or is muted.
    readonly property bool showAudio: (root.audible || root.muted) && !root.compact

    // Compact tabs should not swap their favicon for a close button the instant
    // the pointer passes over them. Reveal it immediately for the active tab,
    // but require a short hover dwell for inactive compact tabs.
    property bool compactHoverCloseReady: false
    readonly property bool compactHoverClose: root.compact && hover.hovered && root.compactHoverCloseReady

    // Whether the close affordance should be offered right now. Non-compact tabs
    // keep the roomy, immediate hover close button; compact tabs only show it
    // when active or after the hover dwell. Pinned tabs never expose this
    // ordinary close affordance.
    readonly property bool showClose: !root.pinned && (root.active || (!root.compact && hover.hovered) || root.compactHoverClose)
    // In compact mode the close button replaces the favicon on active/delayed hover.
    readonly property bool compactClose: root.compact && showClose

    radius: Theme.radiusMd
    color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
          : hover.hovered ? Theme.glassLow : "transparent"
    border.width: activeFocus ? Theme.focusWidth : (active ? 1 : 0)
    border.color: activeFocus ? Theme.focusRing
                : (active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
                          : "transparent")
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTab
    Accessible.name: root.title
    Behavior on color { ColorAnimation { duration: Motion.fast } }
    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

    // Accent rail on the active tab — Arc-like identity.
    Rectangle {
        visible: root.active && !root.compact
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 5 }
        width: 3; height: parent.height * 0.52; radius: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.brandLavender }
            GradientStop { position: 1.0; color: Theme.brandBlue }
        }
    }

    Timer {
        id: compactHoverCloseTimer
        interval: 360
        repeat: false
        onTriggered: root.compactHoverCloseReady = root.compact && hover.hovered
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.compactHoverCloseReady = false
            compactHoverCloseTimer.stop()
            if (hovered && root.compact && !root.active)
                compactHoverCloseTimer.restart()
        }
    }

    onCompactChanged: {
        root.compactHoverCloseReady = false
        compactHoverCloseTimer.stop()
        if (root.compact && hover.hovered && !root.active)
            compactHoverCloseTimer.restart()
    }
    onActiveChanged: {
        if (root.active || !hover.hovered) {
            root.compactHoverCloseReady = false
            compactHoverCloseTimer.stop()
        } else if (root.compact) {
            compactHoverCloseTimer.restart()
        }
    }

    TapHandler { onTapped: root.activated() }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.closed()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (ev) => root.contextRequested(ev.position.x, ev.position.y)
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.compact ? undefined : parent.left
        anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
        anchors.right: root.compact ? undefined : parent.right
        anchors.leftMargin: Theme.s2
        anchors.rightMargin: Theme.s2
        spacing: Theme.s2
        visible: !root.compactClose

        // Favicon, or a spinning loader while the page loads.
        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: root.iconUrl
                visible: !root.loading && root.iconUrl != ""
                sourceSize: Qt.size(32, 32)
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
                    running: spinner.visible && !Motion.reducedMotion; loops: Animation.Infinite
                    from: 0; to: 360; duration: 700
                }
            }
        }

        Text {
            visible: !root.compact
            width: Math.max(0, root.width - 76 - (root.showAudio ? 24 : 0))
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.active ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // Audio indicator / mute toggle — sits just left of the close button.
    IconButton {
        opacity: root.showAudio ? 1 : 0
        visible: opacity > 0.01
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.showClose ? 28 : 4
        iconName: root.muted ? "volume-x" : "volume-2"
        size: 22; iconSize: 12
        active: !root.muted
        Accessible.name: root.muted ? qsTr("Включить звук") : qsTr("Выключить звук")
        onClicked: root.muteToggled()
        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
    }

    // Close button. In the roomy layout it sits at the trailing edge; in the
    // compact layout it takes the favicon's place (centred) on hover/active.
    IconButton {
        opacity: root.showClose ? 1 : 0
        visible: opacity > 0.01
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.compact ? undefined : parent.right
        anchors.rightMargin: 4
        anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
        iconName: "x"; size: 22; iconSize: 12
        Accessible.name: qsTr("Закрыть вкладку")
        onClicked: root.closed()
        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
    }

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()
    Keys.onDeletePressed: if (!root.pinned) root.closed()
}
