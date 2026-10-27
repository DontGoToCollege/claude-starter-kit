<#
Sets up this computer for Claude the starter kit's way: your rules, plugins, tools, and a weekly update.
Setup.cmd downloads and runs this; the weekly task runs its saved copy with -Quiet.

    .\Get-ClaudeRules.ps1                   everything, newest rules
    .\Get-ClaudeRules.ps1 -Version 1.0.0    the same, with an archived version of your rules
    .\Get-ClaudeRules.ps1 -Quiet            what the weekly task runs: never asks anything, skips what needs you

Offers to install what's missing first (GitHub CLI, Git, Node.js), then signs you in to GitHub.
The first time on a GitHub account, asks three questions and makes your own private claude-rules repo from the
kit's template. Then downloads your rules (CLAUDE.md) and settings into this computer's .claude folder, backing up
the current copies first; copies the plugins listed in your plugins.json into .claude\settings.json; installs the
tools switched on there (REA); and sets up a weekly Windows task that runs the newest kit release of this script.
#>
param([string]$Version, [switch]$Quiet)
$KitVersion = '1.0.0'
$kit = 'DontGoToCollege/claude-starter-kit'
$ErrorActionPreference = 'Stop'
# Any failure ends with one plain sentence instead of PowerShell's red error text.
trap {
    Write-Host "`nSomething went wrong: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Nothing was lost. Fix that if you can, then double-click Setup.cmd again."
    exit 1
}
# Runs gh quietly and reports success. 'Continue' here: PowerShell 5.1 turns hidden error output into a crash under 'Stop'.
function Test-Gh { $ErrorActionPreference = 'Continue'; & gh @args *> $null; $LASTEXITCODE -eq 0 }
if ($Quiet) { Write-Host "Weekly update, $(Get-Date -Format 'yyyy-MM-dd HH:mm'), starter kit $KitVersion" }

