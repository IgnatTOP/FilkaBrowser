import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtWebEngine
import Filka

// BrowserWindow — one top-level Filka window: the frameless, translucent shell
// with the animated "aurora glass" backdrop and a full BrowserView inside. The
// primary window is created by Main; Ctrl+N spawns more via openNewWindow(),
// each with its own workspaces/tabs but sharing the persistent profile.
ApplicationWindow {
    id: appWindow
    width: 1280
    height: 820
    minimumWidth: 880
    minimumHeight: 560
    visible: true
    title: "Filka Browser"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    // Spawn another independent browser window (Ctrl+N / menu). The new window
    // is created visible (its `visible: true` default), so we only need to
    // instantiate it; it owns its own tabs/workspaces and shares the profile.
    function openNewWindow() {
        var comp = Qt.createComponent("qrc:/qt/qml/Filka/BrowserWindow.qml")
        if (comp.status === Component.Error)
            console.warn("Filka: cannot open new window:", comp.errorString())
        else
            comp.createObject(null)
    }

    // Persistent named profile — replaces the C++ QWebEngineProfile* context
    // property which can't be assigned to WebEngineView.profile in Qt 6.7+.
    WebEngineProfile {
        id: filkaProfile
        storageName: "filka"
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        persistentPermissionsPolicy: WebEngineProfile.StoreOnDisk
        httpCacheType: WebEngineProfile.DiskHttpCache
        httpCacheMaximumSize: 256 * 1024 * 1024
    }

    // Theme mirrors the persisted preferences; AppSettings is the source of truth.
    Component.onCompleted: {
        Theme.dark = AppSettings.darkMode
        // One-time rebrand migration: installs that still carry the legacy
        // electric-blue default get moved to the new signature coral so the
        // sunset identity lands cohesively. Deliberately-chosen accents stay.
        if (AppSettings.accentColor.toLowerCase() === "#2e7cf6")
            AppSettings.accentColor = "#FF6A4D"
        Theme.accent = AppSettings.accentColor
    }
    Connections {
        target: AppSettings
        function onDarkModeChanged() { Theme.dark = AppSettings.darkMode }
        function onAccentColorChanged() { Theme.accent = AppSettings.accentColor }
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

        // ---- Animated aurora backdrop (blurred drifting accent blobs) ----
        Item {
            id: aurora
            anchors.fill: parent
            // Only alive on the start page (and when the user keeps it on):
            // while a real page is shown the web view covers it anyway, so
            // rendering/animating it just steals GPU from scroll compositing.
            visible: browser.atHome && AppSettings.startPageAurora
            // Render the blurred blobs into a half-resolution cached texture.
            // The blur is visually identical at half-res but costs ~4x less GPU
            // each frame, so it never competes with WebEngine scroll compositing.
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(body.width / 2), Math.ceil(body.height / 2))
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 40
                saturation: 0.2
            }

            Repeater {
                model: [
                    { c: Theme.ember,  x0: 0.12, y0: 0.10, d: 9000,  s: 0.62 },
                    { c: Theme.coral,  x0: 0.70, y0: 0.05, d: 11000, s: 0.74 },
                    { c: Theme.violet, x0: 0.50, y0: 0.65, d: 13000, s: 0.56 }
                ]
                delegate: Rectangle {
                    id: blob
                    required property var modelData
                    width: body.width * modelData.s
                    height: width
                    radius: width / 2
                    color: modelData.c
                    opacity: Theme.dark ? 0.42 : 0.30

                    property real baseX: body.width * modelData.x0
                    property real baseY: body.height * modelData.y0
                    x: baseX
                    y: baseY

                    SequentialAnimation {
                        loops: Animation.Infinite
                        running: aurora.visible
                        ParallelAnimation {
                            NumberAnimation { target: blob; property: "x"; to: blob.baseX + body.width * 0.18; duration: modelData.d; easing.type: Easing.InOutSine }
                            NumberAnimation { target: blob; property: "y"; to: blob.baseY + body.height * 0.16; duration: modelData.d * 1.3; easing.type: Easing.InOutSine }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: blob; property: "x"; to: blob.baseX; duration: modelData.d; easing.type: Easing.InOutSine }
                            NumberAnimation { target: blob; property: "y"; to: blob.baseY; duration: modelData.d * 1.3; easing.type: Easing.InOutSine }
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: Motion.slow } }
                }
            }
        }

        // Darkening veil so foreground text stays readable over the aurora.
        Rectangle {
            anchors.fill: parent
            color: Theme.bgBase
            opacity: Theme.dark ? 0.40 : 0.30
        }

        // ---- Foreground layout ----
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            WindowChrome {
                id: chrome
                target: appWindow
                visible: !browser.fullScreen
                Layout.fillWidth: true

                leftContent: Row {
                    spacing: Theme.s2
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        width: 30; height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/qt/qml/Filka/assets/logo.png"
                        sourceSize: Qt.size(60, 60)   // crisp on HiDPI
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        text: "Filka"
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXl
                        font.weight: Font.DemiBold
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
                profile: filkaProfile
                Layout.fillWidth: true
                Layout.fillHeight: true
                onFullScreenChanged: fullScreen ? appWindow.showFullScreen()
                                                : appWindow.showNormal()
                onNewWindowRequested: appWindow.openNewWindow()
            }
        }

        // Resize grip (bottom-right corner) for the frameless window.
        Item {
            id: gripZone
            width: 18; height: 18
            anchors { right: parent.right; bottom: parent.bottom }
            visible: appWindow.visibility !== Window.Maximized

            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                cursorShape: Qt.SizeFDiagCursor
                onActiveChanged: if (active) appWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
            }
        }

        // First-run onboarding — created only until the user finishes it.
        Loader {
            anchors.fill: parent
            active: !AppSettings.onboarded
            sourceComponent: WelcomeDialog {}
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
}
