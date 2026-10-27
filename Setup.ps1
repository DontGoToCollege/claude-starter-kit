<#
The Claude starter kit's one-time setup. Setup.cmd downloads and runs this.

Installs what's missing (GitHub CLI, Git) after a y/n and signs you in to GitHub, asks three questions, then makes
your own copies of everything, under your own GitHub account:
    <you>/claude-rules   your rules, settings, plugin list, and your own setup and publish scripts
    <you>/setup-band     the status band above Claude's prompt, as a plugin of your own
Both are also downloaded into your projects folder. Then it runs your own Get-ClaudeRules.ps1, which sets up this
computer and a weekly update from your repos. After that nothing comes from the kit: everything is yours to change.
Running it again is safe: whatever already exists is kept, and only missing pieces are added.
#>
$KitVersion = '1.1.0'
$kit = 'DontGoToCollege/claude-starter-kit'
$ErrorActionPreference = 'Stop'
# Any failure ends with one plain sentence instead of PowerShell's red error text.
trap {
    Write-Host "`nSomething went wrong: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Nothing was lost. Fix that if you can, then double-click Setup.cmd again."
    exit 1
}
Write-Host "Claude starter kit $KitVersion`n"
# Runs gh quietly and reports success. 'Continue' here: PowerShell 5.1 turns hidden error output into a crash under 'Stop'.
function Test-Gh { $ErrorActionPreference = 'Continue'; & gh @args *> $null; $LASTEXITCODE -eq 0 }
# Runs git quietly; returns whether it worked.
function Invoke-Git { $ErrorActionPreference = 'Continue'; & git @args *> $null; $LASTEXITCODE -eq 0 }

# Offers to install a missing program with winget. Returns whether it's there now.
function Confirm-Program($command, $wingetId, $name, $why) {
    if (Get-Command $command -ErrorAction SilentlyContinue) { return $true }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
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
function Write-Text($path, $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}
# Fetched as base64 so PowerShell can't mangle the text encoding on the way.
function Get-RepoText($from, $path, $ref) {
    $url = "repos/$from/contents/$path" + $(if ($ref) { "?ref=$ref" })
    $b64 = gh api $url --jq .content
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $path from $from." }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($b64 -join '')))
}

# --- GitHub CLI and Git: installed and signed in? ---
if (-not (Confirm-Program gh GitHub.cli 'The GitHub CLI (gh)' 'It keeps your rules and projects on GitHub.')) {
    throw "The GitHub CLI isn't installed. Install it from https://cli.github.com, then run this again."
}
if (-not (Test-Gh auth status --hostname github.com)) {
    Write-Host "You're not signed in to GitHub yet. A browser window will open: sign in with your own GitHub account"
    Write-Host "(no account yet? make a free one at https://github.com/signup first), then enter the code shown here."
    gh auth login --hostname github.com --web --git-protocol https
    if (-not (Test-Gh auth status --hostname github.com)) { throw "GitHub sign-in didn't finish. Run this again to retry." }
}
if (-not (Confirm-Program git Git.Git 'Git' 'Claude uses it to download plugins and save your projects to GitHub.')) {
    throw "Git is needed to keep your rules on GitHub. Install it from https://git-scm.com, then run this again."
}
gh auth setup-git --hostname github.com
if ($LASTEXITCODE -ne 0) { throw "Couldn't let git use the GitHub sign-in (gh auth setup-git)." }
$me = gh api user | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $me.login) { throw "Couldn't read your GitHub account." }
$login = $me.login
$repo = "$login/claude-rules"
$bandRepo = "$login/setup-band"
# GitHub's private address for this account: commits show your GitHub name, never your real email.
$noreply = "$($me.id)+$login@users.noreply.github.com"
if (-not (git config --global user.email)) {
    git config --global user.name $login
    git config --global user.email $noreply
    Write-Host "Set git's name and email to $login's private GitHub address."
}
# The kit's newest release; 'main' only before the first one.
$kitRef = & { $ErrorActionPreference = 'Continue'; gh api "repos/$kit/releases/latest" --jq .tag_name 2>$null }
if ($LASTEXITCODE -ne 0 -or -not $kitRef) { $kitRef = 'main' }

