// Filka Browser — application entry point.
//
// Sets up the Qt Quick application, the WebEngine runtime and loads the QML
// shell (the Filka design-system UI). Native C++ browser models (tabs,
// workspaces, data) are registered here as the project grows.

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QMutex>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QSysInfo>
#include <QtWebEngineQuick>

#include <cstdio>
#include <cstdlib>

#ifndef FILKA_VERSION
#define FILKA_VERSION "0.0.0"
#endif

namespace {

constexpr qint64 kMaxLogFileSize = 4 * 1024 * 1024;

QMutex gLogMutex;
QFile *gLogFile = nullptr;
QString gLogPath;

const char *messageTypeName(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return "debug";
    case QtInfoMsg:
        return "info";
    case QtWarningMsg:
        return "warning";
    case QtCriticalMsg:
        return "critical";
    case QtFatalMsg:
        return "fatal";
    }
    return "unknown";
}

QString logDirectory()
{
    const QString configured = qEnvironmentVariable("FILKA_LOG_DIR").trimmed();
    if (!configured.isEmpty())
        return configured;

    QString location = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (location.isEmpty()) {
#ifdef Q_OS_WIN
        location = QDir::home().filePath(QStringLiteral("AppData/Local/Filka/Filka Browser"));
#else
        location = QDir::home().filePath(QStringLiteral(".local/share/Filka/Filka Browser"));
#endif
    }
    return QDir(location).filePath(QStringLiteral("logs"));
}

void rotateLogFile(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists() || info.size() <= kMaxLogFileSize)
        return;

    QFile::remove(path + QStringLiteral(".1"));
    QFile::rename(path, path + QStringLiteral(".1"));
}

void filkaMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    QString source;
    if (context.file && context.line > 0) {
        source = QStringLiteral(" (%1:%2)")
                     .arg(QString::fromUtf8(context.file))
                     .arg(context.line);
    }

    const QString category = QString::fromUtf8(context.category ? context.category : "default");
    const QString line = QStringLiteral("%1 [%2] %3: %4%5")
                             .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs))
                             .arg(QString::fromLatin1(messageTypeName(type)))
                             .arg(category)
                             .arg(message)
                             .arg(source);
    const QByteArray bytes = line.toUtf8();

    {
        QMutexLocker locker(&gLogMutex);
        if (gLogFile && gLogFile->isOpen()) {
            gLogFile->write(bytes);
            gLogFile->write("\n");
            gLogFile->flush();
        }
    }

    std::fprintf(stderr, "%s\n", bytes.constData());
    std::fflush(stderr);

    if (type == QtFatalMsg)
        std::abort();
}

void installFileLogging()
{
    const QString dirPath = logDirectory();
    if (!QDir().mkpath(dirPath)) {
        std::fprintf(stderr, "Filka logging: cannot create log directory: %s\n",
                     qPrintable(QDir::toNativeSeparators(dirPath)));
        std::fflush(stderr);
        return;
    }

    gLogPath = QDir(dirPath).filePath(QStringLiteral("filka.log"));
    rotateLogFile(gLogPath);

    gLogFile = new QFile(gLogPath);
    if (!gLogFile->open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        std::fprintf(stderr, "Filka logging: cannot open log file: %s\n",
                     qPrintable(QDir::toNativeSeparators(gLogPath)));
        std::fflush(stderr);
        delete gLogFile;
        gLogFile = nullptr;
        return;
    }

    qInstallMessageHandler(filkaMessageHandler);
    qInfo().noquote() << "File logging started:" << QDir::toNativeSeparators(gLogPath);
}


constexpr auto kPendingCleanupKey = "privacy/pendingWebEngineProfileCleanup";
constexpr auto kPendingCleanupPathsKey = "privacy/pendingWebEngineProfileCleanupPaths";

void performPendingBrowsingDataCleanup()
{
    QSettings store;
    if (!store.value(QString::fromLatin1(kPendingCleanupKey), false).toBool())
        return;

    const QStringList paths = store.value(QString::fromLatin1(kPendingCleanupPathsKey)).toStringList();
    bool allRemoved = true;
    for (const QString &path : paths) {
        const QString cleaned = QDir::cleanPath(path);
        if (cleaned.isEmpty())
            continue;

        QDir dir(cleaned);
        if (!dir.exists())
            continue;

        if (!dir.removeRecursively()) {
            allRemoved = false;
            qWarning().noquote() << "Filka: deferred WebEngine cleanup could not remove"
                               << QDir::toNativeSeparators(cleaned);
        } else {
            qInfo().noquote() << "Filka: deferred WebEngine cleanup removed"
                              << QDir::toNativeSeparators(cleaned);
        }
    }

    if (allRemoved) {
        store.remove(QString::fromLatin1(kPendingCleanupKey));
        store.remove(QString::fromLatin1(kPendingCleanupPathsKey));
    } else {
        store.setValue(QString::fromLatin1(kPendingCleanupKey), true);
    }
    store.sync();
}

void shutdownFileLogging()
{
    qInstallMessageHandler(nullptr);

    QMutexLocker locker(&gLogMutex);
    if (gLogFile) {
        gLogFile->flush();
        gLogFile->close();
        delete gLogFile;
        gLogFile = nullptr;
    }
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("Filka"));
    QCoreApplication::setApplicationName(QStringLiteral("Filka Browser"));
    QCoreApplication::setApplicationVersion(QStringLiteral(FILKA_VERSION));
    installFileLogging();
    performPendingBrowsingDataCleanup();

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
                // Keep Chromium's Windows GPU blocklist/workarounds intact.
                // Forcing zero-copy or bypassing driver workarounds can produce
                // black flicker in WebEngine media/WebGL surfaces.
                // Smooth scrolling
                " --enable-smooth-scrolling"
                // V8 engine — larger heap for heavy pages
                " --js-flags=--max-old-space-size=4096"
                // Prevent renderer throttling that causes jank on heavy pages
                " --disable-renderer-backgrounding"
                " --disable-background-timer-throttling"
                " --disable-backgrounding-occluded-windows"
                // Desktop-browser behaviour for music/video apps.
                " --autoplay-policy=no-user-gesture-required"
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

    qInfo().noquote() << "Filka Browser" << QStringLiteral(FILKA_VERSION)
                      << "starting with Qt" << QString::fromLatin1(qVersion())
                      << "on" << QSysInfo::prettyProductName();
    qInfo().noquote() << "App data:"
                      << QDir::toNativeSeparators(
                             QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation));
    qInfo().noquote() << "Cache data:"
                      << QDir::toNativeSeparators(
                             QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    // Filka brand mark — used for the window/taskbar icon (the same asset is
    // bundled into the QML module for in-app branding).
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Filka/assets/logo.png")));

    // Basic style gives us unstyled controls we fully theme ourselves.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() {
            qCritical().noquote() << "QML root object creation failed; see previous diagnostics.";
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("Filka", "Main");

    const int exitCode = app.exec();
    qInfo() << "Filka exiting with code" << exitCode;
    shutdownFileLogging();
    return exitCode;
}
