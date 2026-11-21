@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur 05

REM ==================================================
REM VERSION 05 - STARTDATEI
REM Die eigentliche Verarbeitung erfolgt in der
REM gleichnamigen PowerShell-Datei.
REM ==================================================

set "PS1=%~dp0L04_EXE_Reparatur_005.ps1"

if not exist "%PS1%" (
    echo FEHLER: Die PowerShell-Datei wurde nicht gefunden:
    echo %PS1%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo Version 005 wurde ohne kritische Fehler beendet.
) else (
    echo Version 005 wurde mit Rueckgabecode %RC% beendet.
)
echo.
pause
exit /b %RC%
