#include "UpdateChecker.h"

#include <chrono>

#include <QCoreApplication>
#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QSslError>
#include <QStringList>
#include <QVersionNumber>

static const QString kRepoApiUrl =
    QStringLiteral("https://api.github.com/repos/IgnatTOP/FilkaBrowser/releases/latest");
static constexpr auto kTransferTimeout = std::chrono::milliseconds(30000);

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent)
{
    connect(&m_nam, &QNetworkAccessManager::sslErrors, this,
            [this](QNetworkReply *reply, const QList<QSslError> &errors) {
        QStringList messages;
        for (const QSslError &error : errors)
            messages.append(error.errorString());
        setLastError(QStringLiteral("Ошибка TLS: %1").arg(messages.join(QStringLiteral("; "))));
        if (reply)
            reply->abort();
    });

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

QString UpdateChecker::currentVersion() const
{
    const QString v = QCoreApplication::applicationVersion();
    return v.isEmpty() ? QStringLiteral("0.1.0") : v;
}

void UpdateChecker::checkForUpdates()
{
    if (m_checking)
        return;

    setChecking(true);
    setUpToDate(false);
    setLastError(QString());

    QNetworkRequest request{QUrl(kRepoApiUrl)};
    request.setTransferTimeout(kTransferTimeout);
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");

    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setChecking(false);

        if (reply->error() != QNetworkReply::NoError) {
            if (m_lastError.isEmpty())
                setLastError(reply->errorString());
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            setLastError(QStringLiteral("Некорректный ответ сервера обновлений."));
            return;
        }

        QJsonObject release = doc.object();
        QString tagName = release.value(QStringLiteral("tag_name")).toString();
        if (tagName.isEmpty()) {
            setLastError(QStringLiteral("В ответе обновлений нет версии релиза."));
            return;
        }

        // Strip leading 'v' if present (v0.2.0 -> 0.2.0)
        if (tagName.startsWith('v'))
            tagName = tagName.mid(1);

        if (!versionIsNewer(currentVersion(), tagName)) {
            // Already on the latest build — let the UI confirm the check ran.
            setUpToDate(true);
            return;
        }

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
        const QUrl asset(assetUrl);
        if (!asset.isValid() || asset.scheme() != QLatin1String("https")) {
            setLastError(QStringLiteral("В ответе обновлений некорректная ссылка загрузки."));
            return;
        }

        QString notes = release.value(QStringLiteral("body")).toString();

        setLatestVersion(tagName);
        setDownloadUrl(assetUrl);
        setReleaseNotes(notes);
        setUpdateAvailable(true);
        // A fresh release supersedes any earlier "dismissed" so the banner and
        // the settings entry surface it again.
        setDismissed(false);
    });
}

void UpdateChecker::openDownload()
{
    const QUrl url(m_downloadUrl);
    if (url.isValid() && url.scheme() == QLatin1String("https"))
        QDesktopServices::openUrl(url);
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

void UpdateChecker::setUpToDate(bool value)
{
    if (m_upToDate == value)
        return;
    m_upToDate = value;
    emit upToDateChanged();
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

void UpdateChecker::setLastError(const QString &error)
{
    if (m_lastError == error)
        return;
    m_lastError = error;
    emit lastErrorChanged();
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
