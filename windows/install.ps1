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

function Download-File($url,$out,$size,$label){
  Add-Type -AssemblyName System.Net.Http
  $c = New-Object System.Net.Http.HttpClient; $c.Timeout = [TimeSpan]::FromHours(3); $c.DefaultRequestHeaders.UserAgent.ParseAdd("free-coder")
  $resp = $c.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result; $resp.EnsureSuccessStatusCode() | Out-Null
  $total = $resp.Content.Headers.ContentLength; if(-not $total){ $total = $size }
  $in = $resp.Content.ReadAsStreamAsync().Result; $fs = [IO.File]::Create("$out.part")
  $buf = New-Object byte[] 1048576; $got = 0; $t0 = Get-Date; $lastUi = [DateTime]::MinValue; $lastTxt = $t0
  try {
    while(($n = $in.Read($buf, 0, $buf.Length)) -gt 0){
      $fs.Write($buf, 0, $n); $got += $n
      if(((Get-Date) - $lastUi).TotalMilliseconds -ge 500){
        $lastUi = Get-Date; $pct = [int](100 * $got / $total); $el = ((Get-Date) - $t0).TotalSeconds; $mbs = if($el -gt 0){ $got/1MB/$el } else { 0 }
        $eta = if($mbs -gt 0){ [int](($total-$got)/1MB/$mbs) } else { 0 }
        Write-Progress -Activity $label -Status ("{0:N0} of {1:N0} MB, {2:N1} MB/s, about {3} s left" -f ($got/1MB),($total/1MB),$mbs,$eta) -PercentComplete $pct
        if(((Get-Date) - $lastTxt).TotalSeconds -ge 30){ Write-Host ("  ... {0}% ({1:N0} MB)" -f $pct,($got/1MB)); $lastTxt = Get-Date }
      }
    }
  } finally { $fs.Close(); $in.Close() }
  Write-Progress -Activity $label -Completed
  if($total -and $got -ne $total){ throw "incomplete download ($got of $total bytes)" }
  Move-Item "$out.part" $out -Force
}

if((Get-CimInstance Win32_OperatingSystem).BuildNumber -lt 17763){ Fail "Windows 10 (1809) or newer is required." }

# 1. OmniRoute: official Windows installer from its GitHub release
$OmniExe = Join-Path $env:LOCALAPPDATA "Programs\OmniRoute\OmniRoute.exe"
if(Test-Path $OmniExe){ Step "OmniRoute already installed" } else {
  Step "Downloading OmniRoute (about 470 MB)"
  $rel = Invoke-RestMethod "https://api.github.com/repos/cheaper-inference/OmniRoute/releases/latest" -Headers @{ "User-Agent" = "free-coder" }
  $asset = $rel.assets | Where-Object { $_.name -match '^OmniRoute\.Setup\..*\.exe$' } | Select-Object -First 1
  if(-not $asset){ Fail "Could not find the OmniRoute Windows installer in the latest release." }
  $dl = Join-Path $Work $asset.name
  if((Test-Path $dl) -and ((Get-Item $dl).Length -eq $asset.size)){ Write-Host "Installer already downloaded." } else {
    for($i=1; $i -le 3; $i++){ try { Download-File $asset.browser_download_url $dl $asset.size "Downloading OmniRoute"; break } catch { if($i -eq 3){ Fail "Download failed: $($_.Exception.Message)" }; Write-Host "Download interrupted, retrying..."; Start-Sleep 5 } }
  }
  Step "Installing OmniRoute $($rel.tag_name). This unpacks about 60,000 files and can take 5-15 minutes; antivirus scanning slows it down."
  $InstDir = Join-Path $env:LOCALAPPDATA "Programs\OmniRoute"
  $p = Start-Process $dl -ArgumentList "/S" -PassThru
  $expected = 60000; $t0 = Get-Date; $last = $t0
  while(-not $p.HasExited){
    $n = 0; if(Test-Path $InstDir){ try { $n = ([IO.Directory]::EnumerateFiles($InstDir, "*", [IO.SearchOption]::AllDirectories) | Measure-Object).Count } catch {} }
    $pct = [Math]::Min(99, [int](100 * $n / $expected)); $el = [int]((Get-Date) - $t0).TotalSeconds
    Write-Progress -Activity "Installing OmniRoute" -Status "$n files unpacked ($pct%), $([int]($el/60)) min $($el % 60) s elapsed" -PercentComplete $pct
    if(((Get-Date) - $last).TotalSeconds -ge 30){ Write-Host ("  ... {0} files, {1}% ({2} min elapsed)" -f $n,$pct,[int]($el/60)); $last = Get-Date }
    Start-Sleep 2
  }
  Write-Progress -Activity "Installing OmniRoute" -Completed
  if($p.ExitCode -ne 0 -or -not (Test-Path $OmniExe)){ Fail "OmniRoute installer exited with code $($p.ExitCode)." }
  Write-Host "OmniRoute installed." -ForegroundColor Green
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
