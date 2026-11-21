#requires -Version 3.0
# L04 EXE-Reparatur 08 - reine ACL-Diagnose, keine Rechteaenderungen
$ErrorActionPreference = 'Stop'
$Base=$PSScriptRoot
$Roots=@('C:\Program Files','C:\Program Files (x86)')
$AclBase=Join-Path $Base 'ACL_Sicherungen\ACL'
$LogDir=Join-Path $Base 'ACL_Sicherungen\LOG'
$Exe=Join-Path $env:SystemRoot 'System32\icacls.exe'
$admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Bitte als Administrator starten.'}
foreach($d in @($AclBase,$LogDir)){if(-not(Test-Path -LiteralPath $d -PathType Container)){throw ('Verzeichnis fehlt: '+$d)}}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$RunDir=Join-Path $AclBase ('ProgramFiles_'+$stamp)
New-Item -ItemType Directory -Path $RunDir -ErrorAction Stop|Out-Null
$Log=Join-Path $LogDir ('Diagnose_V08_'+$stamp+'.log')
$Report=Join-Path $Base ('L04_EXE_Reparatur_08-'+$stamp+'.txt')
New-Item -ItemType File -Path $Log,$Report -ErrorAction Stop|Out-Null
function LogLine([string]$s){Add-Content -LiteralPath $Log -Value $s -Encoding UTF8;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function RunSegment([string]$target,[string]$file,[string]$label,[bool]$recursive){
 $out=$file+'.stdout.tmp';$err=$file+'.stderr.tmp';$a=@($target,'/save',$file);if($recursive){$a+='/T'}
 LogLine '';LogLine ('SEGMENT: '+$label);LogLine ('ZIEL: '+$target)
 $rc=-999;$exception=''
 try{& $Exe @a 1> $out 2> $err;$rc=$LASTEXITCODE}catch{$exception=$_.Exception.Message}
 $o='';$e='';if(Test-Path -LiteralPath $out){$o=[IO.File]::ReadAllText($out)};if(Test-Path -LiteralPath $err){$e=[IO.File]::ReadAllText($err)}
 $bytes=0;if(Test-Path -LiteralPath $file){$bytes=(Get-Item -LiteralPath $file).Length}
 $bad=[regex]::IsMatch(($o+[Environment]::NewLine+$e+[Environment]::NewLine+$exception),'(?im)(Zugriff verweigert|Access is denied|error:|Fehler:)')
 LogLine ('ExitCode='+$rc+'; Bytes='+$bytes+'; Fehlertext='+$bad)
 if($exception){LogLine ('PROZESSFEHLER: '+$exception)};if($o.Trim()){LogLine ('STDOUT: '+$o.Trim())};if($e.Trim()){LogLine ('STDERR: '+$e.Trim())}
 $ok=($rc -eq 0 -and $bytes -gt 0 -and -not $bad -and -not $exception)
 if($ok){LogLine 'ERGEBNIS: OK'}else{LogLine 'ERGEBNIS: FEHLER'}
 return $ok
}
LogLine 'L04 EXE-Reparatur 08 - segmentierte ACL-Diagnose'
LogLine ('Start: '+(Get-Date))
LogLine 'SICHERHEIT: Keine Berechtigungen werden geaendert.'
$allOk=$true;$count=0;$failed=0
foreach($root in $Roots){
 if(-not(Test-Path -LiteralPath $root -PathType Container)){LogLine ('NICHT VORHANDEN: '+$root);continue}
 $tag=if($root -like '*x86*'){'ProgramFiles_x86'}else{'ProgramFiles'}
 $count++;$f=Join-Path $RunDir ($tag+'_ROOT.acl')
 if(-not(RunSegment $root $f ($tag+'_ROOT') $false)){$allOk=$false;$failed++}
 $entries=@(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop|Sort-Object Name)
 LogLine ('DIREKTE EINTRAEGE '+$root+': '+$entries.Count)
 $i=0
 foreach($entry in $entries){
  $i++;$kind=if($entry.PSIsContainer){'DIR'}else{'FILE'}
  $rp=(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0)
  $safe=($entry.Name -replace '[^A-Za-z0-9._-]','_')
  $label=('{0}_{1:D4}_{2}_{3}' -f $tag,$i,$kind,$safe)
  $f=Join-Path $RunDir ($label+'.acl');$count++
  LogLine ('TYP='+$kind+'; REPARSEPOINT='+$rp)
  if(-not(RunSegment $entry.FullName $f $label $true)){$allOk=$false;$failed++}
 }
}
LogLine ''
LogLine ('SEGMENTE='+$count+'; FEHLER='+$failed)
LogLine ('Ende: '+(Get-Date))
if($allOk -and $count -gt 0){LogLine 'GESAMTERGEBNIS: BASISPRUEFUNGEN BESTANDEN; RESTORE-TAUGLICHKEIT NICHT VALIDiert.';Write-Host ('OK. Bericht: '+$Report);Write-Host ('ACL-Ordner: '+$RunDir);exit 0}
LogLine 'GESAMTERGEBNIS: FEHLER; KEINE RECHTE GEAENDERT.'
Write-Host ('FEHLER. Bericht: '+$Report);Write-Host ('ACL-Ordner: '+$RunDir);exit 2
