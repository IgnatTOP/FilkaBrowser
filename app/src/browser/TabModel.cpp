#include "TabModel.h"

namespace {
// New tabs open Filka's own start page. "about:blank" is the sentinel the QML
// shell watches for to show the welcome/start surface instead of web content.
const QUrl kHomeUrl{QStringLiteral("about:blank")};
}

TabModel::TabModel(QObject *parent) : QAbstractListModel(parent) {}

int TabModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_tabs.size());
}

QVariant TabModel::data(const QModelIndex &index, int role) const
{
    if (!valid(index.row()))
        return {};
    const TabData &t = m_tabs.at(index.row());
    switch (role) {
    case TitleRole:   return t.title;
    case UrlRole:     return t.url;
    case IconRole:    return t.icon;
    case LoadingRole: return t.loading;
    case PinnedRole:  return t.pinned;
    case MutedRole:   return t.muted;
    case AudibleRole: return t.audible;
    default:          return {};
    }
}

QHash<int, QByteArray> TabModel::roleNames() const
{
    return {
        {TitleRole, "title"},
        {UrlRole, "url"},
        {IconRole, "iconUrl"},
        {LoadingRole, "loading"},
        {PinnedRole, "pinned"},
        {MutedRole, "muted"},
        {AudibleRole, "audible"},
    };
}

void TabModel::setActiveIndex(int index)
{
    if (index == m_activeIndex || !valid(index))
        return;
    m_activeIndex = index;
    emit activeIndexChanged();
    emit changed();
}

QStringList TabModel::tabUrls() const
{
    QStringList urls;
    for (const TabData &t : m_tabs)
        urls << t.url.toString();
    return urls;
}

void TabModel::restore(const QStringList &urls, int activeIndex)
{
    if (urls.isEmpty())
        return;
    beginResetModel();
    m_tabs.clear();
    for (const QString &u : urls) {
        TabData t;
        t.url = QUrl(u);
        m_tabs.append(t);
    }
    m_activeIndex = qBound(0, activeIndex, int(m_tabs.size()) - 1);
    endResetModel();
    emit countChanged();
    emit activeIndexChanged();
}

int TabModel::insertTab(int row, const QUrl &url, bool activate)
{
    row = qBound(0, row, int(m_tabs.size()));
    beginInsertRows({}, row, row);
    TabData t;
    t.url = url.isEmpty() ? kHomeUrl : url;
    m_tabs.insert(row, t);
    endInsertRows();
    emit countChanged();
    emit changed();

    // Inserting before the active tab shifts its index by one — keep it pinned
    // to the same tab unless we're explicitly activating the new one.
    if (!activate && row <= m_activeIndex) {
        ++m_activeIndex;
        emit activeIndexChanged();
    }
    if (activate)
        setActiveIndex(row);
    return row;
}

int TabModel::addTab(const QUrl &url, bool activate)
{
    return insertTab(int(m_tabs.size()), url, activate);
}

int TabModel::addTabAfter(int index, const QUrl &url, bool activate)
{
    return insertTab(valid(index) ? index + 1 : int(m_tabs.size()), url, activate);
}

int TabModel::duplicateTab(int index)
{
    if (!valid(index))
        return -1;
    return insertTab(index + 1, m_tabs.at(index).url, true);
}