# Offers to install a missing program with winget (never under -Quiet). Returns whether it's there now.
function Confirm-Program($command, $wingetId, $name, $why) {
    if (Get-Command $command -ErrorAction SilentlyContinue) { return $true }
    if ($Quiet -or -not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    if ((Read-Host "$name isn't installed. $why Install it now? (y/n)") -notmatch '^y') { return $false }
    winget install --id $wingetId --exact --source winget --accept-package-agreements --accept-source-agreements
    # A fresh install isn't on this window's PATH yet: reload it from Windows.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    [bool](Get-Command $command -ErrorAction SilentlyContinue)
}

# "~\Claude Projects" -> "C:\Users\<you>\Claude Projects". Settings keep the ~ form so they suit every computer.
function Expand-Folder($path) {
    if ($path -match '^~([\\/]|$)') { return Join-Path $HOME $path.Substring(1).TrimStart('\', '/') }
    $path
}

# Writes text as UTF-8 without a byte-order mark, which PowerShell 5.1's own file commands would add.
function Write-Text($path, $text) { [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false)) }

# --- GitHub CLI: installed and signed in? ---
if (-not (Confirm-Program gh GitHub.cli 'The GitHub CLI (gh)' 'It keeps your rules and projects on GitHub.')) {
    if ($Quiet) { Write-Host "Skipped: the GitHub CLI isn't installed. Double-click Setup.cmd yourself once."; return }
    throw "The GitHub CLI isn't installed. Install it from https://cli.github.com, then run this again."
}
if (-not (Test-Gh auth status --hostname github.com)) {
    if ($Quiet) { Write-Host "Skipped: not signed in to GitHub. Double-click Setup.cmd yourself once."; return }
    Write-Host "You're not signed in to GitHub yet. A browser window will open: sign in with your own GitHub account"
    Write-Host "(no account yet? make a free one at https://github.com/signup first), then enter the code shown here."
    gh auth login --hostname github.com --web --git-protocol https
    if (-not (Test-Gh auth status --hostname github.com)) { throw "GitHub sign-in didn't finish. Run this again to retry." }
}
$me = gh api user | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $me.login) { throw "Couldn't read your GitHub account." }
$login = $me.login
$repo = "$login/claude-rules"
# GitHub's private address for this account: commits show your GitHub name, never your real email.
$noreply = "$($me.id)+$login@users.noreply.github.com"

# Fetched as base64 so PowerShell can't mangle the text encoding on the way. $ref: a tag or branch (default: the repo's own).
function Get-RepoFile($from, $path, $ref) {
    $url = "repos/$from/contents/$path" + $(if ($ref) { "?ref=$ref" })
    $b64 = gh api $url --jq .content
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $path from $from." }
    [Convert]::FromBase64String(($b64 -join ''))
}
function Get-Text($bytes) { [Text.Encoding]::UTF8.GetString($bytes) }
# The kit's newest release: friends get released code only, never work in progress.
$kitRef = & { $ErrorActionPreference = 'Continue'; gh api "repos/$kit/releases/latest" --jq .tag_name 2>$null }
if ($LASTEXITCODE -ne 0 -or -not $kitRef) { $kitRef = 'main' }

# --- Git: Claude downloads plugins with it, and commits with your private GitHub address. ---
$hasGit = Confirm-Program git Git.Git 'Git' 'Claude uses it to download plugins and save your projects to GitHub.'
if ($hasGit) {
    gh auth setup-git --hostname github.com
    if ($LASTEXITCODE -ne 0) { throw "Couldn't let git use the GitHub sign-in (gh auth setup-git)." }
    if (-not (git config --global user.email)) {
        git config --global user.name $login
        git config --global user.email $noreply
        Write-Host "Set git's name and email to $login's private GitHub address."
    }
} else {
    if (-not $Quiet) { throw "Git is needed to keep your rules on GitHub. Install it from https://git-scm.com, then run this again." }
    Write-Host "Skipped: Git isn't installed. Double-click Setup.cmd yourself once."; return
}
$hasNode = Confirm-Program npm OpenJS.NodeJS.LTS 'Node.js' 'Some Claude plugins (like ponytail) need it.'

$dir = Join-Path $HOME '.claude'
$selfDir = Join-Path $dir 'claude-rules'
New-Item -ItemType Directory -Force $selfDir | Out-Null

# --- First run on this GitHub account: three questions, then your own private claude-rules repo. ---
function New-RulesRepo {
    Write-Host "`nWelcome, $login. Three quick questions, asked only this once. Press Enter to take the answer in [brackets].`n" -ForegroundColor Cyan

    $folder = Read-Host "1. Where should your projects live? [~\Claude Projects]  (~ is your user folder)"
    if (-not $folder) { $folder = '~\Claude Projects' }
    if ($folder -notmatch '^~([\\/]|$)' -and -not [IO.Path]::IsPathRooted($folder)) { throw "'$folder' isn't a full folder path like D:\Projects or ~\Claude Projects." }
    # Inside your user folder: kept as ~\..., so the same setting works on your other computers.
    $full = (Expand-Folder $folder).TrimEnd('\')
    if ($full.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase)) { $folder = '~' + $full.Substring($HOME.Length) } else { $folder = $full }

    Write-Host ""
    Write-Host "2. Every project Claude makes for you gets backed up to its own GitHub repo." -ForegroundColor Yellow
    Write-Host "   public  = anyone on the internet can see and download that project's code."
    Write-Host "   private = only you can see it (you can still make one public later, by asking Claude)."
    do { $vis = (Read-Host "   public or private? [private]").Trim().ToLower(); if (-not $vis) { $vis = 'private' } } until ($vis -in 'public', 'private')

    Write-Host ""
    $yours = @(& { $ErrorActionPreference = 'Continue'; gh repo list $login --limit 200 --json name --jq '.[].name' 2>$null }) | Where-Object { $_ -and $_ -ne 'claude-rules' }
    $here = if (Test-Path $full) { @(Get-ChildItem $full -Directory | Select-Object -ExpandProperty Name) } else { @() }
    $known = @($yours + $here | Sort-Object -Unique)
    Write-Host "3. Anything Claude must never touch? Older projects stay untouched anyway until you ask Claude to bring them in;"
    Write-Host "   this list is for things you never want touched at all, even by mistake."
    if ($known.Count -gt 0) { Write-Host "   Your GitHub repos and project folders now: $($known -join ', ')" }
    $handsOff = @((Read-Host "   Names, separated by commas, or Enter for none") -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    $since = Get-Date -Format 'yyyy-MM-dd'
    $settings = [ordered]@{ owner = $login; rulesRepo = $repo; projectsFolder = $folder; newRepos = $vis; handsOff = $handsOff; since = $since }
    $note = if ($vis -eq 'public') {
        'I chose public at setup: anyone can see and download the code, so the check before every push matters.'
    } else {
        'I chose private at setup: only I can see them. To share a project, ask me first, then make just that repo public.'
    }
    $rules = Get-Text (Get-RepoFile $kit 'template/CLAUDE.md' $kitRef)
    $blanks = @{ GITHUB_NAME = $login; RULES_REPO = $repo; NOREPLY_EMAIL = $noreply; PROJECTS_FOLDER = $folder; REPO_VISIBILITY = $vis; VISIBILITY_NOTE = $note; START_DATE = $since }
    foreach ($b in $blanks.GetEnumerator()) { $rules = $rules.Replace("{{$($b.Key)}}", $b.Value) }
    if ($rules -match '\{\{\w+\}\}') { throw "The kit's rules template has a blank nobody filled in: $($Matches[0])." }

    # The rules repo lives in your projects folder like any project; Publish-ClaudeRules.ps1 works from there.
    # A run that stopped halfway left the empty repo and maybe its folder: both are picked up again.
    $clone = Join-Path $full 'claude-rules'
    $origin = if (Test-Path (Join-Path $clone '.git')) { & { $ErrorActionPreference = 'Continue'; git -C $clone remote get-url origin 2>$null } }
    if ((Test-Path $clone) -and $origin -notlike "*github.com/$repo*") { throw "There's already a folder at $clone. Move or rename it, then run this again." }
    New-Item -ItemType Directory -Force $full | Out-Null
    if (-not (Test-Gh api "repos/$repo" --silent)) {
        gh repo create $repo --private --description 'My Claude rules, from the Claude starter kit'
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make your private repo $repo on GitHub." }
    }
    if (-not $origin) { & { $ErrorActionPreference = 'Continue'; git clone -q "https://github.com/$repo.git" $clone 2>&1 | Out-Null } }
    if (-not (Test-Path (Join-Path $clone '.git'))) { throw "Couldn't download your new repo $repo." }

    New-Item -ItemType Directory -Force (Join-Path $clone 'Versions\Archive') | Out-Null
    Write-Text (Join-Path $clone 'CLAUDE.md') $rules
    Write-Text (Join-Path $clone 'Versions\Archive\CLAUDE-1.0.0.md') $rules
    Write-Text (Join-Path $clone 'settings.json') ($settings | ConvertTo-Json)
    foreach ($f in 'plugins.json', 'README.md') { [IO.File]::WriteAllBytes((Join-Path $clone $f), (Get-RepoFile $kit "template/$f" $kitRef)) }
    & {
        $ErrorActionPreference = 'Continue'
        git -C $clone add -A
        git -C $clone commit -q -m 'Rules 1.0.0, from the Claude starter kit'
        git -C $clone push -q -u origin HEAD 2>&1 | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Couldn't save your rules to $repo. Run this again to retry." }
    Write-Host "`nMade your private repo github.com/$repo with your rules, settings and plugin list." -ForegroundColor Green
}

# No repo yet, or an empty one from a first run that stopped halfway (GitHub lists no commits for an empty repo).
if (-not (Test-Gh api "repos/$repo" --silent) -or -not (Test-Gh api "repos/$repo/commits?per_page=1" --silent)) {
    if ($Quiet) { Write-Host "Skipped: there's no $repo yet. Double-click Setup.cmd yourself once."; return }
    New-RulesRepo
} elseif (-not (Test-Gh api "repos/$repo/contents/settings.json" --silent)) {
    # A claude-rules repo the kit didn't make: never touch it, or anything on this computer.
    throw "You already have a repo called $repo that the starter kit didn't make (it has no settings.json). Nothing was changed."
}

# Puts downloaded bytes at $dest unless they're the same, keeping a dated backup of a different old copy.
function Install-File($bytes, $dest, $label) {
    if ((Test-Path $dest) -and (Get-FileHash $dest).Hash -eq (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes))).Hash) {
        Write-Host "Already up to date: $dest"; return
    }
    if (Test-Path $dest) {
        $backup = "$dest.bak-$(Get-Date -Format yyyyMMdd-HHmmss-fff)"
        [IO.File]::Copy($dest, $backup, $false)  # $false: never overwrite an earlier backup
        Write-Host "Backed up your old copy to $backup"
    }
    [IO.File]::WriteAllBytes($dest, $bytes)
    Write-Host "Installed $label at $dest"
}

# --- Rules and settings ---
$path = if ($Version) { "Versions/Archive/CLAUDE-$Version.md" } else { 'CLAUDE.md' }
$bytes = Get-RepoFile $repo $path
$got = [regex]::Match((Get-Text $bytes), 'Rules version: (\S+)').Groups[1].Value
Install-File $bytes (Join-Path $dir 'CLAUDE.md') "rules $(if ($got) { "version $got" } else { $path })"
Install-File (Get-RepoFile $repo 'settings.json') (Join-Path $selfDir 'settings.json') 'your settings'

# --- Plugins: copy plugins.json into settings.json. The list wins, so a plugin marked off there is turned off here too. ---
$want = (Get-Text (Get-RepoFile $repo 'plugins.json')) | ConvertFrom-Json
$settingsPath = Join-Path $dir 'settings.json'
$settings = if (Test-Path $settingsPath) { [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json }
if (-not $settings) { $settings = [pscustomobject]@{} }
$changed = $false
foreach ($key in 'extraKnownMarketplaces', 'enabledPlugins') {
    if (-not $want.$key) { continue }
    if (-not $settings.$key) { $settings | Add-Member $key ([pscustomobject]@{}) -Force }
    foreach ($entry in $want.$key.PSObject.Properties) {
        $have = $settings.$key.($entry.Name)
        if ($null -eq $have) { $settings.$key | Add-Member $entry.Name $entry.Value }
        elseif (($have | ConvertTo-Json -Compress -Depth 20) -ne ($entry.Value | ConvertTo-Json -Compress -Depth 20)) { $settings.$key.($entry.Name) = $entry.Value }
        else { continue }
        $changed = $true
    }
}
$names = ($want.enabledPlugins.PSObject.Properties | ForEach-Object { "$($_.Name -replace '@.*') $(if ($_.Value) { 'on' } else { 'off' })" }) -join ', '
if ($changed) {
    if (Test-Path $settingsPath) {
        $backup = "$settingsPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss-fff)"
        [IO.File]::Copy($settingsPath, $backup, $false)
        Write-Host "Backed up your old Claude settings to $backup"
    }
    Write-Text $settingsPath ($settings | ConvertTo-Json -Depth 20)
    Write-Host "Set plugins: $names. Claude applies this the next time you start it."
} else {
    Write-Host "Plugins already set up: $names"
}

# --- Plugins, installed now: rather than waiting for Claude to fetch them in a chat, install or update each one
# that's on, with Claude's own commands. Open chats switch to a new version by themselves (setup-band reloads them).
function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # The desktop app keeps its own copy of Claude Code, one folder per version: take the newest.
    Get-ChildItem "$env:LOCALAPPDATA\Claude-Data", "$env:APPDATA\Claude" -Recurse -Depth 6 -Filter claude.exe -ErrorAction SilentlyContinue |
        Where-Object FullName -match '\\claude-code\\' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
function Get-PluginVersions {
    $records = Join-Path $dir 'plugins\installed_plugins.json'
    $found = @{}
    if (Test-Path $records) {
        $plugins = ([IO.File]::ReadAllText($records) | ConvertFrom-Json).plugins
        foreach ($p in $plugins.PSObject.Properties) { $found[$p.Name] = @($p.Value)[0].version }
    }
    $found
}
$on = @($want.enabledPlugins.PSObject.Properties | Where-Object { $_.Value } | ForEach-Object { $_.Name })
$claude = Find-Claude
if (-not $claude) {
    Write-Host "Claude installs the plugins itself the next time you start a chat."
} elseif ($on.Count -gt 0) {
    $before = Get-PluginVersions
    & {
        # Claude's commands print progress to stderr; 'Continue' keeps PowerShell 5.1 from treating that as a failure.
        $ErrorActionPreference = 'Continue'
        foreach ($market in ($on | ForEach-Object { ($_ -split '@')[1] } | Select-Object -Unique)) { & $claude plugin marketplace update $market *> $null }
        foreach ($id in $on) { & $claude plugin install $id *> $null; & $claude plugin update $id *> $null }
    }
    $after = Get-PluginVersions
    foreach ($id in $on) {
        $name = $id -replace '@.*'
        if (-not $after[$id]) { Write-Host "Couldn't install $name yet; Claude tries again when you start a chat." }
        elseif ($after[$id] -ne $before[$id]) { Write-Host "Installed $name $($after[$id]). Open chats switch to it by themselves." }
        else { Write-Host "$name $($after[$id]) is current." }
    }
}

# --- Weekly update: keep the kit's newest released scripts in .claude\claude-rules and run this one quietly every week. ---
$self = Join-Path $selfDir 'Get-ClaudeRules.ps1'
foreach ($f in 'Get-ClaudeRules.ps1', 'Publish-ClaudeRules.ps1') { [IO.File]::WriteAllBytes((Join-Path $selfDir $f), (Get-RepoFile $kit $f $kitRef)) }
$task = 'Claude rules weekly update'
if (-not (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue)) {
    $log = Join-Path $selfDir 'last-run.log'
    # cmd does the logging: redirecting inside PowerShell 5.1 would turn npm's and gh's progress messages into errors.
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/d /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$self`" -Quiet > `"$log`" 2>&1"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 12pm
    $when = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $when `
        -Description "Runs the Claude starter kit's Get-ClaudeRules.ps1 -Quiet: your newest rules and plugins from github.com/$repo, the kit's newest scripts from github.com/$kit. Log: $log" | Out-Null
    Write-Host "Set up a weekly Windows task ('$task', Sundays at noon, or at the next start if missed) that keeps all of this up to date."
}

# --- Tools: install or update the ones switched on in plugins.json's "tools". ---
if ($want.tools.rea) {
    if (-not $hasNode) {
        Write-Host "Skipped REA: it needs Node.js (https://nodejs.org). Install it, then run this again."
    } else {
        $latest = npm view rea-agents version
        if ($LASTEXITCODE -ne 0 -or -not $latest) { throw "Couldn't ask npm for REA's newest version." }
        $pkg = Join-Path (npm root -g) 'rea-agents\package.json'
        $have = if (Test-Path $pkg) { ([IO.File]::ReadAllText($pkg) | ConvertFrom-Json).version }
        if ($have -ne $latest) {
            npm install -g "rea-agents@$latest"
            if ($LASTEXITCODE -ne 0) { throw "Couldn't install REA $latest." }
        }
        $claudeJson = Join-Path $HOME '.claude.json'
        $reg = if (Test-Path $claudeJson) { ([IO.File]::ReadAllText($claudeJson) | ConvertFrom-Json).mcpServers.rea.args -join ' ' }
        if ($have -eq $latest -and $reg -like "*rea-agents@$latest *") {
            Write-Host "REA already up to date: $latest"
        } else {
            # REA's own setup points Claude at this version and installs the matching skill, backing up .claude.json first.
            npx -y "rea-agents@$latest" setup --client claude_code --yes
            if ($LASTEXITCODE -ne 0) { throw "REA setup failed." }
            Write-Host "Set up REA $latest for Claude. It loads in your next new chat."
        }
    }
}

if (-not $Quiet) { Write-Host "`nAll set. Start a new chat in Claude to use everything." -ForegroundColor Green }
