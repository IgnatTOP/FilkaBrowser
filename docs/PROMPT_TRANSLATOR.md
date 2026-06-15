# Промт реализации: Умный переводчик страниц FilkaBrowser

## Контекст проекта

**FilkaBrowser** — Qt 6.7+/QML/C++20 браузер на движке Qt WebEngine (Chromium). Дизайн-система: Liquid Glass (транслюцентные поверхности, glass-компоненты, анимации через `Motion.qml`, токены в `Theme.qml`).

### Ключевые файлы для интеграции

| Файл | Роль |
|------|------|
| `app/src/data/AppSettings.{h,cpp}` | QML_SINGLETON для настроек (QSettings). Хранит darkMode, accentColor и т.д. |
| `app/src/data/HistoryModel.{h,cpp}` | QML_SINGLETON для истории (SQLite). |
| `app/qml/browser/BrowserView.qml` | Основная оболочка браузера. Управляет панелями через `show*` boolean-флаги. |
| `app/qml/browser/WebPane.qml` | Стек WebEngineView-ов воркспейса. `activeView` — текущий WebEngineView. |
| `app/qml/components/SidePanel.qml` | Переиспользуемый слайд-овер панель справа (с glass-фоном). |
| `app/qml/components/AddressBar.qml` | Адресная строка с resolve() для URL/search. |
| `app/qml/theme/Theme.qml` | Токены дизайна (цвета, радиусы, отступы, типографика). |
| `app/qml/theme/Motion.qml` | Токены анимаций (dur durations, easing curves). |
| `app/CMakeLists.txt` | Сборка QML-модуля Filka (SOURCES, QML_FILES, RESOURCES). |
| `app/src/main.cpp` | Точка входа, инициализация WebEngine. |

---

## Архитектура решения

```
┌─────────────────────────────────────────────────────┐
│  BrowserView.qml                                    │
│  ┌────────────────────────────────────────────────┐ │
│  │  toolbar: [← → ↻ 🏠 | address bar | 🔖 🌐⚙] │ │
│  │                                    [🌐 translator]│ │
│  └────────────────────────────────────────────────┘ │
│  ┌──────────────────────┐ ┌───────────────────────┐ │
│  │                      │ │  TranslatorPanel      │ │
│  │   WebPane            │ │  (SidePanel-based)    │ │
│  │   (activeView)       │ │  ┌─────────────────┐  │ │
│  │                      │ │  │ Source: EN       │  │ │
│  │                      │ │  │ Target: RU       │  │ │
│  │                      │ │  │ [Translate btn]  │  │ │
│  │                      │ │  │ ────────────────  │  │ │
│  │                      │ │  │ Streaming output  │ │ │
│  │                      │ │  │ with typewriter   │ │ │
│  │                      │ │  │ animation         │ │ │
│  │                      │ │  └─────────────────┘  │ │
│  └──────────────────────┘ └───────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## Детали реализации

### 1. C++ Backend: `PageTranslator` (HTTP-клиент для BotHub API)

**Файл:** `app/src/data/PageTranslator.h` + `app/src/data/PageTranslator.cpp`

**Назначение:** QML_SINGLETON, который:
- Извлекает текстовое содержимое текущей страницы через WebEngineView
- Отправляет запрос к BotHub API (OpenAI-совместимый шлюз)
- Использует модель `qwen3-next-80b-a3b-instruct:free`
- Возвращает переведённый текст (поддержка стриминга)

**Спецификация BotHub API:**

```
Endpoint: https://openai.bothub.chat/v1/chat/completions
Auth: Bearer <API_KEY>
Model: qwen3-next-80b-a3b-instruct:free
```

**Запрос:**
```json
{
  "model": "qwen3-next-80b-a3b-instruct:free",
  "messages": [
    {
      "role": "system",
      "content": "Ты профессиональный переводчик. Переводи текст, сохраняя контекст, стиль и форматирование. Отвечай ТОЛЬКО переведённым текстом, без комментариев."
    },
    {
      "role": "user",
      "content": "Переведи следующий текст на русский язык, сохранив контекст и стиль:\n\n{CONTENT}"
    }
  ],
  "stream": true
}
```

**Стриминговый ответ (SSE):**
```
data: {"id":"...","object":"chat.completion.chunk","choices":[{"delta":{"content":"Привет"},"index":0}]}
data: {"id":"...","object":"chat.completion.chunk","choices":[{"delta":{"content":" мир"},"index":0}]}
data: [DONE]
```

**Интерфейс класса:**

```cpp
// PageTranslator — smart page translator using BotHub API (qwen3-next-80b-a3b-instruct:free).
//
// Extracts text from the active WebEngineView, sends it to the BotHub OpenAI-compatible
// gateway for context-aware translation, and streams the result back to QML.
// The translated text is injected into a glass overlay panel with typewriter animation.

