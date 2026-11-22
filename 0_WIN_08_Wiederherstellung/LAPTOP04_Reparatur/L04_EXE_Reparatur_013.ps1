#requires -Version 3.0
# WARS - EXE-Berechtigungsreparatur 013
# CSV-Rechnerauswahl mit Abgleich gegen den tatsaechlichen Windows-Rechnernamen.
# Die eigentliche Reparaturlogik basiert auf der erfolgreich getesteten Version 012.

$ErrorActionPreference='Stop'
trap {
 Write-Host ('KRITISCHER PS1-FEHLER: '+$_.Exception.Message) -ForegroundColor Red
 exit 1
}
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

# --------------------------------------------------
# PHASE 0: Zentrale Stammdatei lesen und Rechner waehlen
# --------------------------------------------------
if (-not (Test-Path -LiteralPath $StammCsv -PathType Leaf)) {
 Stop-WithMessage ('Zentrale Stammdatei nicht gefunden: '+$StammCsv)
}
try {
 $allConfig=@(Import-Csv -LiteralPath $StammCsv -Delimiter ';' -ErrorAction Stop)
} catch {
 Stop-WithMessage ('Stammdatei konnte nicht gelesen werden: '+$_.Exception.Message)
}
if ($allConfig.Count -eq 0) {
 Stop-WithMessage 'WARS_Stamm.csv enthaelt keine Rechnerdatensaetze.'
}

# Alle 12 festgelegten Spalten muessen vorhanden sein.
$requiredHeaders=@('ID','wars_rechner','wars_rechner_BEZ','wars_backup_LW','wars_backup_PFAD','wars_obj_TYP','wars_obj_PFAD','wars_ob_BEZ','wars_pruef','wars_aktiv','wars_reihe','wars_bem')
$headers=@($allConfig[0].PSObject.Properties | ForEach-Object {$_.Name})
foreach ($headerName in $requiredHeaders) {
 if ($headers -notcontains $headerName) {
  Stop-WithMessage ('Spalte in WARS_Stamm.csv fehlt: '+$headerName)
 }
}

# Leeres wars_aktiv gilt vorerst als aktiv. Explizite 0/Nein/Falsch-Werte deaktivieren.
$inactiveValues=@('0','NEIN','NO','FALSE','INAKTIV','OFF')
$eligibleRows=New-Object System.Collections.ArrayList
foreach ($row in $allConfig) {
 $rowComputer=([string]$row.wars_rechner).Trim()
 if ([string]::IsNullOrWhiteSpace($rowComputer)) {
  Stop-WithMessage 'Ein Datensatz in WARS_Stamm.csv hat keinen wars_rechner-Eintrag.'
 }
 $activeValue=([string]$row.wars_aktiv).Trim().ToUpperInvariant()
 if ($inactiveValues -contains $activeValue) {
  Write-Host ('Datensatz deaktiviert: '+$rowComputer+' (wars_aktiv='+$activeValue+')') -ForegroundColor Yellow
  continue
 }
 [void]$eligibleRows.Add($row)
}
Write-Host ('Eingelesene Stammdatei: '+$StammCsv)
Write-Host ('Datensaetze in CSV: '+$allConfig.Count+' | Aktive Rechner: '+$eligibleRows.Count)
if ($eligibleRows.Count -eq 0) {
 Stop-WithMessage 'In WARS_Stamm.csv gibt es keinen aktiven Rechner zur Auswahl.'
}

# Doppelte aktive Rechnernamen waeren nicht eindeutig und werden deshalb abgewiesen.
$seenComputers=@{}
foreach ($row in $eligibleRows) {
 $key=([string]$row.wars_rechner).Trim().ToUpperInvariant()
 if ($seenComputers.ContainsKey($key)) {
  Stop-WithMessage ('Rechnername mehrfach in WARS_Stamm.csv eingetragen: '+$key)
 }
 $seenComputers[$key]=$true
}

$computerName=[string]$env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($computerName)) {
 Stop-WithMessage 'Windows-Rechnername konnte nicht ermittelt werden.'
}

