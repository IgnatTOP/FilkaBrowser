#include "AppSettings.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

#include <array>

namespace {
// name -> query-string template (%1 is replaced by the encoded query).
struct Engine {
    const char *name;
    const char *query;
};
const Engine kEngines[] = {
    {"DuckDuckGo", "https://duckduckgo.com/?q=%1"},
    {"Google",     "https://www.google.com/search?q=%1"},
    {"Bing",       "https://www.bing.com/search?q=%1"},
    {"Yandex",     "https://yandex.ru/search/?text=%1"},
};

constexpr std::array kTrustedAutoplayDomains = {
    "music.youtube.com",
    "open.spotify.com",
    "soundcloud.com",
    "music.apple.com",
    "deezer.com",
    "tidal.com",
    "bandcamp.com",
};

QString writableOrFallback(QStandardPaths::StandardLocation location,
                           const QString &fallbackName)
{
    QString path = QStandardPaths::writableLocation(location);
    if (path.isEmpty())
        path = QDir::home().filePath(fallbackName);
    QDir().mkpath(path);
    return path;
}

QString defaultDownloadDirectory()
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (path.isEmpty())
        path = QDir::home().filePath(QStringLiteral("Downloads"));
    if (!QDir().mkpath(path)) {
        const QString dataPath = writableOrFallback(QStandardPaths::AppDataLocation,
                                                    QStringLiteral(".local/share/Filka"));
        path = QDir(dataPath).filePath(QStringLiteral("Downloads"));
        QDir().mkpath(path);
    }
    return path;
}

QString normalizedDirectory(const QString &value, const QString &fallback)
{
    QString path = value.trimmed();
    if (path.isEmpty())
        path = fallback;
    QFileInfo info(path);
    if (info.isRelative())
        path = QDir::home().filePath(path);
    QDir().mkpath(path);
    return QDir(path).absolutePath();
}

QString defaultDisplayName()
{
    QString user = qEnvironmentVariable("USER").trimmed();
    if (user.isEmpty())
        user = qEnvironmentVariable("USERNAME").trimmed();
    if (user.isEmpty())
        return QStringLiteral("Ignat");
    user[0] = user.at(0).toUpper();
    return user;
}

QString normalizedWallpaperPreset(const QString &value)
{
    const QString preset = value.trimmed().toLower();
    if (preset == QLatin1String("space") || preset == QLatin1String("minimal"))
        return preset;
    return QStringLiteral("coast");
}
}

AppSettings::AppSettings(QObject *parent) : QObject(parent)
{
    m_onboarded = m_store.value(QStringLiteral("general/onboarded"), false).toBool();
    m_darkMode = m_store.value(QStringLiteral("appearance/darkMode"), true).toBool();
    m_accentColor = m_store.value(QStringLiteral("appearance/accentColor"),
                                  QStringLiteral("#8B5CF6")).toString();
    m_startPageAurora = m_store.value(QStringLiteral("appearance/startPageAurora"),
                                      true).toBool();
    m_displayName = m_store.value(QStringLiteral("appearance/displayName"),
                                  defaultDisplayName()).toString().trimmed();
    if (m_displayName.isEmpty())
        m_displayName = defaultDisplayName();
    m_homeSubtitle = m_store.value(QStringLiteral("appearance/homeSubtitle"),
                                   QStringLiteral("Готовы создать что-то великое сегодня?")).toString().trimmed();
    if (m_homeSubtitle.isEmpty())
        m_homeSubtitle = QStringLiteral("Готовы создать что-то великое сегодня?");
    m_wallpaperPreset = normalizedWallpaperPreset(
        m_store.value(QStringLiteral("appearance/wallpaperPreset"),
                      QStringLiteral("coast")).toString());
    m_reducedMotion = m_store.value(QStringLiteral("appearance/reducedMotion"),
                                    false).toBool();
    m_homeSmartCards = m_store.value(QStringLiteral("home/smartCards"),
                                     true).toBool();
    m_searchEngine = m_store.value(QStringLiteral("search/engine"),
                                   QStringLiteral("DuckDuckGo")).toString();
    m_networkSuggestionsEnabled = m_store.value(QStringLiteral("search/networkSuggestionsEnabled"),
                                                false).toBool();
    m_homePage = m_store.value(QStringLiteral("general/homePage"),
                               QStringLiteral("https://duckduckgo.com")).toString();
    m_downloadPath = normalizedDirectory(
        m_store.value(QStringLiteral("general/downloadPath"), defaultDownloadDirectory()).toString(),
        defaultDownloadDirectory());
    m_askDownloadLocation = m_store.value(QStringLiteral("downloads/askLocation"),
                                          false).toBool();
    m_restoreSessionEnabled = m_store.value(QStringLiteral("general/restoreSessionEnabled"),
                                            true).toBool();
    m_verticalTabs = m_store.value(QStringLiteral("tabs/verticalTabs"), true).toBool();
    m_defaultZoom = qBound(0.5, m_store.value(QStringLiteral("tabs/defaultZoom"), 1.0).toDouble(), 2.0);
    m_translatorCacheEnabled = m_store.value(QStringLiteral("translator/cacheEnabled"), true).toBool();
    m_translatorAutoOffer = m_store.value(QStringLiteral("translator/autoOffer"), true).toBool();
    m_permissiveAutoplayEnabled = m_store.value(QStringLiteral("media/permissiveAutoplayEnabled"), false).toBool();
}

