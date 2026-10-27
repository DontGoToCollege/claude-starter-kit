<#
Archives this version of the kit as Versions\Archive\claude-starter-kit-<version>.zip, before it's released.

    .\build.ps1

The version is $KitVersion in Get-ClaudeRules.ps1: raise it for each release. A version that's already archived is
refused, so no build is ever overwritten. Then commit, push, and release it with Setup.cmd attached:
    gh release create v<version> Setup.cmd --title "Starter kit <version>"
Friends' computers pick up only released versions of the scripts. The band updates when band\.claude-plugin\plugin.json's
version is raised and pushed, so raise that only in a release too.
#>
$ErrorActionPreference = 'Stop'
$v = [regex]::Match([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Get-ClaudeRules.ps1')), "\`$KitVersion = '(\d+\.\d+\.\d+)'").Groups[1].Value
if (-not $v) { throw "No `$KitVersion = 'x.y.z' line in Get-ClaudeRules.ps1." }
$zip = Join-Path $PSScriptRoot "Versions\Archive\claude-starter-kit-$v.zip"
if (Test-Path $zip) { throw "Version $v is already archived. Raise `$KitVersion in Get-ClaudeRules.ps1 first." }
New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
$files = 'Setup.cmd', 'Get-ClaudeRules.ps1', 'Publish-ClaudeRules.ps1', 'README.md', 'LICENSE', '.claude-plugin', 'template', 'band' |
    ForEach-Object { Join-Path $PSScriptRoot $_ }
Compress-Archive -Path $files -DestinationPath $zip
Write-Host "Archived $zip"
