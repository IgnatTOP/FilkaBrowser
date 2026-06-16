#include "PageTranslator.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>

namespace {
const char *kEndpoint = "https://openai.bothub.chat/v1/chat/completions";
const char *kModel    = "gpt-oss-120b:free";
const char *kDefaultApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjZhNjExZmNmLWY5OWMtNGVmZS04MWMyLTAyNjYyNDVjMGM2OSIsImlzRGV2ZWxvcGVyIjp0cnVlLCJpYXQiOjE3ODE1NTQxNDksImV4cCI6MjA5NzEzMDE0OSwianRpIjoiTUZPQTBDdl9PT2w0ZG9CcSJ9.Cd7ooATVO_faFUHheI2NRP6hLzvGyqTuLfH75e4pCFc";
constexpr int kMaxChars = 8000;
}

PageTranslator::PageTranslator(QObject *parent) : QObject(parent)
{
    m_apiKey = m_store.value(QStringLiteral("translator/apiKey"),
                             QString::fromLatin1(kDefaultApiKey)).toString();
    m_sourceLanguage = m_store.value(QStringLiteral("translator/sourceLang"),
                                     QStringLiteral("Автоопределение")).toString();
    m_targetLanguage = m_store.value(QStringLiteral("translator/targetLang"),
                                     QStringLiteral("Русский")).toString();
}

void PageTranslator::setSourcePreview(const QString &text)
{
    if (m_sourcePreview == text)
        return;
    m_sourcePreview = text;
    emit sourcePreviewChanged();
}

void PageTranslator::setSourceLanguage(const QString &lang)
{
    if (m_sourceLanguage == lang)
        return;
    m_sourceLanguage = lang;
    m_store.setValue(QStringLiteral("translator/sourceLang"), lang);
    emit sourceLanguageChanged();
}

void PageTranslator::setTargetLanguage(const QString &lang)
{
    if (m_targetLanguage == lang)
        return;
    m_targetLanguage = lang;
    m_store.setValue(QStringLiteral("translator/targetLang"), lang);
    emit targetLanguageChanged();
}

void PageTranslator::setApiKey(const QString &key)
{
    if (m_apiKey == key)
        return;
    m_apiKey = key;
    m_store.setValue(QStringLiteral("translator/apiKey"), key);
    emit apiKeyChanged();
}

void PageTranslator::copyToClipboard(const QString &text) const
{
    if (auto *cb = QGuiApplication::clipboard())
        cb->setText(text);
}

void PageTranslator::setCachedText(const QString &text, const QString &title, const QString &url)
{
    if (m_cachedText == text && m_cachedTitle == title && m_cachedUrl == url)
        return;
    m_cachedText = text;
    m_cachedTitle = title;
    m_cachedUrl = url;
    emit cachedTextChanged();
    emit cachedTitleChanged();
    emit cachedUrlChanged();

    if (!text.isEmpty())
        setSourcePreview(text.left(240) + (text.length() > 240 ? QStringLiteral("…") : QString()));
}

void PageTranslator::clearCachedText()
{
    if (m_cachedText.isEmpty() && m_cachedTitle.isEmpty() && m_cachedUrl.isEmpty())
        return;
    m_cachedText.clear();
    m_cachedTitle.clear();
    m_cachedUrl.clear();
    emit cachedTextChanged();
    emit cachedTitleChanged();
    emit cachedUrlChanged();
}

QString PageTranslator::systemPrompt() const
{
    return QStringLiteral(
        "Ты — профессиональный переводчик веб-страниц. Переводи предоставленный "
        "текст на %1, строго сохраняя контекст и смысл, стиль повествования, "
        "терминологию, структуру (абзацы, списки, заголовки), а также имена "
        "собственные и URL (их не переводи). Отвечай ТОЛЬКО переведённым текстом, "
        "без комментариев и вступлений. Если текст уже на целевом языке, верни его "
        "без изменений.").arg(m_targetLanguage);
}

