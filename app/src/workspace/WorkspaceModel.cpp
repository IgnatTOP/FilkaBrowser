#include "WorkspaceModel.h"

#include <utility>

#include <QVariantMap>

// Only the first WorkspaceModel (the primary window) owns the persisted session:
// it restores last run's tabs and writes them back. Additional windows (Ctrl+N)
// open fresh so they don't duplicate or clobber the saved session.
bool WorkspaceModel::s_sessionOwned = false;

namespace {
bool restoreSessionEnabled(QSettings &store)
{
    return store.value(QStringLiteral("general/restoreSessionEnabled"), true).toBool();
}
}

WorkspaceModel::WorkspaceModel(QObject *parent) : QAbstractListModel(parent)
{
    loadWorkspaceDefinitions();
    if (m_items.isEmpty()) {
        installDefaultWorkspaces();
        saveWorkspaceDefinitions();
    }

    if (s_sessionOwned)
        return;                 // secondary window: no restore, no autosave
    s_sessionOwned = true;
    m_ownsSession = true;

    // Reopen last session's tabs, then wire up debounced auto-save.
    if (restoreSessionEnabled(m_store))
        restoreSession();

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(800);
    connect(&m_saveTimer, &QTimer::timeout, this, &WorkspaceModel::saveSession);
    for (const Workspace &ws : m_items) {
        connectTabAutosave(ws.tabs);
        connectTabSummarySignals(ws.tabs);
    }
    connect(this, &WorkspaceModel::activeIndexChanged, this, &WorkspaceModel::scheduleSave);
}

WorkspaceModel::~WorkspaceModel()
{
    if (!m_ownsSession)
        return;
    if (m_saveTimer.isActive())
        m_saveTimer.stop();
    saveSession();
    s_sessionOwned = false;
}

void WorkspaceModel::installDefaultWorkspaces()
{
    appendWorkspaceSilently(QStringLiteral("Работа"),     QStringLiteral("briefcase"),      QColor("#38BDF8"), {});
    appendWorkspaceSilently(QStringLiteral("Личное"),     QStringLiteral("house"),          QColor("#F87171"), {});
    appendWorkspaceSilently(QStringLiteral("Обучение"),   QStringLiteral("graduation-cap"), QColor("#34D399"), {});
    appendWorkspaceSilently(QStringLiteral("Проекты"),    QStringLiteral("code"),           QColor("#8B5CF6"), {});
}

void WorkspaceModel::loadWorkspaceDefinitions()
{
    const int n = m_store.beginReadArray(QStringLiteral("workspaces/items"));
    for (int i = 0; i < n; ++i) {
        m_store.setArrayIndex(i);
        const QString name = m_store.value(QStringLiteral("name")).toString();
        const QString glyph = m_store.value(QStringLiteral("glyph"), QStringLiteral("globe")).toString();
        const QColor accent = m_store.value(QStringLiteral("accent"), QColor("#8B5CF6")).value<QColor>();
        if (!name.trimmed().isEmpty())
            appendWorkspaceSilently(name.trimmed(), glyph, accent.isValid() ? accent : QColor("#8B5CF6"), {});
    }
    m_store.endArray();
}

void WorkspaceModel::saveWorkspaceDefinitions()
{
    m_store.beginWriteArray(QStringLiteral("workspaces/items"), m_items.size());
    for (int i = 0; i < m_items.size(); ++i) {
        m_store.setArrayIndex(i);
        m_store.setValue(QStringLiteral("name"), m_items.at(i).name);
        m_store.setValue(QStringLiteral("glyph"), m_items.at(i).glyph);
        m_store.setValue(QStringLiteral("accent"), m_items.at(i).accent);
    }
    m_store.endArray();
    m_store.sync();
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
    if (!m_ownsSession || !restoreSessionEnabled(m_store))
        return;

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

void WorkspaceModel::scheduleSave()
{
    if (m_ownsSession && restoreSessionEnabled(m_store))
        m_saveTimer.start();
}

void WorkspaceModel::connectTabAutosave(TabModel *tabs)
{
    if (!tabs || !m_ownsSession)
        return;
    connect(tabs, &TabModel::changed, this, &WorkspaceModel::scheduleSave, Qt::UniqueConnection);
}

void WorkspaceModel::connectTabSummarySignals(TabModel *tabs)
{
    if (!tabs)
        return;
    connect(tabs, &TabModel::countChanged, this, &WorkspaceModel::tabSummariesChanged,
            Qt::UniqueConnection);
    connect(tabs, &TabModel::activeIndexChanged, this, &WorkspaceModel::tabSummariesChanged,
            Qt::UniqueConnection);
    connect(tabs, &TabModel::dataChanged, this, &WorkspaceModel::tabSummariesChanged,
            Qt::UniqueConnection);
    connect(tabs, &TabModel::audibleTabsChanged, this, &WorkspaceModel::tabSummariesChanged,
            Qt::UniqueConnection);
}

int WorkspaceModel::appendWorkspaceSilently(const QString &name, const QString &glyph,
                                            const QColor &accent, const QUrl &home)
{
    const int row = m_items.size();
    Workspace ws;
    ws.name = name;
    ws.glyph = glyph;
    ws.accent = accent;
    ws.tabs = new TabModel(this);
    ws.tabs->addTab(home);
    connectTabAutosave(ws.tabs);
    connectTabSummarySignals(ws.tabs);
    m_items.append(ws);
    return row;
}

int WorkspaceModel::appendWorkspace(const QString &name, const QString &glyph,
                                    const QColor &accent, const QUrl &home)
{
    const int row = m_items.size();
    beginInsertRows({}, row, row);
    appendWorkspaceSilently(name, glyph, accent, home);

    endInsertRows();
    emit countChanged();
    emit tabSummariesChanged();
    return row;
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
    }
    return {};
}

QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    static const QHash<int, QByteArray> roles = {
        {NameRole, "name"},
        {GlyphRole, "glyph"},
        {AccentRole, "accent"},
        {TabsRole, "tabs"},
    };
    return roles;
}

void WorkspaceModel::setActiveIndex(int index)
{
    if (index == m_activeIndex || !valid(index))
        return;
    m_activeIndex = index;
    emit activeIndexChanged();
    emit activeNameChanged();
    emit tabSummariesChanged();
}

TabModel *WorkspaceModel::activeTabs() const
{
    return valid(m_activeIndex) ? m_items.at(m_activeIndex).tabs : nullptr;
}

QColor WorkspaceModel::activeAccent() const
{
    return valid(m_activeIndex) ? m_items.at(m_activeIndex).accent : QColor("#8B5CF6");
}

QString WorkspaceModel::activeName() const
{
    return valid(m_activeIndex) ? m_items.at(m_activeIndex).name : QString();
}

QVariantList WorkspaceModel::audibleTabs() const
{
    return audibleTabEntries();
}

TabModel *WorkspaceModel::tabsAt(int index) const
{
    return valid(index) ? m_items.at(index).tabs : nullptr;
}

QVariantList WorkspaceModel::allTabEntries(const QString &query) const
{
    QVariantList out;
    const QString q = query.trimmed();

    for (int workspaceIndex = 0; workspaceIndex < m_items.size(); ++workspaceIndex) {
        const Workspace &ws = m_items.at(workspaceIndex);
        const QVariantList tabs = ws.tabs ? ws.tabs->entries(q, 0) : QVariantList{};

        for (const QVariant &value : tabs) {
            QVariantMap entry = value.toMap();
            entry.insert(QStringLiteral("workspaceIndex"), workspaceIndex);
            entry.insert(QStringLiteral("tabId"), QVariantMap{
                {QStringLiteral("workspaceIndex"), workspaceIndex},
                {QStringLiteral("index"), entry.value(QStringLiteral("index")).toInt()},
            });
            entry.insert(QStringLiteral("workspaceName"), ws.name);
            entry.insert(QStringLiteral("workspaceGlyph"), ws.glyph);
            entry.insert(QStringLiteral("workspaceAccent"), ws.accent);
            entry.insert(QStringLiteral("activeWorkspace"), workspaceIndex == m_activeIndex);
            entry.insert(QStringLiteral("active"), workspaceIndex == m_activeIndex
                         && entry.value(QStringLiteral("index")).toInt() == ws.tabs->activeIndex());
            out.append(entry);
        }
    }

    return out;
}

QVariantList WorkspaceModel::audibleTabEntries() const
{
    QVariantList out;

    for (int workspaceIndex = 0; workspaceIndex < m_items.size(); ++workspaceIndex) {
        const Workspace &ws = m_items.at(workspaceIndex);
        const QVariantList tabs = ws.tabs ? ws.tabs->audibleTabs() : QVariantList{};

        for (const QVariant &value : tabs) {
            QVariantMap entry = value.toMap();
            entry.insert(QStringLiteral("workspaceIndex"), workspaceIndex);
            entry.insert(QStringLiteral("tabId"), QVariantMap{
                {QStringLiteral("workspaceIndex"), workspaceIndex},
                {QStringLiteral("index"), entry.value(QStringLiteral("index")).toInt()},
            });
            entry.insert(QStringLiteral("workspaceName"), ws.name);
            entry.insert(QStringLiteral("workspaceGlyph"), ws.glyph);
            entry.insert(QStringLiteral("workspaceAccent"), ws.accent);
            entry.insert(QStringLiteral("activeWorkspace"), workspaceIndex == m_activeIndex);
            out.append(entry);
        }
    }

    return out;
}

void WorkspaceModel::activateTab(int workspaceIndex, int tabIndex)
{
    if (!valid(workspaceIndex) || !m_items.at(workspaceIndex).tabs)
        return;
    setActiveIndex(workspaceIndex);
    m_items.at(workspaceIndex).tabs->setActiveIndex(tabIndex);
}

void WorkspaceModel::closeTab(int workspaceIndex, int tabIndex)
{
    if (!valid(workspaceIndex) || !m_items.at(workspaceIndex).tabs)
        return;
    m_items.at(workspaceIndex).tabs->closeTab(tabIndex);
}

