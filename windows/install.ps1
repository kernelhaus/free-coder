<#
 free-coder installer: official OmniRoute app + official Hermes Agent, connected to each other.
 Run:  powershell -ExecutionPolicy Bypass -File install.ps1
 Both products update themselves afterwards. Needs internet (about 0.6 GB), no admin rights.
#>
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Work = Join-Path $env:LOCALAPPDATA "free-coder"
New-Item -ItemType Directory -Force $Work | Out-Null
Start-Transcript -Path (Join-Path $Work "install.log") -Append | Out-Null
function Step($m){ Write-Host "`n== $m" -ForegroundColor Cyan }
function Fail($m){ Write-Host "`nERROR: $m" -ForegroundColor Red; Write-Host "Send $Work\install.log to your support person."; Stop-Transcript | Out-Null; exit 1 }

if((Get-CimInstance Win32_OperatingSystem).BuildNumber -lt 17763){ Fail "Windows 10 (1809) or newer is required." }

# 1. OmniRoute: official Windows installer from its GitHub release
$OmniExe = Join-Path $env:LOCALAPPDATA "Programs\OmniRoute\OmniRoute.exe"
if(Test-Path $OmniExe){ Step "OmniRoute already installed" } else {
  Step "Downloading OmniRoute (about 470 MB)"
  $rel = Invoke-RestMethod "https://api.github.com/repos/cheaper-inference/OmniRoute/releases/latest" -Headers @{ "User-Agent" = "free-coder" }
  $asset = $rel.assets | Where-Object { $_.name -match '^OmniRoute\.Setup\..*\.exe$' } | Select-Object -First 1
  if(-not $asset){ Fail "Could not find the OmniRoute Windows installer in the latest release." }
  $dl = Join-Path $Work $asset.name
  for($i=1; $i -le 3; $i++){ try { Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $dl; break } catch { if($i -eq 3){ Fail "Download failed: $($_.Exception.Message)" }; Start-Sleep 5 } }
  Step "Installing OmniRoute $($rel.tag_name) (a few minutes)"
  $p = Start-Process $dl -ArgumentList "/S" -PassThru -Wait
  if($p.ExitCode -ne 0 -or -not (Test-Path $OmniExe)){ Fail "OmniRoute installer exited with code $($p.ExitCode)." }
}

# 2. Hermes Agent: official installer, stable channel
$HermesExe = Join-Path $env:LOCALAPPDATA "hermes\bin\hermes.exe"
if(Test-Path $HermesExe){ Step "Hermes already installed" } else {
  Step "Installing Hermes Agent (stable)"
  $s = Invoke-RestMethod "https://hermes-agent.nousresearch.com/install.ps1"
  & ([scriptblock]::Create($s)) -NonInteractive -Channel stable
  if(-not (Test-Path $HermesExe)){ Fail "Hermes did not install." }
}

# 3. Connect them
Step "Connecting Hermes to OmniRoute"
& (Join-Path $PSScriptRoot "connect.ps1")
if($LASTEXITCODE -ne 0){ Fail "Connecting failed. See above." }

# 4. Desktop shortcuts
$sh = New-Object -ComObject WScript.Shell
$desk = [Environment]::GetFolderPath("Desktop")
$lnk = $sh.CreateShortcut("$desk\Free Coder (Hermes).lnk")
$lnk.TargetPath = "powershell.exe"; $lnk.Arguments = "-NoExit -Command `"& '$HermesExe' desktop`""; $lnk.Save()
$lnk2 = $sh.CreateShortcut("$desk\Free Coder - add providers.lnk")
$lnk2.TargetPath = "http://localhost:20128"; $lnk2.Save()

Step "Finished"
Write-Host "1. Open 'Free Coder - add providers' and sign up for the free providers listed in README.md."
Write-Host "2. Open 'Free Coder (Hermes)' and ask for help."
Write-Host "Login details for the dashboard are in $Work\login.txt"
Stop-Transcript | Out-Null
