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

    property bool dragActive: false
    property int dragTabId: -1
    property int dragSourceIndex: -1
    property int dragCurrentIndex: -1
    property int dragTargetIndex: -1
    property real dragPointerOffset: 0
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragGhostW: 0
    property real dragGhostH: 0
    property string dragGhostTitle: ""
    property url dragGhostIconUrl: ""
    property bool dragGhostLoading: false
    property bool dragGhostPinned: false
    property bool dragGhostMuted: false
    property bool dragGhostAudible: false
    property bool dragGhostActive: false
    property double lastDragMoveTime: 0
    readonly property int dragMoveIntervalMs: 70

    function dragStride() {
        return (vertical ? tabH : slotW) + list.spacing
    }

    function tabIndexById(tabId) {
        if (!tabs || tabId < 0)
            return -1
        return tabs.indexOfTabId(tabId)
    }

    function targetSlotFromContentPos(contentPos) {
        if (!tabs || tabs.count <= 0)
            return -1
        var stride = dragStride()
        if (stride <= 0)
            return 0
        return Math.max(0, Math.min(tabs.count - 1, Math.floor(contentPos / stride)))
    }

    function updateDragFromContentPoint(contentPoint, forceMove) {
        if (!dragActive || !tabs)
            return
        var axis = vertical ? contentPoint.y : contentPoint.x
        var target = targetSlotFromContentPos(axis)
        dragTargetIndex = target
        if (vertical) {
            dragGhostX = list.x
            dragGhostY = list.y + axis - dragPointerOffset - list.contentY
        } else {
            dragGhostX = list.x + axis - dragPointerOffset - list.contentX
            dragGhostY = list.y
        }

        var current = tabIndexById(dragTabId)
        if (current < 0 || target < 0 || current === target)
            return

        var now = Date.now()
        if (!forceMove && now - lastDragMoveTime < dragMoveIntervalMs)
            return

        tabs.moveTab(current, target)
        dragCurrentIndex = target
        lastDragMoveTime = now
    }

    function resetDragGhost() {
        dragActive = false
        dragTabId = -1
        dragSourceIndex = -1
        dragCurrentIndex = -1
        dragTargetIndex = -1
        dragPointerOffset = 0
        lastDragMoveTime = 0
    }

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
            // DragHandler does not move the ListView delegate. It drives a
            // separate ghost and computes target slots from pointer coordinates
            // mapped into ListView content space, so model reorders do not feed
            // back through delegate x/y changes.
            opacity: root.dragActive && model.tabId === root.dragTabId ? 0.18 : 1

            DragHandler {
                id: dragH
                target: null
                xAxis.enabled: !root.vertical
                yAxis.enabled: root.vertical
                cursorShape: Qt.ClosedHandCursor
                onActiveChanged: {
                    if (active) {
                        var p = tabDelegate.mapToItem(list.contentItem, centroid.position.x, centroid.position.y)
                        root.dragActive = true
                        root.dragTabId = model.tabId
                        root.dragSourceIndex = tabDelegate.index
                        root.dragCurrentIndex = tabDelegate.index
                        root.dragTargetIndex = tabDelegate.index
                        root.dragPointerOffset = root.vertical ? p.y - tabDelegate.y : p.x - tabDelegate.x
                        root.dragGhostW = tabDelegate.width
                        root.dragGhostH = tabDelegate.height
                        root.dragGhostTitle = model.title
                        root.dragGhostIconUrl = model.iconUrl
                        root.dragGhostLoading = model.loading
                        root.dragGhostPinned = model.pinned
                        root.dragGhostMuted = model.muted
                        root.dragGhostAudible = model.audible
                        root.dragGhostActive = tabDelegate.active
                        root.lastDragMoveTime = 0
                        root.updateDragFromContentPoint(p, false)
                    } else if (root.dragTabId === model.tabId) {
                        var dropPoint = tabDelegate.mapToItem(list.contentItem, centroid.position.x, centroid.position.y)
                        root.updateDragFromContentPoint(dropPoint, true)
                        root.dragCurrentIndex = root.tabIndexById(root.dragTabId)
                        root.resetDragGhost()
                    }
                }
                onTranslationChanged: {
                    if (!active || root.dragTabId !== model.tabId)
                        return
                    var p = tabDelegate.mapToItem(list.contentItem, centroid.position.x, centroid.position.y)
                    root.updateDragFromContentPoint(p, false)
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


    TabItem {
        id: dragGhost
        visible: root.dragActive
        x: root.dragGhostX
        y: root.dragGhostY
        width: root.dragGhostW
        height: root.dragGhostH
        z: 100
        opacity: visible ? 0.92 : 0
        compact: root.horizontalCompact
        title: root.dragGhostTitle
        iconUrl: root.dragGhostIconUrl
        loading: root.dragGhostLoading
        pinned: root.dragGhostPinned
        muted: root.dragGhostMuted
        audible: root.dragGhostAudible
        active: root.dragGhostActive
        enabled: false
        scale: root.dragActive && !Motion.reducedMotion ? 1.03 : 1
    }

    // Shared right-click menu — its target index/state are set on open.
    TabContextMenu {
        id: tabMenu
        onScreenshotRequested: (tabIndex) => root.screenshotRequested(tabIndex)
    }
}
