// DownloadModel — persistent download list backed by live WebEngine requests.

#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QPointer>
#include <QSettings>
#include <QString>
#include <QUrl>
#include <qqmlregistration.h>

class QWebEngineDownloadRequest;

class DownloadModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int publicCount READ publicCount NOTIFY publicCountChanged)
    Q_PROPERTY(int completedCount READ completedCount NOTIFY completedCountChanged)
    Q_PROPERTY(int publicCompletedCount READ publicCompletedCount NOTIFY completedCountChanged)

public:
    enum Roles : int {
        IdRole = Qt::UserRole + 1,
        FileNameRole,
        UrlRole,
        DirectoryRole,
        PathRole,
        StateRole,
        ReceivedBytesRole,
        TotalBytesRole,
        ProgressRole,
        StatusTextRole,
        FinishedRole,
        PausedRole,
        ActiveRole,
        FailedRole,
        StartedAtRole,
        FinishedAtRole,
        PrivateRole,
    };
    Q_ENUM(Roles)

    explicit DownloadModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_items.size()); }
    int publicCount() const;
    int completedCount() const;
    int publicCompletedCount() const;

    Q_INVOKABLE int acceptDownload(QObject *download, const QString &directory,
                                   const QString &fileName, bool privateDownload);
    Q_INVOKABLE bool canNormalizeDirectory(const QString &directory) const;
    Q_INVOKABLE bool directoryExists(const QString &directory) const;
    Q_INVOKABLE bool createDirectory(const QString &directory) const;
    Q_INVOKABLE QString normalizedDirectoryPath(const QString &directory) const;
    Q_INVOKABLE void pause(int id);
    Q_INVOKABLE void resume(int id);
    Q_INVOKABLE void cancel(int id);
    Q_INVOKABLE void open(int id) const;
    Q_INVOKABLE void reveal(int id) const;
    Q_INVOKABLE void remove(int id);
    Q_INVOKABLE int clearCompleted(bool includePrivate = false);
    Q_INVOKABLE void clearPrivateDownloads();

signals:
    void countChanged();
    void publicCountChanged();
    void completedCountChanged();
    void changed();

private:
    struct Item {
        int id = -1;
        QPointer<QWebEngineDownloadRequest> request;
        QString fileName;
        QString url;
        QString directory;
        int state = 0;
        qint64 receivedBytes = 0;
        qint64 totalBytes = 0;
        bool finished = false;
        bool paused = false;
        bool privateDownload = false;
        QDateTime startedAt;
        QDateTime finishedAt;
    };

    QList<Item> m_items;
    QSettings m_store;
    int m_nextId = 1;

    int indexOfId(int id) const;
    int indexOfRequest(QWebEngineDownloadRequest *request) const;
    void refreshFromRequest(int row);
    void touch(int row, const QList<int> &roles);
    void load();
    void save();
    static bool isCompleted(const Item &item);
    static QString fullPath(const Item &item);
    static QString humanBytes(qint64 bytes);
    static QString statusText(const Item &item);
};
