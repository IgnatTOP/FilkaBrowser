#include "DownloadModel.h"

#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QtWebEngineCore/QWebEngineDownloadRequest>

DownloadModel::DownloadModel(QObject *parent) : QAbstractListModel(parent)
{
    load();
}

int DownloadModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

int DownloadModel::publicCount() const
{
    int visible = 0;
    for (const Item &item : m_items) {
        if (!item.privateDownload)
            ++visible;
    }
    return visible;
}

QVariant DownloadModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_items.size())
        return {};

    const Item &item = m_items.at(index.row());
    const bool active = item.state == QWebEngineDownloadRequest::DownloadRequested
                     || item.state == QWebEngineDownloadRequest::DownloadInProgress;
    const bool failed = item.state == QWebEngineDownloadRequest::DownloadCancelled
                     || item.state == QWebEngineDownloadRequest::DownloadInterrupted;

    switch (role) {
    case IdRole:            return item.id;
    case FileNameRole:      return item.fileName;
    case UrlRole:           return item.url;
    case DirectoryRole:     return item.directory;
    case PathRole:          return fullPath(item);
    case StateRole:         return item.state;
    case ReceivedBytesRole: return item.receivedBytes;
    case TotalBytesRole:    return item.totalBytes;
    case ProgressRole:      return item.totalBytes > 0 ? double(item.receivedBytes) / double(item.totalBytes) : 0.0;
    case StatusTextRole:    return statusText(item);
    case FinishedRole:      return item.finished;
    case PausedRole:        return item.paused;
    case ActiveRole:        return active;
    case FailedRole:        return failed;
    case StartedAtRole:     return item.startedAt;
    case FinishedAtRole:    return item.finishedAt;
    case PrivateRole:       return item.privateDownload;
    }
    return {};
}

QHash<int, QByteArray> DownloadModel::roleNames() const
{
    static const QHash<int, QByteArray> roles = {
        {IdRole, "downloadId"},
        {FileNameRole, "fileName"},
        {UrlRole, "url"},
        {DirectoryRole, "directory"},
        {PathRole, "path"},
        {StateRole, "state"},
        {ReceivedBytesRole, "receivedBytes"},
        {TotalBytesRole, "totalBytes"},
        {ProgressRole, "progress"},
        {StatusTextRole, "statusText"},
        {FinishedRole, "finished"},
        {PausedRole, "paused"},
        {ActiveRole, "activeDownload"},
        {FailedRole, "failed"},
        {StartedAtRole, "startedAt"},
        {FinishedAtRole, "finishedAt"},
        {PrivateRole, "privateDownload"},
    };
    return roles;
}

void DownloadModel::load()
{
    const int n = m_store.beginReadArray(QStringLiteral("downloads/history"));
    for (int i = 0; i < n; ++i) {
        m_store.setArrayIndex(i);
        Item item;
        item.id = m_nextId++;
        item.fileName = m_store.value(QStringLiteral("fileName")).toString();
        item.url = m_store.value(QStringLiteral("url")).toString();
        item.directory = m_store.value(QStringLiteral("directory")).toString();
        item.state = m_store.value(QStringLiteral("state"),
                                   QWebEngineDownloadRequest::DownloadCompleted).toInt();
        item.receivedBytes = m_store.value(QStringLiteral("receivedBytes")).toLongLong();
        item.totalBytes = m_store.value(QStringLiteral("totalBytes")).toLongLong();
        item.finished = true;
        item.startedAt = m_store.value(QStringLiteral("startedAt")).toDateTime();
        item.finishedAt = m_store.value(QStringLiteral("finishedAt")).toDateTime();
        item.privateDownload = false;
        if (!item.fileName.isEmpty())
            m_items.append(item);
    }
    m_store.endArray();
}

