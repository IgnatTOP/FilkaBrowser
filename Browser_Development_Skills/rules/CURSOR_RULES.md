# Cursor Rules

Put this content in `.cursor/rules/browser-development.mdc`.

```md
---
description: Qt 6 C++/QML Chromium browser development rules
globs:
  - "app/**/*.cpp"
  - "app/**/*.h"
  - "app/**/*.qml"
  - "app/CMakeLists.txt"
  - "docs/**/*.md"
alwaysApply: true
---

You are working on a Qt 6 desktop browser built with C++, QML and Qt WebEngine.

Read `docs/DESIGN_SYSTEM.md` and `docs/ARCHITECTURE.md` before broad UI or architecture work.

Preserve existing architecture:
- QML owns presentation and interaction.
- C++ owns durable browser state, models, persistence and platform services.
- Qt WebEngine profile/page ownership must be explicit.
- Settings are a centered modal unless the project changes this convention.

Use these checks after code changes:
- `cmake --build build`
- `ctest --test-dir build --output-on-failure`
- `git diff --check`

Security-sensitive areas:
- profiles
- cookies
- downloads
- permissions
- private windows
- storage paths
- injected scripts
- remote debugging

Never invent a disconnected visual language. Match existing shared controls, theme tokens and motion rules.
```

