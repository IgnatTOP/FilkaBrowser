#include "AdBlockManager.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QtWebEngineQuick/QQuickWebEngineProfile>
#include <utility>

namespace {
constexpr int kTransferTimeoutMs = 45000;

QString jsStringLiteral(const QString &value)
{
    QJsonArray array;
    array.append(value);
    const QString encoded = QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact));
    return encoded.mid(1, encoded.size() - 2);
}

QString writableOrFallback(QStandardPaths::StandardLocation location, const QString &fallbackName)
{
    QString path = QStandardPaths::writableLocation(location);
    if (path.isEmpty())
        path = QDir::home().filePath(fallbackName);
    QDir().mkpath(path);
    return path;
}

bool isYandexMusicHost(QString host)
{
    host = host.trimmed().toLower();
    if (host.startsWith(QLatin1String("www.")))
        host = host.mid(4);
    return host == QLatin1String("music.yandex.ru")
        || host.endsWith(QLatin1String(".music.yandex.ru"));
}

bool isYandexMusicUrl(const QUrl &url)
{
    return isYandexMusicHost(url.host());
}
}

AdBlockManager::AdBlockManager(QObject *parent)
    : QObject(parent)
    , m_interceptor(this)
{
    m_enabled = m_store.value(QStringLiteral("adblock/enabled"), true).toBool();
    m_mode = normalizedMode(m_store.value(QStringLiteral("adblock/mode"),
                                          QStringLiteral("standard")).toString());
    m_cosmeticFilteringEnabled = m_store.value(QStringLiteral("adblock/cosmetic"), true).toBool();
    m_trackingProtectionEnabled = m_store.value(QStringLiteral("adblock/tracking"), true).toBool();
    m_annoyanceBlockingEnabled = m_store.value(QStringLiteral("adblock/annoyances"), false).toBool();
    m_sponsorBlockEnabled = m_store.value(QStringLiteral("adblock/sponsorBlock"), true).toBool();
    m_autoUpdate = m_store.value(QStringLiteral("adblock/autoUpdate"), true).toBool();
    m_customLists = normalizedStringList(
        m_store.value(QStringLiteral("adblock/customLists")).toStringList(), false);
    m_allowedSites = normalizedStringList(
        m_store.value(QStringLiteral("adblock/allowedSites")).toStringList(), true);
    m_lastUpdateAt = m_store.value(QStringLiteral("adblock/lastUpdateAt")).toString();
    rebuildEngine();
    maybeAutoUpdate();
}

AdBlockManager::~AdBlockManager()
{
    QMutexLocker locker(&m_engineMutex);
    if (m_engine)
        filka_adblock_engine_free(m_engine);
    m_engine = nullptr;
}

void AdBlockManager::setEnabled(bool value)
{
    if (m_enabled == value)
        return;
    m_enabled = value;
    persistBool(QStringLiteral("adblock/enabled"), value);
    emit enabledChanged();
    setStatusText(defaultStatus());
}

void AdBlockManager::setMode(const QString &value)
{
    const QString clean = normalizedMode(value);
    if (m_mode == clean)
        return;
    m_mode = clean;
    persistString(QStringLiteral("adblock/mode"), clean);
    emit modeChanged();
}

void AdBlockManager::setCosmeticFilteringEnabled(bool value)
{
    if (m_cosmeticFilteringEnabled == value)
        return;
    m_cosmeticFilteringEnabled = value;
    persistBool(QStringLiteral("adblock/cosmetic"), value);
    emit cosmeticFilteringEnabledChanged();
}

void AdBlockManager::setTrackingProtectionEnabled(bool value)
{
    if (m_trackingProtectionEnabled == value)
        return;
    m_trackingProtectionEnabled = value;
    persistBool(QStringLiteral("adblock/tracking"), value);
    emit trackingProtectionEnabledChanged();
}

