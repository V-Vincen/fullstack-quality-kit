@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-project.ps1" %*
exit /b %ERRORLEVEL%
