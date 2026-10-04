@echo off
cd /d "%~dp0"
echo ============================================
echo ZEN MASTER v10 - CODEX AUTO DIAGNOSTICS
echo ============================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$p=$null; try{$p=(Get-Command codex.exe -ErrorAction Stop).Source}catch{}; if(-not $p -and $env:CODEX_CLI_PATH -and (Test-Path $env:CODEX_CLI_PATH)){$p=$env:CODEX_CLI_PATH}; if(-not $p){$r=Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'; if(Test-Path $r){$p=(Get-ChildItem $r -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First 1).FullName}}; Write-Host 'Codex executable:' $p; if($p){Write-Host ''; Write-Host 'Version:'; ^& $p --version; Write-Host ''; Write-Host 'Location:' $p}else{Write-Host 'No runnable codex.exe was found.'}"
echo.
echo Take a screenshot of this window if Zen Master still cannot sync.
pause