void AdBlockManager::setAnnoyanceBlockingEnabled(bool value)
{
    if (m_annoyanceBlockingEnabled == value)
        return;
    m_annoyanceBlockingEnabled = value;
    persistBool(QStringLiteral("adblock/annoyances"), value);
    emit annoyanceBlockingEnabledChanged();
}

void AdBlockManager::setSponsorBlockEnabled(bool value)
{
    if (m_sponsorBlockEnabled == value)
        return;
    m_sponsorBlockEnabled = value;
    persistBool(QStringLiteral("adblock/sponsorBlock"), value);
    emit sponsorBlockEnabledChanged();
}

void AdBlockManager::setAutoUpdate(bool value)
{
    if (m_autoUpdate == value)
        return;
    m_autoUpdate = value;
    persistBool(QStringLiteral("adblock/autoUpdate"), value);
    emit autoUpdateChanged();
    maybeAutoUpdate();
}

void AdBlockManager::setCustomLists(const QStringList &value)
{
    const QStringList clean = normalizedStringList(value, false);
    if (m_customLists == clean)
        return;
    m_customLists = clean;
    persistStringList(QStringLiteral("adblock/customLists"), clean);
    emit customListsChanged();
}

void AdBlockManager::setAllowedSites(const QStringList &value)
{
    const QStringList clean = normalizedStringList(value, true);
    if (m_allowedSites == clean)
        return;
    m_allowedSites = clean;
    persistStringList(QStringLiteral("adblock/allowedSites"), clean);
    emit allowedSitesChanged();
}

void AdBlockManager::attachProfile(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile)
        return;

    for (const auto &knownProfile : std::as_const(m_profiles)) {
        if (knownProfile == webProfile)
            return;
    }

    webProfile->setUrlRequestInterceptor(&m_interceptor);
    m_profiles.append(webProfile);
}

void AdBlockManager::refreshLists()
{
    if (m_updating)
        return;

    const QList<FilterSource> sources = activeSources();
    if (sources.isEmpty()) {
        rebuildEngine();
        return;
    }

    m_downloadedLists.clear();
    m_pendingReplies.clear();
    setUpdating(true);
    setStatusText(QStringLiteral("Обновляем списки блокировки..."));

    for (const FilterSource &source : sources) {
        const QUrl url(source.url);
        if (!url.isValid() || (url.scheme() != QLatin1String("https")
                               && url.scheme() != QLatin1String("http"))) {
            continue;
        }

        QNetworkRequest request(url);
        request.setTransferTimeout(kTransferTimeoutMs);
        request.setRawHeader("User-Agent", "Filka Browser AdBlock");
        QNetworkReply *reply = m_nam.get(request);
        reply->setProperty("filkaAdBlockSource", source.url);
        m_pendingReplies.append(reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            m_pendingReplies.removeAll(reply);
            reply->deleteLater();
            if (reply->error() == QNetworkReply::NoError) {
                const QString text = QString::fromUtf8(reply->readAll());
                if (!text.trimmed().isEmpty())
                    m_downloadedLists.append(text);
            } else {
                qWarning("Filka adblock: list update failed for %s: %s",
                         qPrintable(reply->property("filkaAdBlockSource").toString()),
                         qPrintable(reply->errorString()));
            }

            if (!m_pendingReplies.isEmpty())
                return;

            setUpdating(false);
            if (m_downloadedLists.isEmpty()) {
                setStatusText(QStringLiteral("Не удалось обновить списки; используем локальный кэш."));
                rebuildEngine();
                return;
            }

            QSaveFile out(cacheFilePath());
            if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                out.write(m_downloadedLists.join(QStringLiteral("\n")).toUtf8());
                out.commit();
            }
            setLastUpdateAt(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
            rebuildEngine();
        });
    }

    if (m_pendingReplies.isEmpty()) {
        setUpdating(false);
        rebuildEngine();
    }
}

