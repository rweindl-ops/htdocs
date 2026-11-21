#requires -Version 3.0
# L04 - EXE-Berechtigungsreparatur 07
# ACL-Sicherung mit Status-Heartbeat. Keine Rechteaenderung vor erfolgreicher Sicherung.

$ErrorActionPreference='Stop'
$Base=$PSScriptRoot
$Root1='C:\Program Files'
$Root2='C:\Program Files (x86)'
$AclDir=Join-Path $Base 'ACL_Sicherungen\ACL'
$TxtDir=Join-Path $Base 'ACL_Sicherungen\TXT'
$LogDir=Join-Path $Base 'ACL_Sicherungen\LOG'
$UsersSid=New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')
$Rx=[int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute

function Write-RunLine([string]$Line) {
 Add-Content -LiteralPath $script:ReportPath -Value $Line -Encoding UTF8
 Add-Content -LiteralPath $script:LogPath -Value $Line -Encoding UTF8
}
function Stop-WithMessage([string]$Message) {
 Write-Host $Message -ForegroundColor Red
 if ($script:LogPath -and (Test-Path -LiteralPath $script:LogPath)) { Add-Content -LiteralPath $script:LogPath -Value $Message -Encoding UTF8 }
 exit 1
}
function Get-UniqueReportPath {
 $i=1
 do { $p=Join-Path $Base ('L04_EXE_Reparatur_07-{0:D2}.txt' -f $i); $i++ } while (Test-Path -LiteralPath $p)
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

# Voraussetzungen
foreach ($d in @($AclDir,$TxtDir,$LogDir)) { if (-not (Test-Path -LiteralPath $d -PathType Container)) { Stop-WithMessage ('Sicherungsverzeichnis fehlt: '+$d) } }
$admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Stop-WithMessage 'Bitte die BAT-Datei als Administrator starten.' }
if (-not (Test-Path -LiteralPath $Root1 -PathType Container)) { Stop-WithMessage 'C:\Program Files wurde nicht gefunden.' }

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportPath=Get-UniqueReportPath
$LogPath=Join-Path $LogDir ('Reparatur_'+$stamp+'.log')
$Acl1=Join-Path $AclDir ('ProgramFiles_'+$stamp+'.acl')
$Acl2=Join-Path $AclDir ('ProgramFiles_x86_'+$stamp+'.acl')
$Status1=Join-Path $TxtDir ('Backup_Status_ProgramFiles_'+$stamp+'.txt')
$Status2=Join-Path $TxtDir ('Backup_Status_ProgramFiles_x86_'+$stamp+'.txt')
foreach ($p in @($LogPath,$Acl1,$Acl2,$Status1,$Status2)) { if (Test-Path -LiteralPath $p) { Stop-WithMessage ('Ausgabedatei existiert bereits; nichts ueberschrieben: '+$p) } }
New-Item -ItemType File -Path $ReportPath,$LogPath,$Status1,$Status2 -ErrorAction Stop | Out-Null
$header=@('L04 - EXE-Berechtigungsreparatur 07',('Start: '+(Get-Date)),'Zielgruppe: BUILTIN\Users (S-1-5-32-545)','Zielrecht: Lesen und Ausfuehren (RX)','Nur fehlendes RX ergaenzen; vorhandene ACEs und Vererbung erhalten.','ACL-Sicherung muss vor jeder Rechteaenderung erfolgreich sein.','')
foreach ($l in $header) { Add-Content -LiteralPath $ReportPath -Value $l -Encoding UTF8; Add-Content -LiteralPath $LogPath -Value $l -Encoding UTF8 }

# icacls wird separat gestartet. Die Statusdatei wird waehrend des Laufs
# alle 15 Sekunden aktualisiert; stdout/stderr werden danach vollstaendig
# angehaengt und bleiben zusaetzlich als temporaere Beweisdateien erhalten.
function Invoke-AclBackup {
 param([string]$Root,[string]$AclFile,[string]$StatusFile,[string]$Label)
 $out=$StatusFile+'.stdout.tmp'; $err=$StatusFile+'.stderr.tmp'
 $start=Get-Date; $last=$start; $proc=$null; $rc=-999
 Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value @(('Start: '+$start),('Bereich: '+$Label),('Quelle: '+$Root),'icacls /save /T; /C absichtlich nicht verwendet.','Status: Prozessstart')
 Write-Host ('ACL-Sicherung gestartet: '+$Label)
 try {
  $proc=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\icacls.exe') -ArgumentList @('"' + $Root + '"','/save','"' + $AclFile + '"','/T') -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
  Add-Content -LiteralPath $StatusFile -Value ('PID: '+$proc.Id) -Encoding UTF8
  while (-not $proc.HasExited) {
   Start-Sleep -Seconds 3
   $proc.Refresh()
   if (((Get-Date)-$last).TotalSeconds -ge 15) {
    $ab=0;$ob=0;$eb=0
    if (Test-Path -LiteralPath $AclFile) {$ab=(Get-Item -LiteralPath $AclFile).Length}
    if (Test-Path -LiteralPath $out) {$ob=(Get-Item -LiteralPath $out).Length}
    if (Test-Path -LiteralPath $err) {$eb=(Get-Item -LiteralPath $err).Length}
    $line=('{0} | icacls laeuft | {1:N0}s | ACL {2:N0} Bytes | stdout {3:N0} Bytes | stderr {4:N0} Bytes' -f (Get-Date),((Get-Date)-$start).TotalSeconds,$ab,$ob,$eb)
    Add-Content -LiteralPath $StatusFile -Value $line -Encoding UTF8
    Write-Host $line
    $last=Get-Date
   }
  }
  $proc.WaitForExit(); $rc=$proc.ExitCode
 } catch { Add-Content -LiteralPath $StatusFile -Value ('PROZESSFEHLER: '+$_.Exception.Message) -Encoding UTF8 }

 $output=''
 foreach ($tmp in @($out,$err)) {
  if (Test-Path -LiteralPath $tmp) {
   Add-Content -LiteralPath $StatusFile -Value ('--- '+[IO.Path]::GetFileName($tmp)+' ---') -Encoding UTF8
   $lines=Get-Content -LiteralPath $tmp -ErrorAction SilentlyContinue
   foreach ($line in $lines) { Add-Content -LiteralPath $StatusFile -Value $line -Encoding UTF8 }
   $output += [IO.File]::ReadAllText($tmp)
  }
 }
 $bytes=0
 if (Test-Path -LiteralPath $AclFile) {$bytes=(Get-Item -LiteralPath $AclFile).Length}
 $bad=[regex]::IsMatch($output,'(?im)(Zugriff verweigert|Access is denied|Fehler beim Verarbeiten von [1-9][0-9]*|Failed processing [1-9][0-9]*|error:|Fehler:)')
 $seconds=[math]::Round(((Get-Date)-$start).TotalSeconds,1)
 Add-Content -LiteralPath $StatusFile -Encoding UTF8 -Value @('',('Ende: '+(Get-Date)),('Laufzeit: '+$seconds+' Sekunden'),('icacls ExitCode: '+$rc),('ACL-Dateigroesse: '+$bytes+' Bytes'),('Fehlermuster erkannt: '+$bad))
 if ($null -eq $proc -or $rc -ne 0 -or $bad -or $bytes -le 0) {
  Write-RunLine ('FEHLER: Sicherung '+$Label+' NICHT bestaetigt. ExitCode='+$rc+'; Fehlertext='+$bad+'; ACL-Bytes='+$bytes)
  return $false
 }
 Write-RunLine ('Sicherung '+$Label+' beendet. ExitCode=0; ACL-Bytes='+$bytes+'; Laufzeit='+$seconds+' s.')
 return $true
}

Write-Host ''
Write-Host 'PHASE 1: ACL-Sicherung. Bis zum erfolgreichen Abschluss werden keine Rechte geaendert.'
if (-not (Invoke-AclBackup $Root1 $Acl1 $Status1 'Program Files')) { Stop-WithMessage 'ABBRUCH: Program-Files-Backup nicht zweifelsfrei erfolgreich. Keine Rechte geaendert.' }
$Roots=@($Root1)
if (Test-Path -LiteralPath $Root2 -PathType Container) {
 $children=@(Get-ChildItem -LiteralPath $Root2 -Force -ErrorAction Stop | Select-Object -First 1)
 if ($children.Count -gt 0) {
  if (-not (Invoke-AclBackup $Root2 $Acl2 $Status2 'Program Files (x86)')) { Stop-WithMessage 'ABBRUCH: x86-Backup nicht zweifelsfrei erfolgreich. Keine Rechte geaendert.' }
  $Roots+=$Root2
 } else {
  Add-Content -LiteralPath $Status2 -Value @('Ordner vorhanden, aber leer.','Keine Sicherung erforderlich.','Status: LEER - ausgelassen.') -Encoding UTF8
  Write-RunLine 'Program Files (x86) ist leer; Sicherung ausgelassen.'
 }
} else { Add-Content -LiteralPath $Status2 -Value 'Ordner nicht vorhanden; ausgelassen.' -Encoding UTF8 }
Write-RunLine 'Alle erforderlichen Sicherungen haben die Basispruefung bestanden.'

Write-Host ''
Write-Host 'Sicherungsphase abgeschlossen.'
Write-Host 'P = Nur pruefen | R = fehlendes RX ergaenzen | A = Abbrechen'
$choice=(Read-Host 'Bitte P, R oder A eingeben').Trim().ToUpperInvariant()
if ($choice -eq 'A') { Write-RunLine 'Benutzerabbruch; keine Rechte geaendert.'; exit 0 }
if ($choice -ne 'P' -and $choice -ne 'R') { Stop-WithMessage 'Ungueltige Auswahl. Abbruch ohne Rechteaenderung.' }
$apply=($choice -eq 'R')
if ($apply) { Write-RunLine 'Modus R: fehlendes RX gezielt ergaenzen.' } else { Write-RunLine 'Modus P: reine Pruefung; keine Rechteaenderung.' }

$total=0;$already=0;$denied=0;$unknown=0;$would=0;$changed=0;$readErr=0;$setErr=0;$verifyErr=0;$enumErr=0
foreach ($root in $Roots) {
 Write-RunLine ''; Write-RunLine ('VERZEICHNIS: '+$root)
 $errors=@()
 $files=@(Get-ChildItem -LiteralPath $root -Filter '*.exe' -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable errors)
 if ($errors.Count -gt 0) { $enumErr+=$errors.Count; foreach ($e in $errors) {Write-RunLine ('SUCHFEHLER: '+$e.Exception.Message)} }
 foreach ($file in $files) {
  $total++;$path=$file.FullName
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
}
$summary=@('','================ AUSWERTUNG ================',('Gefundene EXE-Dateien: '+$total),('RX bereits vorhanden: '+$already),('DENY uebersprungen: '+$denied),('Ungeklaerte Identitaeten uebersprungen: '+$unknown),('Wuerde RX ergaenzen: '+$would),('Aenderungen gespeichert: '+$changed),('Fehler Lesen: '+$readErr),('Fehler Setzen: '+$setErr),('Fehler Verifikation: '+$verifyErr),('Fehler Suche: '+$enumErr),('Ende: '+(Get-Date)))
foreach ($line in $summary) {Write-RunLine $line}
Write-Host ''
Write-Host ('Bericht: '+$ReportPath)
Write-Host ('EXE: '+$total+' | Bereits RX: '+$already+' | Aenderungen: '+$changed)
Write-Host ('Fehler Lesen/Setzen/Verifikation/Suche: '+($readErr+$setErr+$verifyErr+$enumErr))
if (($readErr+$setErr+$verifyErr+$enumErr) -gt 0) {exit 2}
exit 0
