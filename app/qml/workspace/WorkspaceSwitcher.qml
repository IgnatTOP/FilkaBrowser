import QtQuick
import QtQuick.Controls.Basic
import Filka

// WorkspaceSwitcher — a row of workspace pills. The active pill expands to show
// its name and lights up with the workspace accent; others collapse to a glyph.
Item {
    id: root
    property var workspaces
    property int editIndex: -1
    implicitHeight: 42
    implicitWidth: pillRow.width + Theme.s2 * 2

    function openEditor(index, name) {
        editIndex = index
        nameField.text = name
        editor.open()
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    property var pendingRestore: null

    function requestWorkspaceRemoval(index) {
        if (!workspaces || !workspaces.workspaceUndoSnapshot || !workspaces.canRestoreWorkspace
                || !workspaces.removeWorkspaceIfRestorable)
            return

        var snapshot = workspaces.workspaceUndoSnapshot(index)
        if (!workspaces.canRestoreWorkspace(snapshot))
            return

        pendingRestore = snapshot
        if (workspaces.removeWorkspaceIfRestorable(index)) {
            undoToast.open()
            undoTimer.restart()
        } else {
            pendingRestore = null
        }
    }

    function undoWorkspaceRemoval() {
        if (!pendingRestore || !workspaces || !workspaces.restoreWorkspace)
            return
        undoTimer.stop()
        if (workspaces.restoreWorkspace(pendingRestore))
            pendingRestore = null
        undoToast.close()
    }

    function saveEditor() {
        var name = nameField.text.trim()
        if (name.length === 0)
            return
        if (editIndex >= 0)
            workspaces.renameWorkspace(editIndex, name)
        else
            workspaces.addWorkspace(name, "globe", Theme.accent)
        editor.close()
    }

    Row {
        id: pillRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.workspaces

            delegate: Rectangle {
                id: pill
                required property int index
                required property string name
                required property string glyph
                required property color accent

                readonly property bool active: index === root.workspaces.activeIndex

                height: 30
                width: active ? labelRow.implicitWidth + 22 : 30
                radius: Theme.radiusSm
                clip: true                       // keep the fading label inside
                color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.14)
                       : hover.hovered ? Theme.hoverFill : "transparent"
                border.width: activeFocus ? Theme.focusWidth : 1
                border.color: activeFocus ? Theme.focusRing : (active ? accent : "transparent")
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: pill.name

                Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                HoverHandler { id: hover }
                TapHandler { onTapped: root.workspaces.activeIndex = pill.index }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        menu.targetIndex = pill.index
                        menu.targetName = pill.name
                        menu.popup()
                    }
                }
                Keys.onReturnPressed: root.workspaces.activeIndex = pill.index
                Keys.onEnterPressed: root.workspaces.activeIndex = pill.index
                Keys.onSpacePressed: root.workspaces.activeIndex = pill.index

                Row {
                    id: labelRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: pill.glyph
                        size: 15
                        color: pill.active ? pill.accent : Theme.textSecondary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: opacity > 0.01
                        opacity: pill.active ? 1 : 0
                        text: pill.name
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.Medium
                        Behavior on opacity { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
                    }
                }
            }
        }

        Rectangle {
            width: 30
            height: 30
            radius: Theme.radiusSm
            color: addHover.hovered ? Theme.hoverFill : "transparent"
            border.width: activeFocus ? Theme.focusWidth : 1
            border.color: activeFocus ? Theme.focusRing : "transparent"
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Новое пространство")

            Icon {
                anchors.centerIn: parent
                name: "plus"
                size: 15
                color: addHover.hovered ? Theme.textPrimary : Theme.textSecondary
            }
            HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.openEditor(-1, "") }
            Keys.onReturnPressed: root.openEditor(-1, "")
            Keys.onEnterPressed: root.openEditor(-1, "")
            Keys.onSpacePressed: root.openEditor(-1, "")
        }
    }

    Menu {
        id: menu
        property int targetIndex: -1
        property string targetName: ""
        width: 190
        padding: 6
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.outline
        }
        MenuItem {
            text: qsTr("Переименовать")
            onTriggered: root.openEditor(menu.targetIndex, menu.targetName)
        }
        MenuItem {
            text: qsTr("Удалить")
            enabled: root.workspaces && root.workspaces.count > 1
                     && root.workspaces.canRestoreWorkspace
                     && root.workspaces.canRestoreWorkspace(root.workspaces.workspaceUndoSnapshot(menu.targetIndex))
            onTriggered: root.requestWorkspaceRemoval(menu.targetIndex)
        }
    }

    Popup {
        id: editor
        modal: true
        focus: true
        width: 260
        padding: Theme.s3
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.outline
        }
        contentItem: Column {
            spacing: Theme.s2
            Text {
                width: parent.width
                text: root.editIndex >= 0 ? qsTr("Переименовать") : qsTr("Новое пространство")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
            }
            TextField {
                id: nameField
                width: parent.width
                height: 38
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("Название")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: nameField.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: nameField.activeFocus ? Theme.accent : Theme.outline
                }
                onAccepted: root.saveEditor()
            }
            Pill {
                anchors.right: parent.right
                implicitHeight: 32
                fillColor: Theme.accent
                strokeWidth: 0
                onClicked: root.saveEditor()
                Text {
                    text: qsTr("Сохранить")
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }
        }
    }
    Timer {
        id: undoTimer
        interval: 7000
        repeat: false
        onTriggered: {
            root.pendingRestore = null
            undoToast.close()
        }
    }

    Popup {
        id: undoToast
        modal: false
        focus: false
        width: Math.min(360, Math.max(260, toastRow.implicitWidth + Theme.s4 * 2))
        height: 48
        x: Math.max(Theme.s2, root.width - width - Theme.s2)
        y: root.height + Theme.s2
        padding: Theme.s2
        closePolicy: Popup.NoAutoClose
        onClosed: undoTimer.stop()
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.outline
        }
        contentItem: Row {
            id: toastRow
            spacing: Theme.s2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.pendingRestore
                      ? qsTr("Пространство «%1» удалено (%n вкладка)", "", root.pendingRestore.tabs ? root.pendingRestore.tabs.length : 0)
                            .arg(root.pendingRestore.name)
                      : qsTr("Пространство удалено")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                elide: Text.ElideRight
                width: Math.min(230, implicitWidth)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Отменить")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold

                HoverHandler { id: undoHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.undoWorkspaceRemoval() }
            }
        }
    }
}
