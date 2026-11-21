@echo off
setlocal EnableExtensions DisableDelayedExpansion
title WARS - EXE-Berechtigungsreparatur 013

REM ==================================================
REM VERSION 013 - STARTDATEI
REM Rechnerauswahl und Identitaetspruefung erfolgen
REM zentral in PowerShell. Bei Fehlwahl erscheint
REM ein modales Windows-Meldungsfenster.
REM ==================================================

set "PS1=%~dp0L04_EXE_Reparatur_013.ps1"

if not exist "%PS1%" (
    echo FEHLER: Die PowerShell-Datei wurde nicht gefunden:
    echo %PS1%
    echo.
    pause
    exit /b 1
)

echo.
echo WARS - EXE-Berechtigungsreparatur 013
echo Rechnerauswahl und Sicherheitspruefung werden gestartet.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo Version 013 wurde ohne kritische Fehler beendet.
) else if "%RC%"=="10" (
    echo Abbruch: Falscher Rechner ausgewaehlt.
) else (
    echo Version 013 wurde mit Rueckgabecode %RC% beendet.
)
echo.
pause
exit /b %RC%