void AppSettings::setOnboarded(bool value)
{
    if (m_onboarded == value)
        return;
    m_onboarded = value;
    m_store.setValue(QStringLiteral("general/onboarded"), value);
    // Flush immediately: onboarding (and other prefs) must survive even if the
    // process is killed rather than quit cleanly, otherwise the welcome screen
    // would reappear on the next launch.
    m_store.sync();
    emit onboardedChanged();
}

void AppSettings::setDarkMode(bool value)
{
    if (m_darkMode == value)
        return;
    m_darkMode = value;
    m_store.setValue(QStringLiteral("appearance/darkMode"), value);
    m_store.sync();
    emit darkModeChanged();
}

void AppSettings::setAccentColor(const QString &value)
{
    if (m_accentColor == value)
        return;
    m_accentColor = value;
    m_store.setValue(QStringLiteral("appearance/accentColor"), value);
    m_store.sync();
    emit accentColorChanged();
}

void AppSettings::setStartPageAurora(bool value)
{
    if (m_startPageAurora == value)
        return;
    m_startPageAurora = value;
    m_store.setValue(QStringLiteral("appearance/startPageAurora"), value);
    m_store.sync();
    emit startPageAuroraChanged();
}

void AppSettings::setDisplayName(const QString &value)
{
    QString clean = value.trimmed();
    if (clean.isEmpty())
        clean = defaultDisplayName();
    if (m_displayName == clean)
        return;
    m_displayName = clean;
    m_store.setValue(QStringLiteral("appearance/displayName"), clean);
    m_store.sync();
    emit displayNameChanged();
}

void AppSettings::setHomeSubtitle(const QString &value)
{
    QString clean = value.trimmed();
    if (clean.isEmpty())
        clean = QStringLiteral("Готовы создать что-то великое сегодня?");
    if (m_homeSubtitle == clean)
        return;
    m_homeSubtitle = clean;
    m_store.setValue(QStringLiteral("appearance/homeSubtitle"), clean);
    m_store.sync();
    emit homeSubtitleChanged();
}

void AppSettings::setWallpaperPreset(const QString &value)
{
    const QString preset = normalizedWallpaperPreset(value);
    if (m_wallpaperPreset == preset)
        return;
    m_wallpaperPreset = preset;
    m_store.setValue(QStringLiteral("appearance/wallpaperPreset"), preset);
    m_store.sync();
    emit wallpaperPresetChanged();
}

void AppSettings::setReducedMotion(bool value)
{
    if (m_reducedMotion == value)
        return;
    m_reducedMotion = value;
    m_store.setValue(QStringLiteral("appearance/reducedMotion"), value);
    m_store.sync();
    emit reducedMotionChanged();
}

void AppSettings::setHomeSmartCards(bool value)
{
    if (m_homeSmartCards == value)
        return;
    m_homeSmartCards = value;
    m_store.setValue(QStringLiteral("home/smartCards"), value);
    m_store.sync();
    emit homeSmartCardsChanged();
}

void AppSettings::setSearchEngine(const QString &value)
{
    if (m_searchEngine == value)
        return;
    m_searchEngine = value;
    m_store.setValue(QStringLiteral("search/engine"), value);
    m_store.sync();
    emit searchEngineChanged();
}

void AppSettings::setNetworkSuggestionsEnabled(bool value)
{
    if (m_networkSuggestionsEnabled == value)
        return;
    m_networkSuggestionsEnabled = value;
    m_store.setValue(QStringLiteral("search/networkSuggestionsEnabled"), value);
    m_store.sync();
    emit networkSuggestionsEnabledChanged();
}

void AppSettings::setHomePage(const QString &value)
{
    if (m_homePage == value)
        return;
    m_homePage = value;
    m_store.setValue(QStringLiteral("general/homePage"), value);
    m_store.sync();
    emit homePageChanged();
}

