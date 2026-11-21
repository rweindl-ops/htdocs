@echo off
setlocal EnableExtensions DisableDelayedExpansion
title WARS - EXE-Berechtigungsreparatur 012

REM ==================================================
REM VERSION 012 - STARTDATEI
REM Die Rechnerauswahl und Identitaetspruefung erfolgen
REM zentral in PowerShell, bevor ein Reparaturmodus startet.
REM ==================================================

set "PS1=%~dp0L04_EXE_Reparatur_012.ps1"

if not exist "%PS1%" (
    echo FEHLER: Die PowerShell-Datei wurde nicht gefunden:
    echo %PS1%
    echo.
    pause
    exit /b 1
)

echo.
echo WARS - EXE-Berechtigungsreparatur 012
echo Rechnerauswahl und Sicherheitspruefung werden gestartet.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo Version 012 wurde ohne kritische Fehler beendet.
) else if "%RC%"=="10" (
    echo Abbruch: Falscher Rechner ausgewaehlt.
) else (
    echo Version 012 wurde mit Rueckgabecode %RC% beendet.
)
echo.
pause
exit /b %RC%
