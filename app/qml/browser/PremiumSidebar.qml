pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// PremiumSidebar — the content rail. Its single job is navigating *content*:
// workspaces, the vertical tab list and a compact tool dock at the bottom.
// Per-page controls (address, back/forward, page actions) live in the page bar
// (NavigationBar), so the sidebar stays calm and free of duplicates.
Item {
    id: root

    required property var browser
    required property var workspaces
    required property ShellState shell
    property var windowTarget: null
    property int editIndex: -1

    function openWorkspaceEditor(index, name) {
        editIndex = index
        workspaceName.text = name
        workspaceEditor.open()
        workspaceName.forceActiveFocus()
        workspaceName.selectAll()
    }

    function saveWorkspace() {
        var name = workspaceName.text.trim()
        if (name.length === 0)
            return
        if (editIndex >= 0)
            workspaces.renameWorkspace(editIndex, name)
        else
            workspaces.addWorkspace(name, "briefcase", Theme.brandViolet)
        workspaceEditor.close()
    }

    component NavRow: Rectangle {
        id: row
        property string label: ""
        property string iconName: "globe"
        property color accent: Theme.accent
        property bool selected: false
        signal triggered()

        implicitHeight: 36
        radius: Theme.radiusMd
        color: selected ? Theme.activeFill : (hover.hovered ? Theme.hoverFill : "transparent")
        border.width: activeFocus ? Theme.focusWidth : (selected ? 1 : 0)
        border.color: activeFocus ? Theme.focusRing : (selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.42)
                                                               : "transparent")
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s3
            spacing: Theme.s2

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusSm
                color: selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
                                : Qt.rgba(1, 1, 1, 0.060)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.080)

                Icon {
                    anchors.centerIn: parent
                    name: row.iconName
                    size: 13
                    color: row.selected ? row.accent : Theme.textSecondary
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: row.label
                color: row.selected ? Theme.textPrimary
                                    : (hover.hovered ? Theme.textPrimary : Theme.textSecondary)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: row.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.triggered() }
        Keys.onReturnPressed: row.triggered()
        Keys.onEnterPressed: row.triggered()
        Keys.onSpacePressed: row.triggered()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.wallpaperSidebar
        border.width: 0

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Theme.glassHairline
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height * 0.34
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.085) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s3
        spacing: 7

        // ===== Header: window controls + brand + new window =====
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 62

            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active && root.windowTarget) root.windowTarget.startSystemMove()
            }
            TapHandler {
                gesturePolicy: TapHandler.DragThreshold
                onDoubleTapped: {
                    if (!root.windowTarget)
                        return
                    root.windowTarget.visibility === Window.Maximized
                        ? root.windowTarget.showNormal() : root.windowTarget.showMaximized()
                }
            }

            WindowControls {
                anchors { left: parent.left; top: parent.top; topMargin: 2 }
                target: root.windowTarget
            }

            Text {
                anchors { left: parent.left; leftMargin: 2; bottom: parent.bottom; bottomMargin: 3 }
                text: "Filka"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }

            IconButton {
                anchors { right: parent.right; bottom: parent.bottom }
                iconName: "plus"
                size: 28
                iconSize: 14
                tooltip: qsTr("Новое окно")
                Accessible.name: qsTr("Новое окно")
                onClicked: root.browser.newWindow()
            }
        }

        // ===== Workspaces =====
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s2
            spacing: Theme.s2
            Text {
                Layout.fillWidth: true
                text: qsTr("Пространства")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold
            }
            IconButton {
                iconName: "plus"
                size: 28
                iconSize: 14
                tooltip: qsTr("Новое пространство")
                Accessible.name: qsTr("Новое пространство")
                onClicked: root.openWorkspaceEditor(-1, "")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.workspaces
                delegate: NavRow {
                    required property int index
                    required property var model
                    Layout.fillWidth: true
                    label: model.name
                    iconName: model.glyph
                    selected: index === root.workspaces.activeIndex
                    accent: model.accent
                    onTriggered: root.workspaces.activeIndex = index

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            workspaceMenu.targetIndex = index
                            workspaceMenu.targetName = model.name
                            workspaceMenu.popup()
                        }
                    }
                }
            }
        }

        // ===== Tabs (vertical layout only) =====
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s3
            spacing: Theme.s2
            visible: root.browser.verticalTabs
            Text {
                Layout.fillWidth: true
                text: qsTr("Вкладки")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold
            }
            IconButton {
                iconName: "plus"
                size: 28
                iconSize: 14
                tooltip: qsTr("Новая вкладка")
                Accessible.name: qsTr("Новая вкладка")
                onClicked: root.browser.newTab()
            }
        }

        TabStrip {
            Layout.fillWidth: true
            Layout.fillHeight: root.browser.verticalTabs
            visible: root.browser.verticalTabs
            tabs: root.workspaces.activeTabs
            workspaceModel: root.workspaces
            vertical: true
            onScreenshotRequested: (tabIndex) => root.browser.screenshotTab(tabIndex)
        }

        // Spacer to push the dock down when tabs live on top.
        Item {
            Layout.fillHeight: !root.browser.verticalTabs
            visible: !root.browser.verticalTabs
        }

        // ===== Tool dock: destinations + profile =====
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s2
            Layout.preferredHeight: 44
            spacing: Theme.s1

            IconButton {
                iconName: "history"
                size: 34
                iconSize: 16
                active: root.shell.activePanel === "history"
                tooltip: qsTr("История")
                Accessible.name: qsTr("История")
                onClicked: root.shell.togglePanel("history")
            }
            IconButton {
                iconName: "download"
                size: 34
                iconSize: 16
                active: root.shell.activePanel === "downloads"
                tooltip: qsTr("Загрузки")
                Accessible.name: qsTr("Загрузки")
                onClicked: root.shell.togglePanel("downloads")
            }
            IconButton {
                iconName: "bookmark"
                size: 34
                iconSize: 16
                active: root.shell.activePanel === "bookmarks"
                tooltip: qsTr("Закладки")
                Accessible.name: qsTr("Закладки")
                onClicked: root.shell.togglePanel("bookmarks")
            }
            IconButton {
                iconName: "settings"
                size: 34
                iconSize: 16
                active: root.shell.activePanel === "settings"
                tooltip: qsTr("Настройки")
                Accessible.name: qsTr("Настройки")
                onClicked: root.shell.togglePanel("settings")
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
                Text {
                    anchors.centerIn: parent
                    text: AppSettings.displayName.length > 0 ? AppSettings.displayName.charAt(0).toUpperCase() : "F"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Menu {
        id: workspaceMenu
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
            onTriggered: root.openWorkspaceEditor(workspaceMenu.targetIndex, workspaceMenu.targetName)
        }
        MenuItem {
            text: qsTr("Удалить")
            enabled: root.workspaces && root.workspaces.count > 1
            onTriggered: root.workspaces.removeWorkspace(workspaceMenu.targetIndex)
        }
    }

    Popup {
        id: workspaceEditor
        modal: true
        focus: true
        x: Theme.s3
        y: 142
        width: root.width - Theme.s6
        padding: Theme.s3
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: Theme.radiusLg
            color: Theme.modalSurface
            border.width: 1
            border.color: Theme.outline
        }
        contentItem: ColumnLayout {
            spacing: Theme.s2
            Text {
                Layout.fillWidth: true
                text: root.editIndex >= 0 ? qsTr("Переименовать") : qsTr("Новое пространство")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
            }
            TextField {
                id: workspaceName
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("Название")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: workspaceName.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: workspaceName.activeFocus ? Theme.accent : Theme.outline
                }
                onAccepted: root.saveWorkspace()
            }
            Pill {
                Layout.alignment: Qt.AlignRight
                implicitHeight: 32
                accessibleName: qsTr("Сохранить пространство")
                fillColor: Theme.accent
                strokeWidth: 0
                onClicked: root.saveWorkspace()
                Text {
                    text: qsTr("Сохранить")
                    color: Theme.accentForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
