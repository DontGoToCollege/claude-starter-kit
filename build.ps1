<#
Archives this version of the kit as Versions\Archive\claude-starter-kit-<version>.zip, before it's released.

    .\build.ps1

The version is $KitVersion in Setup.ps1: raise it for each release. A version that's already archived is
refused, so no build is ever overwritten. Then commit, push, and release it with Setup.cmd attached:
    gh release create v<version> Setup.cmd --title "Starter kit <version>"
Setup.cmd always uses the newest release, so only release what's ready. A friend gets the kit once, when Setup.cmd
first runs: after that their copies are their own, and nothing in a later release reaches them.
#>
$ErrorActionPreference = 'Stop'
$v = [regex]::Match([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Setup.ps1')), "\`$KitVersion = '(\d+\.\d+\.\d+)'").Groups[1].Value
if (-not $v) { throw "No `$KitVersion = 'x.y.z' line in Setup.ps1." }
$zip = Join-Path $PSScriptRoot "Versions\Archive\claude-starter-kit-$v.zip"
if (Test-Path $zip) { throw "Version $v is already archived. Raise `$KitVersion in Setup.ps1 first." }
New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
$files = 'Setup.cmd', 'Setup.ps1', 'README.md', 'LICENSE', 'template' |
    ForEach-Object { Join-Path $PSScriptRoot $_ }
Compress-Archive -Path $files -DestinationPath $zip
Write-Host "Archived $zip"
