# Agent Rules For Qt Browser Development

## Project shape

This project is a Qt Quick desktop browser. UI lives under `app/qml`, C++ support lives under `app/src`, and project guidance lives in `docs/DESIGN_SYSTEM.md` and `docs/ARCHITECTURE.md`.

## Engineering rules

- Prefer existing project patterns over new frameworks.
- Keep QML UI, C++ models/services and WebEngine ownership clearly separated.
- Do not block the UI thread from QML callbacks or C++ slots invoked by QML.
- Treat browser profile, cookies, storage, permissions and downloads as security-sensitive.
- Preserve user data by default; destructive profile/data operations require explicit user intent.
- Use `WorkspaceModel` for cross-workspace tab aggregation.
- Prefer isolated QML components with explicit integration points.
- Use C++ models for state that must be shared, persisted, tested or coordinated.
- Do not hide runtime errors behind UI-only changes.

## Validation

Run the strongest relevant checks available:

```bash
cmake --build build
ctest --test-dir build --output-on-failure
git diff --check
```

If a UI or WebEngine behavior changed, verify with runtime logs, screenshots, remote debugging or a focused manual reproduction path.

