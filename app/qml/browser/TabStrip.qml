import QtQuick
import QtQuick.Controls.Basic
import Filka

// TabStrip — renders the TabModel as either a vertical sidebar (Arc-style) or a
// horizontal bar. Hosts the "new tab" button as a footer so it trails the list
// in both orientations.
//
// In horizontal mode tabs shrink to share the available width (Chrome-style):
// they never run off the edge, and collapse to icon-only chips when space is
// tight so the "+" button stays reachable no matter how many tabs are open.
Item {
    id: root
    property var tabs                 // TabModel
    property bool vertical: true
    signal screenshotRequested(int tabIndex)

    readonly property int tabH: 38
    readonly property int tabW: 214
    readonly property int minTabW: 38      // icon-only chip
    readonly property int footerW: tabH + Theme.s2

    readonly property int tabCount: tabs ? tabs.count : 0

    // Chrome-style close: while the cursor is over the horizontal strip, freeze
    // the per-tab width to the count captured at the moment of a close, so the
    // remaining tabs don't instantly widen mid-animation (which made them
    // overlap). Releasing the hover lets them glide back to fill the row.
    property int frozenCount: 0
    function closeTabAt(index) {
        if (!vertical)
            frozenCount = tabCount
        if (tabs)
            tabs.closeTab(index)
    }
    readonly property int slotCount: (!vertical && stripHover.hovered && frozenCount > tabCount)
                                     ? frozenCount : tabCount

    HoverHandler {
        id: stripHover
        onHoveredChanged: if (!hovered) root.frozenCount = 0
    }

    // Width of one horizontal tab: split the free space evenly, clamped between
    // the icon-only minimum and the comfortable maximum.
    readonly property real slotW: {
        if (vertical || slotCount <= 0)
            return tabW
        var spacing = 6
        var avail = width - footerW - Theme.s2 * 2 - spacing * slotCount
        return Math.max(minTabW, Math.min(tabW, avail / slotCount))
    }
    // Hide the label once a tab gets too thin to read it.
    readonly property bool horizontalCompact: !vertical && slotW < 78

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: root.vertical ? Theme.s1 : Theme.s2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        spacing: root.vertical ? 5 : 5
        clip: true
        model: root.tabs
        boundsBehavior: Flickable.StopAtBounds

        // Vertical sidebar can hold more tabs than fit — surface a scrollbar so
        // overflowing tabs stay reachable (the horizontal bar shrinks instead).
        ScrollBar.vertical: FilkaScrollBar {
            policy: (root.vertical && list.contentHeight > list.height)
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        // ---- List motion ---- tabs fade+scale in/out, neighbours glide aside.
        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
        }
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
            NumberAnimation { property: "scale"; from: 0.82; to: 1; duration: Motion.base; easing.type: Motion.emphasized }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.exit }
            NumberAnimation { property: "scale"; to: 0.82; duration: Motion.fast; easing.type: Motion.exit }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Motion.base; easing.type: Motion.emphasized }
        }
        // Neighbours glide out of the way when a tab is dropped into a new slot.
        moveDisplaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Motion.fast; easing.type: Motion.standard }
        }

        delegate: TabItem {
            id: tabDelegate
            required property int index
            required property var model
            width: root.vertical ? list.width : root.slotW
            height: root.vertical ? root.tabH : list.height
            // Glide horizontal tabs to their new width when the row re-flows
            // (e.g. after the hover-freeze releases) instead of snapping.
            Behavior on width {
                enabled: !root.vertical
                NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized }
            }
            compact: root.horizontalCompact
            title: model.title
            iconUrl: model.iconUrl
            loading: model.loading
            pinned: model.pinned
            muted: model.muted
            audible: model.audible
            active: index === root.tabs.activeIndex
            // Lift the grabbed tab above its neighbours while it's being dragged.
            z: dragH.active ? 10 : (active ? 1 : 0)
            onActivated: root.tabs.activeIndex = index
            onClosed: root.closeTabAt(index)
            onMuteToggled: root.tabs.setMuted(index, !model.muted)
            onContextRequested: {
                tabMenu.tabsModel = root.tabs
                tabMenu.tabIndex = index
                tabMenu.tabPinned = model.pinned
                tabMenu.tabMuted = model.muted
                tabMenu.popup()
            }

            // ---- Drag to reorder ----
            // The handler moves the delegate itself; as it crosses into another
            // tab's slot we reorder the model live (moveTab). The slot stride is
            // the tab size plus the list spacing for the current orientation.
            readonly property real slotStride: root.vertical ? (root.tabH + list.spacing)
                                                             : (root.slotW + list.spacing)
            function slotPos() { return tabDelegate.index * tabDelegate.slotStride }

            function reorderToPointer() {
                if (!dragH.active) return
                var pos = root.vertical ? tabDelegate.y : tabDelegate.x
                var to = Math.round(pos / tabDelegate.slotStride)
                to = Math.max(0, Math.min(root.tabs.count - 1, to))
                if (to !== tabDelegate.index)
                    root.tabs.moveTab(tabDelegate.index, to)
            }
            onXChanged: if (!root.vertical) reorderToPointer()
            onYChanged: if (root.vertical) reorderToPointer()

            // "Magnet": a one-shot glide that snaps the dropped tab onto its exact
            // grid slot. Kept as an explicit animation (not a Behavior) so it
            // never competes with the ListView add/remove/displaced transitions
            // during ordinary tab churn — it only runs on release.
            NumberAnimation {
                id: snapBack
                target: tabDelegate
                property: root.vertical ? "y" : "x"
                duration: Motion.base
                easing.type: Motion.emphasized
            }

            DragHandler {
                id: dragH
                target: tabDelegate
                xAxis.enabled: !root.vertical
                yAxis.enabled: root.vertical
                cursorShape: Qt.ClosedHandCursor
                onActiveChanged: {
                    if (active) { snapBack.stop(); return }
                    // Glide the tab home from wherever the cursor let go.
                    snapBack.property = root.vertical ? "y" : "x"
                    snapBack.from = root.vertical ? tabDelegate.y : tabDelegate.x
                    snapBack.to = tabDelegate.slotPos()
                    snapBack.restart()
                }
            }
        }

        footer: Item {
            width: root.vertical ? list.width : root.footerW
            height: root.vertical ? root.tabH : list.height

            // New-tab affordance: a full-width labelled row in the sidebar, a
            // compact "+" chip on the horizontal bar.
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.vertical ? 2 : 1
                radius: Theme.radiusSm
                color: addHover.hovered ? Theme.hoverFill : "transparent"
                border.width: activeFocus ? Theme.focusWidth : 0
                border.color: Theme.focusRing
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Новая вкладка")
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: root.vertical ? parent.left : undefined
                    anchors.leftMargin: root.vertical ? Theme.s3 : 0
                    anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                    spacing: Theme.s2
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "plus"; size: 16
                        color: addHover.hovered ? Theme.textPrimary : Theme.textSecondary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.vertical
                        text: qsTr("Новая вкладка")
                        color: addHover.hovered ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                    }
                }

                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.tabs.addTab() }   // opens the start page
                Keys.onReturnPressed: root.tabs.addTab()
                Keys.onEnterPressed: root.tabs.addTab()
                Keys.onSpacePressed: root.tabs.addTab()
            }
        }
    }

    // Shared right-click menu — its target index/state are set on open.
    TabContextMenu {
        id: tabMenu
        onScreenshotRequested: (tabIndex) => root.screenshotRequested(tabIndex)
    }
}
