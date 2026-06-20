#include "BrowserImporter.h"

#include <algorithm>

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
// SQLite-backed browser stores require Qt SQL. Keep Qt6::Sql linked when this
// importer is added to a target; Chromium bookmarks are the only JSON-only path.
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QUrl>
#include <QDateTime>
#include <QVariantMap>

namespace {
QString homePath()
{
    return QDir::homePath();
}

QVariantMap makeBrowser(const QString &id, const QString &name, const QString &family,
                        const QString &profilePath, const QString &bookmarksPath,
                        const QString &historyPath)
{
    return QVariantMap{
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), name},
        {QStringLiteral("family"), family},
        {QStringLiteral("profilePath"), profilePath},
        {QStringLiteral("bookmarksPath"), bookmarksPath},
        {QStringLiteral("historyPath"), historyPath},
        {QStringLiteral("bookmarksAvailable"), !bookmarksPath.isEmpty() && QFileInfo::exists(bookmarksPath)},
        {QStringLiteral("historyAvailable"), !historyPath.isEmpty() && QFileInfo::exists(historyPath)},
    };
}

QString copiedDatabasePath(const QString &sourcePath, QTemporaryDir *tempDir)
{
    if (!tempDir->isValid() || !QFileInfo::exists(sourcePath))
        return {};

    const QString target = tempDir->filePath(QFileInfo(sourcePath).fileName());
    QFile::remove(target);
    if (!QFile::copy(sourcePath, target))
        return {};

    QFile::setPermissions(target, QFile::ReadOwner | QFile::WriteOwner);

    const QString walSource = sourcePath + QStringLiteral("-wal");
    if (QFileInfo::exists(walSource)) {
        const QString walTarget = target + QStringLiteral("-wal");
        QFile::remove(walTarget);
        QFile::copy(walSource, walTarget);
        QFile::setPermissions(walTarget, QFile::ReadOwner | QFile::WriteOwner);
    }

    const QString shmSource = sourcePath + QStringLiteral("-shm");
    if (QFileInfo::exists(shmSource)) {
        const QString shmTarget = target + QStringLiteral("-shm");
        QFile::remove(shmTarget);
        QFile::copy(shmSource, shmTarget);
        QFile::setPermissions(shmTarget, QFile::ReadOwner | QFile::WriteOwner);
    }

    return target;
}

QDateTime chromiumTimeToDateTime(qint64 value)
{
    return QDateTime::fromMSecsSinceEpoch((value / 1000) - 11644473600000LL, Qt::UTC);
}

QDateTime firefoxTimeToDateTime(qint64 value)
{
    return QDateTime::fromMSecsSinceEpoch(value / 1000, Qt::UTC);
}

QSqlDatabase openSqlite(const QString &path, const QString &prefix, QString *connectionName)
{
    *connectionName = QStringLiteral("%1_%2").arg(prefix).arg(reinterpret_cast<quintptr>(connectionName), 0, 16);
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), *connectionName);
    db.setDatabaseName(path);
    db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
    if (!db.open()) {
        qWarning("Filka: importer could not open %s: %s",
                 qPrintable(path), qPrintable(db.lastError().text()));
    }
    return db;
}

void closeSqlite(QSqlDatabase *db, const QString &connectionName)
{
    if (!db)
        return;
    *db = QSqlDatabase();
    QSqlDatabase::removeDatabase(connectionName);
}
}

BrowserImporter::BrowserImporter(QObject *parent) : QObject(parent) {}

void BrowserImporter::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void BrowserImporter::setProgress(qreal progress)
{
    progress = std::clamp(progress, 0.0, 1.0);
    if (qFuzzyCompare(m_progress, progress))
        return;
    m_progress = progress;
    emit progressChanged();
}

void BrowserImporter::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}

void BrowserImporter::setImportedCounts(int bookmarks, int history, int passwords)
{
    if (m_importedBookmarks == bookmarks && m_importedHistory == history
        && m_importedPasswords == passwords)
        return;
    m_importedBookmarks = bookmarks;
    m_importedHistory = history;
    m_importedPasswords = passwords;
    emit importedCountsChanged();
}

bool BrowserImporter::isWebUrl(const QString &url)
{
    const QUrl parsed(url);
    return parsed.isValid() && (parsed.scheme() == QLatin1String("http")
                                || parsed.scheme() == QLatin1String("https"));
}

QVariantList BrowserImporter::detectInstalled()
{
    setBusy(true);
    setProgress(0.0);
    setStatus(QStringLiteral("Ищем установленные браузеры..."));

    QVariantList detected = detectChromiumProfiles();
    const QVariantList firefox = detectFirefoxProfiles();
    for (const QVariant &entry : firefox)
        detected.append(entry);

    m_browsers = detected;
    emit browsersChanged();
    setStatus(detected.isEmpty()
              ? QStringLiteral("Браузеры для импорта не найдены")
              : QStringLiteral("Найдено браузеров: %1").arg(detected.size()));
    setProgress(1.0);
    setBusy(false);
    return m_browsers;
}

