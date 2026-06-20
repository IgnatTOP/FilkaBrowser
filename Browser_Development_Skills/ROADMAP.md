# Browser Implementation Roadmap

## Phase 1 - Stable local MVP

- Single main window with WebEngine view.
- Tabs with create, close, reorder, restore, mute, pin.
- Navigation bar with URL/search parsing, back, forward, reload, stop.
- Persistent default profile with cookies, cache, storage path and downloads path.
- Private profile that does not leak into normal profile.
- History, bookmarks and downloads as explicit C++ models exposed to QML.
- Basic settings modal with profile, privacy and UI options.
- Build and tests passing locally.

## Phase 2 - Browser product basics

- Session restore with windows, workspaces and selected tabs.
- Tab search, recently closed tabs, workspace-level tab aggregation.
- Permission prompts for camera, mic, geolocation, notifications, clipboard.
- Download manager with danger states, open file, show in folder, retry.
- PDF handling, media controls, picture-in-picture and full screen.
- Import from Chromium/Firefox profile copies.
- Clear browsing data by data type and time range.

## Phase 3 - Quality and security

- Security review of profile ownership and storage isolation.
- Strict private-mode tests.
- Static analysis pass with clang-tidy and clazy.
- QML performance profiling on shell interactions.
- CDP-based web compatibility smoke tests.
- Crash logging and reproducible diagnostic bundle.
- Release-time license inventory for Qt WebEngine and third-party code.

## Phase 4 - Cross-platform release

- GitHub Actions matrix for Linux, Windows and macOS.
- Packaged runtime assets and WebEngine subprocess resources.
- Windows installer and portable build.
- Linux AppImage or package artifact.
- macOS bundle, signing path and notarization plan.
- Version bump, tag push and GitHub Release notes.

## Phase 5 - Differentiation

- AI page summary, translation and smart bookmark naming.
- Local/private AI mode where possible.
- Side panel with tabs, bookmarks, history and AI actions.
- Better privacy controls: tracker blocking, cookie partition policy, per-site data view.
- Extensions strategy: either WebEngine-supported surface or explicit non-extension feature alternatives.

