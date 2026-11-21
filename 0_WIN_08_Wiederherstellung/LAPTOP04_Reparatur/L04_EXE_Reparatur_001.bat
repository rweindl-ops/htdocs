@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur

rem ============================================================
rem L04 EXE-Reparatur
rem Prueft EXE-Dateien unter C:\Programme.
rem Ergaenzt fuer VORDEFINIERT\Benutzer nur dann RX,
rem wenn Lesen/Ausfuehren fehlt und kein passender DENY-Eintrag
rem gefunden wird.
rem ============================================================

set "ROOT=C:\Program Files"
set "BASE=D:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP04_Reparatur"
set "BACKUP=%BASE%\ACL_Sicherungen"
set "TEMPACL=%TEMP%\L04_EXE_ACL_TEMP.txt"

if not exist "%ROOT%\" (
    echo FEHLER: Der Suchpfad "%ROOT%" wurde nicht gefunden.
    pause
    exit /b 2
)

if not exist "%BASE%\" md "%BASE%"
if not exist "%BACKUP%\" md "%BACKUP%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
if not defined STAMP set "STAMP=ohne_Zeitstempel"

set "ACLFILE=%BACKUP%\ACL_vorher_%STAMP%.txt"
set "LOG=%BACKUP%\Reparatur_%STAMP%.log"

echo ============================================================
echo L04 - EXE-Berechtigungspruefung und Reparatur
echo Suchpfad: %ROOT%
echo Sicherung: %ACLFILE%
echo Protokoll: %LOG%
echo ============================================================
echo.
echo WICHTIG: Dieses Skript muss als Administrator ausgefuehrt werden.
echo.

echo Start: %date% %time% > "%LOG%"
echo Suchpfad: %ROOT% >> "%LOG%"

echo Sichere zuerst die ACLs des gesamten Suchbaums ...
icacls "%ROOT%" /save "%ACLFILE%" /T /C > "%BACKUP%\Backup_Status_%STAMP%.txt" 2>&1

if not exist "%ACLFILE%" (
    echo FEHLER: ACL-Sicherung wurde nicht erstellt. Es werden keine Rechte geaendert.
    echo FEHLER: ACL-Sicherung fehlt. Abbruch. >> "%LOG%"
    pause
    exit /b 3
)

echo ACL-Sicherung erstellt.
echo ACL-Sicherung: %ACLFILE% >> "%LOG%"
echo.
echo Pruefe EXE-Dateien ...
echo.

set /a CHECKED=0
set /a FIXED=0
set /a DENIED=0

for /R "%ROOT%" %%F in (*.exe) do call :CHECK "%%~fF"

echo. 
echo Ende: %date% %time% >> "%LOG%"
echo Gepruefte Dateien: %CHECKED% >> "%LOG%"
echo Korrigierte Dateien: %FIXED% >> "%LOG%"
echo Wegen DENY-Eintrag ausgelassene Dateien: %DENIED% >> "%LOG%"

del "%TEMPACL%" >nul 2>&1

echo.
echo ============================================================
echo FERTIG
echo Geprueft: %CHECKED%
echo Korrigiert: %FIXED%
echo Wegen DENY-Eintrag ausgelassen: %DENIED%
echo.
echo Sicherung und Protokoll:
echo %BACKUP%
echo ============================================================
pause
exit /b 0

:CHECK
set /a CHECKED+=1

rem Nur ACEs der lokalen Gruppe "Benutzer" (SID S-1-5-32-545)
rem aus der ACL-Ausgabe herausfiltern.
icacls "%~1" 2>nul | findstr /i /c:"VORDEFINIERT\Benutzer" /c:"BUILTIN\Users" > "%TEMPACL%"

rem Gibt es fuer Benutzer einen DENY-Eintrag, nicht automatisch eingreifen.
findstr /i /c:"(DENY)" "%TEMPACL%" >nul
if not errorlevel 1 (
    set /a DENIED+=1
    echo UEBERSPRUNGEN - DENY: %~1
    echo UEBERSPRUNGEN - DENY: %~1 >> "%LOG%"
    exit /b
)

rem RX, Modify (M) oder Full Control (F) decken Lesen/Ausfuehren ab.
findstr /i /c:"(RX)" /c:"(M)" /c:"(F)" "%TEMPACL%" >nul
if not errorlevel 1 exit /b

echo KORREKTUR: %~1
echo KORREKTUR: %~1 >> "%LOG%"
icacls "%~1" /grant "*S-1-5-32-545:(RX)" >> "%LOG%" 2>&1
if errorlevel 1 (
    echo FEHLER bei: %~1
    echo FEHLER bei: %~1 >> "%LOG%"
) else (
    set /a FIXED+=1
)

exit /b
