---
name: qt-webengine-browser-core
description: Work on Qt WebEngine browser-core behavior in a Qt 6 C++/QML desktop browser. Use for QWebEngineProfile, QWebEnginePage, WebEngineView, cookies, storage, downloads, permissions, PDF/media handling, remote debugging, DevTools Protocol, process behavior, profile isolation, and Qt WebEngine vs CEF trade-offs.
---

# Qt WebEngine Browser Core

## Workflow

1. Locate the profile/page/view owner before editing.
2. Identify whether the behavior belongs in C++, QML, or both.
3. Treat profiles, cookies, permissions, downloads and storage as security-sensitive.
4. Prefer explicit `QWebEngineProfile` setup for persistent storage, cache and cookies.
5. Keep private/incognito profile behavior isolated from the default profile.
6. Validate with a focused runtime scenario, not just compilation.

## Checkpoints

- Profile path is deterministic and platform-appropriate.
- Persistent cookies and cache settings match the requested mode.
- Downloads have lifecycle states and user-visible failure paths.
- Permission prompts are explicit, revocable and scoped to origin.
- Popups, fullscreen, PDF and media behavior are handled intentionally.
- Remote debugging is used only for development diagnostics.

## Useful sources

- Qt WebEngine docs: https://doc.qt.io/qt-6/qtwebengine-index.html
- Qt WebEngine QML types: https://doc.qt.io/qt-6/qtwebengine-qmlmodule.html
- Qt WebEngine debugging: https://doc.qt.io/qt-6/qtwebengine-debugging.html
- Chromium DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/
- CEF project: https://bitbucket.org/chromiumembedded/cef

