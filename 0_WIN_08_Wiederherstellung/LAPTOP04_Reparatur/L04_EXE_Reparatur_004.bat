                               
@echo off
setlocal EnableExtensions DisableDelayedExpansion
title L04 - EXE-Berechtigungsreparatur und Symbolaktualisierung

REM ==================================================
REM EINSTELLUNGEN
REM ==================================================

set "ROOT1=C:\Program Files"
set "ROOT2=C:\Program Files (x86)"

set "BASE=D:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP04_Reparatur"
set "BACKUP=%BASE%\ACL_Sicherungen"

set "ACL_DIR=%BACKUP%\ACL"
set "TXT_DIR=%BACKUP%\TXT"
set "LOG_DIR=%BACKUP%\LOG"

set "REPORT=%BASE%\L04_EXE_Reparatur_004-01.txt"

REM ==================================================
REM VORAUSSETZUNGEN PRUEFEN
REM ==================================================

if not exist "%BASE%\." (
    echo FEHLER: Hauptverzeichnis nicht gefunden.
    pause
    exit /b 1
)

if not exist "%ROOT1%\." (
    echo FEHLER: C:\Program Files nicht gefunden.
    pause
    exit /b 1
)

if not exist "%ACL_DIR%\." (
    echo FEHLER: ACL-Verzeichnis fehlt.
    pause
    exit /b 1
)

if not exist "%TXT_DIR%\." (
    echo FEHLER: TXT-Verzeichnis fehlt.
    pause
    exit /b 1
)

if not exist "%LOG_DIR%\." (
    echo FEHLER: LOG-Verzeichnis fehlt.
    pause
    exit /b 1
)

if exist "%REPORT%" (
    echo FEHLER: Der Bericht existiert bereits:
    echo %REPORT%
    echo Es wird nichts ueberschrieben.
    pause
    exit /b 1
)

REM ==================================================
REM ZEITSTEMPEL UND DATEINAMEN
REM ==================================================

for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"

if not defined STAMP (
    echo FEHLER: Zeitstempel konnte nicht erstellt werden.
    pause
    exit /b 1
)

set "ACLFILE1=%ACL_DIR%\ProgramFiles_%STAMP%.acl"
set "ACLFILE2=%ACL_DIR%\ProgramFiles_x86_%STAMP%.acl"

set "STATUS1=%TXT_DIR%\Backup_Status_ProgramFiles_%STAMP%.txt"
set "STATUS2=%TXT_DIR%\Backup_Status_ProgramFiles_x86_%STAMP%.txt"

set "LOG=%LOG_DIR%\Reparatur_%STAMP%.log"

if exist "%ACLFILE1%" goto COLLISION
if exist "%ACLFILE2%" goto COLLISION
if exist "%STATUS1%" goto COLLISION
if exist "%STATUS2%" goto COLLISION
if exist "%LOG%" goto COLLISION

REM ==================================================
REM STARTPROTOKOLL
REM ==================================================

echo L04 EXE-Berechtigungsreparatur > "%LOG%"
echo Start: %DATE% %TIME% >> "%LOG%"
echo. >> "%LOG%"
echo Programmverzeichnisse: >> "%LOG%"
echo %ROOT1% >> "%LOG%"
if exist "%ROOT2%\." echo %ROOT2% >> "%LOG%"

REM ==================================================
REM ACL-SICHERUNG PROGRAM FILES
REM ==================================================

echo.
echo Sichere ACLs von Program Files ...

icacls "%ROOT1%" /save "%ACLFILE1%" /T /C > "%STATUS1%" 2>&1

if errorlevel 1 goto BACKUP_ERROR

echo Sicherung Program Files erfolgreich. >> "%LOG%"

REM ==================================================
REM ACL-SICHERUNG PROGRAM FILES X86
REM ==================================================

if not exist "%ROOT2%\." goto NO_X86

echo.
echo Sichere ACLs von Program Files (x86) ...

icacls "%ROOT2%" /save "%ACLFILE2%" /T /C > "%STATUS2%" 2>&1

if errorlevel 1 goto BACKUP_ERROR

echo Sicherung Program Files x86 erfolgreich. >> "%LOG%"
goto BACKUP_DONE

:NO_X86
echo Program Files x86 nicht vorhanden. >> "%LOG%"
echo Program Files x86 nicht vorhanden. > "%STATUS2%"

:BACKUP_DONE

REM ==================================================
REM BERECHTIGUNGEN REPARIEREN
REM ==================================================

echo.
echo EXE-Dateien werden untersucht und repariert ...
echo Dies kann einige Zeit dauern.

