@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur 11

REM ==================================================
REM VERSION 011 - STARTDATEI
REM 1 = Nur Inventur
REM 2 = Inventur, ACL-Sicherung und anschliessende
REM     Auswahl zwischen Pruefen, Reparieren oder Abbruch.
REM ==================================================

set "PS1=%~dp0L04_EXE_Reparatur_011.ps1"

if not exist "%PS1%" (
    echo FEHLER: Die PowerShell-Datei wurde nicht gefunden:
    echo %PS1%
    echo.
    pause
    exit /b 1
)

echo.
echo L04 - EXE-Berechtigungsreparatur 011
echo.
echo 1 = Nur Inventur (EXE-Dateien und Registry)
echo 2 = Inventur + ACL-Sicherung + Pruefung/Reparatur
echo A = Abbrechen
echo.
choice /C 12A /N /M "Bitte 1, 2 oder A waehlen: "

if errorlevel 3 goto CANCEL
if errorlevel 2 goto REPAIR
if errorlevel 1 goto INVENTORY

:CANCEL
echo.
echo Vom Benutzer abgebrochen. Es wurde nichts gestartet.
set "RC=0"
goto END

:REPAIR
echo.
echo HINWEIS:
echo Die Reparatur wird nicht automatisch ausgefuehrt.
echo Nach der Inventur muessen die ACL-Sicherungen erfolgreich sein.
echo Danach fragt PowerShell nochmals:
echo P = Nur pruefen, R = RX gezielt ergaenzen, A = Abbrechen.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -EnableRepair
set "RC=%ERRORLEVEL%"
goto RESULT

:INVENTORY
echo.
echo Es wird nur die lesende Inventur ausgefuehrt.
echo Es werden keine ACL-Sicherungen erstellt und keine Rechte geaendert.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
goto RESULT

:RESULT
echo.
if "%RC%"=="0" (
    echo Version 011 wurde ohne kritische Fehler beendet.
) else (
    echo Version 011 wurde mit Rueckgabecode %RC% beendet.
)
goto END

:END
echo.
pause
exit /b %RC%
