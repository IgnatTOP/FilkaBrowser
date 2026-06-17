#pragma once

#include "AdBlockFfi.h"
#include "AdBlockInterceptor.h"

#include <QDateTime>
#include <QtWebEngineCore/QWebEngineUrlRequestInfo>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVector>
#include <atomic>
#include <qqmlregistration.h>

class QNetworkReply;
class QQuickWebEngineProfile;
class QWebEngineUrlRequestInfo;

class AdBlockManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool cosmeticFilteringEnabled READ cosmeticFilteringEnabled WRITE setCosmeticFilteringEnabled NOTIFY cosmeticFilteringEnabledChanged)
    Q_PROPERTY(bool trackingProtectionEnabled READ trackingProtectionEnabled WRITE setTrackingProtectionEnabled NOTIFY trackingProtectionEnabledChanged)
    Q_PROPERTY(bool annoyanceBlockingEnabled READ annoyanceBlockingEnabled WRITE setAnnoyanceBlockingEnabled NOTIFY annoyanceBlockingEnabledChanged)
    Q_PROPERTY(bool sponsorBlockEnabled READ sponsorBlockEnabled WRITE setSponsorBlockEnabled NOTIFY sponsorBlockEnabledChanged)
    Q_PROPERTY(bool autoUpdate READ autoUpdate WRITE setAutoUpdate NOTIFY autoUpdateChanged)
    Q_PROPERTY(bool updating READ updating NOTIFY updatingChanged)
    Q_PROPERTY(int blockedRequests READ blockedRequests NOTIFY blockedRequestsChanged)
    Q_PROPERTY(int rulesCount READ rulesCount NOTIFY rulesCountChanged)
    Q_PROPERTY(QString lastUpdateAt READ lastUpdateAt NOTIFY lastUpdateAtChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QStringList customLists READ customLists WRITE setCustomLists NOTIFY customListsChanged)
    Q_PROPERTY(QStringList allowedSites READ allowedSites WRITE setAllowedSites NOTIFY allowedSitesChanged)

public:
    explicit AdBlockManager(QObject *parent = nullptr);
    ~AdBlockManager() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool value);

    QString mode() const { return m_mode; }
    void setMode(const QString &value);

    bool cosmeticFilteringEnabled() const { return m_cosmeticFilteringEnabled; }
    void setCosmeticFilteringEnabled(bool value);

    bool trackingProtectionEnabled() const { return m_trackingProtectionEnabled; }
    void setTrackingProtectionEnabled(bool value);

    bool annoyanceBlockingEnabled() const { return m_annoyanceBlockingEnabled; }
    void setAnnoyanceBlockingEnabled(bool value);

    bool sponsorBlockEnabled() const { return m_sponsorBlockEnabled; }
    void setSponsorBlockEnabled(bool value);

    bool autoUpdate() const { return m_autoUpdate; }
    void setAutoUpdate(bool value);

    bool updating() const { return m_updating; }
    int blockedRequests() const { return m_blockedRequests.load(); }
    int rulesCount() const { return m_rulesCount; }
    QString lastUpdateAt() const { return m_lastUpdateAt; }
    QString statusText() const { return m_statusText; }

    QStringList customLists() const { return m_customLists; }
    void setCustomLists(const QStringList &value);

    QStringList allowedSites() const { return m_allowedSites; }
    void setAllowedSites(const QStringList &value);

    Q_INVOKABLE void attachProfile(QObject *profile);
    Q_INVOKABLE void refreshLists();
    Q_INVOKABLE void addCustomList(const QString &url);
    Q_INVOKABLE void removeCustomList(const QString &url);
    Q_INVOKABLE void setSiteAllowed(const QString &url, bool allowed);
    Q_INVOKABLE bool isSiteAllowed(const QString &url) const;
    Q_INVOKABLE QString earlyCosmeticScript() const;
    Q_INVOKABLE QString cosmeticScriptForUrl(const QString &url);
    Q_INVOKABLE QString sponsorBlockScriptForUrl(const QString &url) const;
    Q_INVOKABLE QString sponsorBlockDisableScript() const;

    void interceptRequest(QWebEngineUrlRequestInfo &info);

signals:
    void enabledChanged();
    void modeChanged();
    void cosmeticFilteringEnabledChanged();
    void trackingProtectionEnabledChanged();
    void annoyanceBlockingEnabledChanged();
    void sponsorBlockEnabledChanged();
    void autoUpdateChanged();
    void updatingChanged();
    void blockedRequestsChanged();
    void rulesCountChanged();
    void lastUpdateAtChanged();
    void statusTextChanged();
    void customListsChanged();
    void allowedSitesChanged();

private:
    struct FilterSource {
        QString url;
        bool tracking = false;
        bool annoyance = false;
    };

    mutable QMutex m_engineMutex;
    FilkaAdBlockEngine *m_engine = nullptr;
    AdBlockInterceptor m_interceptor;
    QNetworkAccessManager m_nam;
    QVector<QNetworkReply *> m_pendingReplies;
    QStringList m_downloadedLists;
    QVector<QPointer<QQuickWebEngineProfile>> m_profiles;
    QSettings m_store;
    std::atomic<int> m_blockedRequests = 0;

    bool m_enabled = true;
    QString m_mode = QStringLiteral("standard");
    bool m_cosmeticFilteringEnabled = true;
    bool m_trackingProtectionEnabled = true;
    bool m_annoyanceBlockingEnabled = false;
    bool m_sponsorBlockEnabled = true;
    bool m_autoUpdate = true;
    bool m_updating = false;
    int m_rulesCount = 0;
    QString m_lastUpdateAt;
    QString m_statusText;
    QStringList m_customLists;
    QStringList m_allowedSites;

    QString bundledRules() const;
    QString cachedRules() const;
    QString combinedRules() const;
    QString cacheFilePath() const;
    QString defaultStatus() const;
    QString normalizedMode(const QString &value) const;
    QString normalizedHost(const QString &value) const;
    QStringList normalizedStringList(const QStringList &value, bool hosts) const;
    QList<FilterSource> activeSources() const;
    bool hostIsAllowed(const QString &host) const;
    QString requestTypeName(QWebEngineUrlRequestInfo::ResourceType type) const;

    void rebuildEngine();
    void attachExistingProfiles();
    void maybeAutoUpdate();
    void setUpdating(bool value);
    void setRulesCount(int value);
    void setLastUpdateAt(const QString &value);
    void setStatusText(const QString &value);
    void noteBlockedRequest();
    void persistStringList(const QString &key, const QStringList &value);
    void persistBool(const QString &key, bool value);
    void persistString(const QString &key, const QString &value);
};
