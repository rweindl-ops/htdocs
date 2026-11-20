@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur 06

REM ==================================================
REM VERSION 06 - STARTDATEI
REM Die eigentliche Verarbeitung erfolgt in der
REM gleichnamigen PowerShell-Datei.
REM ==================================================

set "PS1=%~dp0L04_EXE_Reparatur_06.ps1"

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
    echo Version 06 wurde ohne kritische Fehler beendet.
) else (
    echo Version 06 wurde mit Rueckgabecode %RC% beendet.
)
echo.
pause
exit /b %RC%