void PageTranslator::translateText(const QString &pageText, const QString &pageTitle)
{
    if (m_translating)
        cancel();

    setError(QString());

    const QString trimmed = pageText.trimmed();
    if (trimmed.isEmpty()) {
        setError(QStringLiteral("Нечего переводить — страница пустая."));
        return;
    }
    if (m_apiKey.isEmpty()) {
        setError(QStringLiteral("Не указан API-ключ BotHub. Добавьте его в панели переводчика."));
        return;
    }

    // Reset output.
    m_translatedText.clear();
    emit translatedTextChanged();
    m_sseBuffer.clear();

    QString content = trimmed;
    if (content.size() > kMaxChars)
        content = content.left(kMaxChars) + QStringLiteral("\n\n[…текст обрезан…]");

    setTranslating(true);
    startStreamRequest(content, pageTitle);
}

void PageTranslator::translateBatch(const QString &markedText)
{
    if (m_translating)
        cancel();

    setError(QString());

    const QString trimmed = markedText.trimmed();
    if (trimmed.isEmpty()) {
        setError(QStringLiteral("Нечего переводить — страница пустая."));
        return;
    }
    if (m_apiKey.isEmpty()) {
        setError(QStringLiteral("Не указан API-ключ BotHub."));
        return;
    }

    m_translatedText.clear();
    emit translatedTextChanged();
    m_sseBuffer.clear();
    m_batchResult.clear();
    m_batchMode = true;

    setTranslating(true);
    startBatchRequest(trimmed);
}

void PageTranslator::startBatchRequest(const QString &content)
{
    QNetworkRequest req((QUrl(QString::fromLatin1(kEndpoint))));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArrayLiteral("application/json"));
    req.setRawHeader(QByteArrayLiteral("Authorization"),
                     QByteArrayLiteral("Bearer ") + m_apiKey.toUtf8());
    req.setRawHeader(QByteArrayLiteral("Accept"), QByteArrayLiteral("text/event-stream"));

    const QString sysPrompt = QStringLiteral(
        "Ты — переводчик. Переведи текст на %1. "
        "Сохрани ВСЕ маркеры [N] без изменений — они стоят перед каждым сегментом. "
        "Не добавляй и не удаляй маркеры. Не добавляй комментарии. "
        "Верни ТОЛЬКО переведённый текст с маркерами.").arg(m_targetLanguage);

    QJsonObject sys{{QStringLiteral("role"), QStringLiteral("system")},
                    {QStringLiteral("content"), sysPrompt}};
    QJsonObject usr{{QStringLiteral("role"), QStringLiteral("user")},
                    {QStringLiteral("content"), content}};

    QJsonObject body{
        {QStringLiteral("model"), QString::fromLatin1(kModel)},
        {QStringLiteral("messages"), QJsonArray{sys, usr}},
        {QStringLiteral("stream"), true},
    };

    m_reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(m_reply, &QNetworkReply::readyRead, this, [this] {
        if (!m_reply) return;
        m_sseBuffer += m_reply->readAll();
        processSSEBuffer();
    });
    connect(m_reply, &QNetworkReply::finished, this, &PageTranslator::onReplyFinished);
}

void PageTranslator::startStreamRequest(const QString &content, const QString &pageTitle)
{
    QNetworkRequest req((QUrl(QString::fromLatin1(kEndpoint))));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArrayLiteral("application/json"));
    req.setRawHeader(QByteArrayLiteral("Authorization"),
                     QByteArrayLiteral("Bearer ") + m_apiKey.toUtf8());
    req.setRawHeader(QByteArrayLiteral("Accept"), QByteArrayLiteral("text/event-stream"));

    QString userMsg = content;
    if (!pageTitle.isEmpty())
        userMsg = QStringLiteral("Заголовок страницы: %1\n\n%2").arg(pageTitle, content);

    QJsonObject sys{{QStringLiteral("role"), QStringLiteral("system")},
                    {QStringLiteral("content"), systemPrompt()}};
    QJsonObject usr{{QStringLiteral("role"), QStringLiteral("user")},
                    {QStringLiteral("content"), userMsg}};

    QJsonObject body{
        {QStringLiteral("model"), QString::fromLatin1(kModel)},
        {QStringLiteral("messages"), QJsonArray{sys, usr}},
        {QStringLiteral("stream"), true},
    };

    m_reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(m_reply, &QNetworkReply::readyRead, this, [this] {
        if (!m_reply) return;
        m_sseBuffer += m_reply->readAll();
        processSSEBuffer();
    });
    connect(m_reply, &QNetworkReply::finished, this, &PageTranslator::onReplyFinished);
}

