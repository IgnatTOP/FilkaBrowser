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
#include <qqmlregistration.h>

class TabModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int activeIndex READ activeIndex WRITE setActiveIndex NOTIFY activeIndexChanged)

public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
        IconRole,
        LoadingRole,
        PinnedRole,
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
    Q_INVOKABLE void closeTab(int index);
    Q_INVOKABLE void moveTab(int from, int to);
    Q_INVOKABLE void setPinned(int index, bool pinned);

    // Live state pushed from the tab's WebEngineView.
    Q_INVOKABLE void updateTitle(int index, const QString &title);
    Q_INVOKABLE void updateUrl(int index, const QUrl &url);
    Q_INVOKABLE void updateIcon(int index, const QUrl &icon);
    Q_INVOKABLE void updateLoading(int index, bool loading);

    // Session persistence: the real (non-blank) URLs and a restore helper.
    QStringList tabUrls() const;
    void restore(const QStringList &urls, int activeIndex);

signals:
    void countChanged();
    void activeIndexChanged();
    void changed();   // any structural/url change — used to persist the session

private:
    struct TabData {
        QString title = QStringLiteral("New Tab");
        QUrl url;
        QUrl icon;
        bool loading = false;
        bool pinned = false;
    };

    QList<TabData> m_tabs;
    int m_activeIndex = -1;

    bool valid(int index) const { return index >= 0 && index < int(m_tabs.size()); }
    void touch(int index, const QList<int> &roles);
};