void AdBlockManager::addCustomList(const QString &url)
{
    QStringList lists = m_customLists;
    const QString clean = url.trimmed();
    const QUrl parsed(clean);
    if (!parsed.isValid() || (parsed.scheme() != QLatin1String("https")
                              && parsed.scheme() != QLatin1String("http"))) {
        return;
    }
    if (!lists.contains(clean))
        lists.append(clean);
    setCustomLists(lists);
}

void AdBlockManager::removeCustomList(const QString &url)
{
    QStringList lists = m_customLists;
    lists.removeAll(url.trimmed());
    setCustomLists(lists);
}

void AdBlockManager::setSiteAllowed(const QString &url, bool allowed)
{
    const QString host = normalizedHost(url);
    if (host.isEmpty())
        return;
    QStringList sites = m_allowedSites;
    if (allowed) {
        if (!sites.contains(host))
            sites.append(host);
    } else {
        sites.removeAll(host);
    }
    setAllowedSites(sites);
}

bool AdBlockManager::isSiteAllowed(const QString &url) const
{
    return hostIsAllowed(normalizedHost(url));
}

QString AdBlockManager::earlyCosmeticScript() const
{
    if (!m_enabled || !m_cosmeticFilteringEnabled)
        return QString();

    const QStringList selectors = {
        QStringLiteral(".ads"),
        QStringLiteral(".ad"),
        QStringLiteral(".advert"),
        QStringLiteral(".advertisement"),
        QStringLiteral(".ad-banner"),
        QStringLiteral(".adbanner"),
        QStringLiteral(".adsbox"),
        QStringLiteral(".adsbygoogle"),
        QStringLiteral(".google-auto-placed"),
        QStringLiteral(".sponsored"),
        QStringLiteral(".sponsor"),
        QStringLiteral(".text-ad"),
        QStringLiteral("#ad"),
        QStringLiteral("#ads"),
        QStringLiteral("#ad-banner"),
        QStringLiteral("[id='ads']"),
        QStringLiteral("[id*='ad_']"),
        QStringLiteral("[id^='ad-']"),
        QStringLiteral("[id^='ads-']"),
        QStringLiteral("[id*='-ad-']"),
        QStringLiteral("[class*=' ad-']"),
        QStringLiteral("[class*=' ads-']"),
        QStringLiteral("[class*='adbanner']"),
        QStringLiteral("[class*='adsbox']"),
        QStringLiteral("[class*='advertisement']"),
    };
    const QString css = selectors.join(QStringLiteral(",\n"))
        + QStringLiteral("{display:none!important;visibility:hidden!important;}");

    return QStringLiteral(
               "(function(){try{"
               "const css=%1;"
               "function apply(){"
               "if(!document.documentElement||document.getElementById('__filka_adblock_early_css'))return;"
               "const s=document.createElement('style');s.id='__filka_adblock_early_css';s.textContent=css;"
               "(document.head||document.documentElement).appendChild(s);}"
               "apply();"
               "new MutationObserver(apply).observe(document.documentElement||document,{childList:true,subtree:true});"
               "}catch(e){}})();")
        .arg(jsStringLiteral(css));
}

