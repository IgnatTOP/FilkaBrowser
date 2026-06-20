#include "QuickLinkModel.h"

#include <algorithm>

namespace {
struct DefaultLink {
    const char *title;
    const char *url;
};

const DefaultLink kDefaults[] = {
    {"YouTube",   "https://youtube.com"},
    {"GitHub",    "https://github.com"},
    {"Wikipedia", "https://wikipedia.org"},
    {"Reddit",    "https://reddit.com"},
};
}

QuickLinkModel::QuickLinkModel(QObject *parent) : QAbstractListModel(parent)
{
    load();
}

int QuickLinkModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

QVariant QuickLinkModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_items.size())
        return {};

    const Item &item = m_items.at(index.row());
    switch (role) {
    case TitleRole: return item.title;
    case UrlRole:   return item.url;
    case HostRole:  return hostOf(item.url);
    default:        return {};
    }
}

QHash<int, QByteArray> QuickLinkModel::roleNames() const
{
    return {
        {TitleRole, "title"},
        {UrlRole, "url"},
        {HostRole, "host"},
    };
}

void QuickLinkModel::load()
{
    const int n = m_store.beginReadArray(QStringLiteral("start/quickLinks"));
    for (int i = 0; i < n; ++i) {
        m_store.setArrayIndex(i);
        const QString url = m_store.value(QStringLiteral("url")).toString();
        const QUrl qurl(url);
        if (!isAcceptableUrl(qurl))
            continue;
        m_items.append({m_store.value(QStringLiteral("title")).toString(), normalizedUrl(qurl)});
        if (m_items.last().title.isEmpty())
            m_items.last().title = hostOf(m_items.last().url);
    }
    m_store.endArray();

    if (m_items.isEmpty()) {
        installDefaults();
        save();
    }
}

void QuickLinkModel::installDefaults()
{
    m_items.clear();
    for (const DefaultLink &link : kDefaults)
        m_items.append({QString::fromLatin1(link.title), QString::fromLatin1(link.url)});
}

void QuickLinkModel::save()
{
    if (m_saveSuspended) {
        m_savePending = true;
        return;
    }

    m_savePending = false;
    m_store.beginWriteArray(QStringLiteral("start/quickLinks"), m_items.size());
    for (int i = 0; i < m_items.size(); ++i) {
        m_store.setArrayIndex(i);
        m_store.setValue(QStringLiteral("title"), m_items.at(i).title);
        m_store.setValue(QStringLiteral("url"), m_items.at(i).url);
    }
    m_store.endArray();
    m_store.sync();
}

bool QuickLinkModel::isAcceptableUrl(const QUrl &url)
{
    return url.isValid()
        && (url.scheme() == QLatin1String("http")
            || url.scheme() == QLatin1String("https"));
}

QString QuickLinkModel::normalizedUrl(const QUrl &url)
{
    return url.adjusted(QUrl::NormalizePathSegments).toString(QUrl::RemovePassword);
}

QString QuickLinkModel::titleOrHost(const QString &title, const QUrl &url)
{
    const QString trimmed = title.trimmed();
    return trimmed.isEmpty() ? hostOf(normalizedUrl(url)) : trimmed;
}

QString QuickLinkModel::hostOf(const QString &url)
{
    const QUrl qurl(url);
    QString host = qurl.host();
    if (host.startsWith(QLatin1String("www.")))
        host.remove(0, 4);
    return host.isEmpty() ? url : host;
}

void QuickLinkModel::add(const QString &title, const QUrl &url)
{
    if (!isAcceptableUrl(url))
        return;

    const int row = m_items.size();
    beginInsertRows({}, row, row);
    m_items.append({titleOrHost(title, url), normalizedUrl(url)});
    endInsertRows();
    emit countChanged();
    emit changed();
    save();
}

void QuickLinkModel::update(int index, const QString &title, const QUrl &url)
{
    if (index < 0 || index >= m_items.size() || !isAcceptableUrl(url))
        return;

    Item &item = m_items[index];
    const QString nextTitle = titleOrHost(title, url);
    const QString nextUrl = normalizedUrl(url);
    if (item.title == nextTitle && item.url == nextUrl)
        return;

    item.title = nextTitle;
    item.url = nextUrl;
    const QModelIndex mi = createIndex(index, 0);
    emit dataChanged(mi, mi, {TitleRole, UrlRole, HostRole});
    emit changed();
    save();
}

void QuickLinkModel::remove(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    beginRemoveRows({}, index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
    emit changed();
    save();
}

QVariantMap QuickLinkModel::takeForUndo(int index)
{
    if (index < 0 || index >= m_items.size())
        return {};

    const Item item = m_items.at(index);
    beginRemoveRows({}, index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
    emit changed();
    m_saveSuspended = true;
    m_savePending = true;

    return QVariantMap{
        {QStringLiteral("index"), index},
        {QStringLiteral("title"), item.title},
        {QStringLiteral("url"), item.url},
    };
}

void QuickLinkModel::restoreForUndo(int index, const QString &title, const QUrl &url)
{
    if (!isAcceptableUrl(url))
        return;

    const int row = std::clamp(index, 0, m_items.size());
    beginInsertRows({}, row, row);
    m_items.insert(row, {titleOrHost(title, url), normalizedUrl(url)});
    endInsertRows();
    emit countChanged();
    emit changed();
    m_saveSuspended = false;
    save();
}

void QuickLinkModel::saveState()
{
    if (!m_saveSuspended && !m_savePending)
        return;

    m_saveSuspended = false;
    save();
}

void QuickLinkModel::move(int from, int to)
{
    if (from < 0 || from >= m_items.size() || to < 0 || to >= m_items.size() || from == to)
        return;

    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_items.move(from, to);
    endMoveRows();
    emit changed();
    save();
}

void QuickLinkModel::resetDefaults()
{
    beginResetModel();
    installDefaults();
    endResetModel();
    emit countChanged();
    emit changed();
    save();
}

QVariantList QuickLinkModel::search(const QString &query, int limit) const
{
    QVariantList out;
    const QString q = query.trimmed();
    if (limit <= 0)
        return out;

    for (int i = 0; i < m_items.size() && out.size() < limit; ++i) {
        const Item &item = m_items.at(i);
        if (!q.isEmpty()
            && !item.title.contains(q, Qt::CaseInsensitive)
            && !item.url.contains(q, Qt::CaseInsensitive)) {
            continue;
        }
        out.append(QVariantMap{
            {QStringLiteral("title"), item.title},
            {QStringLiteral("url"), item.url},
            {QStringLiteral("host"), hostOf(item.url)},
            {QStringLiteral("index"), i},
        });
    }
    return out;
}
