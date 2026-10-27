<#
Sets up this computer for Claude the way I work: my rules, settings, plugins, tool servers, and a weekly update.

    .\Get-ClaudeRules.ps1                   everything, newest rules
    .\Get-ClaudeRules.ps1 -Version 1.0.0    the same, with an archived version of the rules
    .\Get-ClaudeRules.ps1 -Quiet            what the weekly task runs: never asks anything, skips what needs me

Offers to install what's missing first (GitHub CLI, Git, Node.js), then signs in to GitHub.
Downloads my rules (CLAUDE.md) and settings from {{RULES_REPO}} into this computer's .claude folder, backing up the
current copies first. Copies the plugins listed in plugins.json, on or off, into .claude\settings.json and installs
them; adds the tool servers (MCP) switched on there to Claude and takes out the ones switched off; installs the tools
switched on there (REA); and sets up a weekly Windows task that runs the newest copy of this script with -Quiet.
#>
param([string]$Version, [switch]$Quiet)
$ErrorActionPreference = 'Stop'
# Any failure ends with one plain sentence instead of PowerShell's red error text.
trap {
    Write-Host "`nSomething went wrong: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Nothing was lost. Fix that if you can, then run Get-ClaudeRules.cmd again."
    exit 1
}
$repo = '{{RULES_REPO}}'
# Runs gh quietly and reports success. 'Continue' here: PowerShell 5.1 turns hidden error output into a crash under 'Stop'.
function Test-Gh { $ErrorActionPreference = 'Continue'; & gh @args *> $null; $LASTEXITCODE -eq 0 }
if ($Quiet) { Write-Host "Weekly update, $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }

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

# Writes text as UTF-8 without a byte-order mark, which PowerShell 5.1's own file commands would add.
function Write-Text($path, $text) { [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false)) }

# --- GitHub CLI: installed and signed in? ---
if (-not (Confirm-Program gh GitHub.cli 'The GitHub CLI (gh)' 'It downloads your rules from GitHub.')) {
    if ($Quiet) { Write-Host "Skipped: the GitHub CLI isn't installed. Run Get-ClaudeRules.cmd yourself once."; return }
    throw "The GitHub CLI isn't installed. Install it from https://cli.github.com, then run this again."
}
if (-not (Test-Gh auth status --hostname github.com)) {
    if ($Quiet) { Write-Host "Skipped: not signed in to GitHub. Run Get-ClaudeRules.cmd yourself once."; return }
    Write-Host "You're not signed in to GitHub yet. A browser window will open: sign in as {{GITHUB_NAME}} and enter the code shown here."
    gh auth login --hostname github.com --web --git-protocol https
    if (-not (Test-Gh auth status --hostname github.com)) { throw "GitHub sign-in didn't finish. Run this again to retry." }
}
if (-not (Test-Gh api "repos/$repo" --silent)) {
    $who = gh api user --jq .login
    throw "You're signed in to GitHub as '$who', which can't see $repo. Run 'gh auth logout', then run this again and sign in as {{GITHUB_NAME}}."
}

# --- Git: Claude downloads plugins with it, and commits with my private GitHub address. ---
$hasGit = Confirm-Program git Git.Git 'Git' 'Claude uses it to download plugins and save your projects to GitHub.'
if ($hasGit) {
    # Lets git use gh's sign-in, so Claude can download plugins from private repos (setup-band) without a sign-in window.
    gh auth setup-git --hostname github.com
    if ($LASTEXITCODE -ne 0) { throw "Couldn't let git use the GitHub sign-in (gh auth setup-git)." }
    if (-not (git config --global user.email)) {
        git config --global user.name {{GITHUB_NAME}}
        git config --global user.email {{NOREPLY_EMAIL}}
        Write-Host "Set git's name and email to {{GITHUB_NAME}}'s private GitHub address."
    }
} else {
    Write-Host "Skipped: Git isn't installed, so Claude can't download plugins yet. Install it from https://git-scm.com, then run this again."
}
$hasNode = Confirm-Program npm OpenJS.NodeJS.LTS 'Node.js' 'Some Claude plugins and tool servers (like ponytail) need it.'