void TabModel::removeRow(int index)
{
    // Remember the closed tab's URL so Ctrl+Shift+T can bring it back. Blank
    // start-page tabs aren't worth restoring.
    const QUrl url = m_tabs.at(index).url;
    if (url.isValid() && url.toString() != QLatin1String("about:blank")) {
        m_closed.append({url});
        if (m_closed.size() > kMaxClosed)
            m_closed.removeFirst();
    }

    beginRemoveRows({}, index, index);
    m_tabs.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void TabModel::closeTab(int index)
{
    if (!valid(index))
        return;

    removeRow(index);

    if (m_tabs.isEmpty()) {
        addTab();              // never leave the window tab-less
        return;
    }

    // Keep a valid active tab: shift selection left when needed.
    int next = m_activeIndex;
    if (index < m_activeIndex)
        next = m_activeIndex - 1;
    else if (index == m_activeIndex)
        next = m_activeIndex > 0 ? m_activeIndex - 1 : 0;

    const int clamped = qBound(0, next, int(m_tabs.size()) - 1);
    m_activeIndex = clamped;
    emit activeIndexChanged();
    emit changed();
}

void TabModel::closeOthers(int index)
{
    if (!valid(index))
        return;
    // Remove from the back so indices stay valid; skip the kept tab and pinned
    // tabs (closing those would surprise the user, as in Chrome/Firefox).
    for (int i = int(m_tabs.size()) - 1; i >= 0; --i) {
        if (i == index || m_tabs.at(i).pinned)
            continue;
        removeRow(i);
        if (i < index)
            --index;
    }
    m_activeIndex = index;
    emit activeIndexChanged();
    emit changed();
}

void TabModel::closeToRight(int index)
{
    if (!valid(index))
        return;
    bool removed = false;
    for (int i = int(m_tabs.size()) - 1; i > index; --i) {
        if (m_tabs.at(i).pinned)
            continue;
        removeRow(i);
        removed = true;
    }
    if (!removed)
        return;
    if (m_activeIndex > index) {
        m_activeIndex = index;
        emit activeIndexChanged();
    }
    emit changed();
}

int TabModel::reopenClosedTab()
{
    if (m_closed.isEmpty())
        return -1;
    const QUrl url = m_closed.takeLast().url;
    return addTab(url, true);
}

void TabModel::moveTab(int from, int to)
{
    if (!valid(from) || !valid(to) || from == to)
        return;
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_tabs.move(from, to);
    endMoveRows();

    const int oldActive = m_activeIndex;
    if (m_activeIndex == from)
        m_activeIndex = to;
    else if (from < m_activeIndex && m_activeIndex <= to)
        m_activeIndex--;
    else if (to <= m_activeIndex && m_activeIndex < from)
        m_activeIndex++;

    if (m_activeIndex != oldActive)
        emit activeIndexChanged();
}

void TabModel::setPinned(int index, bool pinned)
{
    if (!valid(index) || m_tabs[index].pinned == pinned)
        return;
    m_tabs[index].pinned = pinned;
    touch(index, {PinnedRole});
}

void TabModel::setMuted(int index, bool muted)
{
    if (!valid(index) || m_tabs[index].muted == muted)
        return;
    m_tabs[index].muted = muted;
    touch(index, {MutedRole});
}

void TabModel::updateAudible(int index, bool audible)
{
    if (!valid(index) || m_tabs[index].audible == audible)
        return;
    m_tabs[index].audible = audible;
    touch(index, {AudibleRole});
}

void TabModel::updateTitle(int index, const QString &title)
{
    if (!valid(index) || title.isEmpty() || m_tabs[index].title == title)
        return;
    m_tabs[index].title = title;
    touch(index, {TitleRole});
}

void TabModel::updateUrl(int index, const QUrl &url)
{
    if (!valid(index) || m_tabs[index].url == url)
        return;
    m_tabs[index].url = url;
    touch(index, {UrlRole});
    emit changed();
}

void TabModel::updateIcon(int index, const QUrl &icon)
{
    if (!valid(index) || m_tabs[index].icon == icon)
        return;
    m_tabs[index].icon = icon;
    touch(index, {IconRole});
}

void TabModel::updateLoading(int index, bool loading)
{
    if (!valid(index) || m_tabs[index].loading == loading)
        return;
    m_tabs[index].loading = loading;
    touch(index, {LoadingRole});
}

void TabModel::touch(int index, const QList<int> &roles)
{
    const QModelIndex mi = createIndex(index, 0);
    emit dataChanged(mi, mi, roles);
}
