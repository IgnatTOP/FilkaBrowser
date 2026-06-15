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

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        GlyphRole,
        AccentRole,
        TabsRole,
    };
    Q_ENUM(Roles)

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_items.size()); }
    int activeIndex() const { return m_activeIndex; }
    void setActiveIndex(int index);

    TabModel *activeTabs() const;
    QColor activeAccent() const;

    Q_INVOKABLE TabModel *tabsAt(int index) const;

signals:
    void countChanged();
    void activeIndexChanged();

private:
    struct Workspace {
        QString name;
        QString glyph;
        QColor accent;
        TabModel *tabs = nullptr;
    };

    QList<Workspace> m_items;
    int m_activeIndex = 0;

    QSettings m_store;
    QTimer m_saveTimer;

    bool valid(int index) const { return index >= 0 && index < int(m_items.size()); }
    void addWorkspace(const QString &name, const QString &glyph, const QColor &accent,
                      const QUrl &home);

    // Session persistence (open tabs per workspace, debounced writes).
    void restoreSession();
    void saveSession();
    void scheduleSave() { m_saveTimer.start(); }
};
