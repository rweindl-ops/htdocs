
@echo off
setlocal DisableDelayedExpansion
title L04 - EXE-Reparatur 03

set "BASE=%~dp0"
set "BACKUP=%BASE%ACL_Sicherungen\ACL"

if not exist "%BACKUP%" md "%BACKUP%"

rem --------------------------------------------------
rem Zeitstempel fuer ACL-Sicherungen
rem --------------------------------------------------

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
if not defined STAMP set "STAMP=ohne_Zeitstempel"

rem --------------------------------------------------
rem Fortlaufende Protokollnummer suchen
rem --------------------------------------------------

set "NR=1"

:MAKELOG
if %NR% LSS 10 (
    set "NUM=0%NR%"
) else (
    set "NUM=%NR%"
)

if exist "%BASE%L04_EXE_Reparatur_003-%NUM%.txt" (
    set /a NR+=1
    goto MAKELOG
)

set "OUT=%BASE%L04_EXE_Reparatur_003-%NUM%.txt"

call :MAIN > "%OUT%" 2>&1

echo.
echo ==========================================
echo L04 EXE-Reparatur 03 beendet.
echo Protokoll: %OUT%
echo ==========================================
pause
exit /b


:MAIN
echo ==========================================
echo L04 - EXE-REPARATUR 03
echo Datum: %DATE% %TIME%
echo ==========================================
echo.
echo ZIEL: Ausschliesslich 20 EXE-Dateien
echo Keine Ordner und keine anderen Dateien
echo.

set "INDEX=0"
set "CHECKED=0"
set "FIXED=0"
set "ALREADY=0"
set "DENIED=0"
set "MISSING=0"
set "ERRORS=0"

rem --------------------------------------------------
rem SCHRITT 1: ACL-Sicherungen der EXE-Dateien
rem --------------------------------------------------

echo ==========================================
echo SCHRITT 1 - ACL-SICHERUNG
echo ==========================================

for %%P in (
"C:\Program Files\PSPad editor\PSPad.exe"
"C:\Corel\Draw70\programs\photopnt.exe"
"C:\Program Files\PDFCreator\PDFCreator.exe"
"C:\Program Files\Mozilla Firefox\firefox.exe"
"C:\Program Files\WinZip\WINZIP32.EXE"
"C:\Program Files\WinRAR\WinRAR.exe"
"C:\Program Files\Tools&More\Joe\Joe.exe"
"C:\Program Files\PDF24\pdf24-Editor.exe"
"C:\Program Files\Mixxx\mixxx.exe"
"C:\MAGIX\FSC_Media_Suite_2005\MediaSuite.exe"
"C:\Program Files\Windows Live\Photo Gallery\MovieMaker.exe"
"C:\Program Files\Vertexshare\Webp Converter\WebpConverter.exe"
"C:\Program Files\Microsoft Office\Office\MSACCESS.EXE"
"C:\Program Files\Microsoft Office\Office\WINWORD.EXE"
"C:\Program Files\Microsoft Office\Office\EXCEL.EXE"
"C:\Program Files\Microsoft Office\Office\WINPROJ.EXE"
"C:\Program Files\Microsoft Office\Office\OUTLOOK.EXE"
"C:\Program Files\Microsoft Office\Office14\MSACCESS.EXE"
"C:\Program Files\Microsoft Office\Office14\EXCEL.EXE"
"C:\Program Files\Microsoft Office\Office14\POWERPNT.EXE"
) do call :BACKUP "%%~P"

if not "%ERRORS%"=="0" goto BACKUPFEHLER

echo.
echo Alle vorhandenen EXE-Dateien wurden gesichert.
echo.

rem --------------------------------------------------
rem SCHRITT 2: Rechte pruefen und ggf. ergaenzen
rem --------------------------------------------------

echo ==========================================
echo SCHRITT 2 - RECHTEPRUEFUNG
echo ==========================================

for %%P in (
"C:\Program Files\PSPad editor\PSPad.exe"
"C:\Corel\Draw70\programs\photopnt.exe"
"C:\Program Files\PDFCreator\PDFCreator.exe"
"C:\Program Files\Mozilla Firefox\firefox.exe"
"C:\Program Files\WinZip\WINZIP32.EXE"
"C:\Program Files\WinRAR\WinRAR.exe"
"C:\Program Files\Tools&More\Joe\Joe.exe"
"C:\Program Files\PDF24\pdf24-Editor.exe"
"C:\Program Files\Mixxx\mixxx.exe"
"C:\MAGIX\FSC_Media_Suite_2005\MediaSuite.exe"
"C:\Program Files\Windows Live\Photo Gallery\MovieMaker.exe"
"C:\Program Files\Vertexshare\Webp Converter\WebpConverter.exe"
"C:\Program Files\Microsoft Office\Office\MSACCESS.EXE"
"C:\Program Files\Microsoft Office\Office\WINWORD.EXE"
"C:\Program Files\Microsoft Office\Office\EXCEL.EXE"
"C:\Program Files\Microsoft Office\Office\WINPROJ.EXE"
"C:\Program Files\Microsoft Office\Office\OUTLOOK.EXE"
"C:\Program Files\Microsoft Office\Office14\MSACCESS.EXE"
"C:\Program Files\Microsoft Office\Office14\EXCEL.EXE"
"C:\Program Files\Microsoft Office\Office14\POWERPNT.EXE"
) do call :CHECK "%%~P"