#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>
#include <QTimer>
#include <qqmlregistration.h>

class PageTranslator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Current state for QML binding.
    Q_PROPERTY(bool translating READ isTranslating NOTIFY translatingChanged)
    Q_PROPERTY(QString translatedText READ translatedText NOTIFY translatedTextChanged)
    Q_PROPERTY(QString sourceLanguage READ sourceLanguage WRITE setSourceLanguage NOTIFY sourceLanguageChanged)
    Q_PROPERTY(QString targetLanguage READ targetLanguage WRITE setTargetLanguage NOTIFY targetLanguageChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool panelVisible READ isPanelVisible WRITE setPanelVisible NOTIFY panelVisibleChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit PageTranslator(QObject *parent = nullptr);

    bool isTranslating() const { return m_translating; }
    QString translatedText() const { return m_translatedText; }
    QString sourceLanguage() const { return m_sourceLanguage; }
    void setSourceLanguage(const QString &lang);
    QString targetLanguage() const { return m_targetLanguage; }
    void setTargetLanguage(const QString &lang);
    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString &key);
    bool isPanelVisible() const { return m_panelVisible; }
    void setPanelVisible(bool visible);
    QString error() const { return m_error; }

    // Translate text content from a page. Called from QML after extracting
    // the page text via WebEngineView.runJavaScript("document.body.innerText").
    Q_INVOKABLE void translateText(const QString &pageText, const QString &pageTitle);

    // Cancel ongoing translation.
    Q_INVOKABLE void cancel();

    // Clear translated text.
    Q_INVOKABLE void clear();

signals:
    void translatingChanged();
    void translatedTextChanged();
    void sourceLanguageChanged();
    void targetLanguageChanged();
    void apiKeyChanged();
    void panelVisibleChanged();
    void errorChanged();

    // Emitted for each chunk during streaming — QML connects to this
    // for the typewriter animation effect.
    void chunkReceived(const QString &chunk);

