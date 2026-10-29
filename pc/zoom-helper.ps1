# Zmanim display - Zoom helper.
# Runs hidden in the background (started by zmanim-online.bat).
# At the times the gabbai set in the settings app it closes the zmanim screen and joins the Zoom shiur
# (or opens the web site of the broadcast), and when the shiur time is over it returns to the zmanim screen.
# YouTube broadcasts are shown by the zmanim screen itself, so this helper ignores them.
param([string]$Page, [string]$Chrome, [string]$Api)

$ErrorActionPreference = 'SilentlyContinue'
# Windows PowerShell 5.1 does not always use TLS 1.2 by default - Google and YouTube require it
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$mutex = New-Object System.Threading.Mutex($false, 'Local\ZmanimZoomHelper')
if (-not $mutex.WaitOne(0)) { exit }          # already running

$shul = ''
if ($Page -match 'shul=([A-Za-z0-9-]+)') { $shul = $matches[1].ToLower() }
if ($Page -match 'screen=2') { exit }          # second screen (hallway) - shiurim only on the main screen
if (-not $shul -or -not $Api) { exit }
$kioskDir = Join-Path $env:LOCALAPPDATA 'ZmanimKiosk'
$logFile  = Join-Path $env:LOCALAPPDATA 'ZmanimKiosk-zoom.log'
function Log($t) { try { Add-Content -Path $logFile -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $t) -Encoding UTF8 } catch {} }

$sessions = @()
$lastFetch = [datetime]::MinValue
$current = $null      # key of the shiur we are in now
$currentType = ''
$done = @{}           # shiurim already joined (key -> $true)

function Fetch {
  try {
    $u = $Api + '?shul=' + $shul + '&what=zoom&t=' + [DateTime]::Now.Ticks
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 40 -Uri $u
    $txt = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    if ($txt -match '^ERR') { return }
    $list = @()
    foreach ($l in ($txt -split "`n")) {
      $p = $l.Trim() -split '\|'
      if ($p.Count -ge 6 -and $p[0] -eq 'zoom') {
        $type = if ($p.Count -ge 7 -and $p[6]) { $p[6].Trim() } else { 'zoom' }
        $obs = -not ($p.Count -ge 8 -and $p[7].Trim() -eq '0')
        if ($type -ne 'youtube') {
          $list += [pscustomobject]@{ Day = [int]$p[1]; Start = $p[2]; End = $p[3]; Link = $p[4]; Name = $p[5]; Type = $type; Obs = $obs }
        }
      }
    }
    if ($list.Count -ne $script:sessions.Count) { Log ('schedule: ' + $list.Count + ' shiurim') }
    $script:sessions = $list
    $script:lastFetch = Get-Date
  } catch { Log ('fetch failed: ' + $_) }
}

function Minutes($hm) { $a = $hm -split ':'; return [int]$a[0] * 60 + [int]$a[1] }

# Is the shiur on now? Returns the key (date of the start + time), or $null
function ActiveKey($s, $now) {
  $st = Minutes $s.Start
  $en = if ($s.End) { Minutes $s.End } else { ($st + 90) % 1440 }
  $cur = $now.Hour * 60 + $now.Minute
  $dow = [int]$now.DayOfWeek
  if ($en -gt $st) {
    if ($dow -eq $s.Day -and $cur -ge $st -and $cur -lt $en) { return $now.ToString('yyyy-MM-dd') + ' ' + $s.Start }
  } else {   # crosses midnight (for example motzei Shabbat 23:00-00:30)
    if ($dow -eq $s.Day -and $cur -ge $st) { return $now.ToString('yyyy-MM-dd') + ' ' + $s.Start }
    if ((($dow + 6) % 7) -eq $s.Day -and $cur -lt $en) { return $now.AddDays(-1).ToString('yyyy-MM-dd') + ' ' + $s.Start }
  }
  return $null
}

function KioskProcs { Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*ZmanimKiosk*' } }
function Stop-Kiosk { KioskProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force } }
function Start-Kiosk {
  if (KioskProcs) { return }
  Start-Process -FilePath $Chrome -ArgumentList @('--kiosk', ('--user-data-dir="' + $kioskDir + '"'), '--no-first-run',
    '--disable-session-crashed-bubble', '--hide-crash-restore-bubble', '--noerrdialogs', '--disable-translate', '--autoplay-policy=no-user-gesture-required', $Page)
}

