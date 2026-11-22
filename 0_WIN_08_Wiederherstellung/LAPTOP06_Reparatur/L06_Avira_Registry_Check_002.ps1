# L06_Avira_Registry_Check_002.ps1
# Read-only Avira registry inventory for LAPTOP06 (Windows 32-bit).
# Output is created relative to this script, so the active drive letter
# (currently X:) is taken from the script location automatically.
# No registry keys, services, drivers, or security settings are modified.

$ErrorActionPreference = 'Stop'
$OutDir = Join-Path $PSScriptRoot 'ACL_Sicherungen\TXT\Avira_Registry_Check_L06'

if (-not (Test-Path -LiteralPath $PSScriptRoot -PathType Container)) {
    throw ('Script directory not found: {0}' -f $PSScriptRoot)
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Save-RegSearch {
    param(
        [string]$Key,
        [string]$Search,
        [string]$FileName
    )

    $Path = Join-Path $OutDir $FileName
    $Header = 'REG QUERY: {0} /s /f "{1}"' -f $Key, $Search
    Set-Content -LiteralPath $Path -Value $Header -Encoding UTF8

    $Output = & reg.exe query $Key /s /f $Search 2>&1
    $ExitCode = $LASTEXITCODE

    if ($null -ne $Output) {
        $Output | Out-String -Width 4096 | Add-Content -LiteralPath $Path -Encoding UTF8
    }

    Add-Content -LiteralPath $Path -Value ('REG_EXITCODE={0}' -f $ExitCode) -Encoding UTF8
}

function Save-RegKey {
    param(
        [string]$Key,
        [string]$FileName
    )

    $Path = Join-Path $OutDir $FileName
    Set-Content -LiteralPath $Path -Value ('REG QUERY: {0} /s' -f $Key) -Encoding UTF8

    $Output = & reg.exe query $Key /s 2>&1
    $ExitCode = $LASTEXITCODE

    if ($null -ne $Output) {
        $Output | Out-String -Width 4096 | Add-Content -LiteralPath $Path -Encoding UTF8
    }

    Add-Content -LiteralPath $Path -Value ('REG_EXITCODE={0}' -f $ExitCode) -Encoding UTF8
}

# 01 – Uninstall entries containing Avira (native 32-bit registry view)
Save-RegSearch 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' 'Avira' '01_Uninstall_Avira.txt'

# 02 – Empty comparison placeholder; L06 runs 32-bit Windows
Set-Content -LiteralPath (Join-Path $OutDir '02_Uninstall_Avira_32bit.txt') -Value '' -Encoding UTF8

# 03 – Avira services and related service/driver registry entries
Save-RegSearch 'HKLM\SYSTEM\CurrentControlSet\Services' 'Avira' '03_Services_Avira.txt'

# 04 – Avira software registry branch
Save-RegKey 'HKLM\SOFTWARE\Avira' '04_Avira_Software.txt'

# 05 – Empty comparison placeholder; no separate WOW6432Node view on 32-bit Windows
Set-Content -LiteralPath (Join-Path $OutDir '05_Avira_Software_32bit.txt') -Value '' -Encoding UTF8

# 06 – Services/entries containing Speedup
Save-RegSearch 'HKLM\SYSTEM\CurrentControlSet\Services' 'Speedup' '06_Services_Speedup.txt'

$Summary = @(
    'LAPTOP06 Avira registry inventory'
    ('Completed: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    ('Output directory: {0}' -f $OutDir)
    'Registry access was read-only.'
    'Windows architecture: 32-bit'
)
Set-Content -LiteralPath (Join-Path $OutDir '00_Erfassungsstatus.txt') -Value $Summary -Encoding UTF8

Write-Host ''
Write-Host 'Avira registry inventory completed.'
Write-Host ('Output directory: {0}' -f $OutDir)
Write-Host 'Status file: 00_Erfassungsstatus.txt'
