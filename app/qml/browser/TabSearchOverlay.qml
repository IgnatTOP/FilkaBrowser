pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    property var tabModel: null
    property var workspaceModel: null
    property int currentWorkspace: workspaceModel ? workspaceModel.activeIndex : 0
    property int currentTabId: tabModel ? tabModel.activeIndex : -1
    property int activeTabId: currentTabId
    property bool opened: false
    property int requestedWorkspaceId: -1
    property int requestedTabId: -1

    readonly property int workspaceNameRole: 257
    readonly property int workspaceGlyphRole: 258
    readonly property int workspaceAccentRole: 259
    property var results: []
    property int totalTabs: 0
    property int totalMatches: 0

    signal requestActivate(int workspaceId, int tabId)
    signal requestClose(int tabId)

    visible: opacity > 0.01 || opened
    enabled: visible
    opacity: opened ? 1 : 0
    z: 500
    focus: opened
    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Поиск по вкладкам")

    Behavior on opacity { OpacityAnimator { duration: Motion.fast; easing.type: Motion.standard } }

    onOpenedChanged: {
        if (opened) {
            query.text = ""
            rebuild()
            query.forceActiveFocus()
        }
    }

    function open() {
        opened = true
    }

    function close() {
        opened = false
    }

    function toggle() {
        opened ? close() : open()
    }

    function workspaceCount() {
        if (workspaceModel && workspaceModel.count !== undefined)
            return workspaceModel.count
        return tabModel ? 1 : 0
    }

    function workspaceData(workspaceId, role, fallbackValue) {
        if (!workspaceModel || !workspaceModel.index || !workspaceModel.data)
            return fallbackValue

        const idx = workspaceModel.index(workspaceId, 0)
        const value = workspaceModel.data(idx, role)
        return value === undefined || value === null || value === "" ? fallbackValue : value
    }

    function tabsForWorkspace(workspaceId) {
        if (workspaceModel && workspaceModel.tabsAt)
            return workspaceModel.tabsAt(workspaceId)
        return workspaceId === 0 ? tabModel : null
    }

    function workspaceName(workspaceId) {
        return workspaceData(workspaceId, workspaceNameRole,
                             qsTr("Пространство %1").arg(workspaceId + 1))
    }

    function workspaceGlyph(workspaceId) {
        return workspaceData(workspaceId, workspaceGlyphRole, "globe")
    }

    function workspaceAccent(workspaceId) {
        return workspaceData(workspaceId, workspaceAccentRole, Theme.accent)
    }

    function hostFromUrl(rawUrl) {
        let value = (rawUrl || "").toString()
        value = value.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "")
        const slash = value.indexOf("/")
        let host = slash >= 0 ? value.slice(0, slash) : value
        const at = host.lastIndexOf("@")
        if (at >= 0)
            host = host.slice(at + 1)
        const colon = host.indexOf(":")
        if (colon > 0)
            host = host.slice(0, colon)
        return host
    }

    function fallbackLetter(title, url) {
        const source = (title && title.length > 0 ? title : url || "").toString().trim()
        return source.length > 0 ? source.charAt(0).toUpperCase() : "F"
    }

    function rebuild() {
        const q = query.text.trim()
        let out = []
        let tabsTotal = 0
        let matchesTotal = 0
        const count = workspaceCount()

        for (let workspaceId = 0; workspaceId < count; ++workspaceId) {
            const tabs = tabsForWorkspace(workspaceId)
            const tabCount = tabs && tabs.count !== undefined ? tabs.count : 0
            tabsTotal += tabCount
            if (!tabs || !tabs.entries || tabCount <= 0)
                continue

            const entries = tabs.entries(q, tabCount)
            if (entries.length === 0)
                continue

            const name = workspaceName(workspaceId)
            const glyph = workspaceGlyph(workspaceId)
            const accent = workspaceAccent(workspaceId)
            matchesTotal += entries.length
            out.push({
                kind: "header",
                workspaceId: workspaceModel ? workspaceId : currentWorkspace,
                title: name,
                glyph: glyph,
                accent: accent,
                count: tabCount,
                matchCount: entries.length
            })

            for (let i = 0; i < entries.length; ++i) {
                const entry = entries[i]
                const title = entry.title && entry.title.length > 0 ? entry.title : entry.url
                const url = entry.url || ""
                out.push({
                    kind: "tab",
                    workspaceId: workspaceModel ? workspaceId : currentWorkspace,
                    workspaceName: name,
                    workspaceAccent: accent,
                    tabId: entry.index,
                    title: title,
                    url: url,
                    host: hostFromUrl(url),
                    fallback: fallbackLetter(title, url)
                })
            }
        }

        results = out
        totalTabs = tabsTotal
        totalMatches = matchesTotal
        list.currentIndex = firstSelectableIndex()
    }

    function firstSelectableIndex() {
        for (let i = 0; i < results.length; ++i) {
            if (results[i].kind === "tab")
                return i
        }
        return -1
    }

    function isTabRow(index) {
        return index >= 0 && index < results.length && results[index].kind === "tab"
    }

    function selectedTab() {
        return isTabRow(list.currentIndex) ? results[list.currentIndex] : null
    }

    function moveSelection(step) {
        if (results.length === 0)
            return

        let next = list.currentIndex
        for (let i = 0; i < results.length; ++i) {
            next = Math.max(0, Math.min(results.length - 1, next + step))
            if (isTabRow(next)) {
                list.currentIndex = next
                list.positionViewAtIndex(next, ListView.Contain)
                return
            }
        }
    }

    function activateCurrent() {
        const tab = selectedTab()
        if (!tab)
            return

        requestedWorkspaceId = tab.workspaceId
        requestedTabId = tab.tabId
        requestActivate(tab.workspaceId, tab.tabId)
        close()
    }

    function closeCurrentTab() {
        const tab = selectedTab()
        if (tab)
            closeTab(tab)
    }

    function closeTab(tab) {
        requestedWorkspaceId = tab.workspaceId
        requestedTabId = tab.tabId
        requestClose(tab.tabId)
        rebuildLater.restart()
    }

    Keys.onEscapePressed: close()
    Keys.onPressed: (event) => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_W) {
            closeCurrentTab()
            event.accepted = true
        }
    }

    Connections {
        target: root.workspaceModel
        function onCountChanged() { if (root.opened) root.rebuild() }
        function onDataChanged() { if (root.opened) root.rebuild() }
        function onRowsInserted() { if (root.opened) root.rebuild() }
        function onRowsRemoved() { if (root.opened) root.rebuild() }
        function onModelReset() { if (root.opened) root.rebuild() }
        function onActiveIndexChanged() { if (root.opened) root.rebuild() }
        function onTabSummariesChanged() { if (root.opened) root.rebuild() }
    }

    Connections {
        target: root.tabModel
        function onCountChanged() { if (root.opened) root.rebuild() }
        function onActiveIndexChanged() { if (root.opened) root.rebuild() }
        function onChanged() { if (root.opened) root.rebuild() }
    }

    Timer {
        id: rebuildLater
        interval: 0
        onTriggered: if (root.opened) root.rebuild()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        Accessible.ignored: true

        TapHandler { onTapped: root.close() }
    }

    GlassPanel {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(58, parent.height * 0.13)
        width: Math.min(740, Math.max(280, parent.width - Theme.s6))
        height: Math.min(600, Math.max(260, parent.height - y - Theme.s6))
        level: 2
        fillColor: Theme.modalSurface
        radius: Theme.radiusLg
        scale: root.opened ? 1 : 0.98
        transformOrigin: Item.Top

        Behavior on scale { ScaleAnimator { duration: Motion.fast; easing.type: Motion.emphasized } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: Theme.radiusMd
                color: query.activeFocus ? Theme.surfaceAlt : Theme.card
                border.width: 1
                border.color: query.activeFocus ? Theme.focusRing : Theme.outline

                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 17
                    color: Theme.textMuted
                }

                TextField {
                    id: query
                    anchors.left: searchIcon.right
                    anchors.right: countLabel.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.s2
                    anchors.rightMargin: Theme.s2
                    background: null
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    placeholderText: qsTr("Найти вкладку...")
                    placeholderTextColor: Theme.textMuted
                    selectByMouse: true
                    Accessible.name: qsTr("Найти вкладку")
                    onTextEdited: root.rebuild()
                    onAccepted: root.activateCurrent()
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onPressed: (event) => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_W) {
                            root.closeCurrentTab()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    id: countLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.totalMatches > 0 ? qsTr("%1 найдено").arg(root.totalMatches) : ""
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    horizontalAlignment: Text.AlignRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 3
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: FilkaScrollBar {}

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData

                        readonly property bool tabRow: modelData.kind === "tab"
                        readonly property bool current: tabRow && modelData.workspaceId === root.currentWorkspace
                                                        && (modelData.tabId === root.currentTabId
                                                            || modelData.tabId === root.activeTabId)
                        readonly property bool selected: tabRow && index === list.currentIndex

                        width: ListView.view.width
                        height: tabRow ? 58 : 34
                        radius: tabRow ? Theme.radiusMd : Theme.radiusSm
                        color: !tabRow ? "transparent"
                              : selected ? Theme.activeFill
                              : hover.hovered ? Theme.hoverFill : "transparent"
                        border.width: activeFocus ? Theme.focusWidth : (current ? 1 : 0)
                        border.color: activeFocus ? Theme.focusRing
                                    : current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42)
                                              : "transparent"
                        activeFocusOnTab: tabRow
                        Accessible.role: tabRow ? Accessible.ListItem : Accessible.StaticText
                        Accessible.name: tabRow
                                         ? qsTr("%1, %2").arg(modelData.title).arg(modelData.url)
                                         : modelData.title

                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                        HoverHandler {
                            id: hover
                            cursorShape: row.tabRow ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onHoveredChanged: {
                                if (hovered && row.tabRow)
                                    list.currentIndex = row.index
                            }
                        }

                        TapHandler {
                            enabled: row.tabRow
                            onTapped: {
                                list.currentIndex = row.index
                                root.activateCurrent()
                            }
                        }

                        Keys.onReturnPressed: if (row.tabRow) root.activateCurrent()
                        Keys.onEnterPressed: if (row.tabRow) root.activateCurrent()
                        Keys.onSpacePressed: if (row.tabRow) root.activateCurrent()
                        Keys.onDeletePressed: if (row.tabRow) root.closeTab(row.modelData)
                        Keys.onEscapePressed: root.close()

                        Row {
                            visible: !row.tabRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.s2
                            anchors.rightMargin: Theme.s2
                            spacing: Theme.s2

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.glyph
                                size: 14
                                color: row.modelData.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - badge.width - Theme.s6)
                                text: row.modelData.title
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: badge
                                anchors.verticalCenter: parent.verticalCenter
                                width: badgeText.implicitWidth + Theme.s3
                                height: 20
                                radius: Theme.radiusPill
                                color: Qt.rgba(row.modelData.accent.r, row.modelData.accent.g,
                                               row.modelData.accent.b, 0.14)
                                border.width: 1
                                border.color: Qt.rgba(row.modelData.accent.r, row.modelData.accent.g,
                                                      row.modelData.accent.b, 0.28)

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: row.modelData.matchCount === row.modelData.count
                                          ? row.modelData.count
                                          : qsTr("%1/%2").arg(row.modelData.matchCount).arg(row.modelData.count)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                }
                            }
                        }

                        Favicon {
                            id: favicon
                            visible: row.tabRow
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.s3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            host: row.modelData.host
                            fallbackText: row.modelData.fallback
                            backdrop: row.current ? Theme.accentSoft : Theme.glassMed
                        }

                        Column {
                            visible: row.tabRow
                            anchors.left: favicon.right
                            anchors.right: closeButton.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.s3
                            anchors.rightMargin: Theme.s2
                            spacing: 2

                            Text {
                                width: parent.width
                                text: row.modelData.title
                                color: row.current || row.selected ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: row.current ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                width: parent.width
                                text: row.modelData.url
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }

                        IconButton {
                            id: closeButton
                            visible: row.tabRow && opacity > 0.01
                            opacity: row.tabRow && (hover.hovered || row.selected || activeFocus) ? 1 : 0
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.s2
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "x"
                            size: 26
                            iconSize: 13
                            Accessible.name: qsTr("Закрыть вкладку")
                            onClicked: root.closeTab(row.modelData)
                            Behavior on opacity { OpacityAnimator { duration: Motion.fast; easing.type: Motion.standard } }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: query.text.trim().length > 0 ? qsTr("Вкладки не найдены")
                                                       : qsTr("Открытых вкладок нет")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
