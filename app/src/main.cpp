// Filka Browser — application entry point.
//
// Sets up the Qt Quick application, the WebEngine runtime and loads the QML
// shell (the Filka design-system UI). Native C++ browser models (tabs,
// workspaces, data) are registered here as the project grows.

#include <QGuiApplication>
#include <QCoreApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtWebEngineQuick>

#ifndef FILKA_VERSION
#define FILKA_VERSION "0.0.0"
#endif

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
    app.setApplicationVersion(QStringLiteral(FILKA_VERSION));

    // Filka brand mark — used for the window/taskbar icon (the same asset is
    // bundled into the QML module for in-app branding).
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Filka/assets/logo.png")));

    // Basic style gives us unstyled controls we fully theme ourselves.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    engine.loadFromModule("Filka", "Main");

    return app.exec();
}