QString AdBlockManager::cosmeticScriptForUrl(const QString &url)
{
    if (!m_enabled || !m_cosmeticFilteringEnabled || isSiteAllowed(url) || isYandexMusicUrl(QUrl(url)))
        return QString();

    QByteArray urlBytes = url.toUtf8();
    QString json;
    {
        QMutexLocker locker(&m_engineMutex);
        if (!m_engine)
            return QString();
        char *raw = filka_adblock_cosmetic_json(m_engine, urlBytes.constData());
        if (!raw)
            return QString();
        json = QString::fromUtf8(raw);
        filka_adblock_string_free(raw);
    }

    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return QString();

    const QJsonObject object = doc.object();
    QStringList selectors;
    const QJsonArray selectorArray = object.value(QStringLiteral("hide_selectors")).toArray();
    for (const QJsonValue &value : selectorArray) {
        const QString selector = value.toString().trimmed();
        if (!selector.isEmpty())
            selectors.append(selector);
    }

    QString css;
    if (!selectors.isEmpty()) {
        css = selectors.join(QStringLiteral(",\n"));
        css.append(QStringLiteral("{display:none!important;visibility:hidden!important;}"));
    }
    const QString injectedScript = object.value(QStringLiteral("injected_script")).toString();
    if (css.isEmpty() && injectedScript.trimmed().isEmpty())
        return QString();

    return QStringLiteral(
               "(function(){try{"
               "const css=%1;"
               "if(css&&document.documentElement&&!document.getElementById('__filka_adblock_css')){"
               "const s=document.createElement('style');s.id='__filka_adblock_css';"
               "s.textContent=css;(document.head||document.documentElement).appendChild(s);}"
               "const script=%2;if(script){(0,eval)(script);}"
               "}catch(e){console.debug('Filka adblock cosmetic failed',e);}})();")
        .arg(jsStringLiteral(css), jsStringLiteral(injectedScript));
}

