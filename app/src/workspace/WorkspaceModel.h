// WorkspaceModel — the list of workspaces (Work / Dev / Personal / Study).
//
// Each workspace owns its own TabModel, so every workspace keeps an independent
// set of tabs. The views for all workspaces stay alive in QML (Arc-style), so
// switching workspaces is instant and never reloads pages. `activeTabs` exposes
// the current workspace's TabModel for the tab strip and toolbar.

#pragma once

#include <QAbstractListModel>
#include <QColor>
#include <QList>
#include <QSettings>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <qqmlregistration.h>

#include "TabModel.h"

class WorkspaceModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int activeIndex READ activeIndex WRITE setActiveIndex NOTIFY activeIndexChanged)
    Q_PROPERTY(TabModel *activeTabs READ activeTabs NOTIFY activeIndexChanged)
    Q_PROPERTY(QColor activeAccent READ activeAccent NOTIFY activeIndexChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY activeNameChanged)
    Q_PROPERTY(QVariantList audibleTabs READ audibleTabs NOTIFY tabSummariesChanged)

public:
    enum Roles : int {
        NameRole = Qt::UserRole + 1,
        GlyphRole,
        AccentRole,
        TabsRole,
    };
    Q_ENUM(Roles)

    explicit WorkspaceModel(QObject *parent = nullptr);
    ~WorkspaceModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_items.size()); }
    int activeIndex() const { return m_activeIndex; }
    void setActiveIndex(int index);

    TabModel *activeTabs() const;
    QColor activeAccent() const;
    QString activeName() const;
    QVariantList audibleTabs() const;

    Q_INVOKABLE TabModel *tabsAt(int index) const;
    Q_INVOKABLE QVariantList allTabEntries(const QString &query = {}) const;
    Q_INVOKABLE QVariantList audibleTabEntries() const;
    Q_INVOKABLE void activateTab(int workspaceIndex, int tabIndex);
    Q_INVOKABLE void closeTab(int workspaceIndex, int tabIndex);
    Q_INVOKABLE void setTabMuted(int workspaceIndex, int tabIndex, bool muted);
    Q_INVOKABLE int addWorkspace(const QString &name, const QString &glyph = QStringLiteral("globe"),
                                 const QColor &accent = QColor("#8B5CF6"));
    Q_INVOKABLE void renameWorkspace(int index, const QString &name);
    Q_INVOKABLE void setWorkspaceGlyph(int index, const QString &glyph);
    Q_INVOKABLE void setWorkspaceAccent(int index, const QColor &accent);
    Q_INVOKABLE void removeWorkspace(int index);
    Q_INVOKABLE void moveWorkspace(int from, int to);
    Q_INVOKABLE void resetWorkspaces();

signals:
    void countChanged();
    void activeIndexChanged();
    void activeNameChanged();
    void tabSummariesChanged();

private:
    struct Workspace {
        QString name;
        QString glyph;
        QColor accent;
        TabModel *tabs = nullptr;
    };

    QList<Workspace> m_items;
    int m_activeIndex = 0;
    bool m_ownsSession = false;

    // True once the primary window has claimed the persisted session (see .cpp).
    static bool s_sessionOwned;

    QSettings m_store;
    QTimer m_saveTimer;

    bool valid(int index) const { return index >= 0 && index < int(m_items.size()); }
    int appendWorkspaceSilently(const QString &name, const QString &glyph, const QColor &accent,
                                const QUrl &home);
    int appendWorkspace(const QString &name, const QString &glyph, const QColor &accent,
                        const QUrl &home);

    // Session persistence (open tabs per workspace, debounced writes).
    void loadWorkspaceDefinitions();
    void saveWorkspaceDefinitions();
    void installDefaultWorkspaces();
    void restoreSession();
    void saveSession();
    void scheduleSave();
    void connectTabAutosave(TabModel *tabs);
    void connectTabSummarySignals(TabModel *tabs);
};