# Fetched as base64 so PowerShell can't mangle the text encoding on the way.
function Get-RepoFile($path) {
    $b64 = gh api "repos/$repo/contents/$path" --jq .content
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $path from $repo." }
    [Convert]::FromBase64String(($b64 -join ''))
}
function Get-Text($bytes) { [Text.Encoding]::UTF8.GetString($bytes) }

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

# --- Rules and settings (projects folder, public or private, hands-off list) ---
$dir = Join-Path $HOME '.claude'
$selfDir = Join-Path $dir 'claude-rules'
New-Item -ItemType Directory -Force $selfDir | Out-Null
$path = if ($Version) { "Versions/Archive/CLAUDE-$Version.md" } else { 'CLAUDE.md' }
$bytes = Get-RepoFile $path
$got = [regex]::Match((Get-Text $bytes), 'Rules version: (\S+)').Groups[1].Value
Install-File $bytes (Join-Path $dir 'CLAUDE.md') "rules $(if ($got) { "version $got" } else { $path })"
Install-File (Get-RepoFile 'settings.json') (Join-Path $selfDir 'settings.json') 'settings'

# --- Plugins: copy plugins.json into settings.json. The list wins, so a plugin marked off there is turned off here too. ---
$want = (Get-Text (Get-RepoFile 'plugins.json')) | ConvertFrom-Json
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

# --- Tool servers (MCP): each one in plugins.json's "mcpServers" that's on is added to Claude for every chat, with
# its "config" exactly as written there; one that's off is taken out. Servers not on the list are left alone. ---
$servers = @($want.mcpServers.PSObject.Properties)
$claudeJson = Join-Path $HOME '.claude.json'
# One argument in Windows' own quoting. PowerShell 5.1's quoting breaks JSON that holds spaces, so it's done by hand.
function ConvertTo-Arg($s) { '"' + (($s -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }
function Invoke-Claude($arguments) { (Start-Process $claude -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden).ExitCode }
if ($servers.Count -gt 0 -and -not $claude) {
    Write-Host "Skipped tool servers: couldn't find Claude on this computer. Start Claude once, then run this again."
} elseif ($servers.Count -gt 0) {
    $have = if (Test-Path $claudeJson) { ([IO.File]::ReadAllText($claudeJson) | ConvertFrom-Json).mcpServers }
    foreach ($s in $servers) {
        $now = $have.($s.Name)
        $json = $s.Value.config | ConvertTo-Json -Compress -Depth 20
        if ($s.Value.on -and $now -and ($now | ConvertTo-Json -Compress -Depth 20) -eq $json) { Write-Host "Tool server $($s.Name) is set up."; continue }
        if (-not $s.Value.on -and -not $now) { continue }
        if ($now) { Invoke-Claude "mcp remove $(ConvertTo-Arg $s.Name) --scope user" | Out-Null }
        if ($s.Value.on -and (Invoke-Claude "mcp add-json $(ConvertTo-Arg $s.Name) $(ConvertTo-Arg $json) --scope user") -ne 0) {
            throw "Couldn't add the tool server $($s.Name) to Claude. Check its config in plugins.json."
        }
        Write-Host $(if ($s.Value.on) { "Added tool server $($s.Name). It loads in your next new chat." } else { "Took out tool server $($s.Name): it's off in plugins.json." })
    }
}

# --- Weekly update: keep the newest copy of this script in .claude\claude-rules and run it quietly every week. ---
$self = Join-Path $selfDir 'Get-ClaudeRules.ps1'
[IO.File]::WriteAllBytes($self, (Get-RepoFile 'Get-ClaudeRules.ps1'))
$task = 'Claude rules weekly update'
if (-not (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue)) {
    $log = Join-Path $selfDir 'last-run.log'
    # cmd does the logging: redirecting inside PowerShell 5.1 would turn npm's and gh's progress messages into errors.
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/d /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$self`" -Quiet > `"$log`" 2>&1"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 12pm
    $when = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $when `
        -Description "Runs Get-ClaudeRules.ps1 -Quiet: newest Claude rules, plugins and tools from github.com/$repo. Log: $log" | Out-Null
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
