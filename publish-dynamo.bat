@echo off
REM Double-click launcher for publish-dynamo.ps1 (keeps the window open at the end)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish-dynamo.ps1" %*
pause
