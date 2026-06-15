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
    Q_PROPERTY(QString searchEngine READ searchEngine WRITE setSearchEngine NOTIFY searchEngineChanged)
    Q_PROPERTY(QString homePage READ homePage WRITE setHomePage NOTIFY homePageChanged)

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

    QString searchEngine() const { return m_searchEngine; }
    void setSearchEngine(const QString &value);

    QString homePage() const { return m_homePage; }
    void setHomePage(const QString &value);

    // The list of selectable search-engine names (for the settings UI).
    Q_INVOKABLE QStringList searchEngines() const;
    // Builds a full search URL for the active engine and the given query.
    Q_INVOKABLE QString searchUrl(const QString &query) const;

signals:
    void onboardedChanged();
    void darkModeChanged();
    void accentColorChanged();
    void startPageAuroraChanged();
    void searchEngineChanged();
    void homePageChanged();

private:
    QSettings m_store;
    bool m_onboarded = false;
    bool m_darkMode = true;
    QString m_accentColor;
    bool m_startPageAurora = true;
    QString m_searchEngine;
    QString m_homePage;
};