QVariantMap BrowserImporter::browser(const QString &browserId) const
{
    for (const QVariant &entry : m_browsers) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("id")).toString() == browserId)
            return map;
    }
    return {};
}

QVariantList BrowserImporter::importBookmarks(const QString &browserId)
{
    if (m_browsers.isEmpty())
        detectInstalled();

    const QVariantMap b = browser(browserId);
    if (b.isEmpty())
        return {};

    setBusy(true);
    setProgress(0.0);
    setStatus(QStringLiteral("Читаем закладки из %1...").arg(b.value(QStringLiteral("name")).toString()));

    const QString family = b.value(QStringLiteral("family")).toString();
    QVariantList entries = family == QLatin1String("firefox")
        ? readFirefoxBookmarks(b)
        : readChromiumBookmarks(b);

    setImportedCounts(entries.size(), m_importedHistory, m_importedPasswords);
    setStatus(QStringLiteral("Готово: %1 закладок").arg(entries.size()));
    setProgress(1.0);
    setBusy(false);
    return entries;
}

QVariantList BrowserImporter::importHistory(const QString &browserId)
{
    if (m_browsers.isEmpty())
        detectInstalled();

    const QVariantMap b = browser(browserId);
    if (b.isEmpty())
        return {};

    setBusy(true);
    setProgress(0.0);
    setStatus(QStringLiteral("Читаем историю из %1...").arg(b.value(QStringLiteral("name")).toString()));

    const QString family = b.value(QStringLiteral("family")).toString();
    QVariantList entries = family == QLatin1String("firefox")
        ? readFirefoxHistory(b)
        : readChromiumHistory(b);

    setImportedCounts(m_importedBookmarks, entries.size(), m_importedPasswords);
    setStatus(QStringLiteral("Готово: %1 записей истории").arg(entries.size()));
    setProgress(1.0);
    setBusy(false);
    return entries;
}

QVariantList BrowserImporter::importPasswords(const QString &browserId)
{
    Q_UNUSED(browserId)
    setBusy(false);
    setProgress(0.0);
    setImportedCounts(m_importedBookmarks, m_importedHistory, 0);
    setStatus(QStringLiteral("Импорт паролей недоступен: в Filka пока нет защищённого хранилища паролей."));
    return {};
}

QVariantList BrowserImporter::detectChromiumProfiles() const
{
    struct Candidate {
        QString id;
        QString name;
        QString basePath;
        QStringList profiles;
    };

    const QString home = homePath();
    const QList<Candidate> candidates = {
        {QStringLiteral("chrome"), QStringLiteral("Google Chrome"),
         home + QStringLiteral("/.config/google-chrome"), {QStringLiteral("Default")}},
        {QStringLiteral("chromium"), QStringLiteral("Chromium"),
         home + QStringLiteral("/.config/chromium"), {QStringLiteral("Default")}},
        {QStringLiteral("opera"), QStringLiteral("Opera"),
         home + QStringLiteral("/.config/opera"), {QString()}},
        {QStringLiteral("brave"), QStringLiteral("Brave"),
         home + QStringLiteral("/.config/BraveSoftware/Brave-Browser"), {QStringLiteral("Default")}},
    };

    QVariantList out;
    for (const Candidate &candidate : candidates) {
        for (const QString &profileName : candidate.profiles) {
            const QString profile = profileName.isEmpty()
                ? candidate.basePath
                : QDir(candidate.basePath).filePath(profileName);
            const QString bookmarks = QDir(profile).filePath(QStringLiteral("Bookmarks"));
            const QString history = QDir(profile).filePath(QStringLiteral("History"));
            if (!QFileInfo::exists(bookmarks) && !QFileInfo::exists(history))
                continue;
            out.append(makeBrowser(candidate.id, candidate.name, QStringLiteral("chromium"),
                                   profile, bookmarks, history));
        }
    }
    return out;
}

QVariantList BrowserImporter::detectFirefoxProfiles() const
{
    const QString root = homePath() + QStringLiteral("/.mozilla/firefox");
    QVariantList out;
    if (!QFileInfo(root).isDir())
        return out;

    QDirIterator it(root, QDir::Dirs | QDir::NoDotAndDotDot);
    int index = 0;
    while (it.hasNext()) {
        const QString profile = it.next();
        const QString places = QDir(profile).filePath(QStringLiteral("places.sqlite"));
        if (!QFileInfo::exists(places))
            continue;
        const QString name = QFileInfo(profile).fileName();
        out.append(makeBrowser(QStringLiteral("firefox_%1").arg(index++),
                               name.contains(QStringLiteral("default"), Qt::CaseInsensitive)
                                   ? QStringLiteral("Firefox") : QStringLiteral("Firefox (%1)").arg(name),
                               QStringLiteral("firefox"), profile, places, places));
    }
    return out;
}

