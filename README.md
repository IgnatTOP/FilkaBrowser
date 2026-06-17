<p align="center">
  <img src="app/assets/logo.png" width="120" alt="Filka Browser">
</p>

<h1 align="center">Filka Browser</h1>

<p align="center">
  <b>Современный десктопный браузер на Qt 6 / WebEngine</b><br>
  <sub>Компактный chrome, рабочие пространства, приватные окна и быстрые команды</sub>
</p>

<p align="center">
  <a href="#особенности">Особенности</a> •
  <a href="#скриншоты">Скриншоты</a> •
  <a href="#сборка">Сборка</a> •
  <a href="#структура-проекта">Структура</a> •
  <a href="#обновления">Обновления</a> •
  <a href="#лицензия">Лицензия</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Qt-6.8+-00B900?style=flat-square&logo=qt&logoColor=white" alt="Qt 6.8+">
  <img src="https://img.shields.io/badge/C++-20-00599C?style=flat-square&logo=cplusplus&logoColor=white" alt="C++20">
  <img src="https://img.shields.io/badge/CMake-3.21+-064F8C?style=flat-square&logo=cmake&logoColor=white" alt="CMake 3.21+">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-FF6C37?style=flat-square" alt="Platform">
</p>

---

## Особенности

### Дизайн браузера
Filka использует спокойный desktop chrome: компактная навигация, читаемые панели, светлая/тёмная тема, акцентный цвет и минимум декоративного шума. Интерфейс рассчитан на повседневное использование, а не на демонстрационный экран.

### Вкладки и рабочие пространства
- **Вертикальные и горизонтальные вкладки** — переключение одним кликом
- **Рабочие пространства** (Work / Dev / Personal / Study) — изолированные наборы вкладок, как в Arc. Переключение мгновенное, страницы не перезагружаются
- **Редактируемые пространства** — создание, переименование и удаление прямо из переключателя
- **Закрепление вкладок**, сессия восстанавливается при перезапуске
- **Приватные окна** (`Ctrl+Shift+N`) — отдельный off-the-record профиль без записи истории

### Быстрые команды и стартовая страница
- **Командная палитра** (`Ctrl+Shift+P`) — команды, вкладки, история, закладки и быстрые ссылки в одном поиске
- **Редактируемые быстрые ссылки** на стартовой странице
- **Недавняя история и закладки** на новой вкладке

### Встроенный переводчик страниц
- Перевод на **8 языков** прямо на странице — текст заменяется in-place
- Пошаговый перевод длинных страниц без блокировки интерфейса
- Выбор целевого языка, откат к оригиналу
- Работает через нейросеть (API BotHub / Qwen)

### Умная строка адреса
- Поиск и навигация в одном поле
- Автоопределение URL vs поискового запроса
- Индикатор безопасности (HTTPS) и прогресс загрузки
- Горячие клавиши: `Ctrl+L`, `Ctrl+K`, `Alt+D`

### Другое
- **Закладки** с панелью быстрого доступа
- **История** посещений с относительным временем
- **Загрузки** с историей, прогрессом, паузой/продолжением, отменой и optional prompt перед сохранением
- **Поиск на странице** (`Ctrl+F`)
- **Информация о сайте** по клику на замок/глобус в адресной строке
- **Инструменты разработчика** (F12) — отдельное окно
- **Масштабирование** (`Ctrl++` / `Ctrl+-` / `Ctrl+0`)
- **Светлая и тёмная тема** + 7 акцентных цветов
- **Автообновление** — проверка GitHub Releases при запуске

---

## Сборка

### Требования

| Компонент | Минимальная версия |
|-----------|-------------------|
| Qt        | 6.8               |
| CMake     | 3.21              |
| C++       | 20                |
| GCC / Clang | 14+ / 16+      |

### Qt-модули

```
Core Gui Qml Quick QuickControls2 WebEngineCore WebEngineQuick Svg Sql Network
```

### Сборка из исходников

```bash
# Клонировать
git clone https://github.com/IgnatTOP/FilkaBrowser.git
cd FilkaBrowser

# Настроить и собрать
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# Запустить
./build/app/filka
```

### Установка (Linux)

```bash
cmake --install build --prefix ~/.local
```

### Сборка на Windows

#### Автоматическая (GitHub Actions)

При пуше в `main` или создании тега `v*` автоматически собирается Windows-билд.
Скачать готовый `Filka-<ref>-windows-x86_64.zip` можно из раздела **Actions → Artifacts**.

#### Локальная сборка

Требования:
- **Visual Studio 2022** (MSVC v143+)
- **CMake** 3.21+
- **Qt 6.8+** (модули: Core, Gui, Qml, Quick, QuickControls2, WebEngineCore, WebEngineQuick, Svg, Sql, Network; Test нужен только при `BUILD_TESTING=ON`)
- **Ninja** (рекомендуется) или Visual Studio generator
- **ImageMagick** (для генерации иконки из `logo.png`)

