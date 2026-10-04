@echo off
cd /d "%~dp0"
echo Starting Zen Master Usage Warden...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ZenMasterUsageWarden.ps1"
echo.
echo Zen Master stopped or failed to start.
echo If there is an error above, take a screenshot and send it to Sol.
pause
