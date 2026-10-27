@echo off
rem Claude starter kit: double-click this file to set up Claude on this computer.
rem It downloads the newest setup script from the starter kit on GitHub and runs it. Running it again is always safe.
set "KIT=DontGoToCollege/claude-starter-kit"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $tag = (Invoke-RestMethod 'https://api.github.com/repos/%KIT%/releases/latest').tag_name; $ps = Join-Path $env:TEMP 'claude-starter-kit-setup.ps1'; Invoke-WebRequest -UseBasicParsing ('https://raw.githubusercontent.com/%KIT%/' + $tag + '/Get-ClaudeRules.ps1') -OutFile $ps } catch { Write-Host ('Could not download the setup from GitHub: ' + $_.Exception.Message) -ForegroundColor Red; Write-Host 'Check the internet connection, then double-click Setup.cmd again.'; exit 1 }; & $ps %*"
pause