function Start-OBS([int]$wait = 0) {   # optional: OBS virtual camera with the synagogue logo
  if (Get-Process obs64) { return }
  foreach ($p in @("$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe", "${env:ProgramFiles(x86)}\obs-studio\bin\64bit\obs64.exe")) {
    if (Test-Path $p) {
      Start-Process -FilePath $p -WorkingDirectory (Split-Path $p) -ArgumentList @('--startvirtualcam', '--minimize-to-tray', '--disable-shutdown-check')
      Log 'OBS started'
      if ($wait -gt 0) { Start-Sleep -Seconds $wait }
      return
    }
  }
}

$liveDir = Join-Path $env:LOCALAPPDATA 'ZmanimLive'
function Open-Web($s) {   # web broadcast: separate full-screen Chrome window
  Start-Process -FilePath $Chrome -ArgumentList @('--kiosk', ('--user-data-dir="' + $liveDir + '"'), '--no-first-run',
    '--disable-session-crashed-bubble', '--hide-crash-restore-bubble', '--noerrdialogs', '--autoplay-policy=no-user-gesture-required', $s.Link)
  Log ('open web ' + $s.Start + ' ' + $s.Link)
}
function Close-Web {
  Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*ZmanimLive*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

function Resolve-ZoomLink($link) {   # short / redirect links (e.g. https://zoom.mydomain.com) -> the real zoom.us/j/... link
  if ($link -match 'zoom\.(us|com)/(j|w)/\d+') { return $link }
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $link -MaximumRedirection 6 -TimeoutSec 20
    $final = ''
    try { $final = $r.BaseResponse.ResponseUri.AbsoluteUri } catch {}
    if (-not $final) { try { $final = $r.BaseResponse.RequestMessage.RequestUri.AbsoluteUri } catch {} }
    if ($final -match 'zoom\.(us|com)/(j|w)/\d+') { return $final }
    if ($r.Content -match '(https://[\w.-]*zoom\.(us|com)/(j|w)/\d+[^\s"''<>]*)') { return ($matches[1] -replace '&amp;', '&') }
  } catch { Log ('resolve failed: ' + $_) }
  return $link
}

function Join-Zoom($s) {
  $name = [uri]::EscapeDataString($s.Name)
  $s.Link = Resolve-ZoomLink $s.Link
  if ($s.Link -match '/(?:j|w)/(\d+)') {
    $conf = $matches[1]
    $pw = ''
    if ($s.Link -match '[?&]pwd=([^&#\s]+)') { $pw = '&pwd=' + $matches[1] }
    $url = 'zoommtg://zoom.us/join?action=join&confno=' + $conf + $pw + '&uname=' + $name
  } else {
    $url = $s.Link   # other link types - opened as is
  }
  Start-Process $url
  Log ('join ' + $s.Start + ' ' + $s.Link)
}

function Leave-Zoom {
  Get-Process Zoom | Stop-Process -Force
  Log 'leave'
}

function ZoomInstalled { return (Test-Path 'Registry::HKEY_CLASSES_ROOT\zoommtg') }
if (-not (ZoomInstalled)) { Log 'Zoom is not installed yet (zoommtg link not registered)' }
Log ('helper started for ' + $shul)

while ($true) {
  if (((Get-Date) - $lastFetch).TotalMinutes -ge 2) { Fetch }
  $now = Get-Date
  $active = $null; $key = $null
  foreach ($s in $sessions) { $k = ActiveKey $s $now; if ($k) { $active = $s; $key = $k } }
  # OBS opens 2 minutes before a Zoom shiur, so the logo camera is ready when Zoom joins
  if (-not $active) {
    foreach ($s in $sessions) { if ($s.Type -eq 'zoom' -and $s.Obs -and (ActiveKey $s $now.AddMinutes(2))) { Start-OBS } }
  }

  if ($active -and -not $done.ContainsKey($key) -and $active.Type -eq 'zoom' -and -not (ZoomInstalled)) {
    if (-not $done.ContainsKey('nozoom ' + $key)) { $done['nozoom ' + $key] = $true; Log 'shiur time, but Zoom is not installed - install Zoom from zoom.us/download' }
  }
  elseif ($active -and -not $done.ContainsKey($key)) {
    $done[$key] = $true
    $script:current = $key
    $script:currentType = $active.Type
    Stop-Kiosk
    if ($active.Type -eq 'web') { Open-Web $active }
    else {
      if ($active.Obs) { Start-OBS 15 }   # normally already open from 2 minutes before
      Join-Zoom $active
    }
  }
  elseif ($current -and $current -ne $key) {   # shiur time is over (or the shiur was deleted)
    $script:current = $null
    if ($currentType -eq 'web') { Close-Web } else { Leave-Zoom }
    Start-Sleep -Seconds 3
    Start-Kiosk
  }
  Start-Sleep -Seconds 20
}
