<#
Back up this computer's Claude rules (~\.claude\CLAUDE.md) and settings to your claude-rules repo as a new version.

    ~\.claude\claude-rules\Publish-ClaudeRules.ps1

Raise the "Rules version: x.y.z" line in CLAUDE.md first: a version that's already archived is refused, so no version is ever lost.
Copies CLAUDE.md and settings.json into your claude-rules folder (downloading it first if this computer hasn't got it),
archives the rules as Versions\Archive\CLAUDE-<version>.md, commits, pushes, and makes a GitHub Release.
#>
$ErrorActionPreference = 'Stop'
$settingsFile = Join-Path $PSScriptRoot 'settings.json'
if (-not (Test-Path $settingsFile)) { throw "No settings at $settingsFile. Double-click Setup.cmd once first." }
$s = [IO.File]::ReadAllText($settingsFile) | ConvertFrom-Json
$live = Join-Path $HOME '.claude\CLAUDE.md'
$m = [regex]::Match([IO.File]::ReadAllText($live), 'Rules version: (\d+\.\d+\.\d+)')
if (-not $m.Success) { throw "No 'Rules version: x.y.z' line in $live." }
$v = $m.Groups[1].Value

$folder = if ($s.projectsFolder -match '^~([\\/]|$)') { Join-Path $HOME $s.projectsFolder.Substring(1).TrimStart('\', '/') } else { $s.projectsFolder }
$repoDir = Join-Path $folder 'claude-rules'
if (-not (Test-Path (Join-Path $repoDir '.git'))) {
    gh repo clone $s.rulesRepo $repoDir
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $($s.rulesRepo) to $repoDir. Nothing was published." }
}
git -C $repoDir pull --ff-only -q
if ($LASTEXITCODE -ne 0) { throw "Couldn't update $repoDir from GitHub first. Nothing was published." }
$archive = Join-Path $repoDir "Versions\Archive\CLAUDE-$v.md"
if (Test-Path $archive) { throw "Version $v is already archived. Raise the 'Rules version' line in $live, then publish again." }

New-Item -ItemType Directory -Force (Split-Path $archive) | Out-Null
Copy-Item $live $archive
Copy-Item $live (Join-Path $repoDir 'CLAUDE.md')
Copy-Item $settingsFile (Join-Path $repoDir 'settings.json')
git -C $repoDir add CLAUDE.md settings.json $archive
git -C $repoDir commit -q -m "Rules $v"
git -C $repoDir push -q
if ($LASTEXITCODE -ne 0) { throw "Push failed. The commit is saved in $repoDir; push it once GitHub is reachable." }
gh release create "v$v" $archive -R $s.rulesRepo --title "Rules $v" --notes "Rules version $v."
if ($LASTEXITCODE -ne 0) { throw "Pushed rules $v, but couldn't make its GitHub Release." }
Write-Host "Published rules $v."
