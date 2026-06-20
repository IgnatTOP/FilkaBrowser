#include "SiteDataHelper.h"

#include <QNetworkCookie>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEnginePermission>
#include <QtWebEngineQuick/QQuickWebEngineProfile>

namespace {
QQuickWebEngineProfile *asProfile(QObject *profile)
{
    return qobject_cast<QQuickWebEngineProfile *>(profile);
}

QUrl normalizedOrigin(const QString &value)
{
    const QUrl url(value);
    if (!url.isValid() || url.scheme().isEmpty() || url.host().isEmpty())
        return {};
    QUrl origin;
    origin.setScheme(url.scheme().toLower());
    origin.setHost(url.host().toLower());
    if (url.port() >= 0)
        origin.setPort(url.port());
    return origin;
}

bool sameOrigin(const QUrl &left, const QUrl &right)
{
    return left.scheme().compare(right.scheme(), Qt::CaseInsensitive) == 0
        && left.host().compare(right.host(), Qt::CaseInsensitive) == 0
        && left.port() == right.port();
}

bool cookieMatchesHost(const QNetworkCookie &cookie, const QString &host)
{
    QString domain = cookie.domain().toLower();
    const QString needle = host.toLower();
    if (domain.startsWith(QLatin1Char('.')))
        domain.remove(0, 1);
    return domain.isEmpty() || needle == domain || needle.endsWith(QLatin1Char('.') + domain);
}

QString permissionTypeName(QWebEnginePermission::PermissionType type)
{
    switch (type) {
    case QWebEnginePermission::PermissionType::Geolocation:
        return QObject::tr("Геолокация");
    case QWebEnginePermission::PermissionType::MediaAudioCapture:
        return QObject::tr("Микрофон");
    case QWebEnginePermission::PermissionType::MediaVideoCapture:
        return QObject::tr("Камера");
    case QWebEnginePermission::PermissionType::MediaAudioVideoCapture:
        return QObject::tr("Камера и микрофон");
    case QWebEnginePermission::PermissionType::MouseLock:
        return QObject::tr("Захват курсора");
    case QWebEnginePermission::PermissionType::DesktopVideoCapture:
        return QObject::tr("Запись экрана");
    case QWebEnginePermission::PermissionType::DesktopAudioVideoCapture:
        return QObject::tr("Экран и звук");
    case QWebEnginePermission::PermissionType::Notifications:
        return QObject::tr("Уведомления");
    case QWebEnginePermission::PermissionType::ClipboardReadWrite:
        return QObject::tr("Буфер обмена");
    case QWebEnginePermission::PermissionType::LocalFontsAccess:
        return QObject::tr("Локальные шрифты");
    default:
        return QObject::tr("Разрешение сайта");
    }
}

QString permissionStateName(QWebEnginePermission::State state)
{
    switch (state) {
    case QWebEnginePermission::State::Granted:
        return QObject::tr("Разрешено");
    case QWebEnginePermission::State::Denied:
        return QObject::tr("Запрещено");
    default:
        return QObject::tr("Спрашивать");
    }
}
} // namespace

SiteDataHelper::SiteDataHelper(QObject *parent) : QObject(parent) {}

QVariantList SiteDataHelper::permissionsForOrigin(QObject *profile, const QString &url) const
{
    QVariantList result;
    auto *p = asProfile(profile);
    const QUrl origin = normalizedOrigin(url);
    if (!p || origin.isEmpty())
        return result;

    const auto permissions = p->listAllPermissions();
    for (const QWebEnginePermission &permission : permissions) {
        if (!permission.isValid() || !sameOrigin(permission.origin(), origin))
            continue;
        QVariantMap item;
        item.insert(QStringLiteral("name"), permissionTypeName(permission.permissionType()));
        item.insert(QStringLiteral("state"), permissionStateName(permission.state()));
        result.append(item);
    }
    return result;
}

void SiteDataHelper::clearPermissionsForOrigin(QObject *profile, const QString &url)
{
    auto *p = asProfile(profile);
    const QUrl origin = normalizedOrigin(url);
    if (!p || origin.isEmpty())
        return;

    const auto permissions = p->listAllPermissions();
    for (const QWebEnginePermission &permission : permissions) {
        if (permission.isValid() && sameOrigin(permission.origin(), origin))
            permission.reset();
    }
}

void SiteDataHelper::clearCookiesForOrigin(QObject *profile, const QString &url)
{
    auto *p = asProfile(profile);
    const QUrl origin = normalizedOrigin(url);
    if (!p || origin.isEmpty())
        return;

    auto *store = p->cookieStore();
    if (!store)
        return;

    const QString host = origin.host();
    auto *context = new QObject(store);
    auto *connection = new QMetaObject::Connection;
    *connection = QObject::connect(store, &QWebEngineCookieStore::cookieAdded, context,
                                   [store, origin, host](const QNetworkCookie &cookie) {
                                       if (cookieMatchesHost(cookie, host))
                                           store->deleteCookie(cookie, origin);
                                   });
    QTimer::singleShot(1500, context, [context, connection]() {
        QObject::disconnect(*connection);
        delete connection;
        context->deleteLater();
    });
    store->loadAllCookies();
}

QString SiteDataHelper::originForUrl(const QString &url) const
{
    const QUrl origin = normalizedOrigin(url);
    return origin.isEmpty() ? QString() : origin.toString(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::StripTrailingSlash);
}

bool SiteDataHelper::isOffTheRecord(QObject *profile) const
{
    auto *p = asProfile(profile);
    return p ? p->isOffTheRecord() : false;
}
