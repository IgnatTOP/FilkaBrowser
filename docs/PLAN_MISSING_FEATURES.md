# Plan: Недостающие функции Filka Browser

Дата: 2026-06-17
Статус: Черновик

---

## Обзор

Filka Browser — современный десктопный браузер на Qt 6 / WebEngine с workspace-подходом (как Arc), стеклянным chrome и встроенным переводчиком. Уже реализованы: вкладки, рабочие пространства, закладки, история, загрузки, командная палитра, переводчик страниц, тёмная/светлая темы, приватные окна, автообновления.

Данный план описывает 5 функций, необходимых для комфортного повседневного использования.

---

## [F1] Скриншоты

### Зачем
Нет способа сохранить скриншот страницы — ни entire page, ни области. Пользователи ежедневно скриншотят статьи, документы, UI.

### Реализация

**Кнопка в NavigationBar:**
- Иконка `camera` в правой части тулбара (между зумом и переключателем вкладок)
- По клику — popover с двумя вариантами:
  - "Весь экран" — захват видимой области через `activeView.grabToImage()`
  - "Область" — оверлей выделения

**Режим "Область":**
- QML Rectangle с DragHandler поверх WebPane
- Полупрозрачный оверлэй (затемнение), выделенная зона — прозрачная
- Зафиксированные размеры показываются рядом с курсором
- Enter / клик по иконке подтверждение, Escape — отмена
- Захват только выделенного региона через `activeView.grabToImage()` + crop в QML

**Сохранение:**
- В папку загрузок: `{title}_{yyyy-MM-dd_HHmmss}.png`
- Опция "Копировать в буфер" — popover с кнопкой после захвата
- Уведомление внизу экрана: "Скриншот сохранён" с кнопкой "Открыть"

**Горячие клавиши:**
- `Ctrl+Shift+S` — весь экран
- `Ctrl+Shift+Alt+S` — область

**Контекстное меню вкладки:**
- Добавить пункт "Скриншот вкладки" в TabContextMenu

### Файлы
- Новый: `app/qml/browser/ScreenshotOverlay.qml`
- Новый: `app/qml/browser/ScreenshotPrompt.qml`
- Изменить: `app/qml/browser/NavigationBar.qml` — добавить кнопку
- Изменить: `app/qml/browser/BrowserShortcuts.qml` — горячие клавиши
- Изменить: `app/qml/browser/TabContextMenu.qml` — пункт меню

---

## [F2] Picture-in-Picture (Картинка в картинке)

### Зачем
Нет возможности вынести видео в отдельное окно. При переключении вкладки видео скрывается.

### Реализация

**Обнаружение видео:**
- На каждой странице (WebPane) через `runJavaScript` inject скрипт, ищущий `<video>` элементы
- Если видео найдено — показывать иконку `maximize-2` в WebContextMenu при клике на видео

**PiP окно:**
- Отдельное `Window` с `flags: Qt.WindowStaysOnTopHint | Qt.Tool`
- Размер: 320×180 (перетаскиваемое, resizable от 200×112 до 1920×1080)
- Содержимое: `WebEngineView` с инжектированным CSS, скрывающим всё кроме `<video>`
- Кнопки управления: play/pause, закрыть, вернуть в вкладку
- Позиция: по умолчанию — правый нижний угол экрана

**WebContextMenu:**
- Новый пункт "Открыть в Picture-in-Picture" (видимо только когда клик по `<video>`)

**Горячие клавиши:**
- `Ctrl+Shift+P` — toggle PiP для активного видео

### Файлы
- Новый: `app/qml/browser/PictureInPictureWindow.qml`
- Новый: `app/src/media/PipManager.h/.cpp` — управление PiP окнами
- Изменить: `app/qml/browser/WebContextMenu.qml` — пункт PiP
- Изменить: `app/qml/browser/WebPane.qml` — inject скрипта обнаружения видео
- Изменить: `app/CMakeLists.txt` — добавить PipManager

---

## [F3] Медиа-контролы

### Зачем
Нет глобального управления воспроизведением. Если на 5 вкладках играет музыка — нет способа поставить всё на паузу.

### Реализация

**Отслеживание:**
- `TabModel` уже хранит `muted` и отслеживает `recentlyAudible`
- Добавить свойство `audibleTabs` — список вкладок с активным звуком

**Кнопка в NavigationBar:**
- Иконка `music` появляется когда `audibleTabs.length > 0`
- Расположение: перед переключателем темы (moon/sun)
- По клику — popover внизу

