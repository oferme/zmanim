@echo off
rem ====== Zmanim display for the synagogue computer. Alt+F4 closes it ======
rem The synagogue ID is kept in shul.txt next to this file (the installer writes it).
set "HERE=%~dp0"
set "SHUL="
if exist "%HERE%shul.txt" set /p SHUL=<"%HERE%shul.txt"
if "%SHUL%"=="" (
  set /p SHUL=Synagogue ID from the sheet, column mazhe [for example ohel-moshe]: 
  call echo %%SHUL%%>"%HERE%shul.txt"
)
rem "ohel-moshe 2" = the second screen of the same synagogue
set "SCR="
for /f "tokens=1,2" %%a in ("%SHUL%") do (set "SHUL=%%a" & set "SCR=%%b")
set "PAGE=https://oferme.github.io/zmanim/?shul=%SHUL%"
if "%SCR%"=="2" set "PAGE=%PAGE%&screen=2"
rem Server address (for Zoom shiurim) - do not change:
set "API=https://script.google.com/macros/s/AKfycbzk_q8nwWNNXzr2UYee4WPWa0k6D-ZGegG16g5KFU46jew3l_bKigET6eW7-cLwTVklyg/exec"

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
  echo Google Chrome was not found on this computer. Install it from google.com/chrome and run again.
  pause
  exit /b
)
start "" "%CHROME%" --kiosk --user-data-dir="%LocalAppData%\ZmanimKiosk" --no-first-run --disable-session-crashed-bubble --hide-crash-restore-bubble --noerrdialogs --disable-translate --autoplay-policy=no-user-gesture-required "%PAGE%"

rem Zoom helper: joins the Zoom shiurim at the times set in the settings app (runs hidden, only if the file is here)
if exist "%HERE%zoom-helper.ps1" start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%HERE%zoom-helper.ps1" -Page "%PAGE%" -Chrome "%CHROME%" -Api "%API%"