void AppSettings::setDownloadPath(const QString &value)
{
    const QString normalized = normalizedDirectory(value, defaultDownloadDirectory());
    if (m_downloadPath == normalized)
        return;
    m_downloadPath = normalized;
    m_store.setValue(QStringLiteral("general/downloadPath"), normalized);
    m_store.sync();
    emit downloadPathChanged();
}

void AppSettings::setAskDownloadLocation(bool value)
{
    if (m_askDownloadLocation == value)
        return;
    m_askDownloadLocation = value;
    m_store.setValue(QStringLiteral("downloads/askLocation"), value);
    m_store.sync();
    emit askDownloadLocationChanged();
}

void AppSettings::setRestoreSessionEnabled(bool value)
{
    if (m_restoreSessionEnabled == value)
        return;
    m_restoreSessionEnabled = value;
    m_store.setValue(QStringLiteral("general/restoreSessionEnabled"), value);
    m_store.sync();
    emit restoreSessionEnabledChanged();
}

void AppSettings::setVerticalTabs(bool value)
{
    if (m_verticalTabs == value)
        return;
    m_verticalTabs = value;
    m_store.setValue(QStringLiteral("tabs/verticalTabs"), value);
    m_store.sync();
    emit verticalTabsChanged();
}

void AppSettings::setDefaultZoom(qreal value)
{
    const qreal clamped = qBound(0.5, value, 2.0);
    if (qFuzzyCompare(m_defaultZoom, clamped))
        return;
    m_defaultZoom = clamped;
    m_store.setValue(QStringLiteral("tabs/defaultZoom"), clamped);
    m_store.sync();
    emit defaultZoomChanged();
}

void AppSettings::setTranslatorCacheEnabled(bool value)
{
    if (m_translatorCacheEnabled == value)
        return;
    m_translatorCacheEnabled = value;
    m_store.setValue(QStringLiteral("translator/cacheEnabled"), value);
    m_store.sync();
    emit translatorCacheEnabledChanged();
}

void AppSettings::setTranslatorAutoOffer(bool value)
{
    if (m_translatorAutoOffer == value)
        return;
    m_translatorAutoOffer = value;
    m_store.setValue(QStringLiteral("translator/autoOffer"), value);
    m_store.sync();
    emit translatorAutoOfferChanged();
}

void AppSettings::setPermissiveAutoplayEnabled(bool value)
{
    if (m_permissiveAutoplayEnabled == value)
        return;
    m_permissiveAutoplayEnabled = value;
    m_store.setValue(QStringLiteral("media/permissiveAutoplayEnabled"), value);
    m_store.sync();
    emit permissiveAutoplayEnabledChanged();
}

QStringList AppSettings::searchEngines() const
{
    QStringList names;
    for (const auto &e : kEngines)
        names << QString::fromLatin1(e.name);
    return names;
}

QString AppSettings::downloadDir() const
{
    QDir().mkpath(m_downloadPath);
    return m_downloadPath.isEmpty() ? defaultDownloadDirectory() : m_downloadPath;
}

QString AppSettings::webStoragePath() const
{
    const QString base = writableOrFallback(QStandardPaths::AppDataLocation,
                                            QStringLiteral(".local/share/Filka"));
    const QString path = QDir(base).filePath(QStringLiteral("webengine"));
    QDir().mkpath(path);
    return path;
}

QString AppSettings::webCachePath() const
{
    const QString base = writableOrFallback(QStandardPaths::CacheLocation,
                                            QStringLiteral(".cache/Filka"));
    const QString path = QDir(base).filePath(QStringLiteral("webengine"));
    QDir().mkpath(path);
    return path;
}

QString AppSettings::searchUrl(const QString &query) const
{
    const QString encoded = QString::fromLatin1(QUrl::toPercentEncoding(query));
    for (const auto &e : kEngines) {
        if (m_searchEngine == QLatin1String(e.name))
            return QString::fromLatin1(e.query).arg(encoded);
    }
    // Fall back to the first engine if the stored name is unknown.
    return QString::fromLatin1(kEngines[0].query).arg(encoded);
}

bool AppSettings::isTrustedAutoplayHost(const QUrl &url) const
{
    const QString host = url.host().toLower();
    if (host.isEmpty())
        return false;

    for (const char *domain : kTrustedAutoplayDomains) {
        const QString trusted = QString::fromLatin1(domain);
        if (host == trusted || host.endsWith(QLatin1Char('.') + trusted))
            return true;
    }
    return false;
}
