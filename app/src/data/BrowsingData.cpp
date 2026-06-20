#include "BrowsingData.h"

#include <QDir>
#include <QSettings>
#include <QStringList>

#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEnginePermission>
#include <QtWebEngineQuick/QQuickWebEngineProfile>

namespace {
constexpr auto kPendingCleanupKey = "privacy/pendingWebEngineProfileCleanup";
constexpr auto kPendingCleanupPathsKey = "privacy/pendingWebEngineProfileCleanupPaths";

QQuickWebEngineProfile *asProfile(QObject *profile)
{
    return qobject_cast<QQuickWebEngineProfile *>(profile);
}

QStringList safeProfileDirectories(const QQuickWebEngineProfile &profile)
{
    QStringList paths;
    const QString storagePath = profile.persistentStoragePath();
    if (!storagePath.isEmpty())
        paths << QDir::cleanPath(storagePath);
    const QString cachePath = profile.cachePath();
    if (!cachePath.isEmpty())
        paths << QDir::cleanPath(cachePath);
    paths.removeDuplicates();
    return paths;
}

void scheduleProfileDirectoryCleanup(const QStringList &paths)
{
    if (paths.isEmpty())
        return;

    QSettings store;
    QStringList pending = store.value(QString::fromLatin1(kPendingCleanupPathsKey)).toStringList();
    for (const QString &path : paths) {
        if (!pending.contains(path))
            pending << path;
    }
    store.setValue(QString::fromLatin1(kPendingCleanupKey), true);
    store.setValue(QString::fromLatin1(kPendingCleanupPathsKey), pending);
    store.sync();
}
}

BrowsingData::BrowsingData(QObject *parent) : QObject(parent) {}

QString BrowsingData::lastClearStatus() const
{
    return m_lastClearStatus;
}

bool BrowsingData::restartRequired() const
{
    return m_restartRequired;
}

void BrowsingData::setLastClearStatus(const QString &status, bool restartRequired)
{
    if (m_lastClearStatus == status && m_restartRequired == restartRequired)
        return;
    m_lastClearStatus = status;
    m_restartRequired = restartRequired;
    emit lastClearStatusChanged();
}

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

QString BrowsingData::clearAll(QObject *profile)
{
    auto *p = asProfile(profile);
    clearCache(profile);
    clearCookies(profile);
    clearPermissions(profile);

    if (!p) {
        const QString status = tr("Очистка запущена для доступных данных.");
        setLastClearStatus(status, false);
        return status;
    }

    p->clearAllVisitedLinks();

    if (p->isOffTheRecord()) {
        const QString status = tr("Данные приватного профиля очищены сейчас.");
        setLastClearStatus(status, false);
        return status;
    }

    const QStringList paths = safeProfileDirectories(*p);
    scheduleProfileDirectoryCleanup(paths);

    const QString status = paths.isEmpty()
        ? tr("Cookie, кэш, разрешения и посещённые ссылки очищены сейчас.")
        : tr("Cookie, кэш, разрешения и посещённые ссылки очищены сейчас. Очистка хранилища сайтов будет завершена после перезапуска.");
    setLastClearStatus(status, !paths.isEmpty());
    return status;
}
