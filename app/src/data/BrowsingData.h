// BrowsingData — privacy actions that act on the shared WebEngine profile.
//
// QWebEngineProfile's cache/cookie/visited-link clearers aren't callable from
// QML directly, so this thin wrapper exposes them as invokables. main.cpp
// constructs one over the live `filka` profile and binds it as `filkaPrivacy`.

#pragma once

#include <QObject>
#include <qqmlregistration.h>

class QWebEngineProfile;

class BrowsingData : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS

public:
    explicit BrowsingData(QWebEngineProfile *profile, QObject *parent = nullptr);

    // Drop the on-disk HTTP cache (does not touch logins).
    Q_INVOKABLE void clearCache();
    // Delete all cookies + site storage — signs the user out everywhere.
    Q_INVOKABLE void clearCookies();
    // Cache + cookies + the visited-link colouring set.
    Q_INVOKABLE void clearAll();

private:
    QWebEngineProfile *m_profile = nullptr;
};