# --- Your settings: from your claude-rules repo if you have one, else three questions. ---
# No repo, or an empty one from a first run that stopped halfway (GitHub lists no commits for an empty repo).
$hasRepo = (Test-Gh api "repos/$repo" --silent) -and (Test-Gh api "repos/$repo/commits?per_page=1" --silent)
if ($hasRepo) {
    if (-not (Test-Gh api "repos/$repo/contents/settings.json" --silent)) {
        # A claude-rules repo the kit didn't make: never touch it, or anything on this computer.
        throw "You already have a repo called $repo that the starter kit didn't make (it has no settings.json). Nothing was changed."
    }
    $settings = (Get-RepoText $repo 'settings.json') | ConvertFrom-Json
    Write-Host "Found your settings in $repo."
} else {
    Write-Host "Welcome, $login. Three quick questions, asked only this once. Press Enter to take the answer in [brackets].`n" -ForegroundColor Cyan

    $folder = Read-Host "1. Where should your projects live? [~\Claude Projects]  (~ is your user folder)"
    if (-not $folder) { $folder = '~\Claude Projects' }
    if ($folder -notmatch '^~([\\/]|$)' -and -not [IO.Path]::IsPathRooted($folder)) { throw "'$folder' isn't a full folder path like D:\Projects or ~\Claude Projects." }
    # Inside your user folder: kept as ~\..., so the same setting works on your other computers.
    $full = (Expand-Folder $folder).TrimEnd('\')
    $folder = if ($full.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase)) { '~' + $full.Substring($HOME.Length) } else { $full }

    Write-Host ""
    Write-Host "2. Every project Claude makes for you gets backed up to its own GitHub repo." -ForegroundColor Yellow
    Write-Host "   public  = anyone on the internet can see and download that project's code."
    Write-Host "   private = only you can see it (you can still make one public later, by asking Claude)."
    do { $vis = (Read-Host "   public or private? [private]").Trim().ToLower(); if (-not $vis) { $vis = 'private' } } until ($vis -in 'public', 'private')

    Write-Host ""
    $yours = @(& { $ErrorActionPreference = 'Continue'; gh repo list $login --limit 200 --json name --jq '.[].name' 2>$null }) | Where-Object { $_ }
    $here = if (Test-Path $full) { @(Get-ChildItem $full -Directory | Select-Object -ExpandProperty Name) } else { @() }
    $known = @(@($yours) + @($here) | Where-Object { $_ -notin 'claude-rules', 'setup-band' } | Sort-Object -Unique)
    Write-Host "3. Anything Claude must never touch? Older projects stay untouched anyway until you ask Claude to bring them in;"
    Write-Host "   this list is for things you never want touched at all, even by mistake."
    if ($known.Count -gt 0) { Write-Host "   Your GitHub repos and project folders now: $($known -join ', ')" }
    $handsOff = @((Read-Host "   Names, separated by commas, or Enter for none") -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    $settings = [pscustomobject][ordered]@{
        owner = $login; rulesRepo = $repo; projectsFolder = $folder; newRepos = $vis; handsOff = $handsOff; since = (Get-Date -Format 'yyyy-MM-dd')
    }
}
$full = Expand-Folder $settings.projectsFolder
$vis = $settings.newRepos
$note = if ($vis -eq 'public') {
    'I chose public at setup: anyone can see and download the code, so the check before every push matters.'
} else {
    'I chose private at setup: only I can see them. To share a project, ask me first, then make just that repo public.'
}
$blanks = [ordered]@{
    GITHUB_NAME = $login; RULES_REPO = $repo; BAND_REPO = $bandRepo; NOREPLY_EMAIL = $noreply; PROJECTS_FOLDER = $settings.projectsFolder
    REPO_VISIBILITY = $vis; VISIBILITY_NOTE = $note; START_DATE = $settings.since; YEAR = (Get-Date).Year
}
# A kit file with your details filled in.
function Get-KitFile($path) {
    $text = Get-RepoText $kit $path $kitRef
    foreach ($b in $blanks.GetEnumerator()) { $text = $text.Replace("{{$($b.Key)}}", [string]$b.Value) }
    if ($text -match '\{\{[A-Z_]+\}\}') { throw "The kit's $path has a blank nobody filled in: $($Matches[0])." }
    $text
}

# Your repo on GitHub and its folder in your projects folder, made if missing. A run that stopped halfway left the repo
# and maybe its folder: both are picked up again. Returns the folder.
function Get-OwnRepo($name, $visibility, $description) {
    $clone = Join-Path $full ($name -split '/')[1]
    $origin = if (Test-Path (Join-Path $clone '.git')) { & { $ErrorActionPreference = 'Continue'; git -C $clone remote get-url origin 2>$null } }
    if ((Test-Path $clone) -and $origin -notlike "*github.com/$name*") { throw "There's already a folder at $clone that isn't $name. Move or rename it, then run this again." }
    if (-not (Test-Gh api "repos/$name" --silent)) {
        gh repo create $name "--$visibility" --description $description
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make your repo $name on GitHub." }
        Write-Host "Made your $visibility repo github.com/$name"
    }
    New-Item -ItemType Directory -Force $full | Out-Null
    if (-not $origin) { Invoke-Git clone -q "https://github.com/$name.git" $clone | Out-Null }
    if (-not (Test-Path (Join-Path $clone '.git'))) { throw "Couldn't download your repo $name." }
    if ($origin) { Invoke-Git -C $clone pull -q --ff-only | Out-Null }
    $clone
}

# Adds each file that isn't there yet (never replacing one), then saves and backs it up; a first Release if there's none.
function Add-Missing($clone, $name, $files, $message, $releaseFiles) {
    $added = @()
    foreach ($f in $files.GetEnumerator()) {
        $dest = Join-Path $clone $f.Key
        if (Test-Path $dest) { continue }
        $text = if ($f.Value -is [scriptblock]) { & $f.Value } else { Get-KitFile $f.Value }
        # cmd reads its own line endings most reliably; GitHub hands files over with Unix ones.
        if ($f.Key -like '*.cmd') { $text = $text -replace "`r?`n", "`r`n" }
        Write-Text $dest $text
        $added += $f.Key
    }
    if ($added.Count -gt 0) {
        Invoke-Git -C $clone add -A | Out-Null
        if (-not (Invoke-Git -C $clone commit -q -m $message)) { throw "Couldn't save the new files in $clone." }
        if (-not (Invoke-Git -C $clone push -q -u origin HEAD)) { throw "Couldn't back up $name to GitHub. Run this again to retry." }
        Write-Host "Added to $name`: $($added -join ', ')"
    }
    if (-not (Test-Gh release view v1.0.0 -R $name)) {
        Push-Location $clone
        try { & { $ErrorActionPreference = 'Continue'; gh release create v1.0.0 @releaseFiles --title "$(($name -split '/')[1]) 1.0.0" --notes 'Made by the Claude starter kit.' *> $null } }
        finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "Couldn't make the first Release of $name." }
    }
}

