<#
 Connects the official OmniRoute app to the official Hermes agent. Safe to re-run.
 Creates: OmniRoute admin password + API key, Hermes config (OmniRoute as default model), login autostart.
#>
param([string]$Model = "auto/best-coding")
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Base    = "http://localhost:20128"
$OmniExe = Join-Path $env:LOCALAPPDATA "Programs\OmniRoute\OmniRoute.exe"
$OmniDir = Join-Path $env:APPDATA "OmniRoute"
$Hermes  = Join-Path $env:LOCALAPPDATA "hermes"
$Secret  = Join-Path $env:LOCALAPPDATA "free-coder\login.txt"
New-Item -ItemType Directory -Force (Split-Path $Secret) | Out-Null

function Fail($m){ Write-Host "`nERROR: $m" -ForegroundColor Red; $m | Out-File (Join-Path (Split-Path $Secret) "last-error.txt"); exit 1 }
if(-not (Test-Path $OmniExe)){ Fail "OmniRoute is not installed ($OmniExe)." }
if(-not (Test-Path "$Hermes\bin\hermes.exe")){ Fail "Hermes is not installed ($Hermes)." }

# 1. admin password (only set before OmniRoute's first start; kept in login.txt)
if(Test-Path $Secret){ $pw = ((Get-Content $Secret) | Where-Object { $_ -like "password:*" }) -replace "^password:\s*","" }
if(-not $pw){ $pw = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_}) }

function Up { try { Invoke-WebRequest -UseBasicParsing "$Base/api/init" -TimeoutSec 4 | Out-Null; $true } catch { $false } }
function Login {
  $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  try { Invoke-WebRequest -UseBasicParsing "$Base/api/auth/login" -Method Post -ContentType "application/json" -Body (@{password=$pw}|ConvertTo-Json) -WebSession $s | Out-Null; $s } catch { $null }
}


