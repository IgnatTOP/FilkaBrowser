pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// StartPage — Filka's welcome / new-tab surface, shown (in place of a web view)
// whenever the active tab sits on the "about:blank" home sentinel. A bento
// dashboard floating over the animated sunset backdrop: a live clock tile, a
// 2×2 speed-dial, a hero search field, and live "recent" / "bookmarks" cards
// fed from the shared history and bookmark models. Emits `navigate` with raw
// user text or a URL.
Item {
    id: root
    signal navigate(string text)

    // Curated speed-dial. Each tile shows the site's real favicon (see Favicon),
    // falling back to the first letter of the name when offline.
    readonly property var quickLinks: [
        { name: "YouTube",   url: "https://youtube.com" },
        { name: "GitHub",    url: "https://github.com" },
        { name: "Reddit",    url: "https://reddit.com" },
        { name: "Wikipedia", url: "https://wikipedia.org" }
    ]

    // Strip scheme / www / path down to a readable host label.
    function hostOf(u) {
        var s = ("" + u).replace(/^[a-z]+:\/\//i, "").replace(/^www\./i, "")
        var slash = s.indexOf("/")
        return slash >= 0 ? s.slice(0, slash) : s
    }

    // ---- Live clock + greeting ----
    readonly property var _loc: Qt.locale("ru_RU")
    property string timeText: ""
    property string dateText: ""
    property string greeting: ""
    function refreshClock() {
        const now = new Date()
        timeText = now.toLocaleTimeString(root._loc, "HH:mm")
        const d = now.toLocaleDateString(root._loc, "dddd, d MMMM")
        dateText = d.charAt(0).toUpperCase() + d.slice(1)
        const h = now.getHours()
        greeting = h < 5  ? qsTr("Доброй ночи")
                 : h < 12 ? qsTr("Доброе утро")
                 : h < 18 ? qsTr("Добрый день")
                 : h < 23 ? qsTr("Добрый вечер")
                          : qsTr("Доброй ночи")
    }
    Timer {
        interval: 1000; repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshClock()
    }

    // Soft fade/rise entrance whenever the start page appears (one subtree, GPU).
    Component.onCompleted: showAnim.start()
    onVisibleChanged: if (visible) showAnim.restart()

    Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, bento.implicitHeight + Theme.s7 * 2)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        GridLayout {
            id: bento
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(Theme.s7, (scroller.height - implicitHeight) / 2)
            width: Math.min(940, scroller.width - Theme.s5 * 2)
            columns: 4
            rowSpacing: Theme.s4
            columnSpacing: Theme.s4

            opacity: 0
            transform: Translate { id: rise; y: 24 }
            ParallelAnimation {
                id: showAnim
                OpacityAnimator { target: bento; from: 0; to: 1; duration: Motion.slow; easing.type: Motion.standard }
                NumberAnimation { target: rise; property: "y"; from: 24; to: 0; duration: Motion.slow; easing.type: Motion.emphasized }
            }

            // ===== Clock tile (2×2) =====
            Rectangle {
                Layout.columnSpan: 2
                Layout.rowSpan: 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 208
                radius: Theme.radiusXl
                color: Theme.glassLow
                border.width: 1
                border.color: Theme.glassStroke
                clip: true

                // Faint accent glow for warmth / depth (top-right).
                Rectangle {
                    width: 260; height: 260; radius: 130
                    anchors { right: parent.right; top: parent.top; rightMargin: -70; topMargin: -90 }
                    color: Theme.accent
                    opacity: 0.16
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s5
                    spacing: 0

                    Text {
                        text: root.greeting
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Medium
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: root.timeText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeDisplay
                        font.weight: Font.Light
                    }
                    Text {
                        Layout.topMargin: Theme.s1
                        text: root.dateText
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }
            }

            // ===== Speed-dial tiles (fill the 2×2 area beside the clock) =====
            Repeater {
                model: root.quickLinks
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 96
                    radius: Theme.radiusLg
                    color: tileHover.hovered ? Theme.glassMed : Theme.glassLow
                    border.width: tile.activeFocus ? Theme.focusWidth : 1
                    border.color: tile.activeFocus ? Theme.focusRing
                                  : tileHover.hovered ? Theme.accent : Theme.glassStroke
                    activeFocusOnTab: true
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    transform: Translate {
                        y: tileHover.hovered ? -3 : 0
                        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.s2

                        Favicon {
                            width: 44; height: 44; radius: Theme.radiusMd
                            anchors.horizontalCenter: parent.horizontalCenter
                            host: root.hostOf(tile.modelData.url)
                            fallbackText: tile.modelData.name.charAt(0)
                            scale: tileHover.hovered ? 1.07 : 1.0
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.name
                            color: tileHover.hovered ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Medium
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                    }

                    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.navigate(tile.modelData.url) }
                    Keys.onReturnPressed: root.navigate(tile.modelData.url)
                    Keys.onEnterPressed: root.navigate(tile.modelData.url)
                    Keys.onSpacePressed: root.navigate(tile.modelData.url)
                    Accessible.role: Accessible.Button
                    Accessible.name: tile.modelData.name
                }
            }

            // ===== Hero search / address field (full width) =====
            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: Theme.radiusPill
                color: search.activeFocus ? Theme.glassHigh : Theme.glassMed
                border.width: search.activeFocus ? 1.5 : 1
                border.color: search.activeFocus ? Theme.accent : Theme.glassStroke
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Rectangle {   // accent focus glow
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: Theme.radiusPill
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: search.activeFocus ? 0.28 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: Theme.s5; verticalCenter: parent.verticalCenter }
                    name: "search"; size: 19
                    color: search.activeFocus ? Theme.accent : Theme.textMuted
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                TextField {
                    id: search
                    anchors { left: searchIcon.right; right: goBtn.left; verticalCenter: parent.verticalCenter
                              leftMargin: Theme.s3; rightMargin: Theme.s2 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    selectByMouse: true
                    background: null
                    placeholderText: qsTr("Поиск или адрес сайта")
                    placeholderTextColor: Theme.textMuted
                    Accessible.name: qsTr("Поиск или адрес")
                    onAccepted: { if (text.trim().length) { root.navigate(text); text = "" } }
                }
                IconButton {
                    id: goBtn
                    anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                    visible: search.text.trim().length > 0
                    iconName: "chevron-right"; size: Theme.controlLg
                    active: true
                    Accessible.name: qsTr("Перейти")
                    onClicked: { if (search.text.trim().length) { root.navigate(search.text); search.text = "" } }
                }
            }

            // ===== Recent (history) =====
            ListCard {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 184
                iconName: "history"
                title: qsTr("Недавнее")
                emptyText: qsTr("История пуста")
                listModel: HistoryModel
                onActivated: (url) => root.navigate(url)
                hostFn: root.hostOf
            }

            // ===== Bookmarks =====
            ListCard {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 184
                iconName: "bookmark"
                title: qsTr("Закладки")
                emptyText: qsTr("Нет закладок")
                listModel: BookmarkModel
                onActivated: (url) => root.navigate(url)
                hostFn: root.hostOf
            }
        }
    }
}
