# התקנת לוח הזמנים במחשב של בית הכנסת – מעתיק את הקבצים, שומר את מזהה בית הכנסת,
# ויוצר קיצור דרך עם אייקון בשולחן העבודה ובהפעלה האוטומטית (Startup).
$ErrorActionPreference = 'Stop'
$src  = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA 'ZmanimDisplay'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in 'zmanim-online.bat', 'zoom-helper.ps1', 'zmanim.ico') {
  $p = Join-Path $src $f
  if (Test-Path $p) { Copy-Item $p $dest -Force; Unblock-File (Join-Path $dest $f) -ErrorAction SilentlyContinue }
}
Write-Host ''
Write-Host 'Synagogue ID - from the management sheet, column "mazhe" (for example: ohel-moshe)'
Write-Host 'For the SECOND screen of the same synagogue add a space and 2 (for example: ohel-moshe 2)'
$id = ''
while ($id -notmatch '^[a-z0-9-]+( 2)?$') { $id = ((Read-Host 'ID').Trim().ToLower() -replace '\s+', ' ') }
Set-Content -Path (Join-Path $dest 'shul.txt') -Value $id -Encoding ASCII

$shell = New-Object -ComObject WScript.Shell
$name  = 'לוח זמנים.lnk'
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))) {
  $l = $shell.CreateShortcut((Join-Path $dir $name))
  $l.TargetPath = Join-Path $dest 'zmanim-online.bat'
  $l.WorkingDirectory = $dest
  $l.IconLocation = (Join-Path $dest 'zmanim.ico') + ',0'
  $l.WindowStyle = 7
  $l.Description = 'לוח זמנים – בית הכנסת'
  $l.Save()
}
Write-Host ''
Write-Host 'Done. A shortcut was added to the Desktop and to Startup. Starting the screen now...'
Start-Sleep -Seconds 2
Start-Process (Join-Path $dest 'zmanim-online.bat') -WorkingDirectory $dest -WindowStyle Minimized
