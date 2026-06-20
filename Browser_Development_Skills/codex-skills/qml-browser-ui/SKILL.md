---
name: qml-browser-ui
description: Design, implement and refine QML/Qt Quick browser UI. Use for tabs, navigation bar, settings modal, sidebars, overlays, menus, keyboard shortcuts, focus, accessibility, responsive layout, theme tokens, motion, QML performance, and visual consistency in a desktop browser shell.
---

# QML Browser UI

## Workflow

1. Read the local design system before broad visual changes.
2. Use shared theme, controls and motion patterns.
3. Keep fixed-format elements stable with explicit dimensions and responsive constraints.
4. Make keyboard, focus and accessibility behavior part of the implementation.
5. Keep QML delegates lightweight and avoid expensive JS in bindings.
6. Verify the actual shell visually or with runtime screenshots when possible.

## Browser UI surfaces

- Tab strip.
- Navigation bar.
- Omnibox and suggestions.
- Settings modal.
- Downloads, history and bookmarks panels.
- Permission prompts.
- Find-in-page and tab search overlays.
- Media controls and picture-in-picture.

## Performance rules

- Avoid binding loops.
- Avoid manual event-loop spinning from C++ called by QML.
- Keep per-frame work small.
- Prefer model roles over QML-side data reconstruction.
- Profile before deep optimization.

## Useful sources

- Qt Quick docs: https://doc.qt.io/qt-6/qtquick-index.html
- Qt Quick Controls: https://doc.qt.io/qt-6/qtquickcontrols-index.html
- QML performance: https://doc.qt.io/qt-6/qtquick-performance.html
- QML Language Server: https://doc.qt.io/qt-6/qtqml-tooling-qmlls.html
- qmllint: https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html

