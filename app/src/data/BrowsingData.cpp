#include "BrowsingData.h"

#include <QDir>

#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEnginePermission>
#include <QtWebEngineQuick/QQuickWebEngineProfile>

namespace {
QQuickWebEngineProfile *asProfile(QObject *profile)
{
    return qobject_cast<QQuickWebEngineProfile *>(profile);
}
}

BrowsingData::BrowsingData(QObject *parent) : QObject(parent) {}

void BrowsingData::clearCache(QObject *profile)
{
    if (auto *p = asProfile(profile))
        p->clearHttpCache();
}

void BrowsingData::clearCookies(QObject *profile)
{
    auto *p = asProfile(profile);
    if (!p)
        return;
    if (auto *cookies = p->cookieStore())
        cookies->deleteAllCookies();
}

void BrowsingData::clearPermissions(QObject *profile)
{
    auto *p = asProfile(profile);
    if (!p)
        return;
    const auto permissions = p->listAllPermissions();
    for (const QWebEnginePermission &permission : permissions) {
        if (permission.isValid())
            permission.reset();
    }
}

void BrowsingData::clearAll(QObject *profile)
{
    auto *p = asProfile(profile);
    clearCache(profile);
    clearCookies(profile);
    clearPermissions(profile);
    if (!p || p->isOffTheRecord())
        return;

    const QString storagePath = p->persistentStoragePath();
    if (!storagePath.isEmpty() && QDir(storagePath).exists()
        && !QDir(storagePath).removeRecursively()) {
        qWarning("Filka: could not remove WebEngine storage path: %s",
                 qPrintable(storagePath));
    }

    const QString cachePath = p->cachePath();
    if (!cachePath.isEmpty() && QDir(cachePath).exists()
        && !QDir(cachePath).removeRecursively()) {
        qWarning("Filka: could not remove WebEngine cache path: %s",
                 qPrintable(cachePath));
    }
}
