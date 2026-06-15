@echo off
set QTWEBENGINE_DISABLE_SANDBOX=1
set QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu-compositing
start "" "%~dp0filka.exe" %*
