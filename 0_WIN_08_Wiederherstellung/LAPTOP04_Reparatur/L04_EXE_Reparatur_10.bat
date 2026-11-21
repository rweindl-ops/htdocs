@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur 10
set "PS1=%~dp0L04_EXE_Reparatur_10.ps1"
if not exist "%PS1%" (
 echo FEHLER: PowerShell-Datei nicht gefunden: "%PS1%"
 pause
 exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (echo Inventurtest Version 10 ohne kritische Fehler beendet.) else (echo Inventurtest Version 10 mit Rueckgabecode %RC% beendet.)
echo.
pause
exit /b %RC%