**Popover медиа-контролов:**
- Список вкладок со звуком (макс. 5)
- Каждая строка: favicon + title + кнопка play/pause + кнопка mute
- Кнопка "Пауза всё" внизу popover
- Клик по заголовку вкладки → переключение на неё

**Горячие клавиши:**
- `Ctrl+Shift+M` — глобальная пауза/воспроизведение всех аудио-вкладок

### Файлы
- Новый: `app/qml/browser/MediaControlsPopover.qml`
- Изменить: `app/qml/browser/NavigationBar.qml` — кнопка music
- Изменить: `app/src/browser/TabModel.h/.cpp` — audibleTabs
- Изменить: `app/qml/browser/BrowserShortcuts.qml` — Ctrl+Shift+M

---

## [F4] Импорт из других браузеров

### Зачем
Нет способа перенести закладки, историю, пароли из Chrome/Firefox. Это первый барьер при переходе.

### Реализация

**C++ Backend:**
- Класс `BrowserImporter` (Q_INVOKABLE)
- Методы:
  - `detectInstalled()` → список найденных браузеров
  - `importBookmarks(browser)` → импорт в BookmarkModel
  - `importHistory(browser)` → импорт в HistoryModel
  - `importPasswords(browser)` → импорт (encrypted, requires key)

**Поддерживаемые браузеры:**
- Chrome/Chromium: `~/.config/google-chrome/Default/` (Bookmarks JSON, History SQLite)
- Firefox: `~/.mozilla/firefox/*.default/` (places.sqlite)
- Opera: `~/.config/opera/` (Chromium-based)

**UI в SettingsPanel:**
- Категория "Дополнительно" → секция "Импорт данных"
- Кнопка "Импорт из другого браузера"
- Выбор браузера (detectInstalled список)
- Прогресс-бар + статистика (N закладок, M записей истории)
- Кнопка "Завершить"

**Горячие клавиши:**
- Нет (только через настройки)

### Файлы
- Новый: `app/src/import/BrowserImporter.h/.cpp`
- Новый: `app/qml/browser/ImportDialog.qml`
- Изменить: `app/qml/panels/SettingsPanel.qml` — секция импорта
- Изменить: `app/CMakeLists.txt` — добавить BrowserImporter

---

## [F5] Поиск по вкладкам

### Зачем
При 20+ вкладках в разных workspace нет способа быстро найти нужную. Command Palette показывает вкладки, но смешивает их с командами и закладками.

### Реализация

**Кнопка в NavigationBar:**
- Иконка `layout-grid` (или `tabs`) в правой части
- Расположение: между кнопками панелей (history/downloads/translator) и кнопкой темы

**Поисковый оверлей (Tab Search):**
- Аналогичен CommandPalette по стилю, но специализирован
- Поле поиска сверху: "Найти вкладку..."
- Список ВСЕХ вкладок из ВСЕХ workspace:
  - favicon + title + URL + badge workspace
  - Группировка по workspace (разделители)
- Фильтрация по title и URL
- Клик → переключение на вкладку (активирует нужный workspace + index)
- `Ctrl+Shift+Tab` — toggle оверлея
- `Escape` — закрыть

**Дополнительно:**
- Показать количество вкладок в workspace badge
- "Закрыть вкладку" кнопка справа от каждого элемента (как в HistoryPanel)

### Файлы
- Новый: `app/qml/browser/TabSearchOverlay.qml`
- Изменить: `app/qml/browser/NavigationBar.qml` — кнопка
- Изменить: `app/qml/browser/BrowserShortcuts.qml` — Ctrl+Shift+Tab
- Изменить: `app/qml/browser/ShellState.qml` — activeOverlay "tabSearch"

---

## Порядок реализации

| # | Функция | Сложность | Приоритет |
|---|---------|-----------|-----------|
| F5 | Поиск по вкладкам | Низкая | Высокий |
| F1 | Скриншоты | Средняя | Высокий |
| F3 | Медиа-контролы | Средняя | Средний |
| F2 | Picture-in-Picture | Высокая | Средний |
| F4 | Импорт из браузеров | Высокая | Средний |

Рекомендуемый порядок: F5 → F1 → F3 → F2 → F4

---

## Зависимости

- F1, F2, F3, F5 — независимы, можно делать параллельно
- F4 — независима, но требует больше C++ кода
- Все функции используют существующие паттерны (GlassPanel, IconButton, ShellState)