Write-Host ''
Write-Host 'WARS - Rechnerauswahl'
Write-Host '---------------------'
for ($i=0; $i -lt $eligibleRows.Count; $i++) {
 $row=$eligibleRows[$i]
 $short=([string]$row.wars_rechner_BEZ).Trim()
 if ([string]::IsNullOrWhiteSpace($short)) { $short='ohne Kurzbezeichnung' }
 $name=([string]$row.wars_rechner).Trim()
 Write-Host ('{0} = {1} ({2})' -f ($i+1),$short,$name)
}
Write-Host 'A = Abbrechen'
Write-Host ''
while ($true) {
 $selection=(Read-Host 'Bitte Rechnernummer oder A waehlen').Trim()
 if ($selection -match '^[Aa]$') {
  Write-Host 'Vom Benutzer abgebrochen. Es wurde nichts gestartet.'
  exit 0
 }
 $selectedNumber=0
 if ([int]::TryParse($selection,[ref]$selectedNumber) -and $selectedNumber -ge 1 -and $selectedNumber -le $eligibleRows.Count) {
  break
 }
 Write-Host 'Ungueltige Auswahl. Bitte eine angezeigte Nummer oder A eingeben.' -ForegroundColor Yellow
}

$config=$eligibleRows[$selectedNumber-1]
$selectedComputer=([string]$config.wars_rechner).Trim()
$computerBez=([string]$config.wars_rechner_BEZ).Trim()
if ([string]::IsNullOrWhiteSpace($computerBez)) { $computerBez=$selectedComputer }

# Sicherheitsabgleich: Auswahl aus der CSV muss zum echten Windows-Rechner passen.
if ($selectedComputer -ine $computerName) {
 $popupMessage="Du sitzt am falschen Rechner, du besoffener Voltrottel!`r`n`r`nIch bin Rechner $computerName! Du hast aber $selectedComputer ausgewaehlt!"
 $popupTitle='WARS - Falsche Rechnerauswahl'
 Write-Host ''
 Write-Host 'FALSCHE RECHNERAUSWAHL!' -ForegroundColor Red
 Write-Host $popupMessage -ForegroundColor Red
 try {
  # Win32-MessageBox mit MB_SETFOREGROUND und MB_TOPMOST:
  # Das Fenster wird in den Vordergrund geholt und bleibt ueber der Konsole.
  $nativeMessageBox=@'
using System;
using System.Runtime.InteropServices;
public static class WARSForegroundMessageBox {
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="MessageBoxW")]
    public static extern int Show(IntPtr hWnd, string text, string caption, uint type);
}
'@
  Add-Type -TypeDefinition $nativeMessageBox -Language CSharp -ErrorAction Stop
  $messageBoxFlags=[uint32](0x00000010 -bor 0x00010000 -bor 0x00040000)
  [void][WARSForegroundMessageBox]::Show([IntPtr]::Zero,$popupMessage,$popupTitle,$messageBoxFlags)
 } catch {
  Write-Host 'Das Windows-Meldungsfenster konnte nicht angezeigt werden.' -ForegroundColor Yellow
  Write-Host $_.Exception.Message -ForegroundColor Yellow
 }
 Write-Host ''
 exit 10
}

