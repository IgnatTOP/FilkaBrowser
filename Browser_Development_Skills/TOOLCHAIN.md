# Toolchain For Browser Agent

## Required baseline

- `rg` - fast repository search.
- `cmake` + `ninja` - repeatable builds.
- `compile_commands.json` - semantic C++ tooling.
- `clangd` - C++ navigation, diagnostics, rename, references.
- `qmlls` - QML Language Server.
- `qmllint` and `qmlformat` - QML checks and formatting.
- `ctest` - unified test runner.
- `git` and GitHub CLI or GitHub app - issues, PRs, CI, releases.

## Strongly recommended

- `clang-tidy` - C++ static analysis.
- `clazy` - Qt-specific static analysis.
- `ast-grep` - structural search and rewrite.
- `ccache` or `sccache` - faster rebuilds.
- GDB on Linux, LLDB on macOS and as a cross-platform debugger.
- Playwright MCP or Playwright CLI - browser automation and web-layer smoke tests.
- Qt WebEngine remote debugging via `--remote-debugging-port=9222`.

## Advanced production layer

- IWYU - include hygiene and build-time reduction.
- Cppcheck - independent static analysis signal.
- Valgrind, Heaptrack, Hotspot, Tracy - Linux memory and performance work.
- REUSE/SPDX tooling - release-time license inventory.
- Squish for Qt - optional commercial GUI automation.

## Standard local validation order

For FilkaBrowser prefer this order:

```bash
cmake --build build
ctest --test-dir build --output-on-failure
git diff --check
```

Use `qmllint` as a secondary signal when local Qt modules are discoverable.