void DownloadModel::save()
{
    QList<Item> persistable;
    for (const Item &item : m_items) {
        if (item.finished && !item.privateDownload)
            persistable.append(item);
    }
    while (persistable.size() > 100)
        persistable.removeLast();

    m_store.beginWriteArray(QStringLiteral("downloads/history"), persistable.size());
    for (int i = 0; i < persistable.size(); ++i) {
        const Item &item = persistable.at(i);
        m_store.setArrayIndex(i);
        m_store.setValue(QStringLiteral("fileName"), item.fileName);
        m_store.setValue(QStringLiteral("url"), item.url);
        m_store.setValue(QStringLiteral("directory"), item.directory);
        m_store.setValue(QStringLiteral("state"), item.state);
        m_store.setValue(QStringLiteral("receivedBytes"), item.receivedBytes);
        m_store.setValue(QStringLiteral("totalBytes"), item.totalBytes);
        m_store.setValue(QStringLiteral("startedAt"), item.startedAt);
        m_store.setValue(QStringLiteral("finishedAt"), item.finishedAt);
    }
    m_store.endArray();
    m_store.sync();
}

int DownloadModel::indexOfId(int id) const
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).id == id)
            return i;
    }
    return -1;
}

int DownloadModel::indexOfRequest(QWebEngineDownloadRequest *request) const
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).request == request)
            return i;
    }
    return -1;
}

int DownloadModel::acceptDownload(QObject *download, const QString &directory,
                                  const QString &fileName, bool privateDownload)
{
    auto *request = qobject_cast<QWebEngineDownloadRequest *>(download);
    if (!request)
        return -1;

    int row = indexOfRequest(request);
    const bool isNewRequest = row < 0;
    if (isNewRequest) {
        row = 0;
        beginInsertRows({}, row, row);
        Item item;
        item.id = m_nextId++;
        item.request = request;
        item.startedAt = QDateTime::currentDateTimeUtc();
        item.privateDownload = privateDownload;
        m_items.prepend(item);
        endInsertRows();
        emit countChanged();
        emit publicCountChanged();
    } else {
        m_items[row].privateDownload = privateDownload;
        emit publicCountChanged();
    }

    if (!directory.trimmed().isEmpty()) {
        QDir().mkpath(directory.trimmed());
        request->setDownloadDirectory(QDir(directory.trimmed()).absolutePath());
    }
    if (!fileName.trimmed().isEmpty())
        request->setDownloadFileName(QFileInfo(fileName.trimmed()).fileName());

    refreshFromRequest(row);

    if (isNewRequest) {
        connect(request, &QWebEngineDownloadRequest::stateChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i < 0) return;
            refreshFromRequest(i);
            if (m_items.at(i).finished)
                save();
        });
        connect(request, &QWebEngineDownloadRequest::receivedBytesChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i >= 0) refreshFromRequest(i);
        });
        connect(request, &QWebEngineDownloadRequest::totalBytesChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i >= 0) refreshFromRequest(i);
        });
        connect(request, &QWebEngineDownloadRequest::isPausedChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i >= 0) refreshFromRequest(i);
        });
        connect(request, &QWebEngineDownloadRequest::downloadDirectoryChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i >= 0) refreshFromRequest(i);
        });
        connect(request, &QWebEngineDownloadRequest::downloadFileNameChanged, this, [this, request] {
            const int i = indexOfRequest(request);
            if (i >= 0) refreshFromRequest(i);
        });
    }

    request->accept();
    emit changed();
    return m_items.at(row).id;
}

void DownloadModel::refreshFromRequest(int row)
{
    if (row < 0 || row >= m_items.size() || !m_items[row].request)
        return;

    auto *request = m_items[row].request.data();
    Item &item = m_items[row];
    item.fileName = request->downloadFileName().isEmpty()
        ? request->suggestedFileName()
        : request->downloadFileName();
    item.directory = request->downloadDirectory();
    item.url = request->url().toString();
    item.state = request->state();
    item.receivedBytes = request->receivedBytes();
    item.totalBytes = request->totalBytes();
    item.paused = request->isPaused();
    item.finished = request->isFinished();
    if (item.finished && !item.finishedAt.isValid())
        item.finishedAt = QDateTime::currentDateTimeUtc();
    touch(row, {FileNameRole, UrlRole, DirectoryRole, PathRole, StateRole,
                ReceivedBytesRole, TotalBytesRole, ProgressRole, StatusTextRole,
                FinishedRole, PausedRole, ActiveRole, FailedRole, StartedAtRole,
                FinishedAtRole, PrivateRole});
}

