#include "WorkspaceModel.h"

WorkspaceModel::WorkspaceModel(QObject *parent) : QAbstractListModel(parent)
{
    // Default workspaces. Accents echo the aurora palette from the design system.
    // Each opens on Filka's start page (empty URL -> "about:blank" sentinel).
    addWorkspace(QStringLiteral("Работа"),     QStringLiteral("briefcase"),      QColor("#2E7CF6"), {});
    addWorkspace(QStringLiteral("Разработка"), QStringLiteral("code"),           QColor("#22D3EE"), {});
    addWorkspace(QStringLiteral("Личное"),     QStringLiteral("house"),          QColor("#8B5CF6"), {});
    addWorkspace(QStringLiteral("Учёба"),      QStringLiteral("graduation-cap"), QColor("#34D399"), {});

    // Reopen last session's tabs, then wire up debounced auto-save.
    restoreSession();

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(800);
    connect(&m_saveTimer, &QTimer::timeout, this, &WorkspaceModel::saveSession);
    for (const Workspace &ws : m_items)
        connect(ws.tabs, &TabModel::changed, this, &WorkspaceModel::scheduleSave);
    connect(this, &WorkspaceModel::activeIndexChanged, this, &WorkspaceModel::scheduleSave);
}

void WorkspaceModel::restoreSession()
{
    const int n = m_store.beginReadArray(QStringLiteral("session/workspaces"));
    for (int i = 0; i < n && i < m_items.size(); ++i) {
        m_store.setArrayIndex(i);
        const QStringList urls = m_store.value(QStringLiteral("tabs")).toStringList();
        const int active = m_store.value(QStringLiteral("active"), 0).toInt();
        if (!urls.isEmpty())
            m_items.at(i).tabs->restore(urls, active);
    }
    m_store.endArray();

    const int activeWs = m_store.value(QStringLiteral("session/activeWorkspace"), 0).toInt();
    if (valid(activeWs))
        m_activeIndex = activeWs;
}

void WorkspaceModel::saveSession()
{
    m_store.beginWriteArray(QStringLiteral("session/workspaces"), m_items.size());
    for (int i = 0; i < m_items.size(); ++i) {
        m_store.setArrayIndex(i);
        m_store.setValue(QStringLiteral("tabs"), m_items.at(i).tabs->tabUrls());
        m_store.setValue(QStringLiteral("active"), m_items.at(i).tabs->activeIndex());
    }
    m_store.endArray();
    m_store.setValue(QStringLiteral("session/activeWorkspace"), m_activeIndex);
    m_store.sync();
}

void WorkspaceModel::addWorkspace(const QString &name, const QString &glyph,
                                  const QColor &accent, const QUrl &home)
{
    const int row = m_items.size();
    beginInsertRows({}, row, row);

    Workspace ws;
    ws.name = name;
    ws.glyph = glyph;
    ws.accent = accent;
    ws.tabs = new TabModel(this);
    ws.tabs->addTab(home);
    m_items.append(ws);

    endInsertRows();
    emit countChanged();
}

int WorkspaceModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

QVariant WorkspaceModel::data(const QModelIndex &index, int role) const
{
    if (!valid(index.row()))
        return {};
    const Workspace &w = m_items.at(index.row());
    switch (role) {
    case NameRole:   return w.name;
    case GlyphRole:  return w.glyph;
    case AccentRole: return w.accent;
    case TabsRole:   return QVariant::fromValue(w.tabs);
    default:         return {};
    }
}

QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {GlyphRole, "glyph"},
        {AccentRole, "accent"},
        {TabsRole, "tabs"},
    };
}

void WorkspaceModel::setActiveIndex(int index)
{
    if (index == m_activeIndex || !valid(index))
        return;
    m_activeIndex = index;
    emit activeIndexChanged();
}

TabModel *WorkspaceModel::activeTabs() const
{
    return valid(m_activeIndex) ? m_items.at(m_activeIndex).tabs : nullptr;
}

QColor WorkspaceModel::activeAccent() const
{
    return valid(m_activeIndex) ? m_items.at(m_activeIndex).accent : QColor("#2E7CF6");
}

TabModel *WorkspaceModel::tabsAt(int index) const
{
    return valid(index) ? m_items.at(index).tabs : nullptr;
}
