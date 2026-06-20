---
name: browser-security-privacy
description: Review and implement browser security and privacy behavior. Use for permissions, HTTPS, sandbox assumptions, dangerous downloads, private/incognito mode, cookie and storage isolation, tracker blocking, data clearing, profile separation, extension/script injection risk, and release-time license or security checks.
---

# Browser Security And Privacy

## Workflow

1. Identify the trust boundary: local app, web content, profile data, download, extension-like code or external process.
2. Default to least privilege.
3. Make origin-scoped decisions explicit.
4. Keep private mode and normal profile storage separate.
5. Avoid silent persistence of sensitive data.
6. Add regression tests for security-sensitive state where practical.

## Security checklist

- Permissions are user-visible and origin-scoped.
- Downloads have safe states and do not auto-open dangerous content.
- Mixed content and HTTPS signals are not hidden.
- Remote debugging is disabled in production builds unless explicitly requested.
- Injected scripts are audited and scoped.
- Web content cannot directly access privileged C++ APIs.

## Privacy checklist

- Private windows do not persist cookies, history or storage into normal profile.
- Clear-data flows cover cookies, cache, history, downloads and site storage.
- Profile paths are separated.
- Tracker blocking decisions are testable and explainable.
- Sync or AI features do not leak browsing data by default.

## Useful sources

- Qt WebEngine security: https://doc.qt.io/qt-6/qtwebengine-security.html
- Chromium security: https://www.chromium.org/Home/chromium-security/
- Chromium sandbox: https://chromium.googlesource.com/chromium/src/+/main/docs/security/sandbox.md
- OWASP Secure Coding Practices: https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/
- REUSE: https://reuse.software/
- SPDX: https://spdx.dev/