void PageTranslator::processSSEBuffer()
{
    int idx;
    while ((idx = m_sseBuffer.indexOf('\n')) >= 0) {
        QByteArray line = m_sseBuffer.left(idx).trimmed();
        m_sseBuffer.remove(0, idx + 1);

        if (line.isEmpty() || !line.startsWith("data:"))
            continue;

        QByteArray data = line.mid(5).trimmed();
        if (data == "[DONE]")
            return;

        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
        if (perr.error != QJsonParseError::NoError)
            continue;

        const QJsonArray choices = doc.object().value(QStringLiteral("choices")).toArray();
        if (choices.isEmpty())
            continue;
        const QString chunk = choices.at(0).toObject()
                                  .value(QStringLiteral("delta")).toObject()
                                  .value(QStringLiteral("content")).toString();
        if (!chunk.isEmpty()) {
            m_translatedText += chunk;
            if (m_batchMode)
                m_batchResult += chunk;
            emit translatedTextChanged();
            emit chunkReceived(chunk);
        }
    }
}

void PageTranslator::onReplyFinished()
{
    if (!m_reply)
        return;

    const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QNetworkReply::NetworkError err = m_reply->error();

    if (err != QNetworkReply::NoError && err != QNetworkReply::OperationCanceledError) {
        // Prefer a server-supplied message if present.
        QString msg = m_reply->errorString();
        const QByteArray rest = m_reply->readAll();
        const QJsonObject obj = QJsonDocument::fromJson(rest).object();
        if (obj.contains(QStringLiteral("error"))) {
            const QJsonValue e = obj.value(QStringLiteral("error"));
            const QString m = e.isObject() ? e.toObject().value(QStringLiteral("message")).toString()
                                           : e.toString();
            if (!m.isEmpty()) msg = m;
        }
        if (status == 429)
            msg = QStringLiteral("Слишком много запросов. Попробуйте позже.");
        else if (status == 401)
            msg = QStringLiteral("Неверный API-ключ BotHub.");
        setError(msg);
    } else if (err == QNetworkReply::NoError && m_translatedText.isEmpty()) {
        setError(QStringLiteral("Пустой ответ от сервиса перевода."));
    }

    m_reply->deleteLater();
    m_reply = nullptr;
    if (m_batchMode) {
        m_batchMode = false;
        emit batchReady(m_batchResult);
    }
    setTranslating(false);
}

void PageTranslator::cancel()
{
    if (m_reply)
        m_reply->abort();          // triggers finished() with OperationCanceledError
    setTranslating(false);
}

void PageTranslator::clear()
{
    cancel();
    m_translatedText.clear();
    m_sourcePreview.clear();
    m_cachedText.clear();
    m_cachedTitle.clear();
    m_cachedUrl.clear();
    emit translatedTextChanged();
    emit sourcePreviewChanged();
    emit cachedTextChanged();
    emit cachedTitleChanged();
    emit cachedUrlChanged();
    setError(QString());
}

void PageTranslator::setTranslating(bool value)
{
    if (m_translating == value)
        return;
    m_translating = value;
    emit translatingChanged();
}

void PageTranslator::setError(const QString &msg)
{
    if (m_error == msg)
        return;
    m_error = msg;
    emit errorChanged();
}