function Wait-Omni([int]$maxSec = 600){
  $t = 0; $nextMsg = 0
  while($t -lt $maxSec){
    if(Up){ return $true }
    $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^OmniRoute" })
    if($procs.Count -eq 0 -and $t -ge 20 -and ($t % 60) -eq 20){
      Write-Host "  OmniRoute is not running; starting it directly..."
      Start-Process $OmniExe -ArgumentList "--hidden"
    }
    if($t -ge $nextMsg){
      $ports = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $procs.Id -contains $_.OwningProcess } | ForEach-Object { $_.LocalPort } | Sort-Object -Unique) -join ","
      Write-Host ("  ... {0}s: {1} OmniRoute process(es), listening on [{2}]. First start can take several minutes." -f $t, $procs.Count, $ports)
      $nextMsg += 15
    }
    Write-Progress -Activity "Waiting for OmniRoute to start" -Status "$t s elapsed (up to $([int]($maxSec/60)) min on a first start)" -PercentComplete ([Math]::Min(99, [int](100*$t/$maxSec)))
    Start-Sleep 3; $t += 3
  }
  Write-Progress -Activity "Waiting for OmniRoute to start" -Completed
  return $false
}
function Omni-Diag {
  $logf = Join-Path $OmniDir "logs\application\app.log"
  Write-Host "`n--- diagnostics ---"
  Write-Host ("Processes: " + ((Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^OmniRoute" } | ForEach-Object { $_.Id }) -join ","))
  Write-Host ("Port 20128 owner: " + ((Get-NetTCPConnection -LocalPort 20128 -ErrorAction SilentlyContinue | ForEach-Object { "$($_.State):pid$($_.OwningProcess)" }) -join ","))
  Write-Host ("Task state: " + (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue).State)
  if(Test-Path $logf){ Write-Host "Last log lines ($logf):"; Get-Content $logf -Tail 8 | ForEach-Object { Write-Host "  $_" } } else { Write-Host "No OmniRoute log yet at $logf" }
}

# 2. start OmniRoute as the logged-in user and make it start at every login
$me = (whoami)
$task = "FreeCoder-OmniRoute"
Register-ScheduledTask -TaskName $task -Force `
  -Action (New-ScheduledTaskAction -Execute $OmniExe -Argument "--hidden") `
  -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $me) `
  -Principal (New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive) | Out-Null

if(-not (Up)){ Start-ScheduledTask -TaskName $task }
Write-Host "Waiting for OmniRoute to start..."
if(-not (Wait-Omni 600)){ Omni-Diag; Fail "OmniRoute did not start within 10 minutes. The diagnostics above are saved in install.log. Try opening OmniRoute from the Start menu, then run install.cmd again." }

$sess = Login
if(-not $sess){
  # password not set yet: set it via OmniRoute's own env file, restart once, log in again
  Write-Host "Could not sign in with the saved password; resetting OmniRoute's login (old data is kept as a backup)."
  for($i=0; $i -lt 5; $i++){ Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^OmniRoute" } | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
  $env_ = Join-Path $OmniDir "server.env"
  $lines = @(); if(Test-Path $env_){ $lines = Get-Content $env_ | Where-Object { $_ -notmatch "^INITIAL_PASSWORD=" } }
  ($lines + "INITIAL_PASSWORD=$pw") | Set-Content $env_ -Encoding ascii
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  foreach($f in Get-ChildItem $OmniDir -Filter "storage.sqlite*" -ErrorAction SilentlyContinue){
    try { Move-Item $f.FullName "$($f.FullName).bak-$stamp" -Force -ErrorAction Stop } catch { Fail "Could not reset OmniRoute: $($f.Name) is locked. Close OmniRoute (tray or Task Manager), then run install.cmd again." }
  }
  Start-ScheduledTask -TaskName $task
  if(-not (Wait-Omni 600)){ Omni-Diag; Fail "OmniRoute did not restart within 10 minutes." }
  $sess = Login
  if(-not $sess){ Fail "Could not sign in to OmniRoute even after a reset. Please send install.log and last-error.txt from $env:LOCALAPPDATA\free-coder." }
}

# 3. API key for Hermes (reuse the one on disk if present)
$key = $null
if(Test-Path $Secret){ $key = ((Get-Content $Secret) | Where-Object { $_ -like "apikey:*" }) -replace "^apikey:\s*","" }
if($key){ try { Invoke-WebRequest -UseBasicParsing "$Base/v1/models" -Headers @{Authorization="Bearer $key"} -TimeoutSec 20 | Out-Null } catch { $key = $null } }
if(-not $key){
  $r = Invoke-WebRequest -UseBasicParsing "$Base/api/keys" -Method Post -ContentType "application/json" -Body '{"name":"hermes"}' -WebSession $sess
  $key = ($r.Content | ConvertFrom-Json).key
  if(-not $key){ Fail "OmniRoute did not return an API key." }
}
@("OmniRoute dashboard: $Base", "password: $pw", "apikey: $key") | Set-Content $Secret -Encoding ascii

# 4. point Hermes at OmniRoute
$hx = "$Hermes\bin\hermes.exe"
& $hx config set model.provider custom | Out-Null
& $hx config set model.base_url "$Base/v1" | Out-Null
& $hx config set model.default $Model | Out-Null
$envf = "$Hermes\.env"
$keep = @(); if(Test-Path $envf){ $keep = Get-Content $envf | Where-Object { $_ -notmatch "^(OPENAI_API_KEY|OMNIROUTE_API_KEY)=" } }
($keep + "OPENAI_API_KEY=$key" + "OMNIROUTE_API_KEY=$key") | Set-Content $envf -Encoding ascii

# 5. persona: honest, fact-checking assistant (not a yes-man). Keep the original as a backup once.
$soulSrc = Join-Path $PSScriptRoot "SOUL.md"
$soulDst = Join-Path $Hermes "SOUL.md"
if(Test-Path $soulSrc){
  if((Test-Path $soulDst) -and -not (Select-String -Path $soulDst -SimpleMatch "free-coder persona" -Quiet) -and -not (Test-Path "$soulDst.orig")){ Copy-Item $soulDst "$soulDst.orig" }
  Copy-Item $soulSrc $soulDst -Force
}

Write-Host "`nDone. OmniRoute is running and Hermes is connected." -ForegroundColor Green
Write-Host "Next: add free providers at $Base (see README). Login details: $Secret"
