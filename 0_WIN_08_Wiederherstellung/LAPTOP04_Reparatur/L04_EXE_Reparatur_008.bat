@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsdiagnose 08
set "PS1=%~dp0L04_EXE_Reparatur_008.ps1"
if not exist "%PS1%" (echo FEHLER: PowerShell-Datei fehlt: "%PS1%"& pause& exit /b 1)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
echo.
echo Version 008 beendet mit Rueckgabecode %RC%.
pause
exit /b %RC%
