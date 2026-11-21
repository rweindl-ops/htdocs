#requires -Version 3.0
# L04 - EXE-Berechtigungsreparatur 06
# Ziel: Fehlendes Lesen/Ausfuehren (RX) fuer BUILTIN\Users
#       gezielt ergaenzen, ohne vorhandene ACL-Strukturen zu zerstoeren.
# WICHTIG: Keine Vererbungsumstellung, kein PurgeAccessRules,
#          keine Aenderung des Besitzers und keine Entfernung von ACEs.

$ErrorActionPreference = 'Stop'

$Base = $PSScriptRoot
$Root1 = 'C:\Program Files'
$Root2 = 'C:\Program Files (x86)'
$Backup = Join-Path $Base 'ACL_Sicherungen'
$AclDir = Join-Path $Backup 'ACL'
$TxtDir = Join-Path $Backup 'TXT'
$LogDir = Join-Path $Backup 'LOG'

$UsersSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')
$Rx = [int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute

function Write-RunLine {
    param([string]$Line, [string]$StatusPath)
    Add-Content -LiteralPath $script:ReportPath -Value $Line -Encoding UTF8
    Add-Content -LiteralPath $script:LogPath -Value $Line -Encoding UTF8
    if ($StatusPath) {
        Add-Content -LiteralPath $StatusPath -Value $Line -Encoding UTF8
    }
}

function Get-UsersAclState {
    param([System.Security.AccessControl.FileSystemSecurity]$Acl)

    $Allow = $false
    $Deny = $false
    $Unresolved = 0

    foreach ($Ace in $Acl.Access) {
        $AceSid = $null
        try {
            if ($Ace.IdentityReference -is [System.Security.Principal.SecurityIdentifier]) {
                $AceSid = $Ace.IdentityReference.Value
            } else {
                $AceSid = $Ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
        } catch {
            # Eine nicht aufloesbare Identitaet darf nicht die gesamte
            # Dateipruefung abbrechen. Die Datei wird spaeter vorsichtshalber
            # von einer automatischen Aenderung ausgeschlossen.
            $Unresolved++
            continue
        }

        if ($AceSid -eq $script:UsersSid.Value) {
            if ($Ace.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
                $Deny = $true
            }
            if ($Ace.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) {
                if (([int]$Ace.FileSystemRights -band $script:Rx) -eq $script:Rx) {
                    $Allow = $true
                }
            }
        }
    }

    return [pscustomobject]@{
        Allow = $Allow
        Deny = $Deny
        Unresolved = $Unresolved
    }
}

function Stop-WithMessage {
    param([string]$Message)
    Write-Host ''
    Write-Host $Message -ForegroundColor Red
    if ($script:LogPath -and (Test-Path -LiteralPath $script:LogPath)) {
        Add-Content -LiteralPath $script:LogPath -Value $Message -Encoding UTF8
    }
    exit 1
}

# --------------------------------------------------
# VORAUSSETZUNGEN
# --------------------------------------------------

if (-not (Test-Path -LiteralPath $Base -PathType Container)) {
    Stop-WithMessage 'FEHLER: Hauptverzeichnis nicht gefunden.'
}

foreach ($Dir in @($AclDir, $TxtDir, $LogDir)) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
        Stop-WithMessage ('FEHLER: Sicherungsverzeichnis fehlt: ' + $Dir)
    }
}

$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-WithMessage 'FEHLER: Bitte die BAT-Datei mit "Als Administrator ausfuehren" starten.'
}

if (-not (Test-Path -LiteralPath $Root1 -PathType Container)) {
    Stop-WithMessage 'FEHLER: C:\Program Files wurde nicht gefunden.'
}

$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportPath = Join-Path $Base ('L04_EXE_Reparatur_006-01.txt')
$LogPath = Join-Path $LogDir ('Reparatur_' + $Stamp + '.log')
$AclFile1 = Join-Path $AclDir ('ProgramFiles_' + $Stamp + '.acl')
$AclFile2 = Join-Path $AclDir ('ProgramFiles_x86_' + $Stamp + '.acl')
$Status1 = Join-Path $TxtDir ('Backup_Status_ProgramFiles_' + $Stamp + '.txt')
$Status2 = Join-Path $TxtDir ('Backup_Status_ProgramFiles_x86_' + $Stamp + '.txt')

