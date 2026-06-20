import QtQuick
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// FindBar — in-page search (Ctrl+F). Lives in the chrome strip (never over the
// web view, which would punch through it) and drives the active view's findText.
// Animates open/closed by collapsing its height.
Item {
    id: root
    property var view: null
    property bool active: false
    signal closed()

    property int matchCount: 0
    property int activeMatch: 0
    property var previousView: null

    implicitHeight: active ? 44 : 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    function openBar() { field.forceActiveFocus(); field.selectAll() }
    function closeBar() {
        searchDebounce.stop()
        if (view)
            view.findText("")
        field.text = ""
        field.focus = false
        matchCount = 0
        activeMatch = 0
        if (view)
            view.forceActiveFocus()
        root.closed()
    }
    function findNext(backward) {
        if (!view || field.text.length === 0) { root.matchCount = 0; return }
        view.findText(field.text, backward ? WebEngineView.FindBackward : 0)
    }
    function findPreviousMatch() { findNext(true) }
    function findNextMatch() { findNext(false) }
    onViewChanged: {
        if (previousView && previousView !== view)
            previousView.findText("")
        previousView = view
        matchCount = 0
        activeMatch = 0
        if (active && view && field.text.length > 0)
            findNext(false)
    }

    Timer {
        id: searchDebounce
        interval: 150
        repeat: false
        onTriggered: root.findNext(false)
    }

    Connections {
        target: root.view
        function onFindTextFinished(result) {
            root.matchCount = result.numberOfMatches
            root.activeMatch = result.activeMatch
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.s3; rightMargin: Theme.s3 }
        height: 36
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1
        border.color: field.activeFocus ? Theme.accent : Theme.outline

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s2
            spacing: Theme.s2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"; size: 15; color: Theme.textMuted
            }
            TextField {
                id: field
                width: 320
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                background: null
                placeholderText: qsTr("Поиск на странице")
                placeholderTextColor: Theme.textMuted
                onTextChanged: {
                    searchDebounce.stop()
                    if (text.length === 0) {
                        root.matchCount = 0
                        root.activeMatch = 0
                        return
                    }
                    searchDebounce.restart()
                }
                onAccepted: {
                    searchDebounce.stop()
                    root.findNext(false)
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        searchDebounce.stop()
                        if (event.modifiers & Qt.ShiftModifier)
                            root.findPreviousMatch()
                        else
                            root.findNextMatch()
                        event.accepted = true
                    }
                }
                }
                Keys.onEscapePressed: root.closeBar()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.matchCount > 0 ? (root.activeMatch + "/" + root.matchCount)
                                          : (field.text.length ? qsTr("нет совпадений") : "")
                color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.s1 }
            spacing: 0
            IconButton { iconName: "chevron-left";  size: 30; Accessible.name: qsTr("Назад");   onClicked: { searchDebounce.stop(); root.findPreviousMatch() } }
            IconButton { iconName: "chevron-right"; size: 30; Accessible.name: qsTr("Вперёд");  onClicked: { searchDebounce.stop(); root.findNextMatch() } }
            IconButton { iconName: "x";             size: 30; Accessible.name: qsTr("Закрыть"); onClicked: root.closeBar() }
        }
    }
}
