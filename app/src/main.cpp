// Filka Browser — application entry point.
//
// Sets up the Qt Quick application, the WebEngine runtime and loads the QML
// shell (the Filka design-system UI). Native C++ browser models (tabs,
// workspaces, data) are registered here as the project grows.

#include <QGuiApplication>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QtWebEngineQuick>
#include <QWebEngineProfile>
#include <QWebEngineSettings>

#include "data/BrowsingData.h"

namespace {
QString writableOrFallback(QStandardPaths::StandardLocation location,
                           const QString &fallbackName)
{
    QString path = QStandardPaths::writableLocation(location);
    if (path.isEmpty())
        path = QDir::home().filePath(fallbackName);
    QDir().mkpath(path);
    return path;
}

QString safeDownloadDirectory()
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (path.isEmpty())
        path = QDir::home().filePath(QStringLiteral("Downloads"));
    if (!QDir().mkpath(path)) {
        path = writableOrFallback(QStandardPaths::AppDataLocation,
                                  QStringLiteral(".local/share/Filka"));
        path = QDir(path).filePath(QStringLiteral("Downloads"));
        QDir().mkpath(path);
    }
    return path;
}
}

int main(int argc, char *argv[])
{
#ifdef Q_OS_WIN
    qputenv("QTWEBENGINE_DISABLE_SANDBOX", "1");
#endif

    // --- Chromium tuning (must be set before WebEngine is initialised) ---
    // Comprehensive flags for smooth scrolling, GPU compositing, and
    // responsive heavy pages. Mirrors what premium Chromium-based browsers
    // (Brave, Arc, Edge) enable by default.
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_CHROMIUM_FLAGS")) {
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS",
                // GPU compositing — the single biggest factor for smooth scroll
                " --enable-gpu-compositing"
                " --enable-gpu-rasterization"
                " --enable-zero-copy"
                " --ignore-gpu-blocklist"
                " --disable-gpu-driver-bug-workarounds"
                // Smooth scrolling
                " --enable-smooth-scrolling"
                // V8 engine — larger heap for heavy pages
                " --js-flags=--max-old-space-size=4096"
                // Prevent renderer throttling that causes jank on heavy pages
                " --disable-renderer-backgrounding"
                " --disable-background-timer-throttling"
                " --disable-backgrounding-occluded-windows"
                // Feature flags MUST be one comma-list: Chromium keeps only the
                // last --enable-features=, so separate flags silently drop the
                // earlier ones. Merged here: DNS prefetch, SharedArrayBuffer,
                // back/forward cache (instant nav) and HW video decode.
                " --enable-features=UseDnsHttpsSvcb,SharedArrayBuffer,"
                "BackForwardCache,VaapiVideoDecodeLinuxGL,"
                "OverlayScrollbar,CanvasOopRasterization");
    }

    // High-refresh-rate friendly: let Qt pick the best swap behaviour and keep
    // GPU rendering on. Must be set before the QGuiApplication is constructed.
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    app.setOrganizationName("Filka");
    app.setApplicationName("Filka Browser");
    app.setApplicationVersion(QStringLiteral("3.1.1"));

    // Filka brand mark — used for the window/taskbar icon (the same asset is
    // bundled into the QML module for in-app branding).
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Filka/assets/logo.png")));

    // Basic style gives us unstyled controls we fully theme ourselves.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // --- Persistent browsing profile ---
    // Qt's default profile is off-the-record: it forgets cookies, logins and
    // cache the moment the app quits. A *named* profile owns an on-disk store,
    // so sessions (e.g. staying signed into Yandex/Google) survive restarts.
    // Exposed to QML as `filkaProfile` and shared by every tab's WebEngineView.
    const QString dataPath = writableOrFallback(QStandardPaths::AppDataLocation,
                                                QStringLiteral(".local/share/Filka"));
    const QString cachePath = writableOrFallback(QStandardPaths::CacheLocation,
                                                 QStringLiteral(".cache/Filka"));
    const QString downloadPath = safeDownloadDirectory();

    auto *profile = new QWebEngineProfile(QStringLiteral("filka"), &app);
    profile->setPersistentStoragePath(QDir(dataPath).filePath(QStringLiteral("webengine")));
    profile->setCachePath(QDir(cachePath).filePath(QStringLiteral("webengine")));
    profile->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);
    profile->setPersistentPermissionsPolicy(QWebEngineProfile::PersistentPermissionsPolicy::StoreOnDisk);
    profile->setHttpCacheType(QWebEngineProfile::DiskHttpCache);
    profile->setHttpCacheMaximumSize(256 * 1024 * 1024);
    profile->setDownloadPath(downloadPath);
    // Download handling is done in QML (WebEngineProfile.onDownloadRequested).

    auto *s = profile->settings();

    // Wheel scrolling responsiveness: Qt's ScrollAnimator adds a slow, springy
    // tween on top of Chromium's own smooth scrolling, which makes a single
    // wheel notch crawl. Leaving it off lets Chromium's native
    // `--enable-smooth-scrolling` (set above) drive a snappy, normal-paced feel.
    s->setAttribute(QWebEngineSettings::ScrollAnimatorEnabled, false);

    // DNS prefetch: resolve hostnames before the user clicks links.
    s->setAttribute(QWebEngineSettings::DnsPrefetchEnabled, true);

    // Local storage for web apps.
    s->setAttribute(QWebEngineSettings::LocalStorageEnabled, true);

    // Print backgrounds for correct page appearance.
    s->setAttribute(QWebEngineSettings::PrintElementBackgrounds, true);

    // Allow plugins (PDF viewer, etc.) and the built-in PDF viewer.
    s->setAttribute(QWebEngineSettings::PluginsEnabled, true);
    s->setAttribute(QWebEngineSettings::PdfViewerEnabled, true);

    // Let pages auto-load images and run JS (browser defaults made explicit).
    s->setAttribute(QWebEngineSettings::JavascriptEnabled, true);
    s->setAttribute(QWebEngineSettings::FullScreenSupportEnabled, true);
    s->setAttribute(QWebEngineSettings::ScreenCaptureEnabled, true);
    s->setAttribute(QWebEngineSettings::WebGLEnabled, true);

    QQmlApplicationEngine engine;
    auto *privacy = new BrowsingData(profile, &app);
    engine.rootContext()->setContextProperty(QStringLiteral("filkaPrivacy"), privacy);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    engine.loadFromModule("Filka", "Main");

    return app.exec();
}
