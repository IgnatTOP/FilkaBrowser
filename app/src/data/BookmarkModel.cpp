#include "BookmarkModel.h"

#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>

BookmarkModel::BookmarkModel(QObject *parent) : QAbstractListModel(parent)
{
    openDatabase();
    load();
}

void BookmarkModel::openDatabase()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("filka_bookmarks"));
    m_db.setDatabaseName(dir + QStringLiteral("/bookmarks.db"));
    if (!m_db.open()) {
        qWarning("Filka: could not open bookmarks database: %s",
                 qPrintable(m_db.lastError().text()));
        return;
    }

    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS bookmarks ("
        "  url   TEXT PRIMARY KEY,"
        "  title TEXT,"
        "  added INTEGER NOT NULL)"));
}

void BookmarkModel::load()
{
    if (!m_db.isOpen())
        return;

    QSqlQuery q(m_db);
    q.exec(QStringLiteral("SELECT url, title, added FROM bookmarks ORDER BY added DESC"));
    while (q.next()) {
        Entry e;
        e.url = q.value(0).toString();
        e.title = q.value(1).toString();
        e.added = QDateTime::fromMSecsSinceEpoch(q.value(2).toLongLong());
        m_entries.append(e);
    }
}

int BookmarkModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QVariant BookmarkModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= int(m_entries.size()))
        return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case TitleRole: return e.title.isEmpty() ? e.url : e.title;
    case UrlRole:   return e.url;
    default:        return {};
    }
}

QHash<int, QByteArray> BookmarkModel::roleNames() const
{
    return {
        {TitleRole, "title"},
        {UrlRole, "url"},
    };
}

int BookmarkModel::indexOfUrl(const QString &url) const
{
    for (int i = 0; i < m_entries.size(); ++i)
        if (m_entries.at(i).url == url)
            return i;
    return -1;
}

bool BookmarkModel::contains(const QUrl &url) const
{
    return indexOfUrl(url.toString()) >= 0;
}

void BookmarkModel::add(const QUrl &url, const QString &title)
{
    if (!url.isValid() || (url.scheme() != QLatin1String("http")
                           && url.scheme() != QLatin1String("https")))
        return;
    const QString key = url.toString();
    if (indexOfUrl(key) >= 0)
        return;

    const QDateTime now = QDateTime::currentDateTime();
    beginInsertRows({}, 0, 0);
    Entry e;
    e.url = key;
    e.title = title;
    e.added = now;
    m_entries.prepend(e);
    endInsertRows();
    emit countChanged();
    emit changed();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "INSERT OR REPLACE INTO bookmarks (url, title, added) VALUES (?, ?, ?)"));
        q.addBindValue(key);
        q.addBindValue(title);
        q.addBindValue(now.toMSecsSinceEpoch());
        q.exec();
    }
}

void BookmarkModel::removeUrl(const QUrl &url)
{
    const int i = indexOfUrl(url.toString());
    if (i >= 0)
        removeAt(i);
}

void BookmarkModel::removeAt(int index)
{
    if (index < 0 || index >= int(m_entries.size()))
        return;

    const QString key = m_entries.at(index).url;
    beginRemoveRows({}, index, index);
    m_entries.removeAt(index);
    endRemoveRows();
    emit countChanged();
    emit changed();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("DELETE FROM bookmarks WHERE url = ?"));
        q.addBindValue(key);
        q.exec();
    }
}

bool BookmarkModel::toggle(const QUrl &url, const QString &title)
{
    if (contains(url)) {
        removeUrl(url);
        return false;
    }
    add(url, title);
    return true;
}

QVariantList BookmarkModel::search(const QString &query, int limit) const
{
    QVariantList out;
    const QString q = query.trimmed();
    if (q.isEmpty() || limit <= 0)
        return out;

    for (const Entry &e : m_entries) {
        if (out.size() >= limit)
            break;
        if (e.url.contains(q, Qt::CaseInsensitive)
            || e.title.contains(q, Qt::CaseInsensitive)) {
            out.append(QVariantMap{
                {QStringLiteral("title"), e.title.isEmpty() ? e.url : e.title},
                {QStringLiteral("url"), e.url},
            });
        }
    }
    return out;
}

void BookmarkModel::clear()
{
    if (m_entries.isEmpty())
        return;

    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
    emit changed();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.exec(QStringLiteral("DELETE FROM bookmarks"));
    }
}
