// TabModel — source of truth for browser tabs (metadata + active index).
//
// The model owns tab *metadata* (title, url, favicon, loading, pinned). Each
// tab's live Qt WebEngine view lives in QML; it pushes state back here via the
// update* invokables, and reads its initial url once on creation. Navigation is
// driven against the active view directly, so url stays one-way (view -> model)
// and there are no binding loops.

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <qqmlregistration.h>

class TabModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int activeIndex READ activeIndex WRITE setActiveIndex NOTIFY activeIndexChanged)
    Q_PROPERTY(QVariantList audibleTabs READ audibleTabs NOTIFY audibleTabsChanged)

public:
    enum Roles : int {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
        IconRole,
        LoadingRole,
        PinnedRole,
        MutedRole,
        AudibleRole,
    };
    Q_ENUM(Roles)

    explicit TabModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_tabs.size()); }
    int activeIndex() const { return m_activeIndex; }
    void setActiveIndex(int index);

    // Tab lifecycle.
    Q_INVOKABLE int addTab(const QUrl &url = {}, bool activate = true);
    // Insert a new tab right after `index` (browser-standard placement for
    // "duplicate"/"open in new tab"). Returns the new row.
    Q_INVOKABLE int addTabAfter(int index, const QUrl &url = {}, bool activate = true);
    Q_INVOKABLE int duplicateTab(int index);
    Q_INVOKABLE void closeTab(int index);
    Q_INVOKABLE void closeOthers(int index);
    Q_INVOKABLE void closeToRight(int index);
    Q_INVOKABLE void moveTab(int from, int to);
    int moveTabTo(TabModel *target, int index, bool activate);
    Q_INVOKABLE void setPinned(int index, bool pinned);
    Q_INVOKABLE void setMuted(int index, bool muted);
    Q_INVOKABLE bool isMuted(int index) const { return valid(index) && m_tabs[index].muted; }

    // Reopen the most recently closed tab (Ctrl+Shift+T). Returns its new row,
    // or -1 when the closed-tab stack is empty.
    Q_INVOKABLE int reopenClosedTab();
    Q_INVOKABLE bool hasClosedTabs() const { return !m_closed.isEmpty(); }

    // Live state pushed from the tab's WebEngineView.
    Q_INVOKABLE void updateTitle(int index, const QString &title);
    Q_INVOKABLE void updateUrl(int index, const QUrl &url);
    Q_INVOKABLE void updateIcon(int index, const QUrl &icon);
    Q_INVOKABLE void updateLoading(int index, bool loading);
    Q_INVOKABLE void updateAudible(int index, bool audible);

    // Session persistence: the real (non-blank) URLs and a restore helper.
    QStringList tabUrls() const;
    void restore(const QStringList &urls, int activeIndex);
    Q_INVOKABLE QVariantList entries(const QString &query = {}, int limit = 12) const;
    QVariantList audibleTabs() const;

signals:
    void countChanged();
    void activeIndexChanged();
    void audibleTabsChanged();
    void changed();   // any structural/url change — used to persist the session

private:
    struct TabData {
        QString title = QStringLiteral("Новая вкладка");
        QUrl url;
        QUrl icon;
        bool loading = false;
        bool pinned = false;
        bool muted = false;
        bool audible = false;
    };

    QList<TabData> m_tabs;
    int m_activeIndex = -1;

    // Recently-closed tabs (newest last), for Ctrl+Shift+T. Capped so the
    // window never holds an unbounded history of dead tabs.
    struct ClosedTab { QUrl url; };
    QList<ClosedTab> m_closed;
    static constexpr int kMaxClosed = 25;

    // Shared insert + remove primitives used by the lifecycle invokables.
    int insertTab(int row, const QUrl &url, bool activate);
    int insertTabData(int row, const TabData &tab, bool activate);
    void removeRow(int index);

    bool valid(int index) const { return index >= 0 && index < int(m_tabs.size()); }
    void touch(int index, const QList<int> &roles);
};
