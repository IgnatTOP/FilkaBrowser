# Filka Browser — Architecture

> Status: MVP in progress. This document tracks the **client** architecture.
> Backend services (accounts, sync, VPN control) are later phases.

## Stack (MVP)

| Layer | Choice | Notes |
|-------|--------|-------|
| Rendering engine | **Qt WebEngine** (Chromium) | Native QML integration; CEF / Chromium fork deferred. |
| UI | **Qt 6 + QML** | GPU rendering, shaders, `MultiEffect` blur, high-refresh-rate. |
| Client core | **C++** | Tabs, workspaces, data models exposed to QML. |
| Build | **CMake** + Qt 6.7+ | |
| Local storage | **SQLite** (`Qt6::Sql`) | bookmarks / history / downloads. |

Rust + PostgreSQL + Redis + S3 + Xray belong to the **backend phases** (not MVP).

## Module map (client)

```
app/
  src/
    main.cpp        entry point, WebEngine init, QML engine
    browser/        TabModel, TabManager, WebProfile        (M2/M3)
    workspace/      WorkspaceModel, tab groups, session     (M4)
    data/           bookmarks / history / downloads (SQLite) (M5)
    platform/       per-OS blur/acrylic                      (M7)
  qml/
    theme/          Theme, Motion (design tokens)            (M1)
    components/     GlassPanel, GlassButton, IconButton, chrome
    browser/        TabStrip, WebView wrapper                (M2/M3)
    workspace/      WorkspaceSwitcher                        (M4)
    panels/         VpnPanel(mock), AiPanel(mock), …         (M6)
    settings/       settings screen                          (M5)
```

## Milestones

M0 foundation · M1 design system · M2 web engine + address bar · M3 tabs ·
M4 workspaces · M5 data + settings · M6 ecosystem panels (mock) · M7 polish.

## Deferred (post-MVP)

VPN (Xray), accounts (JWT/OAuth2), E2EE sync, password manager, AI backend,
privacy engine, update system, extensions API. UI placeholders only in MVP.