set "CHECK_SID=S-1-5-32-545"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $sid=New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545'); $rx=[int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute; $report=$env:REPORT; $log=$env:LOG; Set-Content -LiteralPath $report -Value 'L04 - EXE-Berechtigungsreparatur'; Add-Content -LiteralPath $report -Value ('Start: '+(Get-Date)); Add-Content -LiteralPath $report -Value 'Ziel: Users - Lesen und Ausfuehren (RX)'; Add-Content -LiteralPath $report -Value ' '; $total=0; $ok=0; $err=0; $roots=@($env:ROOT1); if(Test-Path -LiteralPath $env:ROOT2){$roots+= $env:ROOT2}; foreach($root in $roots){if($root -eq $env:ROOT1){$status=$env:STATUS1}else{$status=$env:STATUS2}; Add-Content -LiteralPath $report -Value ('VERZEICHNIS: '+$root); $files=Get-ChildItem -LiteralPath $root -Filter '*.exe' -Recurse -File -ErrorAction SilentlyContinue; foreach($f in $files){$total++; try{$acl=Get-Acl -LiteralPath $f.FullName; $acl.SetAccessRuleProtection($true,$true); $acl.PurgeAccessRules($sid); $rule=New-Object System.Security.AccessControl.FileSystemAccessRule($sid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,[System.Security.AccessControl.AccessControlType]::Allow); $acl.AddAccessRule($rule); Set-Acl -LiteralPath $f.FullName -AclObject $acl; $verify=Get-Acl -LiteralPath $f.FullName; $allow=$false; $deny=$false; foreach($a in $verify.Access){$as=$a.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value; if($as -eq $sid.Value){if($a.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny){$deny=$true}; if($a.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and (([int]$a.FileSystemRights -band $rx) -eq $rx)){$allow=$true}}}; if(!$allow -or $deny){throw 'RX-Pruefung nach Reparatur fehlgeschlagen'}; $line='OK - '+$f.FullName; $ok++}catch{$line='FEHLER - '+$f.FullName+' - '+$_.Exception.Message; $err++}; Add-Content -LiteralPath $report -Value $line; Add-Content -LiteralPath $log -Value $line; Add-Content -LiteralPath $status -Value $line}}; Add-Content -LiteralPath $report -Value ' '; Add-Content -LiteralPath $report -Value ('Gefundene EXE-Dateien: '+$total); Add-Content -LiteralPath $report -Value ('Erfolgreich repariert/geprueft: '+$ok); Add-Content -LiteralPath $report -Value ('Fehler: '+$err); Add-Content -LiteralPath $log -Value ('Gesamt: '+$total+' | OK: '+$ok+' | Fehler: '+$err); if($err -gt 0){exit 2}else{exit 0}"

set "PSRC=%ERRORLEVEL%"

if not exist "%REPORT%" (
    echo FEHLER: Reparaturbericht wurde nicht erstellt.
    echo PowerShell-Rueckgabecode: %PSRC% >> "%LOG%"
    pause
    exit /b 1
)

REM ==================================================
REM SYMBOLCACHE AKTUALISIEREN
REM ==================================================

echo.
echo Aktualisiere Symbolcache ...

taskkill /f /im explorer.exe >nul 2>&1

if exist "%LOCALAPPDATA%\IconCache.db" (
    del /f /q "%LOCALAPPDATA%\IconCache.db" >> "%LOG%" 2>&1
)

start explorer.exe

echo Symbolcache-Aktualisierung ausgefuehrt. >> "%LOG%"

REM ==================================================
REM ABSCHLUSS
REM ==================================================

echo. >> "%REPORT%"
echo Ende: %DATE% %TIME% >> "%REPORT%"
echo Ende: %DATE% %TIME% >> "%LOG%"

if "%PSRC%"=="0" (
    echo.
    echo REPARATUR ABGESCHLOSSEN.
    echo Alle gefundenen EXE-Dateien wurden erfolgreich bearbeitet.
    echo.
    echo Bericht:
    echo %REPORT%
    echo.
    echo Protokoll:
    echo %LOG%
    pause
    exit /b 0
)

echo.
echo REPARATUR MIT FEHLERN BEENDET.
echo Bitte Bericht und Protokoll beachten.
echo.
echo Bericht:
echo %REPORT%
echo.
echo Protokoll:
echo %LOG%
pause
exit /b 2

REM ==================================================
REM FEHLERBEHANDLUNG
REM ==================================================

:BACKUP_ERROR
echo.
echo FEHLER BEI DER ACL-SICHERUNG.
echo Reparatur wird nicht gestartet.
echo Siehe Sicherungsdateien und Statusprotokolle.
echo Fehler bei ACL-Sicherung: %DATE% %TIME% >> "%LOG%"
pause
exit /b 1

:COLLISION
echo.
echo FEHLER: Eine Ausgabedatei mit diesem Namen existiert bereits.
echo Es wird nichts ueberschrieben.
pause
exit /b 1
