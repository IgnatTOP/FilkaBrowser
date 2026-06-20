// QuickLinkModel — persistent editable shortcuts for the start page.
//
// The model is intentionally small: title + URL + order. It is shared by the
// start page and command palette, and persists through QSettings.

#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QSettings>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlregistration.h>

class QuickLinkModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        UrlRole,
        HostRole,
    };
    Q_ENUM(Roles)

    explicit QuickLinkModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_items.size()); }

    Q_INVOKABLE void add(const QString &title, const QUrl &url);
    Q_INVOKABLE void insert(int index, const QString &title, const QUrl &url);
    Q_INVOKABLE void update(int index, const QString &title, const QUrl &url);
    Q_INVOKABLE void remove(int index);
    Q_INVOKABLE QVariantMap takeForUndo(int index);
    Q_INVOKABLE void restoreForUndo(int index, const QString &title, const QUrl &url);
    Q_INVOKABLE void saveState();
    Q_INVOKABLE void move(int from, int to);
    Q_INVOKABLE void resetDefaults();
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 6) const;

signals:
    void countChanged();
    void changed();

private:
    struct Item {
        QString title;
        QString url;
    };

    QList<Item> m_items;
    QSettings m_store;
    bool m_saveSuspended = false;
    bool m_savePending = false;

    void load();
    void save();
    void installDefaults();
    static bool isAcceptableUrl(const QUrl &url);
    static QString normalizedUrl(const QUrl &url);
    static QString titleOrHost(const QString &title, const QUrl &url);
    static QString hostOf(const QString &url);
};
