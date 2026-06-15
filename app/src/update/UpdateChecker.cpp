#include "UpdateChecker.h"

#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QSettings>
#include <QVersionNumber>

static const QString kRepoApiUrl =
    QStringLiteral("https://api.github.com/repos/IgnatTOP/FilkaBrowser/releases/latest");

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent)
{
    m_dismissed = m_store.value(QStringLiteral("updates/dismissed"), false).toBool();
}

void UpdateChecker::setDismissed(bool value)
{
    if (m_dismissed == value)
        return;
    m_dismissed = value;
    m_store.setValue(QStringLiteral("updates/dismissed"), value);
    emit dismissedChanged();
}

void UpdateChecker::checkForUpdates()
{
    if (m_checking)
        return;

    setChecking(true);

    QNetworkRequest request{QUrl(kRepoApiUrl)};
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");

    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setChecking(false);

        if (reply->error() != QNetworkReply::NoError)
            return;

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject())
            return;

        QJsonObject release = doc.object();
        QString tagName = release.value(QStringLiteral("tag_name")).toString();
        if (tagName.isEmpty())
            return;

        // Strip leading 'v' if present (v0.2.0 -> 0.2.0)
        if (tagName.startsWith('v'))
            tagName = tagName.mid(1);

        QString currentVersion = QStringLiteral("0.2.0");

        if (!versionIsNewer(currentVersion, tagName))
            return;

        // Find platform-matching asset.
        QString assetUrl;
        QJsonArray assets = release.value(QStringLiteral("assets")).toArray();
        QString filter = platformAssetFilter();

        for (const QJsonValue &val : assets) {
            QJsonObject asset = val.toObject();
            QString name = asset.value(QStringLiteral("name")).toString();
            if (name.contains(filter, Qt::CaseInsensitive)) {
                assetUrl = asset.value(QStringLiteral("browser_download_url")).toString();
                break;
            }
        }

        // If no asset matches, link to the release page itself.
        if (assetUrl.isEmpty())
            assetUrl = release.value(QStringLiteral("html_url")).toString();

        QString notes = release.value(QStringLiteral("body")).toString();

        setLatestVersion(tagName);
        setDownloadUrl(assetUrl);
        setReleaseNotes(notes);
        setUpdateAvailable(true);
    });
}

void UpdateChecker::openDownload()
{
    if (!m_downloadUrl.isEmpty())
        QDesktopServices::openUrl(QUrl(m_downloadUrl));
}

void UpdateChecker::setChecking(bool value)
{
    if (m_checking == value)
        return;
    m_checking = value;
    emit checkingChanged();
}

void UpdateChecker::setUpdateAvailable(bool value)
{
    if (m_updateAvailable == value)
        return;
    m_updateAvailable = value;
    emit updateAvailableChanged();
}

void UpdateChecker::setLatestVersion(const QString &version)
{
    if (m_latestVersion == version)
        return;
    m_latestVersion = version;
    emit latestVersionChanged();
}

void UpdateChecker::setDownloadUrl(const QString &url)
{
    if (m_downloadUrl == url)
        return;
    m_downloadUrl = url;
    emit downloadUrlChanged();
}

void UpdateChecker::setReleaseNotes(const QString &notes)
{
    if (m_releaseNotes == notes)
        return;
    m_releaseNotes = notes;
    emit releaseNotesChanged();
}

bool UpdateChecker::versionIsNewer(const QString &current, const QString &latest)
{
    QVersionNumber cv = QVersionNumber::fromString(current);
    QVersionNumber lv = QVersionNumber::fromString(latest);
    return lv > cv;
}

QString UpdateChecker::platformAssetFilter()
{
#if defined(Q_OS_LINUX)
    return QStringLiteral("linux");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#elif defined(Q_OS_WIN)
    return QStringLiteral("windows");
#else
    return QString();
#endif
}