# --- Your claude-rules ---
$rulesDir = Get-OwnRepo $repo 'private' 'My Claude rules, settings and setup'
# Where each file goes in your repo -> the kit file it comes from (filled in), or a script block that makes it.
$rules = [ordered]@{ 'CLAUDE.md' = 'template/rules/CLAUDE.md'; 'Versions\Archive\CLAUDE-1.0.0.md' = 'template/rules/CLAUDE.md'; 'settings.json' = { $settings | ConvertTo-Json } }
foreach ($f in 'plugins.json', 'README.md', 'Get-ClaudeRules.cmd', 'Get-ClaudeRules.ps1', 'Publish-ClaudeRules.ps1') { $rules[$f] = "template/rules/$f" }
$rules['LICENSE'] = 'template/LICENSE'
# Made by kit 1.0.0, whose plugin list used the kit's own band: from now on it's your own.
$list = Join-Path $rulesDir 'plugins.json'
if ((Test-Path $list) -and ($old = [IO.File]::ReadAllText($list)) -match 'claude-starter-kit') {
    Write-Text $list $old.Replace('DontGoToCollege/claude-starter-kit', $bandRepo).Replace('"claude-starter-kit"', '"setup-band"').Replace('setup-band@claude-starter-kit', 'setup-band@setup-band')
    Invoke-Git -C $rulesDir commit -q -am 'Plugins: my own setup-band' | Out-Null
}
Add-Missing $rulesDir $repo $rules 'Rules 1.0.0, from the Claude starter kit' @('Versions\Archive\CLAUDE-1.0.0.md', 'Get-ClaudeRules.cmd', 'Get-ClaudeRules.ps1')

# --- Your setup-band: the kit's band, as a plugin of your own. ---
$bandDir = Get-OwnRepo $bandRepo $vis 'The status band above my Claude prompt: is my setup current and backed up?'
$band = [ordered]@{}
foreach ($f in '.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', 'hooks/hooks.json', 'hooks/register.tsx', 'types/index.d.ts',
    'tests/projects.test.tsx', 'tsconfig.json', '.gitignore', 'README.md') { $band[$f] = "template/band/$f" }
$band['LICENSE'] = 'template/LICENSE'
Add-Missing $bandDir $bandRepo $band 'setup-band 1.0.0, from the Claude starter kit' @()

# --- This computer: your own setup script, from your own repo, does the rest (and keeps doing it every week). ---
Write-Host "`nYour repos are ready. Now setting up this computer from them.`n" -ForegroundColor Green
& (Join-Path $rulesDir 'Get-ClaudeRules.ps1')
