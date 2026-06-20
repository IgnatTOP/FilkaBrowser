// AppSettings — persistent user preferences (QSettings-backed QML singleton).
//
// Holds the small set of choices a "good browser" must remember between runs:
// colour theme, default search engine and the page new tabs open. QML reads and
// writes the properties directly; changes are saved immediately.

#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <qqmlregistration.h>

class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool onboarded READ onboarded WRITE setOnboarded NOTIFY onboardedChanged)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(bool startPageAurora READ startPageAurora WRITE setStartPageAurora NOTIFY startPageAuroraChanged)
    Q_PROPERTY(QString displayName READ displayName WRITE setDisplayName NOTIFY displayNameChanged)
    Q_PROPERTY(QString homeSubtitle READ homeSubtitle WRITE setHomeSubtitle NOTIFY homeSubtitleChanged)
    Q_PROPERTY(QString wallpaperPreset READ wallpaperPreset WRITE setWallpaperPreset NOTIFY wallpaperPresetChanged)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY reducedMotionChanged)
    Q_PROPERTY(bool homeSmartCards READ homeSmartCards WRITE setHomeSmartCards NOTIFY homeSmartCardsChanged)
    Q_PROPERTY(QString searchEngine READ searchEngine WRITE setSearchEngine NOTIFY searchEngineChanged)
    Q_PROPERTY(bool networkSuggestionsEnabled READ networkSuggestionsEnabled WRITE setNetworkSuggestionsEnabled NOTIFY networkSuggestionsEnabledChanged)
    Q_PROPERTY(QString homePage READ homePage WRITE setHomePage NOTIFY homePageChanged)
    Q_PROPERTY(QString downloadPath READ downloadPath WRITE setDownloadPath NOTIFY downloadPathChanged)
    Q_PROPERTY(bool askDownloadLocation READ askDownloadLocation WRITE setAskDownloadLocation NOTIFY askDownloadLocationChanged)
    Q_PROPERTY(bool restoreSessionEnabled READ restoreSessionEnabled WRITE setRestoreSessionEnabled NOTIFY restoreSessionEnabledChanged)
    Q_PROPERTY(bool verticalTabs READ verticalTabs WRITE setVerticalTabs NOTIFY verticalTabsChanged)
    Q_PROPERTY(qreal defaultZoom READ defaultZoom WRITE setDefaultZoom NOTIFY defaultZoomChanged)
    Q_PROPERTY(bool translatorCacheEnabled READ translatorCacheEnabled WRITE setTranslatorCacheEnabled NOTIFY translatorCacheEnabledChanged)
    Q_PROPERTY(bool translatorAutoOffer READ translatorAutoOffer WRITE setTranslatorAutoOffer NOTIFY translatorAutoOfferChanged)
    Q_PROPERTY(bool permissiveAutoplayEnabled READ permissiveAutoplayEnabled WRITE setPermissiveAutoplayEnabled NOTIFY permissiveAutoplayEnabledChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    bool onboarded() const { return m_onboarded; }
    void setOnboarded(bool value);

    bool darkMode() const { return m_darkMode; }
    void setDarkMode(bool value);

    QString accentColor() const { return m_accentColor; }
    void setAccentColor(const QString &value);

    bool startPageAurora() const { return m_startPageAurora; }
    void setStartPageAurora(bool value);

    QString displayName() const { return m_displayName; }
    void setDisplayName(const QString &value);

    QString homeSubtitle() const { return m_homeSubtitle; }
    void setHomeSubtitle(const QString &value);

    QString wallpaperPreset() const { return m_wallpaperPreset; }
    void setWallpaperPreset(const QString &value);

    bool reducedMotion() const { return m_reducedMotion; }
    void setReducedMotion(bool value);

    bool homeSmartCards() const { return m_homeSmartCards; }
    void setHomeSmartCards(bool value);

    QString searchEngine() const { return m_searchEngine; }
    void setSearchEngine(const QString &value);

    bool networkSuggestionsEnabled() const { return m_networkSuggestionsEnabled; }
    void setNetworkSuggestionsEnabled(bool value);

    QString homePage() const { return m_homePage; }
    void setHomePage(const QString &value);

    QString downloadPath() const { return m_downloadPath; }
    void setDownloadPath(const QString &value);

    bool askDownloadLocation() const { return m_askDownloadLocation; }
    void setAskDownloadLocation(bool value);

    bool restoreSessionEnabled() const { return m_restoreSessionEnabled; }
    void setRestoreSessionEnabled(bool value);

    bool verticalTabs() const { return m_verticalTabs; }
    void setVerticalTabs(bool value);

    qreal defaultZoom() const { return m_defaultZoom; }
    void setDefaultZoom(qreal value);

    bool translatorCacheEnabled() const { return m_translatorCacheEnabled; }
    void setTranslatorCacheEnabled(bool value);

    bool translatorAutoOffer() const { return m_translatorAutoOffer; }
    void setTranslatorAutoOffer(bool value);

    bool permissiveAutoplayEnabled() const { return m_permissiveAutoplayEnabled; }
    void setPermissiveAutoplayEnabled(bool value);

    // The list of selectable search-engine names (for the settings UI).
    Q_INVOKABLE QStringList searchEngines() const;
    // Builds a full search URL for the active engine and the given query.
    Q_INVOKABLE QString searchUrl(const QString &query) const;
    // Writable downloads directory — used as the target for "save as PDF".
    Q_INVOKABLE QString downloadDir() const;
    Q_INVOKABLE QString webStoragePath() const;
    Q_INVOKABLE QString webCachePath() const;
    Q_INVOKABLE bool isTrustedAutoplayHost(const QUrl &url) const;

signals:
    void onboardedChanged();
    void darkModeChanged();
    void accentColorChanged();
    void startPageAuroraChanged();
    void displayNameChanged();
    void homeSubtitleChanged();
    void wallpaperPresetChanged();
    void reducedMotionChanged();
    void homeSmartCardsChanged();
    void searchEngineChanged();
    void networkSuggestionsEnabledChanged();
    void homePageChanged();
    void downloadPathChanged();
    void askDownloadLocationChanged();
    void restoreSessionEnabledChanged();
    void verticalTabsChanged();
    void defaultZoomChanged();
    void translatorCacheEnabledChanged();
    void translatorAutoOfferChanged();
    void permissiveAutoplayEnabledChanged();

private:
    QSettings m_store;
    bool m_onboarded = false;
    bool m_darkMode = true;
    QString m_accentColor;
    bool m_startPageAurora = true;
    QString m_displayName;
    QString m_homeSubtitle;
    QString m_wallpaperPreset;
    bool m_reducedMotion = false;
    bool m_homeSmartCards = true;
    QString m_searchEngine;
    bool m_networkSuggestionsEnabled = false;
    QString m_homePage;
    QString m_downloadPath;
    bool m_askDownloadLocation = false;
    bool m_restoreSessionEnabled = true;
    bool m_verticalTabs = true;
    qreal m_defaultZoom = 1.0;
    bool m_translatorCacheEnabled = true;
    bool m_translatorAutoOffer = true;
    bool m_permissiveAutoplayEnabled = false;
};
