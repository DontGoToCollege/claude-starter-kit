# setup-band

A mod for Claude Code: a line above the prompt that shows whether this computer's Claude setup is current and backed up.

- **Rules:** this computer's rules version against the one in my claude-rules repo, and whether I've edited them without publishing.
- **Weekly update:** whether the "Claude rules weekly update" task is set up and ran lately without problems.
- **Projects:** which folders in my projects folder have changes that aren't backed up to GitHub yet.
- **Plugins and tools:** whether each one switched on in my `plugins.json` is installed and current.

Buttons: **Update now** runs my setup script, **Ask Claude** fills in a request for whatever needs fixing, **What's new** shows what changed in my rules, **Details** shows everything (also `/setup-status`), and **Projects** downloads any of my GitHub projects onto this computer, at the version I pick.

It reads my settings from `~\.claude\claude-rules\settings.json`, which `Get-ClaudeRules.ps1` puts there. It's listed in my `plugins.json`, so every computer of mine gets it.

## Changing it

Ask Claude, for example *"make my setup band show only problems"* or *"add a button to setup-band that…"*. Claude edits it here, raises `version` in `.claude-plugin/plugin.json` (installed copies only update when it changes), and pushes. Checks: `claude plugin validate .` and `claude plugin test .`.

Settings (in Claude's plugin settings): what it shows (everything, or problems only), how often it checks, and pop-ups for new problems.

## License

MIT: free for anyone to use, change and share. See [LICENSE](LICENSE).
