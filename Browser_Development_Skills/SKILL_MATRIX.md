# Skill Matrix

## Ядро браузера

Использовать `qt-webengine-browser-core`, когда задача касается:

- `QWebEngineProfile`, cookies, storage, cache, downloads;
- `QWebEnginePage`, permissions, navigation, lifecycle;
- PDF, media, popups, geolocation, clipboard, notifications;
- remote debugging, DevTools Protocol, WebEngine process behavior.

## C++ backend

Использовать `qt-cpp-browser-backend`, когда задача касается:

- моделей вкладок, истории, закладок, загрузок, профилей;
- C++/QML bridge, `QAbstractListModel`, singleton services;
- ownership, RAII, signals/slots, threading;
- persistence, SQLite, filesystem paths, migration logic.

## QML UI

Использовать `qml-browser-ui`, когда задача касается:

- shell browser UI: tabs, navigation bar, overlays, settings;
- Qt Quick Controls, keyboard navigation, focus, accessibility;
- responsive layout, visual states, animations;
- QML performance and avoiding binding churn.

## Security and privacy

Использовать `browser-security-privacy`, когда задача касается:

- permissions, sandbox assumptions, HTTPS, dangerous downloads;
- incognito/private mode, profile isolation, cookie policy;
- tracker/ad blocking, data clearing, storage boundaries;
- extension or script injection risks.

## Testing and debugging

Использовать `browser-testing-debugging`, когда задача касается:

- `ctest`, Qt Test, QML tests, regression tests;
- crash reproduction, logs, GDB/LLDB;
- WebEngine remote debugging and CDP;
- profiler traces, screenshots, runtime verification.

## Build and release

Использовать `browser-build-release`, когда задача касается:

- CMake, presets, Ninja, compile databases;
- GitHub Actions, artifacts, packaging;
- Windows/Linux/macOS release builds;
- changelog, tags, installer/runtime layout.

