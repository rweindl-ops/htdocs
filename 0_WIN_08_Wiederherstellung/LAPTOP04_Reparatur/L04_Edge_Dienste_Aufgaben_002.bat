@echo off
setlocal EnableExtensions

rem ============================================================
rem L04 - EDGE DIENSTE UND AUFGABEN
rem BAT-Version: 02
rem Ausgabe: L04_Edge_Dienste_Aufgaben_02-01.txt usw.
rem ============================================================

set "BASE=%~dp0"
set "PREFIX=L04_Edge_Dienste_Aufgaben_02-"
set /a NR=1

:FINDE_DATEI
if exist "%BASE%%PREFIX%%NR%.txt" (
    set /a NR+=1
    goto FINDE_DATEI
)

if %NR% LSS 10 (
    set "NR=0%NR%"
)
set "OUT=%BASE%%PREFIX%%NR%.txt"

(
    echo ============================================================
    echo L04 - EDGE DIENSTE UND AUFGABEN - DIAGNOSE 02
    echo Datum: %DATE% %TIME%
    echo Rechner: %COMPUTERNAME%
    echo Ausgabedatei: %OUT%
    echo ============================================================
    echo.

    echo ------------------------------------------------------------
    echo 1. EDGE-DIENSTE
    echo ------------------------------------------------------------
    echo.
    echo [edgeupdate]
    sc query edgeupdate
    echo.
    echo [edgeupdatem]
    sc query edgeupdatem
    echo.
    echo [MicrosoftEdgeElevationService]
    sc query MicrosoftEdgeElevationService
    echo.

    echo ------------------------------------------------------------
    echo 2. EDGE-UPDATE-AUFGABE: MACHINE CORE
    echo ------------------------------------------------------------
    schtasks /query /tn "\Microsoft\EdgeUpdate\MicrosoftEdgeUpdateTaskMachineCore{0D1D302E-A50F-40F0-90AB-7F35A78205A7}" /fo LIST /v
    echo.

    echo ------------------------------------------------------------
    echo 3. EDGE-UPDATE-AUFGABE: MACHINE UA
    echo ------------------------------------------------------------
    schtasks /query /tn "\Microsoft\EdgeUpdate\MicrosoftEdgeUpdateTaskMachineUA{93905322-6AFD-4771-B10C-10B41C925090}" /fo LIST /v
    echo.

    echo ------------------------------------------------------------
    echo 4. ZUSAETZLICHE SUCHE NACH EDGE-UPDATE-AUFGABEN
    echo ------------------------------------------------------------
    schtasks /query /fo LIST /v | findstr /i /c:"MicrosoftEdgeUpdateTaskMachine" /c:"EdgeUpdate"
    echo.

    echo ============================================================
    echo ENDE DER DIAGNOSE
    echo ============================================================
) > "%OUT%" 2>&1

echo.
echo Diagnose abgeschlossen.
echo Die Ausgabedatei lautet:
echo "%OUT%"
echo.
pause
endlocal
