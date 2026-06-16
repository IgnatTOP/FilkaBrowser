#include "BrowsingData.h"

#include <QWebEngineCookieStore>
#include <QWebEngineProfile>

BrowsingData::BrowsingData(QWebEngineProfile *profile, QObject *parent)
    : QObject(parent), m_profile(profile)
{
}

void BrowsingData::clearCache()
{
    if (m_profile)
        m_profile->clearHttpCache();
}

void BrowsingData::clearCookies()
{
    if (!m_profile)
        return;
    if (auto *cookies = m_profile->cookieStore())
        cookies->deleteAllCookies();
}

void BrowsingData::clearAll()
{
    clearCache();
    clearCookies();
    if (m_profile)
        m_profile->clearAllVisitedLinks();
}
