#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QSettings>
#include <QString>
#include <qqmlregistration.h>

class QNetworkReply;

class UpdateChecker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(QString downloadUrl READ downloadUrl NOTIFY downloadUrlChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY releaseNotesChanged)
    Q_PROPERTY(bool dismissed READ dismissed WRITE setDismissed NOTIFY dismissedChanged)

public:
    explicit UpdateChecker(QObject *parent = nullptr);

    bool checking() const { return m_checking; }
    bool updateAvailable() const { return m_updateAvailable; }
    QString latestVersion() const { return m_latestVersion; }
    QString downloadUrl() const { return m_downloadUrl; }
    QString releaseNotes() const { return m_releaseNotes; }
    bool dismissed() const { return m_dismissed; }
    void setDismissed(bool value);

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void openDownload();

signals:
    void checkingChanged();
    void updateAvailableChanged();
    void latestVersionChanged();
    void downloadUrlChanged();
    void releaseNotesChanged();
    void dismissedChanged();

private:
    QNetworkAccessManager m_nam;
    QSettings m_store;
    bool m_checking = false;
    bool m_updateAvailable = false;
    QString m_latestVersion;
    QString m_downloadUrl;
    QString m_releaseNotes;
    bool m_dismissed = false;

    void setChecking(bool value);
    void setUpdateAvailable(bool value);
    void setLatestVersion(const QString &version);
    void setDownloadUrl(const QString &url);
    void setReleaseNotes(const QString &notes);

    static bool versionIsNewer(const QString &current, const QString &latest);
    static QString platformAssetFilter();
};
