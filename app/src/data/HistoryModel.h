// HistoryModel — persistent browsing history (SQLite, one row per URL).
//
// A QML singleton shared by every workspace/tab. Each successful navigation
// calls recordVisit(); the model keeps an in-memory list (most-recent first)
// mirrored to a SQLite database under the app data location so history
// survives restarts. The list is exposed to the History panel in QML.

#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <qqmlregistration.h>

class HistoryModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles : int {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
        LastVisitRole,
        VisitCountRole,
    };
    Q_ENUM(Roles)

    explicit HistoryModel(QObject *parent = nullptr);
    ~HistoryModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_entries.size()); }

    // Records a successful navigation. Ignores blank/non-web URLs. Existing
    // URLs are bumped to the top with an incremented visit count.
    Q_INVOKABLE void recordVisit(const QUrl &url, const QString &title);
    Q_INVOKABLE void removeEntry(int index);
    Q_INVOKABLE bool restoreEntry(int index, const QString &title, const QUrl &url,
                                   const QDateTime &lastVisit);
    Q_INVOKABLE void clear();

    // Address-bar autocomplete: case-insensitive substring match on url/title,
    // ranked by visit count then recency. Returns [{title, url}] maps.
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 6) const;
    Q_INVOKABLE QVariantList recent(int limit = 3) const;

signals:
    void countChanged();

private:
    struct Entry {
        QString url;
        QString title;
        QDateTime lastVisit;
        int visitCount = 1;
    };

    QList<Entry> m_entries;   // most-recent first
    QSqlDatabase m_db;
    QString m_connectionName;

    void openDatabase();
    void load();
    int indexOfUrl(const QString &url) const;
};
