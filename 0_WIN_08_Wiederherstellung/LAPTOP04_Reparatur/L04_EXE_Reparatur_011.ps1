#requires -Version 3.0
param([switch]$EnableRepair)
# L04 - EXE-Berechtigungsreparatur 011 (CSV-gesteuerte Rechnerkonfiguration)
# EXE-DACL-Sicherung aus der Inventur. Keine Rechteaenderung vor vollstaendiger Sicherung.

$ErrorActionPreference='Stop'
$ScriptDir=$PSScriptRoot
$StammCsv=Join-Path (Split-Path -Parent $ScriptDir) 'WARS_Stamm.csv'
$Root1='C:\Program Files'
$Root2='C:\Program Files (x86)'
$UsersSid=New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')
$Rx=[int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute
$script:RegistryReadErrors=0
$script:InventorySearchErrors=0

function Write-RunLine([string]$Line) {
 Add-Content -LiteralPath $script:ReportPath -Value $Line -Encoding UTF8
 Add-Content -LiteralPath $script:LogPath -Value $Line -Encoding UTF8
}
function Stop-WithMessage([string]$Message) {
 Write-Host $Message -ForegroundColor Red
 if ($script:LogPath -and (Test-Path -LiteralPath $script:LogPath)) { Add-Content -LiteralPath $script:LogPath -Value $Message -Encoding UTF8 }
 exit 1
}
# Rechnerkonfiguration aus der zentralen Stamm-CSV einlesen
if (-not (Test-Path -LiteralPath $StammCsv -PathType Leaf)) {
 Stop-WithMessage ('Zentrale Stammdatei nicht gefunden: '+$StammCsv)
}
try {
 $allConfig=@(Import-Csv -LiteralPath $StammCsv -Delimiter ';' -ErrorAction Stop)
} catch {
 Stop-WithMessage ('Stammdatei konnte nicht gelesen werden: '+$_.Exception.Message)
}
$computerName=[string]$env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($computerName)) {
 Stop-WithMessage 'Windows-Rechnername konnte nicht ermittelt werden.'
}
$matches=@($allConfig | Where-Object {([string]$_.wars_rechner).Trim() -ieq $computerName})
if ($matches.Count -ne 1) {
 Stop-WithMessage ('Fuer Rechner '+$computerName+' wurde in WARS_Stamm.csv kein eindeutiger Datensatz gefunden. Treffer: '+$matches.Count)
}
$config=$matches[0]
$backupDrive=([string]$config.wars_backup_LW).Trim()
$backupPath=([string]$config.wars_backup_PFAD).Trim()
if ($backupDrive -notmatch '^[A-Za-z]:$') {
 Stop-WithMessage ('Ungueltiges oder fehlendes Backup-Laufwerk in WARS_Stamm.csv: '+$backupDrive)
}
if ([string]::IsNullOrWhiteSpace($backupPath)) {
 Stop-WithMessage 'Backup-Pfad fehlt in WARS_Stamm.csv.'
}
$relativeBackupPath=$backupPath.TrimStart([char[]]@('\','/'))
if ([string]::IsNullOrWhiteSpace($relativeBackupPath)) {
 Stop-WithMessage 'Backup-Pfad in WARS_Stamm.csv ist ungueltig.'
}
$Base=[System.IO.Path]::Combine(($backupDrive+'\'),$relativeBackupPath)
$computerBez=([string]$config.wars_rechner_BEZ).Trim()
if ([string]::IsNullOrWhiteSpace($computerBez)) { $computerBez=$computerName }
$AclDir=Join-Path $Base 'ACL_Sicherungen\ACL'
$TxtDir=Join-Path $Base 'ACL_Sicherungen\TXT'
$CsvDir=Join-Path $Base 'ACL_Sicherungen\CSV'
$LogDir=Join-Path $Base 'ACL_Sicherungen\LOG'
Write-Host ('Rechner: '+$computerName+' ('+$computerBez+')')
Write-Host ('Backup-Ziel: '+$Base)

function Get-UniqueReportPath {
 $i=1
 do { $p=Join-Path $Base ('L04_EXE_Reparatur_011-{0:D2}.txt' -f $i); $i++ } while (Test-Path -LiteralPath $p)
 return $p
}
function Get-UsersAclState([System.Security.AccessControl.FileSystemSecurity]$Acl) {
 $allow=$false; $deny=$false; $unknown=0
 foreach ($ace in $Acl.Access) {
  try {
   if ($ace.IdentityReference -is [System.Security.Principal.SecurityIdentifier]) { $sid=$ace.IdentityReference.Value }
   else { $sid=$ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value }
  } catch { $unknown++; continue }
  if ($sid -eq $script:UsersSid.Value) {
   if ($ace.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) { $deny=$true }
   if ($ace.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and (([int]$ace.FileSystemRights -band $script:Rx) -eq $script:Rx)) { $allow=$true }
  }
 }
 return [pscustomobject]@{Allow=$allow;Deny=$deny;Unresolved=$unknown}
}

function Get-RegistryProgramRows {
 $rows=New-Object System.Collections.ArrayList
 $keys=@(
  @{Root='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall';Hive='HKLM';View='64/Native'},
  @{Root='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';Hive='HKLM';View='32'},
  @{Root='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall';Hive='HKCU';View='Current'}
 )
 foreach($k in $keys) {
  if(Test-Path -LiteralPath $k.Root) {
   foreach($sub in @(Get-ChildItem -LiteralPath $k.Root -ErrorAction SilentlyContinue)) {
    try { $p=Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction Stop; if($p.DisplayName -or $p.InstallLocation -or $p.DisplayIcon) {
     $null=$rows.Add([pscustomobject]@{RecordType='RegistryApp';Path='';DisplayName=[string]$p.DisplayName;InstallLocation=[string]$p.InstallLocation;DisplayIcon=[string]$p.DisplayIcon;RegistryHive=$k.Hive;RegistryView=$k.View;RegistryKey=$sub.PSChildName})
    }} catch { $script:RegistryReadErrors++; Write-RunLine ('REGISTRY_LESEN_FEHLER - '+$sub.Name+' - '+$_.Exception.Message) }
   }
  }
 }
 return @($rows)
}

# Voraussetzungen
# Im reinen Inventurmodus werden nur TXT- und LOG-Ausgabeordner benoetigt.
# Der ACL-Ordner ist ausschliesslich fuer den ausdruecklich aktivierten Reparaturpfad erforderlich.
$requiredDirs=if($EnableRepair){@($AclDir,$TxtDir,$CsvDir,$LogDir)}else{@($TxtDir,$CsvDir,$LogDir)}
foreach ($d in $requiredDirs) { if (-not (Test-Path -LiteralPath $d -PathType Container)) { Stop-WithMessage ('Ausgabeverzeichnis fehlt: '+$d) } }
$admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Stop-WithMessage 'Bitte die BAT-Datei als Administrator starten.' }
if (-not (Test-Path -LiteralPath $Root1 -PathType Container)) { Stop-WithMessage 'C:\Program Files wurde nicht gefunden.' }

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportPath=Get-UniqueReportPath
$LogPath=Join-Path $LogDir ('Reparatur_'+$stamp+'.log')
$ExeAclBackup=Join-Path $AclDir ('EXE_ACL_Backup_'+$stamp+'.csv')
$ExeAclStatus=Join-Path $TxtDir ('EXE_ACL_Backup_Status_'+$stamp+'.txt')
$checkPaths=@($LogPath)
if($EnableRepair){$checkPaths+=@($ExeAclBackup,$ExeAclStatus)}
foreach ($p in $checkPaths) { if (Test-Path -LiteralPath $p) { Stop-WithMessage ('Ausgabedatei existiert bereits; nichts ueberschrieben: '+$p) } }
$createPaths=@($ReportPath,$LogPath)
if($EnableRepair){$createPaths+=@($ExeAclStatus)}
New-Item -ItemType File -Path $createPaths -ErrorAction Stop | Out-Null
$header=@('L04 - EXE-Berechtigungsreparatur 011',('Start: '+(Get-Date)),'Zielgruppe: BUILTIN\Users (S-1-5-32-545)','Zielrecht: Lesen und Ausfuehren (RX)','Nur fehlendes RX ergaenzen; vorhandene ACEs und Vererbung erhalten.','ACL-Sicherung muss vor jeder Rechteaenderung erfolgreich sein.','')
foreach ($l in $header) { Add-Content -LiteralPath $ReportPath -Value $l -Encoding UTF8; Add-Content -LiteralPath $LogPath -Value $l -Encoding UTF8 }

# Die Sicherung betrifft nur die EXE-Dateien, deren Berechtigungen spaeter
# geprueft oder geaendert werden. Jeder einzelne DACL-Eintrag muss lesbar sein.
function Invoke-ExeAclBackup {
 param([string]$InventoryCsv,[string]$BackupFile,[string]$StatusFile)
 $exeRows=@(Import-Csv -LiteralPath $InventoryCsv | Where-Object {$_.RecordType -eq 'ExeFile'})
 $backupRows=New-Object System.Collections.ArrayList
 $errors=0
 Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value @(
  ('Start: '+(Get-Date)),
  'Sicherungsumfang: ausschliesslich die in der EXE-Inventur aufgefuehrten EXE-Dateien.',
  ('Inventur-EXE-Anzahl: '+$exeRows.Count),
  'Gesichert wird jeweils die DACL (Access Control List) der einzelnen EXE-Datei.'
 )
 foreach($entry in $exeRows) {
  $path=[string]$entry.Path
  try {
   $acl=Get-Acl -LiteralPath $path -ErrorAction Stop
   $sddl=$acl.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Access)
   if([string]::IsNullOrEmpty($sddl)) { throw 'DACL-SDDL ist leer.' }
   $null=$backupRows.Add([pscustomobject]@{Path=$path;DaclSddl=$sddl})
  } catch {
   $errors++
   Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value ('FEHLER: '+$path+' - '+$_.Exception.Message)
  }
 }
 if($errors -gt 0 -or $backupRows.Count -ne $exeRows.Count) {
  Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value @(
   ('Ergebnis: FEHLER'),
   ('Erfolgreich gesichert: '+$backupRows.Count),
   ('Fehler: '+$errors),
   'Keine Rechte werden geaendert.'
  )
  Write-RunLine ('FEHLER: EXE-ACL-Sicherung nicht vollstaendig. Gesichert='+$backupRows.Count+'; Inventur='+$exeRows.Count+'; Fehler='+$errors)
  return $false
 }
 $backupRows | Export-Csv -LiteralPath $BackupFile -NoTypeInformation -Encoding UTF8
 $verify=@(Import-Csv -LiteralPath $BackupFile)
 if($verify.Count -ne $exeRows.Count -or @($verify | Where-Object {[string]::IsNullOrEmpty($_.DaclSddl)}).Count -gt 0) {
  Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value 'Ergebnis: FEHLER - Dateipruefung fehlgeschlagen. Keine Rechte werden geaendert.' 
  Write-RunLine 'FEHLER: EXE-ACL-Sicherung nach dem Schreiben nicht bestaetigt.'
  return $false
 }
 Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value @(
  ('Ende: '+(Get-Date)),
  ('Ergebnis: ERFOLGREICH'),
  ('Gesicherte EXE-DACLs: '+$verify.Count),
  ('Dateigroesse: '+(Get-Item -LiteralPath $BackupFile).Length+' Bytes')
 )
 Write-RunLine ('EXE-ACL-Sicherung erfolgreich: '+$verify.Count+' DACLs; Datei='+$BackupFile)
 return $true
}

# PHASE 0: lesende EXE- und Registry-Inventur vor der ACL-Sicherung
$InventoryPath=Join-Path $CsvDir ('EXE_Inventur_'+$stamp+'.csv')
if(Test-Path -LiteralPath $InventoryPath){Stop-WithMessage ('Inventurdatei existiert bereits: '+$InventoryPath)}
$inventoryRows=New-Object System.Collections.ArrayList
$regRows=@(Get-RegistryProgramRows)
foreach($row in $regRows){$null=$inventoryRows.Add($row)}
foreach($scanRoot in @($Root1,$Root2)){
 if(Test-Path -LiteralPath $scanRoot -PathType Container){
  $scanErrors=@()
  $exeFiles=@(Get-ChildItem -LiteralPath $scanRoot -Filter '*.exe' -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable scanErrors)
  foreach($e in $exeFiles){$null=$inventoryRows.Add([pscustomobject]@{RecordType='ExeFile';Path=$e.FullName;DisplayName='';InstallLocation='';DisplayIcon='';RegistryHive='';RegistryView='';RegistryKey=''})}
  foreach($err in $scanErrors){$script:InventorySearchErrors++;Write-RunLine ('INVENTUR_SUCHFEHLER - '+$err.Exception.Message)}
  if($scanErrors.Count -gt 0){Write-RunLine ('INVENTUR_SUCHFEHLER_ANZAHL '+$scanRoot+': '+$scanErrors.Count)}
 }
}
$inventoryRows | Export-Csv -LiteralPath $InventoryPath -NoTypeInformation -Encoding UTF8
$exeCount=@($inventoryRows | Where-Object {$_.RecordType -eq 'ExeFile'}).Count
Write-RunLine ('EXE_INVENTUR: '+$exeCount+' EXE-Dateien; CSV='+$InventoryPath)
Write-RunLine ('REGISTRY_INVENTUR: '+$regRows.Count+' Eintraege aus HKLM 64/32 und HKCU')
Write-RunLine ('REGISTRY_LESFEHLER: '+$script:RegistryReadErrors)
Write-RunLine ('INVENTUR_SUCHFEHLER: '+$script:InventorySearchErrors)
Write-Host ('Inventur abgeschlossen: '+$exeCount+' EXE-Dateien; '+$regRows.Count+' Registry-Eintraege')
Write-Host ('CSV: '+$InventoryPath)

if (-not $EnableRepair) {
 Write-RunLine 'INVENTURTEST (Standardmodus): abgeschlossen. ACL-Sicherung und Berechtigungspruefung/-aenderung wurden bewusst nicht gestartet.'
 Write-Host ''
 Write-Host 'INVENTURTEST (Standardmodus) abgeschlossen. Es wurden keine ACL-Sicherungen gestartet und keine Berechtigungen geaendert.' -ForegroundColor Green
 Write-Host ('Bericht: '+$ReportPath)
 Write-Host ('Log: '+$LogPath)
 Write-Host ('Inventur-CSV: '+$InventoryPath)
 if (($script:RegistryReadErrors+$script:InventorySearchErrors) -gt 0) { exit 2 }
 exit 0
}

Write-Host ''
Write-Host 'PHASE 1: ACL-Sicherung der inventarisierten EXE-Dateien.'
Write-Host 'Nicht zu EXE-Dateien gehoerende Verzeichnisse werden nicht rekursiv gesichert.'
if (-not (Invoke-ExeAclBackup $InventoryPath $ExeAclBackup $ExeAclStatus)) {
 Stop-WithMessage 'ABBRUCH: EXE-ACL-Sicherung nicht vollstaendig bestaetigt. Keine Rechte geaendert.'
}
$ExeInventoryRows=@(Import-Csv -LiteralPath $InventoryPath | Where-Object {$_.RecordType -eq 'ExeFile'})
if($ExeInventoryRows.Count -le 0) { Stop-WithMessage 'ABBRUCH: Keine EXE-Dateien in der Inventur. Keine Rechte geaendert.' }

Write-Host ''
Write-Host 'Sicherungsphase abgeschlossen.'
Write-Host 'P = Nur pruefen | R = fehlendes RX ergaenzen | A = Abbrechen'
$choice=(Read-Host 'Bitte P, R oder A eingeben').Trim().ToUpperInvariant()
if ($choice -eq 'A') { Write-RunLine 'Benutzerabbruch; keine Rechte geaendert.'; exit 0 }
if ($choice -ne 'P' -and $choice -ne 'R') { Stop-WithMessage 'Ungueltige Auswahl. Abbruch ohne Rechteaenderung.' }
$apply=($choice -eq 'R')
if ($apply) { Write-RunLine 'Modus R: fehlendes RX gezielt ergaenzen.' } else { Write-RunLine 'Modus P: reine Pruefung; keine Rechteaenderung.' }

$total=0;$already=0;$denied=0;$unknown=0;$would=0;$changed=0;$readErr=0;$setErr=0;$verifyErr=0;$enumErr=0
Write-RunLine ''
Write-RunLine 'VERARBEITUNG: EXE-Dateien aus der gesicherten Inventur'
foreach ($entry in $ExeInventoryRows) {
 $total++;$path=[string]$entry.Path
 try {$acl=Get-Acl -LiteralPath $path -ErrorAction Stop;$state=Get-UsersAclState $acl}
 catch {$readErr++;Write-RunLine ('FEHLER_BEIM_LESEN - '+$path+' - '+$_.Exception.Message);continue}
 if ($state.Deny) {$denied++;Write-RunLine ('UEBERSPRUNGEN_DENY - '+$path);continue}
 if ($state.Allow) {$already++;Write-RunLine ('BEREITS_AUSREICHEND - '+$path);continue}
 if ($state.Unresolved -gt 0) {$unknown++;Write-RunLine ('UEBERSPRUNGEN_UNGEKLAERTE_IDENTITAETEN - '+$path);continue}
 if (-not $apply) {$would++;Write-RunLine ('WUERDE_RX_ERGAENZEN - '+$path);continue}
 try {
  $rule=New-Object System.Security.AccessControl.FileSystemAccessRule($UsersSid,[System.Security.AccessControl.FileSystemRights]::ReadAndExecute,[System.Security.AccessControl.AccessControlType]::Allow)
  $acl.AddAccessRule($rule);Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop
  $changed++;Write-RunLine ('AENDERUNG_GESPEICHERT - '+$path)
 } catch {$setErr++;Write-RunLine ('FEHLER_BEIM_SETZEN - '+$path+' - '+$_.Exception.Message);continue}
 try {
  $check=Get-UsersAclState (Get-Acl -LiteralPath $path -ErrorAction Stop)
  if ($check.Allow -and -not $check.Deny -and $check.Unresolved -eq 0) {Write-RunLine ('ERFOLGREICH_GESETZT_UND_VERIFIZIERT - '+$path)}
  else {$verifyErr++;Write-RunLine ('AENDERUNG_GESPEICHERT_ABER_VERIFIKATION_UNKLAR - '+$path)}
 } catch {$verifyErr++;Write-RunLine ('AENDERUNG_GESPEICHERT_ABER_VERIFIKATION_FEHLER - '+$path+' - '+$_.Exception.Message)}
}
$summary=@('','================ AUSWERTUNG ================',('Gefundene EXE-Dateien: '+$total),('RX bereits vorhanden: '+$already),('DENY uebersprungen: '+$denied),('Ungeklaerte Identitaeten uebersprungen: '+$unknown),('Wuerde RX ergaenzen: '+$would),('Aenderungen gespeichert: '+$changed),('Fehler Lesen: '+$readErr),('Fehler Setzen: '+$setErr),('Fehler Verifikation: '+$verifyErr),('Fehler Suche: '+$enumErr),('Registry-Lesefehler: '+$script:RegistryReadErrors),('Inventur-Suchfehler: '+$script:InventorySearchErrors),('Ende: '+(Get-Date)))
foreach ($line in $summary) {Write-RunLine $line}
Write-Host ''
Write-Host ('Bericht: '+$ReportPath)
Write-Host ('Inventur-CSV: '+$InventoryPath)
Write-Host ('EXE: '+$total+' | Bereits RX: '+$already+' | Aenderungen: '+$changed)
Write-Host ('Fehler Lesen/Setzen/Verifikation/Suche: '+($readErr+$setErr+$verifyErr+$enumErr))
if (($readErr+$setErr+$verifyErr+$enumErr+$script:RegistryReadErrors+$script:InventorySearchErrors) -gt 0) {exit 2}
exit 0
