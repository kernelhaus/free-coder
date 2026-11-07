@echo off
rem Double-click to install Free Coder. Bypasses the PowerShell script policy for this run only.
cd /d "%~dp0"
powershell -NoProfile -Command "Get-ChildItem -Recurse -File | Unblock-File" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\install.ps1"
echo.
pause