void BrowserImporter::collectChromiumBookmarkNode(const QVariantMap &node, QVariantList *out)
{
    if (!out)
        return;

    const QString type = node.value(QStringLiteral("type")).toString();
    if (type == QLatin1String("url")) {
        const QString url = node.value(QStringLiteral("url")).toString();
        if (isWebUrl(url)) {
            out->append(QVariantMap{
                {QStringLiteral("title"), node.value(QStringLiteral("name")).toString()},
                {QStringLiteral("url"), url},
            });
        }
        return;
    }

    const QVariantList children = node.value(QStringLiteral("children")).toList();
    for (const QVariant &child : children)
        collectChromiumBookmarkNode(child.toMap(), out);
}

QVariantList BrowserImporter::readChromiumBookmarks(const QVariantMap &browser) const
{
    QVariantList out;
    QFile file(browser.value(QStringLiteral("bookmarksPath")).toString());
    if (!file.open(QIODevice::ReadOnly))
        return out;

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject())
        return out;

    const QVariantMap roots = doc.object().value(QStringLiteral("roots")).toObject().toVariantMap();
    for (const QVariant &rootNode : roots)
        collectChromiumBookmarkNode(rootNode.toMap(), &out);
    return out;
}

QVariantList BrowserImporter::readChromiumHistory(const QVariantMap &browser) const
{
    QVariantList out;
    QTemporaryDir tempDir;
    const QString path = copiedDatabasePath(browser.value(QStringLiteral("historyPath")).toString(), &tempDir);
    if (path.isEmpty())
        return out;

    QString connectionName;
    QSqlDatabase db = openSqlite(path, QStringLiteral("filka_import_chromium"), &connectionName);
    if (!db.isOpen()) {
        closeSqlite(&db, connectionName);
        return out;
    }

    {
        QSqlQuery q(db);
        if (q.exec(QStringLiteral("SELECT url, title, last_visit_time FROM urls WHERE url LIKE 'http%' ORDER BY last_visit_time DESC LIMIT 5000"))) {
            while (q.next()) {
                const QString url = q.value(0).toString();
                if (!isWebUrl(url))
                    continue;
                out.append(QVariantMap{
                    {QStringLiteral("url"), url},
                    {QStringLiteral("title"), q.value(1).toString()},
                    {QStringLiteral("lastVisit"), chromiumTimeToDateTime(q.value(2).toLongLong())},
                });
            }
        }
    }
    closeSqlite(&db, connectionName);
    return out;
}

QVariantList BrowserImporter::readFirefoxBookmarks(const QVariantMap &browser) const
{
    QVariantList out;
    QTemporaryDir tempDir;
    const QString path = copiedDatabasePath(browser.value(QStringLiteral("bookmarksPath")).toString(), &tempDir);
    if (path.isEmpty())
        return out;

    QString connectionName;
    QSqlDatabase db = openSqlite(path, QStringLiteral("filka_import_firefox_bookmarks"), &connectionName);
    if (!db.isOpen()) {
        closeSqlite(&db, connectionName);
        return out;
    }

    {
        QSqlQuery q(db);
        if (q.exec(QStringLiteral(
                "SELECT COALESCE(b.title, p.title), p.url "
                "FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id "
                "WHERE b.type = 1 AND p.url LIKE 'http%' "
                "ORDER BY b.dateAdded DESC LIMIT 5000"))) {
            while (q.next()) {
                const QString url = q.value(1).toString();
                if (!isWebUrl(url))
                    continue;
                out.append(QVariantMap{
                    {QStringLiteral("title"), q.value(0).toString()},
                    {QStringLiteral("url"), url},
                });
            }
        }
    }
    closeSqlite(&db, connectionName);
    return out;
}

QVariantList BrowserImporter::readFirefoxHistory(const QVariantMap &browser) const
{
    QVariantList out;
    QTemporaryDir tempDir;
    const QString path = copiedDatabasePath(browser.value(QStringLiteral("historyPath")).toString(), &tempDir);
    if (path.isEmpty())
        return out;

    QString connectionName;
    QSqlDatabase db = openSqlite(path, QStringLiteral("filka_import_firefox_history"), &connectionName);
    if (!db.isOpen()) {
        closeSqlite(&db, connectionName);
        return out;
    }

    {
        QSqlQuery q(db);
        if (q.exec(QStringLiteral(
                "SELECT url, title, last_visit_date FROM moz_places "
                "WHERE url LIKE 'http%' AND last_visit_date IS NOT NULL "
                "ORDER BY last_visit_date DESC LIMIT 5000"))) {
            while (q.next()) {
                const QString url = q.value(0).toString();
                if (!isWebUrl(url))
                    continue;
                out.append(QVariantMap{
                    {QStringLiteral("url"), url},
                    {QStringLiteral("title"), q.value(1).toString()},
                    {QStringLiteral("lastVisit"), firefoxTimeToDateTime(q.value(2).toLongLong())},
                });
            }
        }
    }
    closeSqlite(&db, connectionName);
    return out;
}