QString AdBlockManager::sponsorBlockScriptForUrl(const QString &url) const
{
    if (!m_sponsorBlockEnabled)
        return QString();

    const QUrl parsed(url.trimmed());
    const QString host = parsed.host().toLower();
    if (host.isEmpty()
        || (host != QLatin1String("youtu.be") && host != QLatin1String("youtube.com")
            && !host.endsWith(QLatin1String(".youtube.com")))) {
        return QString();
    }

    QJsonArray categories;
    categories.append(QStringLiteral("sponsor"));
    categories.append(QStringLiteral("selfpromo"));
    categories.append(QStringLiteral("interaction"));
    categories.append(QStringLiteral("intro"));
    categories.append(QStringLiteral("outro"));
    categories.append(QStringLiteral("preview"));
    categories.append(QStringLiteral("music_offtopic"));
    categories.append(QStringLiteral("filler"));
    const QString categoriesJson = QString::fromUtf8(
        QJsonDocument(categories).toJson(QJsonDocument::Compact));

    return QStringLiteral(R"JS((function(){
try {
    if (window.__filkaSponsorBlockInstalled && window.__filkaSponsorBlockTimer)
        return;

    window.__filkaSponsorBlockDisabled = false;
    window.__filkaSponsorBlockInstalled = true;

    const categories = %1;
    const actionTypes = ["skip"];
    let currentId = "";
    let segments = [];
    let fetching = false;

    function videoIdFromLocation() {
        try {
            const u = new URL(location.href);
            if (u.hostname === "youtu.be")
                return u.pathname.replace(/^\/+/, "").split(/[/?#]/)[0] || "";
            const watchId = u.searchParams.get("v");
            if (watchId)
                return watchId;
            const match = u.pathname.match(/\/(?:shorts|embed|live)\/([^/?#]+)/);
            return match ? match[1] : "";
        } catch (e) {
            return "";
        }
    }

    function usableSegment(item) {
        if (!item || !Array.isArray(item.segment) || item.segment.length < 2)
            return false;
        const start = Number(item.segment[0]);
        const end = Number(item.segment[1]);
        return Number.isFinite(start) && Number.isFinite(end) && end > start;
    }

    async function loadSegments(id) {
        if (!id || fetching)
            return;
        fetching = true;
        try {
            const endpoint = new URL("https://sponsor.ajay.app/api/skipSegments");
            endpoint.searchParams.set("videoID", id);
            endpoint.searchParams.set("categories", JSON.stringify(categories));
            endpoint.searchParams.set("actionTypes", JSON.stringify(actionTypes));
            const response = await fetch(endpoint.toString(), { cache: "force-cache" });
            if (window.__filkaSponsorBlockDisabled)
                return;
            if (response.status === 404 || !response.ok) {
                segments = [];
                return;
            }
            const payload = await response.json();
            segments = Array.isArray(payload)
                ? payload.filter(usableSegment).sort(function(a, b) {
                    return Number(a.segment[0]) - Number(b.segment[0]);
                })
                : [];
        } catch (e) {
            segments = [];
        } finally {
            fetching = false;
        }
    }

    function tick() {
        if (window.__filkaSponsorBlockDisabled)
            return;
        const id = videoIdFromLocation();
        if (id !== currentId) {
            currentId = id;
            segments = [];
            loadSegments(id);
        }

        const video = document.querySelector("video");
        if (!video || !segments.length || video.seeking)
            return;

        const now = Number(video.currentTime);
        for (const item of segments) {
            const start = Number(item.segment[0]);
            const end = Number(item.segment[1]);
            if (now >= start && now < end - 0.08) {
                video.currentTime = Math.min(end + 0.05, Number.isFinite(video.duration) ? video.duration : end + 0.05);
                break;
            }
        }
    }

    if (window.__filkaSponsorBlockTimer)
        clearInterval(window.__filkaSponsorBlockTimer);
    window.__filkaSponsorBlockTimer = setInterval(tick, 350);
    tick();
} catch (e) {
    console.debug("Filka SponsorBlock failed", e);
}
})();
)JS")
        .arg(categoriesJson);
}

QString AdBlockManager::sponsorBlockDisableScript() const
{
    return QStringLiteral(
        "(function(){"
        "window.__filkaSponsorBlockDisabled=true;"
        "window.__filkaSponsorBlockInstalled=false;"
        "if(window.__filkaSponsorBlockTimer){clearInterval(window.__filkaSponsorBlockTimer);}"
        "window.__filkaSponsorBlockTimer=null;"
        "})();");
}

void AdBlockManager::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    const QUrl requestUrl = info.requestUrl();
    const QString scheme = requestUrl.scheme();
    if (scheme != QLatin1String("http") && scheme != QLatin1String("https")
        && scheme != QLatin1String("ws") && scheme != QLatin1String("wss")) {
        return;
    }

    const QUrl firstParty = info.firstPartyUrl().isEmpty() ? info.initiator() : info.firstPartyUrl();
    if (isYandexMusicUrl(requestUrl) || isYandexMusicUrl(firstParty))
        return;
    if (hostIsAllowed(requestUrl.host()) || hostIsAllowed(firstParty.host()))
        return;

    const bool mainFrame = info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeMainFrame
        || info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeNavigationPreloadMainFrame;

    QByteArray urlBytes = requestUrl.toString(QUrl::FullyEncoded).toUtf8();
    QByteArray sourceBytes = (firstParty.isEmpty() ? requestUrl : firstParty)
                                 .toString(QUrl::FullyEncoded).toUtf8();
    QByteArray typeBytes = requestTypeName(info.resourceType()).toUtf8();

    FilkaAdBlockDecision decision{};
    {
        QMutexLocker locker(&m_engineMutex);
        if (!m_enabled || !m_engine)
            return;
        decision = filka_adblock_check_network(m_engine,
                                               urlBytes.constData(),
                                               sourceBytes.constData(),
                                               typeBytes.constData());
    }

    if (!decision.blocked)
        return;
    if (mainFrame && m_mode != QLatin1String("aggressive") && !decision.important)
        return;

    info.block(true);
    noteBlockedRequest();
}

QString AdBlockManager::bundledRules() const
{
    QFile file(QStringLiteral(":/qt/qml/Filka/assets/filters/filka-default.txt"));
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromUtf8(file.readAll());
}

QString AdBlockManager::cachedRules() const
{
    QFile file(cacheFilePath());
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromUtf8(file.readAll());
}

QString AdBlockManager::combinedRules() const
{
    QStringList parts;
    parts << bundledRules();
    const QString cache = cachedRules();
    if (!cache.trimmed().isEmpty())
        parts << cache;
    return parts.join(QStringLiteral("\n"));
}

QString AdBlockManager::cacheFilePath() const
{
    const QString base = writableOrFallback(QStandardPaths::AppDataLocation,
                                            QStringLiteral(".local/share/Filka"));
    const QString dir = QDir(base).filePath(QStringLiteral("adblock"));
    QDir().mkpath(dir);
    return QDir(dir).filePath(QStringLiteral("lists.txt"));
}

QString AdBlockManager::defaultStatus() const
{
    if (!m_enabled)
        return QStringLiteral("Блокировщик выключен");
    return QStringLiteral("Активен: %1 правил").arg(m_rulesCount);
}

QString AdBlockManager::normalizedMode(const QString &value) const
{
    const QString clean = value.trimmed().toLower();
    return clean == QLatin1String("aggressive") ? clean : QStringLiteral("standard");
}

QString AdBlockManager::normalizedHost(const QString &value) const
{
    QString clean = value.trimmed().toLower();
    if (clean.isEmpty())
        return QString();
    QUrl url(clean);
    if (!url.isValid() || url.host().isEmpty())
        url = QUrl(QStringLiteral("https://") + clean);
    clean = url.host().toLower();
    if (clean.startsWith(QStringLiteral("www.")))
        clean = clean.mid(4);
    return clean;
}

QStringList AdBlockManager::normalizedStringList(const QStringList &value, bool hosts) const
{
    QStringList clean;
    for (const QString &item : value) {
        const QString entry = hosts ? normalizedHost(item) : item.trimmed();
        if (!entry.isEmpty() && !clean.contains(entry))
            clean.append(entry);
    }
    return clean;
}

QList<AdBlockManager::FilterSource> AdBlockManager::activeSources() const
{
    QList<FilterSource> sources = {
        {QStringLiteral("https://easylist.to/easylist/easylist.txt"), false, false},
        {QStringLiteral("https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt"), false, false},
    };
    if (m_trackingProtectionEnabled) {
        sources.append({QStringLiteral("https://easylist.to/easylist/easyprivacy.txt"), true, false});
        sources.append({QStringLiteral("https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt"), true, false});
    }
    if (m_annoyanceBlockingEnabled || m_mode == QLatin1String("aggressive")) {
        sources.append({QStringLiteral("https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt"), false, true});
        sources.append({QStringLiteral("https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt"), false, true});
    }
    for (const QString &custom : m_customLists)
        sources.append({custom, false, false});
    return sources;
}

bool AdBlockManager::hostIsAllowed(const QString &host) const
{
    const QString clean = normalizedHost(host);
    if (clean.isEmpty())
        return false;
    for (const QString &allowed : m_allowedSites) {
        if (clean == allowed || clean.endsWith(QStringLiteral(".") + allowed))
            return true;
    }
    return false;
}

QString AdBlockManager::requestTypeName(QWebEngineUrlRequestInfo::ResourceType type) const
{
    switch (type) {
    case QWebEngineUrlRequestInfo::ResourceTypeMainFrame:
    case QWebEngineUrlRequestInfo::ResourceTypeNavigationPreloadMainFrame:
        return QStringLiteral("main_frame");
    case QWebEngineUrlRequestInfo::ResourceTypeSubFrame:
    case QWebEngineUrlRequestInfo::ResourceTypeNavigationPreloadSubFrame:
        return QStringLiteral("sub_frame");
    case QWebEngineUrlRequestInfo::ResourceTypeStylesheet:
        return QStringLiteral("stylesheet");
    case QWebEngineUrlRequestInfo::ResourceTypeScript:
    case QWebEngineUrlRequestInfo::ResourceTypeWorker:
    case QWebEngineUrlRequestInfo::ResourceTypeSharedWorker:
    case QWebEngineUrlRequestInfo::ResourceTypeServiceWorker:
        return QStringLiteral("script");
    case QWebEngineUrlRequestInfo::ResourceTypeImage:
    case QWebEngineUrlRequestInfo::ResourceTypeFavicon:
        return QStringLiteral("image");
    case QWebEngineUrlRequestInfo::ResourceTypeFontResource:
        return QStringLiteral("font");
    case QWebEngineUrlRequestInfo::ResourceTypeObject:
    case QWebEngineUrlRequestInfo::ResourceTypePluginResource:
        return QStringLiteral("object");
    case QWebEngineUrlRequestInfo::ResourceTypeMedia:
        return QStringLiteral("media");
    case QWebEngineUrlRequestInfo::ResourceTypeXhr:
    case QWebEngineUrlRequestInfo::ResourceTypeJson:
        return QStringLiteral("xmlhttprequest");
    case QWebEngineUrlRequestInfo::ResourceTypePing:
        return QStringLiteral("ping");
    case QWebEngineUrlRequestInfo::ResourceTypeCspReport:
        return QStringLiteral("csp_report");
    case QWebEngineUrlRequestInfo::ResourceTypeWebSocket:
        return QStringLiteral("websocket");
    default:
        return QStringLiteral("other");
    }
}

void AdBlockManager::rebuildEngine()
{
    const QByteArray rules = combinedRules().toUtf8();
    FilkaAdBlockEngine *newEngine = filka_adblock_engine_new(
        reinterpret_cast<const std::uint8_t *>(rules.constData()),
        static_cast<std::size_t>(rules.size()));
    const int ruleCount = static_cast<int>(filka_adblock_engine_rule_count(newEngine));
    {
        QMutexLocker locker(&m_engineMutex);
        if (m_engine)
            filka_adblock_engine_free(m_engine);
        m_engine = newEngine;
    }
    setRulesCount(ruleCount);
    setStatusText(defaultStatus());
    attachExistingProfiles();
}

void AdBlockManager::attachExistingProfiles()
{
    for (const auto &profile : std::as_const(m_profiles)) {
        if (profile)
            profile->setUrlRequestInterceptor(&m_interceptor);
    }
}

void AdBlockManager::maybeAutoUpdate()
{
    if (!m_autoUpdate || m_updating)
        return;
    const QDateTime last = QDateTime::fromString(m_lastUpdateAt, Qt::ISODate);
    if (last.isValid() && last.secsTo(QDateTime::currentDateTimeUtc()) < 60 * 60 * 24)
        return;
    QMetaObject::invokeMethod(this, [this]() { refreshLists(); }, Qt::QueuedConnection);
}

void AdBlockManager::setUpdating(bool value)
{
    if (m_updating == value)
        return;
    m_updating = value;
    emit updatingChanged();
}

void AdBlockManager::setRulesCount(int value)
{
    if (m_rulesCount == value)
        return;
    m_rulesCount = value;
    emit rulesCountChanged();
}

void AdBlockManager::setLastUpdateAt(const QString &value)
{
    if (m_lastUpdateAt == value)
        return;
    m_lastUpdateAt = value;
    persistString(QStringLiteral("adblock/lastUpdateAt"), value);
    emit lastUpdateAtChanged();
}

void AdBlockManager::setStatusText(const QString &value)
{
    if (m_statusText == value)
        return;
    m_statusText = value;
    emit statusTextChanged();
}

void AdBlockManager::noteBlockedRequest()
{
    ++m_blockedRequests;
    QMetaObject::invokeMethod(this, [this]() { emit blockedRequestsChanged(); },
                              Qt::QueuedConnection);
}

void AdBlockManager::persistStringList(const QString &key, const QStringList &value)
{
    m_store.setValue(key, value);
    m_store.sync();
}

void AdBlockManager::persistBool(const QString &key, bool value)
{
    m_store.setValue(key, value);
    m_store.sync();
}

void AdBlockManager::persistString(const QString &key, const QString &value)
{
    m_store.setValue(key, value);
    m_store.sync();
}