```powershell
# Настроить (от Developer Command Prompt for VS)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Собрать
cmake --build build --config Release

# Запустить
.\build\app\filka.exe
```

#### Упаковка

```powershell
windeployqt --release --qmldir app/qml build/app/filka.exe
```

---

## Структура проекта

```
FilkaBrowser/
├── app/
│   ├── assets/           # Логотип, SVG-иконки (Lucide-стиль)
│   ├── qml/
│   │   ├── Main.qml      # Корневое окно (Aurora-фон, безрамочный)
│   │   ├── WelcomeDialog.qml
│   │   ├── browser/      # BrowserView, TabPanel, TabStrip, WebPane, StartPage…
│   │   ├── components/   # GlassPanel, IconButton, AddressBar, SidePanel…
│   │   ├── panels/       # HistoryPanel, SettingsPanel, DownloadsPanel, TranslatorPanel
│   │   ├── theme/        # Theme.qml, Motion.qml (дизайн-система)
│   │   └── workspace/    # WorkspaceSwitcher
│   └── src/
│       ├── main.cpp      # Точка входа, настройка Chromium/WebEngine
│       ├── browser/      # TabModel (C++)
│       ├── workspace/    # WorkspaceModel (C++)
│       ├── data/         # HistoryModel, BookmarkModel, PageTranslator, AppSettings
│       └── update/       # UpdateChecker (автообновления)
├── CMakeLists.txt
├── docs/                 # Архитектурные заметки
└── README.md
```

---

## Обновления

Filka автоматически проверяет наличие новых версий через **GitHub Releases** при каждом запуске (с задержкой 3 секунды, чтобы не тормозить старт).

Как это работает:

1. При старте `UpdateChecker` делает запрос к `api.github.com/repos/IgnatTOP/FilkaBrowser/releases/latest`
2. Сравнивает текущую версию приложения с тегом последнего релиза
3. Если версия новее — показывается **UpdateBanner** в верхней части окна
4. Баннер содержит краткое описание релиза и кнопку «Скачать»
5. Скачивание открывает страницу релиза с файлом для вашей платформы (Linux / macOS / Windows)
6. Баннер можно закрыть; повторно не появится до следующего обновления

### Подготовка релиза

Для работы системы обновлений создавайте релизы на GitHub с тегами формата `v0.2.0` и прикрепляйте файлы:

| Платформа | Имя ассета |
|-----------|-----------|
| Linux x86_64 | `Filka-<tag>-linux-x86_64.AppImage` |
| macOS ARM | `filka-macos-arm64.dmg` |
| macOS Intel | `filka-macos-x86_64.dmg` |
| Windows | `Filka-<tag>-windows-x86_64.zip` |

---

## Горячие клавиши

| Действие | Комбинация |
|----------|-----------|
| Новая вкладка | `Ctrl+T` |
| Новое окно | `Ctrl+N` |
| Приватное окно | `Ctrl+Shift+N` |
| Закрыть вкладку | `Ctrl+W` |
| Командная палитра | `Ctrl+Shift+P` |
| Фокус на строку адреса | `Ctrl+L` / `Ctrl+K` / `Alt+D` |
| Переключение вкладок | `Ctrl+Tab` / `Ctrl+Shift+Tab` |
| К вкладке 1–8 | `Ctrl+1` … `Ctrl+8` |
| К последней вкладке | `Ctrl+9` |
| Назад | `Alt+←` |
| Вперёд | `Alt+→` |
| Обновить | `Ctrl+R` |
| Поиск на странице | `Ctrl+F` |
| Масштаб + | `Ctrl++` |
| Масштаб − | `Ctrl+-` |
| Сброс масштаба | `Ctrl+0` |
| Инструменты разработчика | `F12` |
| Переводчик | `Ctrl+Alt+T` |
| Полный экран (выйти) | `Escape` |

---

## Технологии

- **Qt 6.8+** — фреймворк с QML, WebEngine, MultiEffect (блюр)
- **Chromium** — встроенный движок через Qt WebEngine с GPU-композитингом
- **Liquid Glass** — кастомная дизайн-система: стеклянные панели, анимации, темы
- **Aurora** — анимированный фон стартовой страницы (три дрейфующих сферы с блюром)
- **C++20** — модели данных (вкладки, рабочие пространства, история, закладки, переводчик)
- **QML** — полностью кастомный UI без нативных виджетов

---

## Лицензия

MIT License. Используйте как хотите.

---

<p align="center">
  <sub>Filka Browser — сделано с вниманием к деталям</sub>
</p>
