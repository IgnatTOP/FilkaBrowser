#include "HistoryModel.h"

#include <algorithm>

#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>
#include <QVariantMap>

HistoryModel::HistoryModel(QObject *parent) : QAbstractListModel(parent)
{
    openDatabase();
    load();
}

HistoryModel::~HistoryModel()
{
    if (m_connectionName.isEmpty())
        return;
    const QString connectionName = m_connectionName;
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(connectionName);
}

void HistoryModel::openDatabase()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (!QDir().mkpath(dir)) {
        qWarning("Filka: could not create history database directory: %s", qPrintable(dir));
        return;
    }

    m_connectionName = QStringLiteral("filka_history_%1")
        .arg(reinterpret_cast<quintptr>(this), 0, 16);
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_db.setDatabaseName(dir + QStringLiteral("/history.db"));
    if (!m_db.open()) {
        qWarning("Filka: could not open history database: %s",
                 qPrintable(m_db.lastError().text()));
        return;
    }

    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS history ("
        "  url        TEXT PRIMARY KEY,"
        "  title      TEXT,"
        "  last_visit INTEGER NOT NULL,"
        "  visits     INTEGER NOT NULL DEFAULT 1)"))) {
        qWarning("Filka: could not create history table: %s",
                 qPrintable(q.lastError().text()));
    }
}

void HistoryModel::load()
{
    if (!m_db.isOpen())
        return;

    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral(
        "SELECT url, title, last_visit, visits FROM history ORDER BY last_visit DESC"))) {
        qWarning("Filka: could not load history: %s", qPrintable(q.lastError().text()));
        return;
    }
    while (q.next()) {
        Entry e;
        e.url = q.value(0).toString();
        e.title = q.value(1).toString();
        e.lastVisit = QDateTime::fromMSecsSinceEpoch(q.value(2).toLongLong());
        e.visitCount = q.value(3).toInt();
        m_entries.append(e);
    }
}

int HistoryModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QVariant HistoryModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= int(m_entries.size()))
        return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case TitleRole:      return e.title.isEmpty() ? e.url : e.title;
    case UrlRole:        return e.url;
    case LastVisitRole:  return e.lastVisit;
    case VisitCountRole: return e.visitCount;
    }
    return {};
}

QHash<int, QByteArray> HistoryModel::roleNames() const
{
    static const QHash<int, QByteArray> roles = {
        {TitleRole, "title"},
        {UrlRole, "url"},
        {LastVisitRole, "lastVisit"},
        {VisitCountRole, "visitCount"},
    };
    return roles;
}

int HistoryModel::indexOfUrl(const QString &url) const
{
    for (int i = 0; i < m_entries.size(); ++i)
        if (m_entries.at(i).url == url)
            return i;
    return -1;
}

bool HistoryModel::isWebUrl(const QUrl &url)
{
    return url.isValid() && (url.scheme() == QLatin1String("http")
                             || url.scheme() == QLatin1String("https"));
}

void HistoryModel::recordVisit(const QUrl &url, const QString &title)
{
    // Only track real, navigable web pages.
    if (!isWebUrl(url))
        return;

    const QString key = url.toString();
    const QDateTime now = QDateTime::currentDateTimeUtc();
    QString effectiveTitle = title;

    const int existing = indexOfUrl(key);
    if (existing >= 0) {
        if (existing != 0) {
            beginMoveRows({}, existing, existing, {}, 0);
            m_entries.move(existing, 0);
            endMoveRows();
        }

        Entry &e = m_entries[0];
        e.lastVisit = now;
        e.visitCount += 1;
        if (!title.isEmpty())
            e.title = title;
        effectiveTitle = e.title;
        emit dataChanged(index(0), index(0), {TitleRole, LastVisitRole, VisitCountRole});
    } else {
        beginInsertRows({}, 0, 0);
        Entry e;
        e.url = key;
        e.title = title;
        e.lastVisit = now;
        m_entries.prepend(e);
        endInsertRows();
        emit countChanged();
        effectiveTitle = e.title;
    }

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, 1) "
            "ON CONFLICT(url) DO UPDATE SET "
            "  title = excluded.title, last_visit = excluded.last_visit, visits = visits + 1"));
        q.addBindValue(key);
        q.addBindValue(effectiveTitle);
        q.addBindValue(now.toMSecsSinceEpoch());
        if (!q.exec()) {
            qWarning("Filka: could not persist history visit: %s",
                     qPrintable(q.lastError().text()));
        }
    }
}

