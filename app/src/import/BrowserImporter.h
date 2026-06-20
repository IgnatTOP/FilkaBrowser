#pragma once

#include <QFutureWatcher>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlregistration.h>

class BrowserImporter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY stageChanged)
    Q_PROPERTY(int importedBookmarks READ importedBookmarks NOTIFY importedCountsChanged)
    Q_PROPERTY(int importedHistory READ importedHistory NOTIFY importedCountsChanged)
    Q_PROPERTY(int importedPasswords READ importedPasswords NOTIFY importedCountsChanged)
    Q_PROPERTY(QVariantList browsers READ browsers NOTIFY browsersChanged)

public:
    explicit BrowserImporter(QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    qreal progress() const { return m_progress; }
    QString status() const { return m_status; }
    QString stage() const { return m_stage; }
    int importedBookmarks() const { return m_importedBookmarks; }
    int importedHistory() const { return m_importedHistory; }
    int importedPasswords() const { return m_importedPasswords; }
    QVariantList browsers() const { return m_browsers; }

    Q_INVOKABLE QVariantList detectInstalled();
    Q_INVOKABLE void startDetection();
    Q_INVOKABLE void startImportBookmarks(const QString &browserId);
    Q_INVOKABLE void startImportHistory(const QString &browserId);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void finishImportResult(const QVariantMap &result, const QString &kind);
    Q_INVOKABLE QVariantList importBookmarks(const QString &browserId);
    Q_INVOKABLE QVariantList importHistory(const QString &browserId);
    Q_INVOKABLE QVariantList importPasswords(const QString &browserId);
    Q_INVOKABLE QVariantMap browser(const QString &browserId) const;

signals:
    void busyChanged();
    void progressChanged();
    void statusChanged();
    void stageChanged();
    void importedCountsChanged();
    void browsersChanged();
    void bookmarksReady(const QVariantList &entries);
    void historyReady(const QVariantList &entries);

private:
    bool m_busy = false;
    qreal m_progress = 0.0;
    QString m_status;
    QString m_stage;
    int m_importedBookmarks = 0;
    int m_importedHistory = 0;
    int m_importedPasswords = 0;
    QVariantList m_browsers;
    bool m_cancelRequested = false;
    QFutureWatcher<QVariantList> m_detectionWatcher;
    QFutureWatcher<QVariantList> m_importWatcher;
    QString m_pendingKind;

    void setBusy(bool busy);
    void setProgress(qreal progress);
    void setStatus(const QString &status);
    void setStage(const QString &stage);
    void setImportedCounts(int bookmarks, int history, int passwords);

    QVariantList detectChromiumProfiles() const;
    QVariantList detectFirefoxProfiles() const;
    QVariantList readChromiumBookmarks(const QVariantMap &browser) const;
    QVariantList readChromiumHistory(const QVariantMap &browser) const;
    QVariantList readFirefoxBookmarks(const QVariantMap &browser) const;
    QVariantList readFirefoxHistory(const QVariantMap &browser) const;
    static void collectChromiumBookmarkNode(const QVariantMap &node, QVariantList *out);
    static bool isWebUrl(const QString &url);
};
