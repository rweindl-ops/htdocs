@echo off
setlocal EnableExtensions
title L04 - Edge-Dienste und Aufgaben Diagnose

rem Fester Diagnoseordner auf L04
set "OUT=D:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP04_Reparatur\L04_Edge_Dienste_Aufgaben.txt"
set "EDGE=C:\Program Files\Microsoft\Edge\Application\msedge.exe"

(
echo ============================================================
echo L04 - EDGE-DIENSTE / GEPLANTE AUFGABEN / REGISTRY-DIAGNOSE
echo Datum: %DATE%   Uhrzeit: %TIME%
echo Rechner: %COMPUTERNAME%
echo ============================================================
echo.
echo HINWEIS: Diese BAT liest nur Informationen aus.
echo Es werden KEINE Einstellungen oder Dateien geaendert.
echo.

echo ------------------------------------------------------------
echo 1. EDGE-PROGRAMMPFAD
echo ------------------------------------------------------------
echo.
echo Erwarteter Edge-Pfad:
echo "%EDGE%"
if exist "%EDGE%" (
  echo STATUS: Edge-Datei wurde gefunden.
) else (
  echo STATUS: Edge-Datei wurde an diesem Pfad NICHT gefunden.
)
echo.

echo ------------------------------------------------------------
echo 2. EDGE-BEZOGENE DIENSTE
echo ------------------------------------------------------------
echo.
echo [Dienst: edgeupdate]
sc query edgeupdate
echo.
echo [Dienst: edgeupdatem]
sc query edgeupdatem
echo.
echo [Dienst: MicrosoftEdgeElevationService]
sc query MicrosoftEdgeElevationService
echo.
echo [Alle Dienste mit Edge im Namen]
sc query state= all | findstr /i "SERVICE_NAME DISPLAY_NAME edge"
echo.

echo ------------------------------------------------------------
echo 3. GEPLANTE AUFGABEN MIT EDGE-BEZUG
echo ------------------------------------------------------------
echo.
schtasks /query /fo LIST /v | findstr /i /c:"TaskName:" /c:"Task To Run:" /c:"Edge" /c:"MicrosoftEdge"
echo.

echo ------------------------------------------------------------
echo 4. REGISTRY - EDGE UPDATE UND EDGE
echo ------------------------------------------------------------
echo.
echo [HKLM - EdgeUpdate]
reg query "HKLM\SOFTWARE\Microsoft\EdgeUpdate" /s
echo.
echo [HKLM - WOW6432Node - EdgeUpdate]
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate" /s
echo.
echo [HKLM - Microsoft Edge Uninstall]
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /s
echo.
echo [HKLM - WOW6432Node - Microsoft Edge Uninstall]
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /s
echo.
echo [HKCU - EdgeUpdate]
reg query "HKCU\SOFTWARE\Microsoft\EdgeUpdate" /s
echo.

echo ------------------------------------------------------------
echo 5. EDGE-UPDATE-DATEIEN / PROGRAMMPFADE
echo ------------------------------------------------------------
echo.
if exist "%ProgramFiles%\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" (
  echo EdgeUpdate-Datei gefunden unter:
  echo "%ProgramFiles%\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
) else (
  echo Keine EdgeUpdate-Datei unter ProgramFiles gefunden.
)
echo.
echo ============================================================
echo ENDE DER DIAGNOSE
echo ============================================================
) > "%OUT%" 2>&1

echo.
echo Diagnose abgeschlossen.
echo Die Datei wurde gespeichert unter:
echo "%OUT%"
echo.
pause
endlocal
