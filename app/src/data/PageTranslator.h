// PageTranslator — smart page translator using the BotHub API
// (qwen3-next-80b-a3b-instruct:free).
//
// A QML_SINGLETON. QML extracts the active page's text via
// WebEngineView.runJavaScript("document.body.innerText"), hands it to
// translateText(), and this class streams a context-aware translation back from
// the BotHub OpenAI-compatible gateway. Tokens arrive via chunkReceived() and
// accumulate in translatedText for the glass translator panel.

#pragma once

#include <QByteArray>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSettings>
#include <QString>
#include <qqmlregistration.h>

class QNetworkReply;

class PageTranslator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool translating READ isTranslating NOTIFY translatingChanged)
    Q_PROPERTY(QString translatedText READ translatedText NOTIFY translatedTextChanged)
    Q_PROPERTY(QString sourcePreview READ sourcePreview WRITE setSourcePreview NOTIFY sourcePreviewChanged)
    Q_PROPERTY(QString sourceLanguage READ sourceLanguage WRITE setSourceLanguage NOTIFY sourceLanguageChanged)
    Q_PROPERTY(QString targetLanguage READ targetLanguage WRITE setTargetLanguage NOTIFY targetLanguageChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool hasApiKey READ hasApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString cachedText READ cachedText NOTIFY cachedTextChanged)
    Q_PROPERTY(QString cachedTitle READ cachedTitle NOTIFY cachedTitleChanged)
    Q_PROPERTY(QString cachedUrl READ cachedUrl NOTIFY cachedUrlChanged)

public:
    explicit PageTranslator(QObject *parent = nullptr);

    bool isTranslating() const { return m_translating; }
    QString translatedText() const { return m_translatedText; }

    QString sourcePreview() const { return m_sourcePreview; }
    void setSourcePreview(const QString &text);

    QString sourceLanguage() const { return m_sourceLanguage; }
    void setSourceLanguage(const QString &lang);

    QString targetLanguage() const { return m_targetLanguage; }
    void setTargetLanguage(const QString &lang);

    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString &key);
    bool hasApiKey() const { return !m_apiKey.isEmpty(); }

    QString error() const { return m_error; }

    QString cachedText() const { return m_cachedText; }
    QString cachedTitle() const { return m_cachedTitle; }
    QString cachedUrl() const { return m_cachedUrl; }

    // Store pre-extracted page text (called from BrowserView before panel opens).
    Q_INVOKABLE void setCachedText(const QString &text, const QString &title, const QString &url);
    Q_INVOKABLE void clearCachedText();

    // Translate the supplied page text. pageTitle is used as light context.
    Q_INVOKABLE void translateText(const QString &pageText, const QString &pageTitle);
    // Batch translate (non-streaming) for in-page injection. Emits batchReady().
    Q_INVOKABLE void translateBatch(const QString &markedText);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void copyToClipboard(const QString &text) const;

signals:
    void translatingChanged();
    void translatedTextChanged();
    void sourcePreviewChanged();
    void sourceLanguageChanged();
    void targetLanguageChanged();
    void apiKeyChanged();
    void errorChanged();
    void cachedTextChanged();
    void cachedTitleChanged();
    void cachedUrlChanged();
    void chunkReceived(const QString &chunk);
    void batchReady(const QString &result);

private:
    QNetworkAccessManager m_nam;
    QNetworkReply *m_reply = nullptr;
    QSettings m_store;

    bool m_translating = false;
    QString m_translatedText;
    QString m_sourcePreview;
    QString m_sourceLanguage;
    QString m_targetLanguage;
    QString m_apiKey;
    QString m_error;
    QString m_cachedText;
    QString m_cachedTitle;
    QString m_cachedUrl;

    QByteArray m_sseBuffer;
    QString m_batchResult;
    bool m_batchMode = false;

    void startStreamRequest(const QString &content, const QString &pageTitle);
    void startBatchRequest(const QString &content);
    void processSSEBuffer();
    void onReplyFinished();
    void setTranslating(bool value);
    void setError(const QString &msg);
    QString systemPrompt() const;
};
