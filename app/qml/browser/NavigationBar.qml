pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Filka

// NavigationBar — the chrome toolbar that drives the active tab: history nav,
// reload/home, the address pill, bookmark + zoom, and the right-hand cluster of
// panel toggles. State lives on `browser` (BrowserView) and `shell`
// (ShellState); the panel cluster is data-driven so adding a panel is one entry.
Item {
    id: root

    required property var browser
    required property ShellState shell

    implicitHeight: Theme.toolbarHeight

    // Let the host pull keyboard focus into the address input (Ctrl+L / Ctrl+K).
    function focusAddress() { addressBar.focusInput() }

    // Resolve raw text (URL or search query) to a loadable URL. Shared by the
    // start page and bookmarks/history via BrowserView.navigate().
    function resolve(text) { return addressBar.resolve(text) }

    // Right-hand panel toggles. Each is a mutually-exclusive ShellState panel,
    // so a new panel only needs one row here (and one Loader in PanelHost).
    readonly property var panelButtons: [
        { icon: "history",   panel: "history",    name: "История" },
        { icon: "download",  panel: "downloads",  name: "Загрузки" },
        { icon: "languages", panel: "translator", name: "Переводчик" }
    ]

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        spacing: Theme.s2

        IconButton {
            iconName: "chevron-left"; size: Theme.controlMd
            enabled: root.browser.canGoBack
            opacity: enabled ? 1 : 0.4
            Accessible.name: qsTr("Назад")
            onClicked: root.browser.activeView.goBack()
        }
        IconButton {
            iconName: "chevron-right"; size: Theme.controlMd
            enabled: root.browser.canGoForward
            opacity: enabled ? 1 : 0.4
            Accessible.name: qsTr("Вперёд")
            onClicked: root.browser.activeView.goForward()
        }
        IconButton {
            iconName: root.browser.isLoading ? "x" : "rotate-cw"
            size: Theme.controlMd
            Accessible.name: root.browser.isLoading ? qsTr("Остановить") : qsTr("Обновить")
            onClicked: {
                if (!root.browser.activeView) return
                root.browser.isLoading ? root.browser.activeView.stop()
                                       : root.browser.activeView.reload()
            }
        }
        IconButton {
            iconName: "house"; size: Theme.controlMd
            Accessible.name: qsTr("Домой")
            onClicked: if (root.browser.activeView) root.browser.activeView.url = AppSettings.homePage
        }

        AddressBar {
            id: addressBar
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            displayUrl: root.browser.currentUrl
            secure: root.browser.isSecure
            loading: root.browser.isLoading
            progress: root.browser.loadProgress
            onNavigate: (text) => { if (root.browser.activeView) root.browser.activeView.url = text }
        }

        IconButton {
            iconName: "bookmark"; size: Theme.controlMd
            enabled: root.browser.currentUrl.length > 0
            opacity: enabled ? 1 : 0.4
            active: root.browser.bookmarked
            Accessible.name: qsTr("Закладка")
            onClicked: root.browser.toggleBookmark()
        }

        // Zoom badge — only while zoomed; tap resets to 100%. Expands/collapses
        // and fades so it doesn't just blink in when the zoom level changes.
        Pill {
            id: zoomPill
            readonly property bool shown: Math.abs(root.browser.zoomFactor - 1) > 0.01
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: shown ? implicitWidth : 0
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            clip: true
            onClicked: root.browser.resetZoom()
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }
            Text {
                text: Math.round(root.browser.zoomFactor * 100) + "%"
                color: Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.Medium
            }
        }

        IconButton {
            iconName: root.browser.verticalTabs ? "panel-left" : "panel-top"; size: Theme.controlMd
            Accessible.name: qsTr("Положение вкладок")
            onClicked: root.browser.verticalTabs = !root.browser.verticalTabs
        }

        Repeater {
            model: root.panelButtons
            delegate: IconButton {
                required property var modelData
                iconName: modelData.icon; size: Theme.controlMd
                active: root.shell.activePanel === modelData.panel
                Accessible.name: modelData.name
                onClicked: root.shell.togglePanel(modelData.panel)
            }
        }

        IconButton {
            iconName: Theme.dark ? "moon" : "sun"; size: Theme.controlMd
            Accessible.name: qsTr("Сменить тему")
            onClicked: AppSettings.darkMode = !AppSettings.darkMode
        }
        IconButton {
            iconName: "settings"; size: Theme.controlMd
            active: root.shell.activePanel === "settings"
            Accessible.name: qsTr("Настройки")
            onClicked: root.shell.togglePanel("settings")
        }
    }
}
