// BookmarkModel — persistent bookmarks (SQLite, one row per URL).
//
// A QML singleton shared by every workspace/tab. The star button toggles the
// active page; the bookmarks bar/panel lists entries newest-first. Mirrors the
// HistoryModel storage approach under the app data location.

#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <qqmlregistration.h>

class BookmarkModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles : int {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
    };
    Q_ENUM(Roles)

    explicit BookmarkModel(QObject *parent = nullptr);
    ~BookmarkModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_entries.size()); }

    // True if the URL is already bookmarked.
    Q_INVOKABLE bool contains(const QUrl &url) const;
    // Adds the URL if missing, removes it if present. Returns the new state.
    Q_INVOKABLE bool toggle(const QUrl &url, const QString &title);
    Q_INVOKABLE void add(const QUrl &url, const QString &title);
    Q_INVOKABLE void insertAt(int index, const QUrl &url, const QString &title);
    Q_INVOKABLE void removeUrl(const QUrl &url);
    Q_INVOKABLE void removeAt(int index);
    Q_INVOKABLE void clear();

    // Address-bar autocomplete: case-insensitive substring match on url/title.
    // Returns [{title, url}] maps, newest first.
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 4) const;

signals:
    void countChanged();
    void changed();   // any add/remove — lets the star button re-evaluate

private:
    struct Entry {
        QString url;
        QString title;
        QDateTime added;
    };

    QList<Entry> m_entries;   // most-recent first
    QSqlDatabase m_db;
    QString m_connectionName;

    void openDatabase();
    void load();
    void persistEntry(const Entry &entry);
    void persistOrder();
    int indexOfUrl(const QString &url) const;
    static bool isWebUrl(const QUrl &url);
};
