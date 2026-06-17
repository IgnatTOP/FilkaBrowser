# Filka Browser — Architecture

> Status: MVP in progress. This document tracks the **client** architecture.
> Backend services (accounts, sync, VPN control) are later phases.

## Stack (MVP)

| Layer | Choice | Notes |
|-------|--------|-------|
| Rendering engine | **Qt WebEngine** (Chromium) | Native QML integration; persistent and private profiles. |
| UI | **Qt 6 + QML** | Tokenized desktop browser chrome, panels, command palette. |
| Client core | **C++** | Tabs, workspaces, data models exposed to QML. |
| Build | **CMake** + Qt 6.8+ | |
| Local storage | **SQLite** (`Qt6::Sql`) | bookmarks / history / downloads. |

Rust + PostgreSQL + Redis + S3 + Xray belong to the **backend phases** (not MVP).

## Module map (client)

```
app/
  src/
    main.cpp        entry point, WebEngine init, QML engine
    browser/        TabModel, TabManager, WebProfile        (M2/M3)
    workspace/      WorkspaceModel, tab groups, session     (M4)
    data/           bookmarks / history / quick links / downloads / settings
    platform/       per-OS blur/acrylic                      (M7)
  qml/
    theme/          Theme, Motion (design tokens)            (M1)
    components/     reusable chrome controls
    browser/        TabStrip, WebPane, command palette, site info
    workspace/      editable WorkspaceSwitcher
    panels/         History, Downloads, Settings, Translator
```

## Milestones

M0 foundation · M1 design system · M2 web engine + address bar · M3 tabs ·
M4 workspaces · M5 data + settings · M6 browser convenience · M7 polish.

## Deferred (post-MVP)

VPN (Xray), accounts (JWT/OAuth2), E2EE sync, password manager, AI backend,
full extension API and full adblock/privacy engine.
