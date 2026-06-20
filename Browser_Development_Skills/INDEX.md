# Browser Development Skills

Локальный набор skills, правил и источников для разработки desktop-браузера на Qt 6, C++, QML и Chromium через Qt WebEngine. CEF оставлен как альтернативный путь, если когда-нибудь понадобится больше контроля над Chromium.

## Структура

- `codex-skills/` - installable Codex-style skills с `SKILL.md`.
- `rules/` - правила для Cursor, Claude Code, Cline, Roo Code и универсальный `AGENTS.md`.
- `knowledge-sources/` - ссылки на официальные документы, community skills/rules и инструменты.
- `templates/` - готовые промпты для агента.
- `ROADMAP.md` - путь разработки браузера от MVP до production.
- `SKILL_MATRIX.md` - какие skills использовать для какой задачи.
- `TOOLCHAIN.md` - набор инструментов, которые агент должен уметь запускать.

## Быстрый старт

1. Для Codex скопировать нужные skills:

```bash
cp -a Browser_Development_Skills/codex-skills/* ~/.codex/skills/
```

2. Для Cursor положить правила из `rules/CURSOR_RULES.md` в `.cursor/rules/browser-development.mdc`.

3. Для Claude Code положить `rules/CLAUDE.md` в корень проекта как `CLAUDE.md` или слить с существующим файлом.

4. Для Cline/Roo Code использовать `rules/CLINE_ROO_RULES.md` как проектный rules-файл.

## Минимальный набор для этого проекта

- `qt-webengine-browser-core`
- `qt-cpp-browser-backend`
- `qml-browser-ui`
- `browser-security-privacy`
- `browser-testing-debugging`
- `browser-build-release`

## Уже найденные локальные skills на машине

Для FilkaBrowser уже доступны полезные skills:

- `qt-qml`
- `qt-qml-review`
- `qt-qml-profiler`
- `qt-qml-test`
- `qt-qml-test-run`
- `qt-cpp-review`
- `qt-cpp-docs`
- `qt-ui-design`
- `cmake`
- `frontend-design-ui-ux`
- `gh-fix-ci`
- `gh-address-comments`
- `codebase-migrate`
- `create-plan`
- `changelog-generator`
- `theme-factory`
- `canvas-design`

Новые skills в этой папке не заменяют их, а связывают в один браузерный workflow.

