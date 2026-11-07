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

# 2. start OmniRoute as the logged-in user and make it start at every login
$me = (whoami)
$task = "FreeCoder-OmniRoute"
Register-ScheduledTask -TaskName $task -Force `
  -Action (New-ScheduledTaskAction -Execute $OmniExe) `
  -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $me) `
  -Principal (New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive) | Out-Null

if(-not (Up)){ Start-ScheduledTask -TaskName $task }
Write-Host "Waiting for OmniRoute to start..."
$t=0; while(-not (Up) -and $t -lt 180){ Start-Sleep 3; $t+=3 }
if(-not (Up)){ Fail "OmniRoute did not start within 3 minutes." }

$sess = Login
if(-not $sess){
  # password not set yet: set it via OmniRoute's own env file, restart once, log in again
  Get-Process | Where-Object Name -match "^OmniRoute" | Stop-Process -Force; Start-Sleep 3
  $env_ = Join-Path $OmniDir "server.env"
  $lines = @(); if(Test-Path $env_){ $lines = Get-Content $env_ | Where-Object { $_ -notmatch "^INITIAL_PASSWORD=" } }
  ($lines + "INITIAL_PASSWORD=$pw") | Set-Content $env_ -Encoding ascii
  Remove-Item (Join-Path $OmniDir "storage.sqlite*") -Force -ErrorAction SilentlyContinue   # fresh install only: no data to lose yet
  Start-ScheduledTask -TaskName $task
  $t=0; while(-not (Up) -and $t -lt 180){ Start-Sleep 3; $t+=3 }
  $sess = Login
  if(-not $sess){ Fail "Could not sign in to OmniRoute. If you set your own password already, delete $Secret and re-run." }
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

Write-Host "`nDone. OmniRoute is running and Hermes is connected." -ForegroundColor Green
Write-Host "Next: add free providers at $Base (see README). Login details: $Secret"