private:
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply = nullptr;
    QTimer *m_streamTimer;

    bool m_translating = false;
    QString m_translatedText;
    QString m_sourceLanguage;
    QString m_targetLanguage;
    QString m_apiKey;
    bool m_panelVisible = false;
    QString m_error;

    // Accumulated SSE buffer for parsing streaming chunks.
    QByteArray m_sseBuffer;

    void startStreamRequest(const QString &content);
    void processSSEBuffer();
    void setTranslating(bool value);
    void setError(const QString &msg);
};
```

**Ключевые моменты реализации (C++):**

1. **HTTP-запрос через `QNetworkAccessManager`** — не требует дополнительных зависимостей, уже доступен в Qt6::Network (нужно добавить `find_package(Qt6 6.7 REQUIRED COMPONENTS ... Network)` в корневой CMakeLists.txt).

2. **Стриминг (SSE):** `m_reply` остаётся открытым, сигнал `readyRead` вызывает `processSSEBuffer()`, который парсит `data: {...}` строки и эмитит `chunkReceived(QString)`.

3. **Извлечение текста страницы** — вызывается из QML:
   ```qml
   activeView.runJavaScript("document.body.innerText", function(text) {
       PageTranslator.translateText(text, activeView.title)
   })
   ```

4. **API-ключ хранится в `QSettings`** через `AppSettings` или отдельно в `PageTranslator`.

---

### 2. QML UI: `TranslatorPanel.qml`

**Файл:** `app/qml/panels/TranslatorPanel.qml`

**Назначение:** Слайд-овер панель справа (наследует паттерн `SidePanel.qml`) с UI перевода.

**Дизайн-спецификация:**

```
┌──────────────────────────────────────┐
│  🌐 Переводчик                    ✕  │
├──────────────────────────────────────┤
│                                      │
│  [ English ▼ ]  →  [ Русский ▼ ]     │
│                                      │
│  ┌──────────────────────────────────┐│
│  │  Исходный текст (read-only)      ││
│  │  Превью первых 200 символов      ││
│  │  текущей страницы...             ││
│  └──────────────────────────────────┘│
│                                      │
│  [ 🔮 Перевести страницу ]           │
│  (aurora gradient кнопка)            │
│                                      │
│  ┌──────────────────────────────────┐│
│  │  Перевод                         ││
│  │  ┌────────────────────────────┐  ││
│  │  │ Привет мир! Это текст     │  ││
│  │  │ который появляется с      │  ││
│  │  │ анимацией печатной        │  ││
│  │  │ машинки...                │  ││
│  │  │ █ (cursor мигает)         │  ││
│  │  └────────────────────────────┘  ││
│  │                                  ││
│  │  [ 📋 Копировать ] [ 🔄 Заново]  ││
│  └──────────────────────────────────┘│
│                                      │
│  ────────────────────────────────────│
│  💡 Powered by BotHub + Qwen3       │
│                                      │
└──────────────────────────────────────┘
```

**Спецификация анимаций:**

| Элемент | Анимация | Параметры |
|---------|----------|-----------|
| Панель (вход) | Slide from right + fade | `duration: Motion.slow, easing: Motion.emphasized` |
| Панель (выход) | Slide right + fade | `duration: Motion.base, easing: Motion.exit` |
| Текст перевода | Typewriter (посимвольное появление) | `duration: Motion.instant per char, с cursor миганием` |
| Кнопка «Перевести» | Pulse glow during translation | `Behavior on opacity { NumberAnimation { duration: Motion.fast } }` |
| Scrim (затемнение) | Fade in/out | `duration: Motion.base` |
| Ошибка | Shake + fade | `NumberAnimation { from: -6; to: 0; duration: Motion.fast }` |

**Структура QML-компонента:**

```qml
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// TranslatorPanel — glass slide-over panel for smart page translation.
// Uses BotHub API (qwen3-next-80b-a3b-instruct:free) for context-aware
// translation with streaming typewriter animation.
SidePanel {
    id: root
    title: "Переводчик"

    property var activeView: null  // current WebEngineView

    // Language selector model
    ListModel {
        id: languages
        ListElement { name: "Русский"; code: "ru" }
        ListElement { name: "English"; code: "en" }
        ListElement { name: "Deutsch"; code: "de" }
        ListElement { name: "Français"; code: "fr" }
        ListElement { name: "中文"; code: "zh" }
        ListElement { name: "日本語"; code: "ja" }
        ListElement { name: "Español"; code: "es" }
        ListElement { name: "Português"; code: "pt" }
    }

    // --- Content area ---

    Flickable {
        anchors.fill: parent
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: Theme.s4

            // Language selectors (source → target)
            RowLayout {
                width: parent.width
                spacing: Theme.s3

                // Source language combo
                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: Theme.radiusMd
                    color: Theme.glassLow; border.width: 1; border.color: Theme.glassStroke
                    // ComboBox with glass styling...
                }

                Icon { name: "arrow-right"; size: 16; color: Theme.textMuted }

                // Target language combo
                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: Theme.radiusMd
                    color: Theme.glassLow; border.width: 1; border.color: Theme.glassStroke
                    // ComboBox with glass styling...
                }
            }

            // Source text preview
            Rectangle {
                width: parent.width; height: 120
                radius: Theme.radiusMd
                color: Theme.glassLow; border.width: 1; border.color: Theme.glassStroke
                Text {
                    anchors { fill: parent; margins: Theme.s3 }
                    text: PageTranslator.sourcePreview || "Нажмите «Перевести страницу» для извлечения текста..."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }
            }

            // Translate button (aurora gradient)
            Rectangle {
                width: parent.width; height: 44
                radius: Theme.radiusPill
                visible: !PageTranslator.translating
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.electricBlue }
                    GradientStop { position: 1.0; color: Theme.auroraPurple }
                }
                Text {
                    anchors.centerIn: parent
                    text: "Перевести страницу"
                    color: "white"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.extractAndTranslate() }
            }

            // Loading indicator (during translation)
            Row {
                visible: PageTranslator.translating
                spacing: Theme.s2
                // Animated dots or aurora spinner
            }

            // Translated text output
            Rectangle {
                width: parent.width; height: Math.min(outputText.implicitHeight + Theme.s6, 400)
                radius: Theme.radiusMd
                color: Theme.glassLow; border.width: 1; border.color: Theme.glassStroke
                visible: PageTranslator.translatedText.length > 0

                Text {
                    id: outputText
                    anchors { fill: parent; margins: Theme.s3 }
                    text: PageTranslator.translatedText + (PageTranslator.translating ? "▌" : "")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                }
            }

            // Action buttons (copy, redo)
            Row {
                visible: PageTranslator.translatedText.length > 0 && !PageTranslator.translating
                spacing: Theme.s3

                Rectangle {
                    width: copyRow.width + Theme.s4; height: 36
                    radius: Theme.radiusPill; color: Theme.glassLow
                    border.width: 1; border.color: Theme.glassStroke
                    Row { id: copyRow; anchors.centerIn: parent; spacing: Theme.s2
                        Icon { name: "copy"; size: 14; color: Theme.textSecondary }
                        Text { text: "Копировать"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: /* copy to clipboard */ }
                }

                Rectangle {
                    width: redoRow.width + Theme.s4; height: 36
                    radius: Theme.radiusPill; color: Theme.glassLow
                    border.width: 1; border.color: Theme.glassStroke
                    Row { id: redoRow; anchors.centerIn: parent; spacing: Theme.s2
                        Icon { name: "refresh-cw"; size: 14; color: Theme.textSecondary }
                        Text { text: "Заново"; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.extractAndTranslate() }
                }
            }

            // Footer
            Text {
                width: parent.width
                text: "Powered by BotHub + Qwen3"
                color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // --- Functions ---

    function extractAndTranslate() {
        if (!root.activeView) return
        // Step 1: extract page text via JS injection
        root.activeView.runJavaScript("document.body.innerText", function(text) {
            if (text && text.length > 0) {
                // Store preview (first 200 chars)
                PageTranslator.sourcePreview = text.substring(0, 200) + (text.length > 200 ? "..." : "")
                // Step 2: send to BotHub API
                PageTranslator.translateText(text, root.activeView.title)
            }
        })
    }
}
```

---

### 3. Интеграция в `BrowserView.qml`

Добавить в `BrowserView.qml`:

**a) Новый флаг и панель:**
```qml
property bool showTranslator: false
```

**b) Кнопка в тулбаре (рядом с настройками):**
```qml
IconButton {
    iconName: "languages"; size: 34
    active: root.showTranslator
    Accessible.name: "Translator"
    onClicked: { root.showHistory = false; root.showSettings = false; root.showDownloads = false; root.showTranslator = !root.showTranslator }
}
```

**c) Панель перевода (в section «Slide-over panels»):**
```qml
TranslatorPanel {
    open: root.showTranslator
    activeView: root.activeView
    onRequestClose: root.showTranslator = false
}
```

**d) Горячая клавиша Ctrl+Shift+T** (или другая, не занятая):
```qml
Shortcut { sequence: "Ctrl+Shift+T"; onActivated: { root.showTranslator = !root.showTranslator } }
```

---

### 4. Интеграция в `AppSettings.{h,cpp}`

Добавитьpersistency для настроек переводчика:

```cpp
// В AppSettings.h добавить:
Q_PROPERTY(QString translatorSourceLang READ translatorSourceLang WRITE setTranslatorSourceLang NOTIFY translatorSourceLangChanged)
Q_PROPERTY(QString translatorTargetLang READ translatorTargetLang WRITE setTranslatorTargetLang NOTIFY translatorTargetLangChanged)
Q_PROPERTY(QString botHubApiKey READ botHubApiKey WRITE setBotHubApiKey NOTIFY botHubApiKeyChanged)
```

---

### 5. Интеграция в `CMakeLists.txt`

```cmake
# В корневом CMakeLists.txt — добавить Network:
find_package(Qt6 6.7 REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2 WebEngineQuick Svg Sql Network)

# В app/CMakeLists.txt — добавить SOURCES и QML_FILES:
SOURCES
    ...existing...
    src/data/PageTranslator.h
    src/data/PageTranslator.cpp
QML_FILES
    ...existing...
    qml/panels/TranslatorPanel.qml
```

---

### 6. Иконка

Добавить SVG-иконку `languages` (или `globe`) в `app/assets/icons/` для кнопки переводчика. Использовать стиль Lucide (как остальные иконки в проекте).

---

## Детали стриминга и typewriter-анимации

### SSE парсинг (C++)

```cpp
void PageTranslator::processSSEBuffer()
{
    while (m_sseBuffer.contains('\n')) {
        int idx = m_sseBuffer.indexOf('\n');
        QByteArray line = m_sseBuffer.left(idx).trimmed();
        m_sseBuffer.remove(0, idx + 1);

        if (line.isEmpty()) continue;                    // empty line = event boundary
        if (line.startsWith("data: ")) {
            QByteArray data = line.mid(6);
            if (data == "[DONE]") {
                setTranslating(false);
                return;
            }
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonObject obj = doc.object();
            QJsonArray choices = obj["choices"].toArray();
            if (!choices.isEmpty()) {
                QJsonObject delta = choices[0].toObject()["delta"].toObject();
                QString content = delta["content"].toString();
                if (!content.isEmpty()) {
                    m_translatedText += content;
                    emit translatedTextChanged();
                    emit chunkReceived(content);     // для typewriter-анимации
                }
            }
        }
    }
}
```

### Typewriter-анимация (QML)

Два варианта реализации:

**Вариант А (простой):** Каждый чанк добавляется к `translatedText` в C++, QML показывает текст с мигающим курсором `▌`. Текст появляется "порциями" — достаточно плавно для стриминга.

**Вариант Б (продвинутый, посимвольный):** QML-компонент, который по таймеру раскрывает символы:

```qml
// TypewriterText — text that reveals character by character
Item {
    id: twRoot
    property string fullText: ""
    property bool streaming: true
    property int revealIndex: 0

    Timer {
        id: revealTimer
        interval: Motion.instant  // 90ms per char
        running: twRoot.streaming && twRoot.revealIndex < twRoot.fullText.length
        repeat: true
        onTriggered: {
            twRoot.revealIndex++
            displayText.text = twRoot.fullText.substring(0, twRoot.revealIndex)
        }
    }

    Text {
        id: displayText
        anchors.fill: parent
        color: Theme.textPrimary
        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
        wrapMode: Text.WordWrap
    }

    // Blinking cursor
    Text {
        visible: twRoot.streaming
        text: "▌"
        color: Theme.accent
        Timer {
            running: true; repeat: true; interval: 530
            onTriggered: cursor.visible = !cursor.visible
        }
    }

    Connections {
        target: PageTranslator
        function onChunkReceived(chunk) {
            twRoot.fullText += chunk
        }
    }

    onFullTextChanged: {
        if (!streaming) revealIndex = fullText.length
    }
}
```

---

## Языковые пары

| Исходный → Целевой | Код |
|---------------------|-----|
| Русский → Английский | ru → en |
| Английский → Русский | en → ru |
| Немецкий → Русский | de → ru |
| Французский → Русский | fr → ru |
| Китайский → Русский | zh → ru |
| Японский → Русский | ja → ru |
| Испанский → Русский | es → ru |
| Португальский → Русский | pt → ru |

Модель `qwen3-next-80b-a3b-instruct:free` поддерживает все эти языки.

---

## System Prompt для модели

```
Ты — профессиональный переводчик веб-страниц. Переводи предоставленный текст на {TARGET_LANG}, строго сохраняя:

1. Контекст и смысл — не искажай информацию
2. Стиль повествования — формальный остаётся формальным, разговорный — разговорным
3. Терминологию — используй устоявшиеся переводы технических терминов
4. Структуру — абзацы, списки, заголовки должны соответствовать оригиналу
5. Ссылки и имена собственные — не переводи URL, оставляй имена компаний/продуктов как есть

Отвечай ТОЛЬКО переведённым текстом. Не добавляй комментарии, пояснения или вступления.
Если текст уже на целевом языке, верни его без изменений.
```

---

## Файлы для создания/изменения

| Действие | Файл | Описание |
|----------|------|----------|
| **Создать** | `app/src/data/PageTranslator.h` | C++ класс переводчика (HTTP, SSE парсинг) |
| **Создать** | `app/src/data/PageTranslator.cpp` | Реализация PageTranslator |
| **Создать** | `app/qml/panels/TranslatorPanel.qml` | UI панель переводчика (glass slide-over) |
| **Создать** | `app/assets/icons/languages.svg` | Lucide-style иконка для кнопки |
| **Изменить** | `app/qml/browser/BrowserView.qml` | Добавить кнопку, панель, горячую клавишу |
| **Изменить** | `app/src/data/AppSettings.h` | Добавить настройки переводчика (lang, API key) |
| **Изменить** | `app/src/data/AppSettings.cpp` | Реализация getter/setter для новых настроек |
| **Изменить** | `app/CMakeLists.txt` | Добавить PageTranslator.{h,cpp} и TranslatorPanel.qml |
| **Изменить** | `CMakeLists.txt` (корень) | Добавить `Network` в `find_package` |
| **Изменить** | `app/src/main.cpp` | Зарегистрировать QML-тип PageTranslator (если потребуется) |

---

## Дополнительные требования

### Qt Network модуль
`PageTranslator` использует `QNetworkAccessManager` для HTTP-запросов. Нужно добавить `Qt6::Network` в `find_package` и `target_link_libraries`.

### Обработка ошибок
- Нет API-ключа → показать настройку в панели
- Нет интернета → показать ошибку с анимацией shake
- Rate limit → показать сообщение «Попробуйте позже»
- Пустая страница → «Нечего переводить»

### Конфиденциальность
- API-ключ хранится локально в QSettings, не отправляется никуда кроме BotHub
- Текст страницы отправляется напрямую в BotHub API (не кэшируется на стороне)
- При закрытии панели текст очищается из памяти

### Производительность
- Длинные страницы (>10000 символов) разбиваются на чанки по 3000 символов
- Каждый чанк переводится отдельно, результат конкатенируется
- Стриминг позволяет видеть результат до завершения всего перевода

---

## Пример интеграционного промта для LLM-ассистента

Используйте этот промт для генерации кода:

```
Реализуй функционал умного переводчика страниц для FilkaBrowser.

Контекст:
- Qt 6.7+, QML, C++20 браузер
- Дизайн-система: Liquid Glass (Theme.qml, Motion.qml, GlassPanel.qml, SidePanel.qml)
- BotHub API: https://openai.bothub.chat/v1/chat/completions
- Модель: qwen3-next-80b-a3b-instruct:free
- Auth: Bearer <API_KEY>

Что нужно сделать:

1. C++ класс PageTranslator (QML_SINGLETON):
   - HTTP POST к BotHub API с SSE-стримингом
   - Парсинг `data: {...}` строк из ответа
   - Эмит `chunkReceived(QString)` для каждого токена
   - Метод translateText(pageText, pageTitle)
   - Хранение API-ключа в QSettings
   - Методы cancel() и clear()

2. QML компонент TranslatorPanel.qml (наследует SidePanel паттерн):
   - ComboBox для выбора языков (source/target)
   - Превью исходного текста (первые 200 символов)
   - Кнопка «Перевести страницу» с aurora gradient
   - Typewriter-анимация вывода (мигающий курсор ▌)
   - Кнопки «Копировать» и «Заново»
   - Состояния: idle, translating, error, done

3. Интеграция в BrowserView.qml:
   - Кнопка «🌐» в тулбаре
   - Свойство showTranslator
   - TranslatorPanel как slide-over
   - Горячая кладиша Ctrl+Shift+T

4. Интеграция в CMakeLists.txt:
   - Добавить Qt6::Network
   - Добавить PageTranslator.{h,cpp} в SOURCES
   - Добавить TranslatorPanel.qml в QML_FILES

Ключевые файлы для паттернов:
- app/src/data/HistoryModel.{h,cpp} — паттерн QML_SINGLETON
- app/qml/components/SidePanel.qml — паттерн slide-over панели
- app/qml/panels/SettingsPanel.qml — паттерн UI настроек
- app/qml/theme/Theme.qml — токены дизайна
- app/qml/theme/Motion.qml — токены анимаций

API-формат BotHub:
POST https://openai.bothub.chat/v1/chat/completions
Headers: Authorization: Bearer <key>, Content-Type: application/json
Body: { "model": "qwen3-next-80b-a3b-instruct:free", "messages": [...], "stream": true }
SSE response: data: {"choices":[{"delta":{"content":"..."}}]} ... data: [DONE]
```
