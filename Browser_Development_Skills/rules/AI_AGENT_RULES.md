# AI Agent Rules

## Architecture

- Use clean boundaries: QML presentation, C++ services/models, WebEngine integration.
- Use dependency direction from UI to interfaces/services, not from core state into view details.
- Prefer small explicit services over hidden global state.
- Keep browser domain concepts named directly: tabs, workspaces, profiles, sessions, history, bookmarks, downloads, permissions.

## C++

- Use Modern C++20 where the project supports it.
- Use RAII for ownership.
- Prefer value types for data records and QObject-derived types for Qt object lifecycles.
- Use `QPointer`, parent ownership or smart pointers intentionally; do not mix ownership styles casually.
- Keep models testable and expose stable roles.
- Avoid blocking work on the GUI thread.

## QML

- Keep bindings simple.
- Avoid unnecessary binding loops and repeated heavy JS in delegates.
- Keep component dimensions stable.
- Ensure keyboard and focus behavior for overlays, settings and menus.
- Reuse project theme, controls and motion patterns.

## Browser security and privacy

- Default to least privilege for permissions.
- Keep private profiles isolated.
- Make data clearing explicit and testable.
- Treat downloads as untrusted until complete and classified.
- Keep remote debugging a development-only capability.

## Testing

- Add tests near the risk.
- Use Qt Test for Qt models/services.
- Use QML tests for component behavior when practical.
- Use CDP/Playwright for web-layer smoke tests where WebEngine behavior matters.

