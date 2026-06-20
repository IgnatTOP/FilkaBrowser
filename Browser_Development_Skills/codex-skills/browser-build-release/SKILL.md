---
name: browser-build-release
description: Configure, build, package and release a cross-platform Qt WebEngine browser. Use for CMake, CMake presets, Ninja, compile_commands.json, Qt deployment, GitHub Actions, CI artifacts, Windows installer fixes, Linux/macOS packaging, version bumps, tags, release notes and license inventory.
---

# Browser Build And Release

## Workflow

1. Identify target platform and build type.
2. Keep CMake target boundaries clean.
3. Generate or preserve `compile_commands.json` for tooling.
4. Build locally before changing CI.
5. Package WebEngine runtime resources explicitly.
6. For releases, bump version, tag, push and verify artifacts.

## Local commands

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

## CI/release checklist

- Linux, Windows and macOS matrix is explicit.
- Qt version and WebEngine modules are installed.
- WebEngine subprocess/resources/translations are included.
- Artifacts are named with version and platform.
- Release notes match actual commits.
- License inventory is generated or updated for shipped dependencies.

## Useful sources

- CMake docs: https://cmake.org/cmake/help/latest/
- CMake presets: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html
- Qt deployment: https://doc.qt.io/qt-6/deployment.html
- Deploying Qt WebEngine: https://doc.qt.io/qt-6/qtwebengine-deploying.html
- GitHub Actions: https://docs.github.com/actions
- GitHub MCP Server: https://github.com/github/github-mcp-server