echo.
echo ==========================================
echo AUSWERTUNG
echo ==========================================
echo Vorgesehene EXE-Dateien: 20
echo Gepruefte Dateien:       %CHECKED%
echo Rechte ergaenzt:         %FIXED%
echo Bereits ausreichend:     %ALREADY%
echo DENY - uebersprungen:    %DENIED%
echo Nicht vorhanden:         %MISSING%
echo Fehler:                  %ERRORS%
echo ==========================================
echo.

exit /b


rem --------------------------------------------------
rem ACL-SICHERUNG EINER EINZELNEN EXE
rem --------------------------------------------------

:BACKUP
set /a INDEX+=1

if not exist "%~1" (
    echo NICHT VORHANDEN: "%~1"
    exit /b
)

if %INDEX% LSS 10 (
    set "NUM=0%INDEX%"
) else (
    set "NUM=%INDEX%"
)

rem Programmname aus dem Dateinamen ableiten

for %%Z in ("%~1") do set "PROG=%%~nZ"

set "ACLFILE=%BACKUP%\L04_EXE_03_%NUM%_%PROG%_%STAMP%.acl"

echo Sicherung: "%~1"
echo Zieldatei: "%ACLFILE%"

icacls "%~1" /save "%ACLFILE%"

if errorlevel 1 (
    echo FEHLER bei ACL-Sicherung: "%~1"
    set /a ERRORS+=1
    exit /b
)

if not exist "%ACLFILE%" (
    echo FEHLER: Sicherungsdatei fehlt!
    set /a ERRORS+=1
    exit /b
)

for %%Z in ("%ACLFILE%") do if %%~zZ LEQ 0 (
    echo FEHLER: Sicherungsdatei ist leer!
    set /a ERRORS+=1
)

exit /b


rem --------------------------------------------------
rem RECHTEPRUEFUNG EINER EINZELNEN EXE
rem --------------------------------------------------

:CHECK
set /a CHECKED+=1

echo.
echo ------------------------------------------
echo Pruefe: "%~1"

if not exist "%~1" (
    echo NICHT GEFUNDEN
    set /a MISSING+=1
    exit /b
)

set "TMP=%TEMP%\L04_EXE_ACL_%RANDOM%.txt"
set "ACE=%TEMP%\L04_EXE_ACE_%RANDOM%.txt"

icacls "%~1" > "%TMP%" 2>&1

if errorlevel 1 (
    echo FEHLER beim Lesen der Rechte
    set /a ERRORS+=1
    del "%TMP%" "%ACE%" >nul 2>&1
    exit /b
)

rem Nur den Eintrag der lokalen Benutzergruppe

findstr /I /C:"S-1-5-32-545" /C:"BUILTIN\Users" /C:"VORDEFINIERT\Benutzer" "%TMP%" > "%ACE%"

rem Explizites DENY nicht ueberschreiben

findstr /I /C:"(DENY)" "%ACE%" >nul

if not errorlevel 1 (
    echo DENY vorhanden - keine Aenderung
    set /a DENIED+=1
    del "%TMP%" "%ACE%" >nul 2>&1
    exit /b
)

rem RX, M oder F bereits vorhanden?

findstr /I /C:"(RX)" /C:"(M)" /C:"(F)" "%ACE%" >nul

if not errorlevel 1 (
    echo Leserecht bereits vorhanden
    set /a ALREADY+=1
    del "%TMP%" "%ACE%" >nul 2>&1
    exit /b
)

rem Fehlendes Leserecht ergaenzen

echo Ergaenze Leserecht RX

icacls "%~1" /grant "*S-1-5-32-545:(RX)"

if errorlevel 1 (
    echo FEHLER beim Setzen der Rechte
    set /a ERRORS+=1
) else (
    echo RECHT ERGAENZT
    set /a FIXED+=1
)

del "%TMP%" "%ACE%" >nul 2>&1
exit /b


:BACKUPFEHLER
echo.
echo ==========================================
echo ABBRUCH!
echo Mindestens eine ACL-Sicherung ist fehlgeschlagen.
echo Es wurden KEINE Rechte veraendert.
echo ==========================================
exit /b
