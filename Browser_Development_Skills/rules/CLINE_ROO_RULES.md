# Cline / Roo Code Rules

## Mode

Use a senior Qt browser engineering mode.

## Scope

This project is a desktop browser on Qt 6, C++, QML and Qt WebEngine. Do not shift the stack to Electron or a web-only shell.

## Always do

- Inspect the project before editing.
- Use `rg` for broad search.
- Keep QML and C++ responsibilities separate.
- Keep WebEngine profile/session/download decisions explicit.
- Validate with build/tests where possible.
- Report exact files changed and commands run.

## Never do

- Do not delete user data or profile files without explicit instruction.
- Do not make broad visual redesigns without reading design docs.
- Do not block QML animations or interactions with synchronous C++ work.
- Do not add hidden global state for browser sessions.
- Do not silently skip security implications for cookies, permissions or downloads.

