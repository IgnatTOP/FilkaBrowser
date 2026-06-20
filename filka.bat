@echo off
rem Keep WebEngine sandbox enabled by default. For local diagnostics only, run:
rem set FILKA_DISABLE_WEBENGINE_SANDBOX=1
set QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu-compositing
set QT_DEBUG_PLUGINS=1
"%~dp0filka.exe" %*
echo.
echo === Process exited with code %ERRORLEVEL% ===
pause