$OutputPaths = @($ReportPath, $LogPath, $AclFile1, $AclFile2, $Status1, $Status2)
foreach ($Path in $OutputPaths) {
    if (Test-Path -LiteralPath $Path) {
        Stop-WithMessage ('FEHLER: Ausgabedatei existiert bereits. Es wird nichts ueberschrieben: ' + $Path)
    }
}

New-Item -ItemType File -Path $ReportPath -ErrorAction Stop | Out-Null
New-Item -ItemType File -Path $LogPath -ErrorAction Stop | Out-Null
New-Item -ItemType File -Path $Status1 -ErrorAction Stop | Out-Null
New-Item -ItemType File -Path $Status2 -ErrorAction Stop | Out-Null

$Header = @(
    'L04 - EXE-Berechtigungsreparatur 06'
    ('Start: ' + (Get-Date))
    'Zielgruppe: BUILTIN\Users (S-1-5-32-545)'
    'Zielrecht: Lesen und Ausfuehren (RX)'
    'Verfahren: Nur fehlendes RX ergaenzen; vorhandene ACEs und Vererbung erhalten.'
    'Es werden keine Dateiinhalte veraendert.'
    ''
)
foreach ($Line in $Header) {
    Add-Content -LiteralPath $ReportPath -Value $Line -Encoding UTF8
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
}

# --------------------------------------------------
# ACL-SICHERUNG - VOR JEDER RECHTEAENDERUNG
# --------------------------------------------------

Write-Host ''
Write-Host 'Sichere zuerst die ACLs der Programmverzeichnisse ...'

