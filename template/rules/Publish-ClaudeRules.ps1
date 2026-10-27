<#
Back up this computer's Claude rules (~\.claude\CLAUDE.md) and settings (~\.claude\claude-rules\settings.json) to GitHub as a new version.

    .\Publish-ClaudeRules.ps1

Run it from this repo's folder. Raise the "Rules version: x.y.z" line in CLAUDE.md first: a version that's already
archived is refused, so no version is ever lost. Copies both files into this repo and the rules into
Versions\Archive\CLAUDE-<version>.md, commits, pushes, and makes a GitHub Release.
#>
$ErrorActionPreference = 'Stop'
$live = Join-Path $HOME '.claude\CLAUDE.md'
$liveSettings = Join-Path $HOME '.claude\claude-rules\settings.json'
$m = [regex]::Match([IO.File]::ReadAllText($live), 'Rules version: (\d+\.\d+\.\d+)')
if (-not $m.Success) { throw "No 'Rules version: x.y.z' line in $live." }
$v = $m.Groups[1].Value
$archive = Join-Path $PSScriptRoot "Versions\Archive\CLAUDE-$v.md"
if (Test-Path $archive) { throw "Version $v is already archived. Raise the 'Rules version' line in $live, then publish again." }

git -C $PSScriptRoot pull --ff-only -q
if ($LASTEXITCODE -ne 0) { throw "Couldn't update from GitHub first. Nothing was published." }
Copy-Item $live $archive
Copy-Item $live (Join-Path $PSScriptRoot 'CLAUDE.md')
if (Test-Path $liveSettings) { Copy-Item $liveSettings (Join-Path $PSScriptRoot 'settings.json') }
git -C $PSScriptRoot add CLAUDE.md settings.json $archive
git -C $PSScriptRoot commit -q -m "Rules $v"
git -C $PSScriptRoot push -q
if ($LASTEXITCODE -ne 0) { throw "Push failed. The commit is saved locally; push it once GitHub is reachable." }
Push-Location $PSScriptRoot
try { gh release create "v$v" $archive Get-ClaudeRules.ps1 Get-ClaudeRules.cmd --title "Rules $v" --notes "Rules version $v. On a new computer, download Get-ClaudeRules.cmd and Get-ClaudeRules.ps1 into the same folder, then double-click Get-ClaudeRules.cmd." }
finally { Pop-Location }
Write-Host "Published rules $v."