void DownloadModel::touch(int row, const QList<int> &roles)
{
    if (row < 0 || row >= m_items.size())
        return;
    const QModelIndex mi = createIndex(row, 0);
    emit dataChanged(mi, mi, roles);
    emit changed();
}

void DownloadModel::pause(int id)
{
    const int row = indexOfId(id);
    if (row >= 0 && m_items.at(row).request)
        m_items.at(row).request->pause();
}

void DownloadModel::resume(int id)
{
    const int row = indexOfId(id);
    if (row >= 0 && m_items.at(row).request)
        m_items.at(row).request->resume();
}

void DownloadModel::cancel(int id)
{
    const int row = indexOfId(id);
    if (row >= 0 && m_items.at(row).request)
        m_items.at(row).request->cancel();
}

void DownloadModel::open(int id) const
{
    const int row = indexOfId(id);
    if (row >= 0)
        QDesktopServices::openUrl(QUrl::fromLocalFile(fullPath(m_items.at(row))));
}

void DownloadModel::reveal(int id) const
{
    const int row = indexOfId(id);
    if (row >= 0)
        QDesktopServices::openUrl(QUrl::fromLocalFile(m_items.at(row).directory));
}

void DownloadModel::remove(int id)
{
    const int row = indexOfId(id);
    if (row < 0)
        return;
    if (m_items.at(row).request && !m_items.at(row).finished)
        m_items.at(row).request->cancel();

    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
    emit countChanged();
    emit publicCountChanged();
    emit changed();
    save();
}

void DownloadModel::clearCompleted(bool includePrivate)
{
    for (int i = m_items.size() - 1; i >= 0; --i) {
        if (!m_items.at(i).finished || (m_items.at(i).privateDownload && !includePrivate))
            continue;
        beginRemoveRows({}, i, i);
        m_items.removeAt(i);
        endRemoveRows();
    }
    emit countChanged();
    emit publicCountChanged();
    emit changed();
    save();
}

void DownloadModel::clearPrivateDownloads()
{
    for (int i = m_items.size() - 1; i >= 0; --i) {
        if (!m_items.at(i).privateDownload)
            continue;
        if (m_items.at(i).request && !m_items.at(i).finished)
            m_items.at(i).request->cancel();
        beginRemoveRows({}, i, i);
        m_items.removeAt(i);
        endRemoveRows();
    }
    emit countChanged();
    emit publicCountChanged();
    emit changed();
    save();
}

QString DownloadModel::fullPath(const Item &item)
{
    return QDir(item.directory).filePath(item.fileName);
}

QString DownloadModel::humanBytes(qint64 bytes)
{
    if (bytes <= 0)
        return QStringLiteral("0 B");
    const QStringList units{
        QStringLiteral("B"), QStringLiteral("KB"), QStringLiteral("MB"), QStringLiteral("GB")
    };
    int unit = 0;
    double value = bytes;
    while (value >= 1024.0 && unit < units.size() - 1) {
        value /= 1024.0;
        ++unit;
    }
    return QStringLiteral("%1 %2").arg(value, 0, 'f', unit == 0 ? 0 : 1).arg(units.at(unit));
}

QString DownloadModel::statusText(const Item &item)
{
    switch (item.state) {
    case QWebEngineDownloadRequest::DownloadCompleted:
        return QObject::tr("%1 - завершено").arg(humanBytes(item.totalBytes));
    case QWebEngineDownloadRequest::DownloadCancelled:
        return QObject::tr("отменено");
    case QWebEngineDownloadRequest::DownloadInterrupted:
        return QObject::tr("прервано");
    case QWebEngineDownloadRequest::DownloadRequested:
    case QWebEngineDownloadRequest::DownloadInProgress:
        break;
    }

    if (item.paused)
        return QObject::tr("%1 из %2 - пауза")
            .arg(humanBytes(item.receivedBytes))
            .arg(humanBytes(item.totalBytes));
    if (item.totalBytes > 0)
        return QObject::tr("%1 из %2")
            .arg(humanBytes(item.receivedBytes))
            .arg(humanBytes(item.totalBytes));
    return QObject::tr("%1 загружено").arg(humanBytes(item.receivedBytes));
}
