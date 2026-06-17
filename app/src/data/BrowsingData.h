// BrowsingData — privacy actions that act on the active QML WebEngine profile.
//
// QML exposes WebEngineProfile.clearHttpCache(), but not the cookie store. This
// thin wrapper receives the active QQuickWebEngineProfile from QML and clears
// cache, cookies and persisted permissions on that same profile.

#pragma once

#include <QObject>
#include <qqmlregistration.h>

class BrowsingData : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit BrowsingData(QObject *parent = nullptr);

    Q_INVOKABLE void clearCache(QObject *profile);
    Q_INVOKABLE void clearCookies(QObject *profile);
    Q_INVOKABLE void clearPermissions(QObject *profile);
    Q_INVOKABLE void clearAll(QObject *profile);
};