$backupDrive=([string]$config.wars_backup_LW).Trim()
$backupPath=([string]$config.wars_backup_PFAD).Trim()
if ($backupDrive -notmatch '^[A-Za-z]:$') {
 Stop-WithMessage ('Ungueltiges oder fehlendes Backup-Laufwerk in WARS_Stamm.csv: '+$backupDrive)
}
if ([string]::IsNullOrWhiteSpace($backupPath)) {
 Stop-WithMessage 'Backup-Pfad fehlt in WARS_Stamm.csv.'
}
if ($backupPath -match '^[A-Za-z]:' -or $backupPath -match '(^|[\\/])\.\.([\\/]|$)') {
 Stop-WithMessage 'Backup-Pfad muss relativ zum ausgewaehlten Laufwerk sein und darf kein .. enthalten.'
}
$relativeBackupPath=$backupPath.TrimStart([char[]]@('\','/'))
if ([string]::IsNullOrWhiteSpace($relativeBackupPath)) {
 Stop-WithMessage 'Backup-Pfad in WARS_Stamm.csv ist ungueltig.'
}

# CSV-Laufwerk zuerst lokal pruefen. Falls es ein Netzlaufwerk ist,
# dessen UNC-Ziel dynamisch aus Windows ermitteln (keine Rechnerpfade fest codiert).
try {
 $driveRoot=$backupDrive+'\'
 if (Test-Path -LiteralPath $driveRoot -PathType Container) {
  $Base=Join-Path $driveRoot $relativeBackupPath
 } else {
  $remoteRoot=$null
  try {
   if (-not ('WARSNetworkDriveResolver' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WARSNetworkDriveResolver {
    [DllImport("mpr.dll", CharSet=CharSet.Unicode)]
    public static extern int WNetGetConnection(string localName, StringBuilder remoteName, ref int length);
}
'@ -ErrorAction Stop
   }
   $buffer=New-Object System.Text.StringBuilder 1024
   $bufferLength=$buffer.Capacity
   $result=[WARSNetworkDriveResolver]::WNetGetConnection($backupDrive,$buffer,[ref]$bufferLength)
   if ($result -eq 0) { $remoteRoot=$buffer.ToString() }
  } catch {
   Write-Host ('Hinweis: Netzlaufwerkabfrage: '+$_.Exception.Message) -ForegroundColor Yellow
  }
  if ([string]::IsNullOrWhiteSpace($remoteRoot)) {
   $driveKey=Join-Path 'HKCU:\Network' $backupDrive.Substring(0,1)
   if (Test-Path -LiteralPath $driveKey) {
    $mapping=Get-ItemProperty -LiteralPath $driveKey -ErrorAction Stop
    $remoteRoot=[string]$mapping.RemotePath
   }
  }
  if ([string]::IsNullOrWhiteSpace($remoteRoot) -or $remoteRoot -notmatch '^\\\\') {
   Stop-WithMessage ('Das CSV-Laufwerk '+$backupDrive+' ist nicht lokal erreichbar und seine UNC-Zuordnung konnte nicht ermittelt werden. Netzlaufwerkverbindung pruefen.')
  }
  $Base=Join-Path ($remoteRoot.TrimEnd('\')) $relativeBackupPath
 }
 $Base=[System.IO.Path]::GetFullPath($Base)
} catch {
 Stop-WithMessage ('Backup-Pfad konnte nicht aus WARS_Stamm.csv aufgeloest werden: '+$_.Exception.Message)
}
$AclDir=Join-Path $Base 'ACL_Sicherungen\ACL'
$TxtDir=Join-Path $Base 'ACL_Sicherungen\TXT'
$CsvDir=Join-Path $Base 'ACL_Sicherungen\CSV'
$LogDir=Join-Path $Base 'ACL_Sicherungen\LOG'
Write-Host ''
Write-Host ('Rechner: '+$computerName+' ('+$computerBez+')')
Write-Host ('Backup-Ziel: '+$Base)

# --------------------------------------------------
# Hauptmenue erst nach erfolgreicher Rechnerpruefung
# --------------------------------------------------
Write-Host ''
Write-Host ($computerBez+' - EXE-Berechtigungsreparatur 013')
Write-Host ''
Write-Host '1 = Nur Inventur (EXE-Dateien und Registry)'
Write-Host '2 = Inventur + ACL-Sicherung + Pruefung/Reparatur'
Write-Host 'A = Abbrechen'
Write-Host ''
while ($true) {
 $mainChoice=(Read-Host 'Bitte 1, 2 oder A waehlen').Trim().ToUpperInvariant()
 if ($mainChoice -eq '1' -or $mainChoice -eq '2' -or $mainChoice -eq 'A') { break }
 Write-Host 'Ungueltige Auswahl. Bitte 1, 2 oder A eingeben.' -ForegroundColor Yellow
}
if ($mainChoice -eq 'A') {
 Write-Host 'Vom Benutzer abgebrochen. Es wurde nichts gestartet.'
 exit 0
}
$EnableRepair=($mainChoice -eq '2')
if ($EnableRepair) {
 Write-Host ''
 Write-Host 'HINWEIS:'
 Write-Host 'Die Reparatur wird nicht automatisch ausgefuehrt.'
 Write-Host 'Nach der Inventur muessen die ACL-Sicherungen erfolgreich sein.'
 Write-Host 'Danach fragt PowerShell nochmals:'
 Write-Host 'P = Nur pruefen, R = RX gezielt ergaenzen, A = Abbrechen.'
} else {
 Write-Host ''
 Write-Host 'Es wird nur die lesende Inventur ausgefuehrt.'
 Write-Host 'Es werden keine ACL-Sicherungen erstellt und keine Rechte geaendert.'
}

function Get-UniqueReportPath {
 $i=1
 do { $p=Join-Path $Base ($computerBez+'_EXE_Reparatur_013-{0:D2}.txt' -f $i); $i++ } while (Test-Path -LiteralPath $p)
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
$header=@(($computerBez+' - EXE-Berechtigungsreparatur 013'),('Start: '+(Get-Date)),'Zielgruppe: BUILTIN\Users (S-1-5-32-545)','Zielrecht: Lesen und Ausfuehren (RX)','Nur fehlendes RX ergaenzen; vorhandene ACEs und Vererbung erhalten.','ACL-Sicherung muss vor jeder Rechteaenderung erfolgreich sein.','')
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
 # DACL gezielt mit icacls ergaenzen. Set-Acl schreibt den kompletten
 # Sicherheitsdeskriptor und kann bei geschuetzten Dateien unnoetig den
 # Besitzer-/Sicherheitskontext beruehren. icacls /grant aendert nur die DACL.
 try {
  $icaclsPath=Join-Path $env:SystemRoot 'System32\icacls.exe'
  if (-not (Test-Path -LiteralPath $icaclsPath -PathType Leaf)) { throw 'icacls.exe wurde nicht gefunden.' }
  $grantSpec='*'+$UsersSid.Value+':(RX)'
  $icaclsOutput=@(& $icaclsPath $path '/grant' $grantSpec 2>&1)
  $icaclsExitCode=$LASTEXITCODE
  if ($icaclsExitCode -ne 0) { throw ('icacls ExitCode '+$icaclsExitCode+': '+($icaclsOutput -join ' ')) }
  $changed++;Write-RunLine ('AENDERUNG_GESPEICHERT - '+$path)
 } catch {
   $setErr++
   Write-RunLine ('FEHLER_BEIM_SETZEN - '+$path+' - '+$_.Exception.Message)
   # Diagnose bei verweigerter DACL-Aenderung: Identitaet, Datei-/Ordnerbesitzer
   # sowie die tatsaechlich gelesenen ACLs protokollieren; keine Rechte aendern.
   try {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    Write-RunLine ('DIAG_IDENTITAET - '+$id.Name)
    $fileAcl=Get-Acl -LiteralPath $path -ErrorAction Stop
    Write-RunLine ('DIAG_DATEI_OWNER - '+$fileAcl.Owner)
    Write-RunLine ('DIAG_DATEI_SDDL - '+$fileAcl.Sddl)
    $parent=Split-Path -LiteralPath $path -Parent
    $parentAcl=Get-Acl -LiteralPath $parent -ErrorAction Stop
    Write-RunLine ('DIAG_ORDNER - '+$parent)
    Write-RunLine ('DIAG_ORDNER_OWNER - '+$parentAcl.Owner)
    Write-RunLine ('DIAG_ORDNER_SDDL - '+$parentAcl.Sddl)
    $fileIca=@(& $icaclsPath $path 2>&1)
    Write-RunLine ('DIAG_ICACLS_DATEI - '+($fileIca -join ' '))
    $parentIca=@(& $icaclsPath $parent 2>&1)
    Write-RunLine ('DIAG_ICACLS_ORDNER - '+($parentIca -join ' '))
   } catch {Write-RunLine ('DIAGNOSE_FEHLER - '+$_.Exception.Message)}
   continue
  }
 try {
  $check=Get-UsersAclState (Get-Acl -LiteralPath $path -ErrorAction Stop)
  # Unaufloesbare andere ACEs verhindern nicht die Bestaetigung des explizit
  # hinzugefuegten Users-RX. Ein vorhandenes DENY bleibt dagegen ein Fehler.
  if ($check.Allow -and -not $check.Deny) {
   Write-RunLine ('ERFOLGREICH_GESETZT_UND_VERIFIZIERT - '+$path+'; Ungeklaerte andere ACEs: '+$check.Unresolved)
  }
  else {$verifyErr++;Write-RunLine ('AENDERUNG_GESPEICHERT_ABER_VERIFIKATION_UNKLAR - '+$path+'; Allow='+$check.Allow+'; Deny='+$check.Deny+'; Ungeklaerte andere ACEs='+$check.Unresolved)}
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
