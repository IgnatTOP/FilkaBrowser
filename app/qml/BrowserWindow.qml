import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// BrowserWindow — one top-level Filka window: a frameless translucent shell with
// a premium wallpaper home surface and a full BrowserView inside. Ctrl+N spawns
// more independent windows; private windows use an off-the-record profile.
ApplicationWindow {
    id: appWindow
    property bool privateMode: false
    property var sharedProfile: null
    property var windowManager: null
    property alias browserView: browser
    property int visibilityBeforeFullScreen: Window.Windowed
    width: 1280
    height: 820
    minimumWidth: 880
    minimumHeight: 560
    visible: true
    title: privateMode ? qsTr("Приватное окно — Filka Browser") : qsTr("Filka Browser")
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    function openNewWindow(privateWindow, initialUrl) {
        if (windowManager)
            windowManager.openWindow(privateWindow === true, initialUrl || "")
    }

    onClosing: function(close) {
        if (windowManager) {
            close.accepted = false
            windowManager.closeWindow(appWindow)
        }
    }

    WebEngineProfile {
        id: privateProfile
        storageName: ""
        offTheRecord: true
        persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies
        persistentPermissionsPolicy: WebEngineProfile.AskEveryTime
        httpCacheType: WebEngineProfile.MemoryHttpCache
        httpCacheMaximumSize: 0
        downloadPath: AppSettings.downloadPath
        httpAcceptLanguage: Qt.locale().name.replace("_", "-")
        httpUserAgent: Qt.platform.os === "windows"
                       ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
                       : "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        spellCheckEnabled: false
    }

    // Theme mirrors the persisted preferences; AppSettings is the source of truth.
    Component.onCompleted: {
        Theme.dark = AppSettings.darkMode
        Motion.reducedMotion = AppSettings.reducedMotion
        // One-time rebrand migration: legacy defaults move to the Filka violet
        // identity. Deliberately-chosen custom accents stay as-is.
        var accent = AppSettings.accentColor.toLowerCase()
        if (accent === "#2e7cf6" || accent === "#ff6a4d")
            AppSettings.accentColor = "#8B5CF6"
        Theme.accent = AppSettings.accentColor
        AdBlockManager.attachProfile(appWindow.privateMode || !appWindow.sharedProfile
                                     ? privateProfile : appWindow.sharedProfile)
    }
    Connections {
        target: AppSettings
        function onDarkModeChanged() { Theme.dark = AppSettings.darkMode }
        function onAccentColorChanged() { Theme.accent = AppSettings.accentColor }
        function onReducedMotionChanged() { Motion.reducedMotion = AppSettings.reducedMotion }
    }

    // Outer rounded glass body.
    Rectangle {
        id: body
        anchors.fill: parent
        readonly property bool edgeToEdge: appWindow.visibility === Window.Maximized
                                           || appWindow.visibility === Window.FullScreen
        anchors.margins: edgeToEdge ? 0 : 10
        radius: edgeToEdge ? 0 : Theme.radiusXl
        color: Theme.bgBase
        clip: true
        border.width: 1
        border.color: Theme.glassHairline
        Behavior on color { ColorAnimation { duration: Motion.slow; easing.type: Motion.standard } }

        // Aurora backdrop stays on for every page (not just the start page) so
        // the translucent sidebar/chrome keep their frosted-glass look while the
        // rounded web card floats on top of it.
        WallpaperBackdrop {
            anchors.fill: parent
            preset: AppSettings.wallpaperPreset
            opacity: AppSettings.startPageAurora ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.standard } }
        }

        // ---- Foreground layout ----
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            WindowChrome {
                id: chrome
                target: appWindow
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: 0

                leftContent: Row {
                    spacing: Theme.s2
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        width: 24; height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/qt/qml/Filka/assets/logo.png"
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        text: "Filka"
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: appWindow.privateMode
                        anchors.verticalCenter: parent.verticalCenter
                        width: privateText.implicitWidth + Theme.s3
                        height: 24
                        radius: Theme.radiusPill
                        color: Theme.activeFill
                        border.width: 1
                        border.color: Theme.accent
                        Text {
                            id: privateText
                            anchors.centerIn: parent
                            text: qsTr("Приватно")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            // Auto-update banner — slides in below the chrome when a newer
            // release is found, so it's the first thing the user sees.
            UpdateBanner {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s3
                Layout.rightMargin: Theme.s3
                Layout.topMargin: visible ? Theme.s2 : 0
            }

            // Browsing surface (M2): navigation toolbar + Qt WebEngine view.
            BrowserView {
                id: browser
                profile: appWindow.privateMode || !appWindow.sharedProfile
                         ? privateProfile : appWindow.sharedProfile
                privateMode: appWindow.privateMode
                handleProfileDownloads: appWindow.privateMode || !appWindow.sharedProfile
                windowTarget: appWindow
                Layout.fillWidth: true
                Layout.fillHeight: true
                onFullScreenChanged: {
                    if (fullScreen) {
                        appWindow.visibilityBeforeFullScreen = appWindow.visibility
                        appWindow.showFullScreen()
                    } else if (appWindow.visibilityBeforeFullScreen === Window.Maximized) {
                        appWindow.showMaximized()
                    } else {
                        appWindow.showNormal()
                    }
                }
                onNewWindowRequested: (initialUrl) => appWindow.openNewWindow(false, initialUrl)
                onNewPrivateWindowRequested: appWindow.openNewWindow(true)
            }
        }

        // First-run onboarding — created only until the user finishes it.
        Loader {
            id: welcomeLoader
            anchors.fill: parent
            active: !AppSettings.onboarded
            sourceComponent: WelcomeDialog {}
            onStatusChanged: if (status === Loader.Error)
                console.warn("Filka: cannot load welcome dialog", errorString())
        }

        // Check for updates shortly after launch (non-blocking).
        Timer {
            id: updateTimer
            interval: 3000
            running: true
            repeat: false
            onTriggered: UpdateChecker.checkForUpdates()
        }
    }

    readonly property bool resizeZonesEnabled: appWindow.visibility !== Window.Maximized
                                               && appWindow.visibility !== Window.FullScreen

    Item {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 8
        z: 1000
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeHorCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.LeftEdge)
        }
    }
    Item {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 8
        z: 1000
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeHorCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.RightEdge)
        }
    }
    Item {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 8
        z: 1000
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeVerCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.TopEdge)
        }
    }
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 8
        z: 1000
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeVerCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.BottomEdge)
        }
    }
    Item {
        anchors { left: parent.left; top: parent.top }
        width: 18; height: 18
        z: 1001
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
        }
    }
    Item {
        anchors { right: parent.right; top: parent.top }
        width: 18; height: 18
        z: 1001
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeBDiagCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.RightEdge | Qt.TopEdge)
        }
    }
    Item {
        anchors { left: parent.left; bottom: parent.bottom }
        width: 18; height: 18
        z: 1001
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeBDiagCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
        }
    }
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 18; height: 18
        z: 1001
        visible: appWindow.resizeZonesEnabled
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: if (active) appWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }
}