void WorkspaceModel::setTabMuted(int workspaceIndex, int tabIndex, bool muted)
{
    if (!valid(workspaceIndex) || !m_items.at(workspaceIndex).tabs)
        return;
    m_items.at(workspaceIndex).tabs->setMuted(tabIndex, muted);
}

int WorkspaceModel::moveTabToWorkspace(int fromWorkspace, int tabIndex, int toWorkspace, bool activateMoved)
{
    if (!valid(fromWorkspace) || !valid(toWorkspace) || fromWorkspace == toWorkspace)
        return -1;

    TabModel *source = m_items.at(fromWorkspace).tabs;
    TabModel *target = m_items.at(toWorkspace).tabs;
    if (!source || !target)
        return -1;

    const int movedIndex = source->moveTabTo(target, tabIndex, activateMoved);
    if (movedIndex < 0)
        return -1;

    emit tabSummariesChanged();
    if (activateMoved) {
        setActiveIndex(toWorkspace);
        target->setActiveIndex(movedIndex);
    } else {
        scheduleSave();
    }
    return movedIndex;
}

int WorkspaceModel::addWorkspace(const QString &name, const QString &glyph, const QColor &accent)
{
    const QString cleanName = name.trimmed().isEmpty()
        ? QStringLiteral("Новое пространство") : name.trimmed();
    const int row = appendWorkspace(cleanName, glyph.trimmed().isEmpty() ? QStringLiteral("globe") : glyph,
                                    accent.isValid() ? accent : QColor("#8B5CF6"), {});
    setActiveIndex(row);
    saveWorkspaceDefinitions();
    scheduleSave();
    return row;
}

void WorkspaceModel::renameWorkspace(int index, const QString &name)
{
    if (!valid(index))
        return;
    const QString cleanName = name.trimmed();
    if (cleanName.isEmpty() || m_items[index].name == cleanName)
        return;
    m_items[index].name = cleanName;
    const QModelIndex mi = createIndex(index, 0);
    emit dataChanged(mi, mi, {NameRole});
    if (index == m_activeIndex)
        emit activeNameChanged();
    saveWorkspaceDefinitions();
}

void WorkspaceModel::setWorkspaceGlyph(int index, const QString &glyph)
{
    if (!valid(index))
        return;
    const QString cleanGlyph = glyph.trimmed().isEmpty() ? QStringLiteral("globe") : glyph.trimmed();
    if (m_items[index].glyph == cleanGlyph)
        return;
    m_items[index].glyph = cleanGlyph;
    const QModelIndex mi = createIndex(index, 0);
    emit dataChanged(mi, mi, {GlyphRole});
    saveWorkspaceDefinitions();
}

void WorkspaceModel::setWorkspaceAccent(int index, const QColor &accent)
{
    if (!valid(index) || !accent.isValid() || m_items[index].accent == accent)
        return;
    m_items[index].accent = accent;
    const QModelIndex mi = createIndex(index, 0);
    emit dataChanged(mi, mi, {AccentRole});
    if (index == m_activeIndex)
        emit activeIndexChanged();
    saveWorkspaceDefinitions();
}

void WorkspaceModel::removeWorkspace(int index)
{
    if (!valid(index) || m_items.size() <= 1)
        return;

    const QString previousActiveName = activeName();
    Workspace doomed = m_items.at(index);
    beginRemoveRows({}, index, index);
    m_items.removeAt(index);
    endRemoveRows();
    if (doomed.tabs)
        doomed.tabs->deleteLater();

    if (m_activeIndex >= m_items.size())
        m_activeIndex = m_items.size() - 1;
    else if (index < m_activeIndex)
        --m_activeIndex;
    emit countChanged();
    emit activeIndexChanged();
    emit tabSummariesChanged();
    if (activeName() != previousActiveName)
        emit activeNameChanged();
    saveWorkspaceDefinitions();
    scheduleSave();
}

void WorkspaceModel::moveWorkspace(int from, int to)
{
    if (!valid(from) || !valid(to) || from == to)
        return;
    const QString previousActiveName = activeName();
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_items.move(from, to);
    endMoveRows();

    if (m_activeIndex == from)
        m_activeIndex = to;
    else if (from < m_activeIndex && m_activeIndex <= to)
        --m_activeIndex;
    else if (to <= m_activeIndex && m_activeIndex < from)
        ++m_activeIndex;
    emit activeIndexChanged();
    emit tabSummariesChanged();
    if (activeName() != previousActiveName)
        emit activeNameChanged();
    saveWorkspaceDefinitions();
    scheduleSave();
}

void WorkspaceModel::resetWorkspaces()
{
    const QString previousActiveName = activeName();
    beginResetModel();
    for (const Workspace &ws : std::as_const(m_items)) {
        if (ws.tabs)
            ws.tabs->deleteLater();
    }
    m_items.clear();
    installDefaultWorkspaces();
    m_activeIndex = 0;
    endResetModel();
    emit countChanged();
    emit activeIndexChanged();
    emit tabSummariesChanged();
    if (activeName() != previousActiveName)
        emit activeNameChanged();
    saveWorkspaceDefinitions();
    scheduleSave();
}
