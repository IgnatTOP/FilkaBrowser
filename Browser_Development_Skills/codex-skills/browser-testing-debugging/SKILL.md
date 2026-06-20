---
name: browser-testing-debugging
description: Test, debug and reproduce failures in a Qt WebEngine browser. Use for cmake builds, ctest, Qt Test, QML tests, crash logs, runtime diagnostics, screenshots, GDB, LLDB, Valgrind, QML profiling, Qt WebEngine remote debugging, Chrome DevTools Protocol and Playwright smoke tests.
---

# Browser Testing And Debugging

## Workflow

1. Reproduce the failure with the smallest useful scenario.
2. Capture command, logs, platform and build configuration.
3. Decide whether the issue is C++, QML, WebEngine, packaging or site compatibility.
4. Use focused diagnostics before broad refactors.
5. Fix the owner layer.
6. Re-run the failing scenario and the project baseline checks.

## Standard checks

```bash
cmake --build build
ctest --test-dir build --output-on-failure
git diff --check
```

## WebEngine diagnostics

Use remote debugging for page, DOM, network and storage inspection:

```bash
./build/app/filka --remote-debugging-port=9222
```

Then inspect the DevTools endpoint or connect with a CDP-capable tool.

## Debugging map

- QML binding/layout bug: QML logs, qmllint, runtime screenshot.
- C++ model bug: Qt Test, model role inspection, signal tracing.
- Profile/cookie bug: profile path, storage policy, WebEngine settings, CDP storage view.
- Crash: debugger, stack trace, symbols, minimal reproduction.
- Performance: QML Profiler first, then native profiler if needed.

## Useful sources

- Qt Test: https://doc.qt.io/qt-6/qttest-index.html
- QML performance: https://doc.qt.io/qt-6/qtquick-performance.html
- Qt WebEngine debugging: https://doc.qt.io/qt-6/qtwebengine-debugging.html
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- GoogleTest: https://google.github.io/googletest/

