#include "BrowsingData.h"

#include <QDir>
#include <QNetworkCookie>
#include <QTimer>
#include <QUrl>

#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEnginePermission>
#include <QtWebEngineQuick/QQuickWebEngineProfile>

namespace {
QQuickWebEngineProfile *asProfile(QObject *profile)
{
    return qobject_cast<QQuickWebEngineProfile *>(profile);
}

QString normalizedHost(const QUrl &url)
{
    return url.host().toLower();
}

bool domainMatchesHost(QString cookieDomain, const QString &host)
{
    if (host.isEmpty())
        return false;

    cookieDomain = cookieDomain.toLower();
    if (cookieDomain.startsWith(QLatin1Char('.')))
        cookieDomain.remove(0, 1);

    return cookieDomain == host || host.endsWith(QStringLiteral(".") + cookieDomain);
}

bool sameOrigin(const QUrl &left, const QUrl &right)
{
    return left.scheme().compare(right.scheme(), Qt::CaseInsensitive) == 0
        && left.host().compare(right.host(), Qt::CaseInsensitive) == 0
        && left.port() == right.port();
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

void BrowsingData::clearCookiesForOrigin(QObject *profile, const QUrl &url)
{
    auto *p = asProfile(profile);
    if (!p)
        return;

    auto *cookies = p->cookieStore();
    if (!cookies)
        return;

    const QString host = normalizedHost(url);
    if (host.isEmpty())
        return;

    auto *disconnectTimer = new QTimer(cookies);
    disconnectTimer->setSingleShot(true);
    disconnectTimer->setInterval(250);

    QMetaObject::Connection *connection = new QMetaObject::Connection;
    *connection = connect(cookies, &QWebEngineCookieStore::cookieAdded, cookies,
                          [cookies, host, connection, disconnectTimer](const QNetworkCookie &cookie) {
                              if (domainMatchesHost(cookie.domain(), host))
                                  cookies->deleteCookie(cookie);

                              // Keep the temporary filter alive until the asynchronous
                              // loadAllCookies() burst has gone quiet.
                              disconnectTimer->start();
                          });
    connect(disconnectTimer, &QTimer::timeout, cookies, [connection, disconnectTimer]() {
        QObject::disconnect(*connection);
        delete connection;
        disconnectTimer->deleteLater();
    });

    cookies->loadAllCookies();
    disconnectTimer->start();
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

void BrowsingData::clearPermissionsForOrigin(QObject *profile, const QUrl &url)
{
    auto *p = asProfile(profile);
    if (!p || !url.isValid())
        return;

    const auto permissions = p->listAllPermissions();
    for (const QWebEnginePermission &permission : permissions) {
        if (permission.isValid() && sameOrigin(permission.origin(), url))
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