function Invoke-AclBackup {
    param(
        [string]$Root,
        [string]$AclFile,
        [string]$StatusFile,
        [string]$Label
    )

    # Windows PowerShell kann native stderr-Ausgaben als NativeCommandError
    # behandeln. Fuer den icacls-Aufruf wird deshalb temporaer Continue
    # verwendet und stderr explizit in den Statusbericht umgeleitet.
    $PreviousErrorActionPreference = $ErrorActionPreference
    $BackupOutput = @()
    $BackupExitCode = -1
    $InvocationFailure = $null

    try {
        $ErrorActionPreference = 'Continue'
        $BackupOutput = @(& icacls.exe $Root /save $AclFile /T /C 2>&1)
        $BackupExitCode = $LASTEXITCODE
    } catch {
        $InvocationFailure = $_.Exception.Message
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    $NativeErrorRecords = @($BackupOutput | Where-Object {
        $_ -is [System.Management.Automation.ErrorRecord]
    })

    $StatusLines = @()
    foreach ($OutputLine in $BackupOutput) {
        $StatusLines += [string]$OutputLine
    }
    if ($InvocationFailure) {
        $StatusLines += ('PowerShell-Aufruffehler: ' + $InvocationFailure)
    }
    $StatusLines | Out-File -LiteralPath $StatusFile -Encoding UTF8

    $AclExists = Test-Path -LiteralPath $AclFile -PathType Leaf
    $AclHasContent = $false
    if ($AclExists) {
        $AclHasContent = ((Get-Item -LiteralPath $AclFile).Length -gt 0)
    }

    if ($BackupExitCode -ne 0 -or $NativeErrorRecords.Count -gt 0 -or
        $InvocationFailure -or -not $AclExists -or -not $AclHasContent) {
        Write-RunLine ('FEHLER: ACL-Sicherung ' + $Label + ' nicht zweifelsfrei erfolgreich. icacls-Rueckgabecode: ' + $BackupExitCode + '; native Fehlerausgaben: ' + $NativeErrorRecords.Count) $StatusFile
        return $false
    }

    Write-RunLine ('ACL-Sicherung ' + $Label + ' erfolgreich; icacls-Rueckgabecode: 0.') $StatusFile
    return $true
}

if (-not (Invoke-AclBackup -Root $Root1 -AclFile $AclFile1 -StatusFile $Status1 -Label 'Program Files')) {
    Stop-WithMessage 'ABBRUCH: Die ACL-Sicherung von Program Files war nicht zweifelsfrei erfolgreich. Es wurden keine Rechte geaendert.'
}

$Roots = @($Root1)
if (Test-Path -LiteralPath $Root2 -PathType Container) {
    if (-not (Invoke-AclBackup -Root $Root2 -AclFile $AclFile2 -StatusFile $Status2 -Label 'Program Files (x86)')) {
        Stop-WithMessage 'ABBRUCH: Die ACL-Sicherung von Program Files (x86) war nicht zweifelsfrei erfolgreich. Es wurden keine Rechte geaendert.'
    }
    $Roots += $Root2
} else {
    Write-RunLine 'Program Files (x86) ist nicht vorhanden; dieser Bereich wird ausgelassen.' $Status2
}

Write-RunLine '' $null
Write-RunLine 'Beide erforderlichen Sicherungsschritte sind abgeschlossen.' $null

# --------------------------------------------------
# SICHERHEITSABFRAGE: PRUEFEN ODER AENDERN
# --------------------------------------------------

Write-Host ''
Write-Host 'Die ACL-Sicherungen sind abgeschlossen.'
Write-Host 'P = Nur pruefen (keine Aenderungen an Berechtigungen)'
Write-Host 'R = Fehlendes RX gezielt ergaenzen'
Write-Host 'A = Abbrechen'
$Choice = (Read-Host 'Bitte P, R oder A eingeben').Trim().ToUpperInvariant()

if ($Choice -eq 'A') {
    Write-RunLine 'Vom Benutzer abgebrochen. Es wurden keine Berechtigungen geaendert.' $null
    exit 0
}
if ($Choice -ne 'P' -and $Choice -ne 'R') {
    Write-RunLine 'Ungueltige Auswahl. Es wurden keine Berechtigungen geaendert.' $null
    Stop-WithMessage 'ABBRUCH: Bitte nur P, R oder A eingeben.'
}
$ApplyChanges = ($Choice -eq 'R')
if ($ApplyChanges) {
    Write-RunLine 'MODUS: Fehlendes RX wird nach erfolgreicher Einzelpruefung ergaenzt.' $null
} else {
    Write-RunLine 'MODUS: Reiner Prueflauf. Es werden keine Berechtigungen geaendert.' $null
}

# --------------------------------------------------
# EXE-DATEIEN PRUEFEN
# --------------------------------------------------

$Total = 0
$Already = 0
$Denied = 0
$Unresolved = 0
$WouldAdd = 0
$Changed = 0
$ReadErrors = 0
$SetErrors = 0
$VerifyErrors = 0
$EnumerationErrors = 0

foreach ($Root in $Roots) {
    if ($Root -eq $Root1) {
        $StatusPath = $Status1
    } else {
        $StatusPath = $Status2
    }

    Write-RunLine '' $StatusPath
    Write-RunLine ('VERZEICHNIS: ' + $Root) $StatusPath

    $EnumErrors = @()
    $Files = @(Get-ChildItem -LiteralPath $Root -Filter '*.exe' -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable EnumErrors)
    if ($EnumErrors.Count -gt 0) {
        $EnumerationErrors += $EnumErrors.Count
        Write-RunLine ('WARNUNG: Fehler bei der Verzeichnissuche: ' + $EnumErrors.Count) $StatusPath
        foreach ($EnumError in $EnumErrors) {
            Write-RunLine ('SUCHFEHLER: ' + $EnumError.Exception.Message) $StatusPath
        }
    }

    foreach ($File in $Files) {
        $Total++
        $Path = $File.FullName

        try {
            $Acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
            $State = Get-UsersAclState -Acl $Acl
        } catch {
            $ReadErrors++
            Write-RunLine ('FEHLER_BEIM_LESEN - ' + $Path + ' - ' + $_.Exception.Message) $StatusPath
            continue
        }

        if ($State.Deny) {
            $Denied++
            Write-RunLine ('UEBERSPRUNGEN_DENY - ' + $Path) $StatusPath
            continue
        }

        if ($State.Allow) {
            $Already++
            if ($State.Unresolved -gt 0) {
                Write-RunLine ('BEREITS_RX_VORHANDEN; ZUSAETZLICH_UNGEKLAERTE_ACES=' + $State.Unresolved + ' - ' + $Path) $StatusPath
            } else {
                Write-RunLine ('BEREITS_AUSREICHEND - ' + $Path) $StatusPath
            }
            continue
        }

        if ($State.Unresolved -gt 0) {
            $Unresolved++
            Write-RunLine ('UEBERSPRUNGEN_UNGEKLAERTE_IDENTITAETEN=' + $State.Unresolved + ' - ' + $Path) $StatusPath
            continue
        }

        if (-not $ApplyChanges) {
            $WouldAdd++
            Write-RunLine ('WUERDE_RX_ERGAENZEN - ' + $Path) $StatusPath
            continue
        }

        # Aenderung: ausschliesslich einen RX-Allow-Eintrag hinzufuegen.
        # Keine vorhandenen ACEs entfernen und Vererbung nicht umstellen.
        try {
            $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $UsersSid,
                [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $Acl.AddAccessRule($Rule)
            Set-Acl -LiteralPath $Path -AclObject $Acl -ErrorAction Stop
            $Changed++
            Write-RunLine ('AENDERUNG_GESPEICHERT - ' + $Path) $StatusPath
        } catch {
            $SetErrors++
            Write-RunLine ('FEHLER_BEIM_SETZEN - ' + $Path + ' - ' + $_.Exception.Message) $StatusPath
            continue
        }

        # Verifikation ist ein eigener Schritt. Ein Fehler hier macht aus
        # einer gespeicherten Aenderung keinen Set-Acl-Fehler.
        try {
            $VerifyAcl = Get-Acl -LiteralPath $Path -ErrorAction Stop
            $VerifyState = Get-UsersAclState -Acl $VerifyAcl

            if ($VerifyState.Allow -and -not $VerifyState.Deny -and $VerifyState.Unresolved -eq 0) {
                Write-RunLine ('ERFOLGREICH_GESETZT_UND_VERIFIZIERT - ' + $Path) $StatusPath
            } else {
                $VerifyErrors++
                Write-RunLine ('AENDERUNG_GESPEICHERT_ABER_PRUEFUNG_NICHT_EINDEUTIG - ' + $Path + ' - Allow=' + $VerifyState.Allow + '; Deny=' + $VerifyState.Deny + '; Ungeklaert=' + $VerifyState.Unresolved) $StatusPath
            }
        } catch {
            $VerifyErrors++
            Write-RunLine ('AENDERUNG_GESPEICHERT_ABER_VERIFIKATION_FEHLER - ' + $Path + ' - ' + $_.Exception.Message) $StatusPath
        }
    }
}

# --------------------------------------------------
# ABSCHLUSS UND AUSWERTUNG
# --------------------------------------------------

$Summary = @(
    ''
    '================ AUSWERTUNG ================'
    ('Gefundene EXE-Dateien: ' + $Total)
    ('RX bereits vorhanden: ' + $Already)
    ('DENY - uebersprungen: ' + $Denied)
    ('Ungeklaerte Identitaeten - uebersprungen: ' + $Unresolved)
    ('Wuerde RX ergaenzen (nur Pruefmodus): ' + $WouldAdd)
    ('Aenderungen gespeichert: ' + $Changed)
    ('Fehler beim Lesen: ' + $ReadErrors)
    ('Fehler beim Setzen: ' + $SetErrors)
    ('Fehler bei der Verifikation: ' + $VerifyErrors)
    ('Fehler bei der Verzeichnissuche: ' + $EnumerationErrors)
    ('Ende: ' + (Get-Date))
    '============================================'
)
foreach ($Line in $Summary) {
    Write-RunLine $Line $null
}

Write-Host ''
Write-Host 'Version 006 abgeschlossen.'
Write-Host ('Bericht: ' + $ReportPath)
Write-Host ('Protokoll: ' + $LogPath)
Write-Host ''
Write-Host ('Gefundene EXE-Dateien: ' + $Total)
Write-Host ('RX bereits vorhanden: ' + $Already)
Write-Host ('DENY - uebersprungen: ' + $Denied)
Write-Host ('Ungeklaerte Identitaeten: ' + $Unresolved)
Write-Host ('Aenderungen gespeichert: ' + $Changed)
Write-Host ('Fehler Lesen/Setzen/Pruefen: ' + ($ReadErrors + $SetErrors + $VerifyErrors))

if (($ReadErrors + $SetErrors + $VerifyErrors + $EnumerationErrors) -gt 0) {
    exit 2
}
exit 0
