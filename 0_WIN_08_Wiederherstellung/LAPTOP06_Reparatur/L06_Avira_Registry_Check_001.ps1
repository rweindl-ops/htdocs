# L06_Avira_Registry_Check_001.ps1
# Sechs read-only Avira-Registry-Abfragen analog zu den L04-Ausgaben.
# Keine Aenderungen an Diensten, Starttypen, Treibern oder Sicherheitsfunktionen.

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$OutDir = Join-Path $Root 'ACL_Sicherungen\TXT\Avira_Registry_Check_L06'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Save-RegQuery {
    param([string]$Key, [string]$Search, [string]$FileName)
    $Path = Join-Path $OutDir $FileName
    ('Abfrage: reg.exe query {0} /s /f {1}' -f $Key, $Search) |
        Set-Content -LiteralPath $Path -Encoding UTF8
    & reg.exe query $Key /s /f $Search 2>&1 |
        Out-String -Width 4096 |
        Add-Content -LiteralPath $Path -Encoding UTF8
    if ($LASTEXITCODE -ne 0) {
        ('REG_EXITCODE={0}' -f $LASTEXITCODE) |
            Add-Content -LiteralPath $Path -Encoding UTF8
    }
}

# 01 – 64-Bit-Deinstallationsinformationen
Save-RegQuery 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' 'Avira' '01_Uninstall_Avira.txt'

# 02 – 32-Bit-Deinstallationsinformationen
Save-RegQuery 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' 'Avira' '02_Uninstall_Avira_32bit.txt'

# 03 – Avira-Dienste und zugehoerige Service-/Treiber-Registryeintraege
Save-RegQuery 'HKLM\SYSTEM\CurrentControlSet\Services' 'Avira' '03_Services_Avira.txt'

# 04 – Vollstaendiger Avira-Software-Registryzweig
$File04 = Join-Path $OutDir '04_Avira_Software.txt'
'Abfrage: reg.exe query HKLM\SOFTWARE\Avira /s' |
    Set-Content -LiteralPath $File04 -Encoding UTF8
& reg.exe query 'HKLM\SOFTWARE\Avira' /s 2>&1 |
    Out-String -Width 4096 |
    Add-Content -LiteralPath $File04 -Encoding UTF8
if ($LASTEXITCODE -ne 0) {
    ('REG_EXITCODE={0}' -f $LASTEXITCODE) |
        Add-Content -LiteralPath $File04 -Encoding UTF8
}

# 05 – 32-Bit-Avira-Software-Registryzweig
$File05 = Join-Path $OutDir '05_Avira_Software_32bit.txt'
'Abfrage: reg.exe query HKLM\SOFTWARE\WOW6432Node\Avira /s' |
    Set-Content -LiteralPath $File05 -Encoding UTF8
& reg.exe query 'HKLM\SOFTWARE\WOW6432Node\Avira' /s 2>&1 |
    Out-String -Width 4096 |
    Add-Content -LiteralPath $File05 -Encoding UTF8
if ($LASTEXITCODE -ne 0) {
    ('REG_EXITCODE={0}' -f $LASTEXITCODE) |
        Add-Content -LiteralPath $File05 -Encoding UTF8
}

# 06 – Dienste/Eintraege mit Bezug zu System Speedup
Save-RegQuery 'HKLM\SYSTEM\CurrentControlSet\Services' 'Speedup' '06_Services_Speedup.txt'

'Erfassung abgeschlossen: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') |
    Add-Content -LiteralPath (Join-Path $OutDir '01_Uninstall_Avira.txt') -Encoding UTF8

Write-Host ''
Write-Host 'Avira-Erfassung fuer LAPTOP06 abgeschlossen.'
Write-Host ('Ausgaben: {0}' -f $OutDir)
Write-Host 'Es wurden ausschliesslich Registry-Abfragen ausgefuehrt.'
