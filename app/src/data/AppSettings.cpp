#include "AppSettings.h"

#include <QUrl>

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
}

AppSettings::AppSettings(QObject *parent) : QObject(parent)
{
    m_onboarded = m_store.value(QStringLiteral("general/onboarded"), false).toBool();
    m_darkMode = m_store.value(QStringLiteral("appearance/darkMode"), true).toBool();
    m_accentColor = m_store.value(QStringLiteral("appearance/accentColor"),
                                  QStringLiteral("#2E7CF6")).toString();
    m_startPageAurora = m_store.value(QStringLiteral("appearance/startPageAurora"),
                                      true).toBool();
    m_searchEngine = m_store.value(QStringLiteral("search/engine"),
                                   QStringLiteral("DuckDuckGo")).toString();
    m_homePage = m_store.value(QStringLiteral("general/homePage"),
                               QStringLiteral("https://duckduckgo.com")).toString();
}

void AppSettings::setOnboarded(bool value)
{
    if (m_onboarded == value)
        return;
    m_onboarded = value;
    m_store.setValue(QStringLiteral("general/onboarded"), value);
    emit onboardedChanged();
}

void AppSettings::setDarkMode(bool value)
{
    if (m_darkMode == value)
        return;
    m_darkMode = value;
    m_store.setValue(QStringLiteral("appearance/darkMode"), value);
    emit darkModeChanged();
}

void AppSettings::setAccentColor(const QString &value)
{
    if (m_accentColor == value)
        return;
    m_accentColor = value;
    m_store.setValue(QStringLiteral("appearance/accentColor"), value);
    emit accentColorChanged();
}

void AppSettings::setStartPageAurora(bool value)
{
    if (m_startPageAurora == value)
        return;
    m_startPageAurora = value;
    m_store.setValue(QStringLiteral("appearance/startPageAurora"), value);
    emit startPageAuroraChanged();
}

void AppSettings::setSearchEngine(const QString &value)
{
    if (m_searchEngine == value)
        return;
    m_searchEngine = value;
    m_store.setValue(QStringLiteral("search/engine"), value);
    emit searchEngineChanged();
}

void AppSettings::setHomePage(const QString &value)
{
    if (m_homePage == value)
        return;
    m_homePage = value;
    m_store.setValue(QStringLiteral("general/homePage"), value);
    emit homePageChanged();
}

QStringList AppSettings::searchEngines() const
{
    QStringList names;
    for (const auto &e : kEngines)
        names << QString::fromLatin1(e.name);
    return names;
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
