@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur und Symbolaktualisierung

REM ==================================================
REM EINSTELLUNGEN
REM ==================================================

set "ROOT=C:\Program Files"
set "BASE=D:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP04_Reparatur"
set "BACKUP=%BASE%\ACL_Sicherungen"
set "TEMPACL=%TEMP%\L04_EXE_ACL_TEMP.txt"

REM ==================================================
REM VORBEREITUNG
REM ==================================================

if not exist "%ROOT%\" (
    echo FEHLER: Suchpfad nicht gefunden: %ROOT%
    pause
    exit /b 1
)

if not exist "%BACKUP%\" md "%BACKUP%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
if not defined STAMP set "STAMP=ohne_Zeitstempel"

set "ACLFILE=%BACKUP%\ACL_vorher_%STAMP%.txt"
set "LOG=%BACKUP%\Reparatur_%STAMP%.log"

set /a CHECKED=0
set /a FIXED=0
set /a DENIED=0
set /a ERRORS=0

echo Start: %date% %time% > "%LOG%"
echo Suchpfad: %ROOT% >> "%LOG%"
echo ACL-Sicherung: %ACLFILE% >> "%LOG%"

echo.
echo ==========================================
echo L04 - EXE-BERECHTIGUNGSPRUEFUNG
echo ==========================================
echo Suchpfad: %ROOT%
echo Protokoll: %LOG%
echo.
echo Sichere zuerst die bisherigen ACLs ...

icacls "%ROOT%" /save "%ACLFILE%" /T /C > "%BACKUP%\Backup_Status_%STAMP%.txt" 2>&1

if not exist "%ACLFILE%" (
    echo FEHLER: ACL-Sicherung wurde nicht erstellt!
    echo Abbruch ohne Berechtigungsänderungen.
    pause
    exit /b 1
)

echo ACL-Sicherung erstellt.
echo.
echo Pruefe EXE-Dateien ...
echo.

for /R "%ROOT%" %%F in (*.exe) do call :CHECK "%%~fF"

goto SUMMARY

:CHECK
set /a CHECKED+=1

icacls "%~1" 2>nul | findstr /i /c:"VORDEFINIERT\Benutzer" /c:"BUILTIN\Users" > "%TEMPACL%"

findstr /i /c:"(DENY)" "%TEMPACL%" >nul
if not errorlevel 1 (
    set /a DENIED+=1
    echo DENY - ausgelassen: %~1 >> "%LOG%"
    exit /b
)

findstr /i /c:"(RX)" /c:"(M)" /c:"(F)" "%TEMPACL%" >nul
if not errorlevel 1 exit /b

echo KORREKTUR: %~1 >> "%LOG%"
echo KORREKTUR: %~1

icacls "%~1" /grant "*S-1-5-32-545:(RX)" >> "%LOG%" 2>&1

if errorlevel 1 (
    set /a ERRORS+=1
    echo FEHLER bei: %~1 >> "%LOG%"
) else (
    set /a FIXED+=1
)
exit /b

:SUMMARY
del "%TEMPACL%" >nul 2>&1

echo.
echo ==========================================
echo ERGEBNIS DER BERECHTIGUNGSPRUEFUNG
echo ==========================================
echo Geprueft: %CHECKED%
echo Korrigiert: %FIXED%
echo Wegen DENY ausgelassen: %DENIED%
echo Fehler: %ERRORS%

echo. >> "%LOG%"
echo ===== GESAMTERGEBNIS ===== >> "%LOG%"
echo Geprueft: %CHECKED% >> "%LOG%"
echo Korrigiert: %FIXED% >> "%LOG%"
echo Wegen DENY ausgelassen: %DENIED% >> "%LOG%"
echo Fehler: %ERRORS%

REM ==================================================
REM WINDOWS-SYMBOLCACHE AKTUALISIEREN
REM ==================================================

echo.
echo ==========================================
echo WINDOWS-SYMBOLCACHE AKTUALISIEREN
echo ==========================================

echo Symbolcache-Aktualisierung gestartet: %date% %time% >> "%LOG%"

taskkill /f /im explorer.exe >> "%LOG%" 2>&1
timeout /t 2 /nobreak >nul

if exist "%LOCALAPPDATA%\IconCache.db" (
    del /a /f /q "%LOCALAPPDATA%\IconCache.db" >> "%LOG%" 2>&1
)

if exist "%LOCALAPPDATA%\Microsoft\Windows\Explorer" (
    del /a /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" >> "%LOG%" 2>&1
)

start explorer.exe
timeout /t 3 /nobreak >nul

echo Explorer neu gestartet. >> "%LOG%"
echo Symbolcache-Aktualisierung beendet: %date% %time% >> "%LOG%"

echo.
echo ==========================================
echo FERTIG
echo ==========================================
echo.
echo Geprueft: %CHECKED%
echo Korrigiert: %FIXED%
echo DENY-Ausnahmen: %DENIED%
echo Fehler: %ERRORS%
echo.
echo Protokoll:
echo %LOG%
echo.
echo Desktop- und Schnellstartverknuepfungen
echo wurden nicht veraendert.
echo.
pause

endlocal