QVariantMap HistoryModel::importEntries(const QVariantList &entries)
{
    int added = 0;
    int skippedDuplicates = 0;
    int errors = 0;

    if (entries.isEmpty()) {
        return {{QStringLiteral("added"), 0},
                {QStringLiteral("skippedDuplicates"), 0},
                {QStringLiteral("errors"), 0}};
    }

    const QDateTime now = QDateTime::currentDateTimeUtc();
    QList<Entry> pending;
    pending.reserve(entries.size());

    for (const QVariant &item : entries) {
        const QVariantMap map = item.toMap();
        const QUrl url(map.value(QStringLiteral("url")).toString());
        if (!isWebUrl(url)) {
            ++errors;
            continue;
        }

        const QString key = url.toString();
        if (indexOfUrl(key) >= 0) {
            ++skippedDuplicates;
            continue;
        }

        const auto duplicatePending = std::find_if(pending.cbegin(), pending.cend(), [&key](const Entry &entry) {
            return entry.url == key;
        });
        if (duplicatePending != pending.cend()) {
            ++skippedDuplicates;
            continue;
        }

        pending.prepend({key, map.value(QStringLiteral("title")).toString(), now, 1});
    }

    if (!pending.isEmpty()) {
        beginInsertRows({}, 0, pending.size() - 1);
        for (const Entry &entry : pending)
            m_entries.prepend(entry);
        endInsertRows();
        added = pending.size();
        emit countChanged();
    }

    if (m_db.isOpen() && !pending.isEmpty()) {
        m_db.transaction();
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("INSERT OR IGNORE INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, 1)"));
        for (const Entry &entry : pending) {
            q.bindValue(0, entry.url);
            q.bindValue(1, entry.title);
            q.bindValue(2, entry.lastVisit.toMSecsSinceEpoch());
            if (!q.exec())
                ++errors;
        }
        if (!m_db.commit())
            ++errors;
    }

    return {{QStringLiteral("added"), added},
            {QStringLiteral("skippedDuplicates"), skippedDuplicates},
            {QStringLiteral("errors"), errors}};
}

QVariantList HistoryModel::search(const QString &query, int limit) const
{
    QVariantList out;
    const QString q = query.trimmed();
    if (q.isEmpty() || limit <= 0)
        return out;

    // m_entries is already most-recent first; a stable pass keeps recency as the
    // tie-break while we prefer more-visited pages.
    QList<const Entry *> hits;
    for (const Entry &e : m_entries) {
        if (e.url.contains(q, Qt::CaseInsensitive)
            || e.title.contains(q, Qt::CaseInsensitive))
            hits.append(&e);
    }
    std::stable_sort(hits.begin(), hits.end(), [](const Entry *a, const Entry *b) {
        return a->visitCount > b->visitCount;
    });

    for (const Entry *e : hits) {
        if (out.size() >= limit)
            break;
        out.append(QVariantMap{
            {QStringLiteral("title"), e->title.isEmpty() ? e->url : e->title},
            {QStringLiteral("url"), e->url},
        });
    }
    return out;
}

QVariantList HistoryModel::recent(int limit) const
{
    QVariantList out;
    if (limit <= 0)
        return out;

    for (const Entry &e : m_entries) {
        if (out.size() >= limit)
            break;
        out.append(QVariantMap{
            {QStringLiteral("title"), e.title.isEmpty() ? e.url : e.title},
            {QStringLiteral("url"), e.url},
            {QStringLiteral("lastVisit"), e.lastVisit},
            {QStringLiteral("visitCount"), e.visitCount},
        });
    }
    return out;
}

void HistoryModel::removeEntry(int index)
{
    if (index < 0 || index >= int(m_entries.size()))
        return;

    const QString key = m_entries.at(index).url;
    beginRemoveRows({}, index, index);
    m_entries.removeAt(index);
    endRemoveRows();
    emit countChanged();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("DELETE FROM history WHERE url = ?"));
        q.addBindValue(key);
        if (!q.exec()) {
            qWarning("Filka: could not remove history entry: %s",
                     qPrintable(q.lastError().text()));
        }
    }
}

void HistoryModel::clear()
{
    if (m_entries.isEmpty())
        return;

    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        if (!q.exec(QStringLiteral("DELETE FROM history"))) {
            qWarning("Filka: could not clear history: %s",
                     qPrintable(q.lastError().text()));
        }
    }
}
