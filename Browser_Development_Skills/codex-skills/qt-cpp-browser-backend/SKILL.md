---
name: qt-cpp-browser-backend
description: Build and refactor Qt C++ backend code for a browser. Use for QAbstractListModel, QObject services, tab/session/history/bookmark/download/profile models, SQLite or filesystem persistence, C++/QML bridging, signals and slots, RAII ownership, threading, and testable Qt service architecture.
---

# Qt C++ Browser Backend

## Workflow

1. Find the owning model or service before adding state.
2. Keep durable browser state in C++ when it must be shared, persisted or tested.
3. Expose QML APIs as small, stable properties, invokable methods and model roles.
4. Use RAII and explicit QObject ownership.
5. Do long-running work off the UI thread and return results through signals.
6. Add focused tests for model state transitions and persistence boundaries.

## Browser backend responsibilities

- Tabs and workspaces.
- Session restore.
- History and bookmarks.
- Downloads.
- Profiles and private mode.
- Settings and migrations.
- Permission decisions.
- Import/export flows.

## C++ standards

- Prefer clear ownership over clever abstractions.
- Keep public slots/invokables small.
- Avoid exposing raw database or filesystem details to QML.
- Keep role names stable.
- Use explicit error states that QML can render.

## Useful sources

- C++ Core Guidelines: https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines
- Qt Core docs: https://doc.qt.io/qt-6/qtcore-index.html
- Qt QML C++ integration: https://doc.qt.io/qt-6/qtqml-cppintegration-topic.html
- Qt Test: https://doc.qt.io/qt-6/qttest-index.html

