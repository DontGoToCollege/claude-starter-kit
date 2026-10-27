@echo off
rem Double-click to set up Claude on this computer, or bring it up to date. Keep this next to Get-ClaudeRules.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-ClaudeRules.ps1" %*
pause
