# claude-rules

My rules for Claude (`CLAUDE.md`), my settings, and the scripts that set up any computer of mine the same way. Private on purpose.

## Set up a computer

Open this repo's [latest release](https://github.com/{{RULES_REPO}}/releases/latest), download `Get-ClaudeRules.cmd` and `Get-ClaudeRules.ps1` into the same folder, and double-click `Get-ClaudeRules.cmd`. Sign in to GitHub as {{GITHUB_NAME}} when it asks.

It installs what's missing (it asks first), then sets up my rules, settings, plugins, tool servers and a weekly update. When it says **All set**, start a new chat in Claude. If something goes wrong it says what in one red sentence and nothing is lost: fix that and run it again. Running it again is always safe.

If Windows shows a blue "Windows protected your PC" box, click **More info**, then **Run anyway**.

## What's here

| File | What it's for |
|---|---|
| `CLAUDE.md` | My rules: how Claude works for me |
| `settings.json` | My projects folder, public or private for new projects, and things Claude must never touch (`handsOff`) |
| `plugins.json` | The plugins, tool servers (MCP) and tools every computer of mine gets, each on or off |
| `Get-ClaudeRules.cmd` / `.ps1` | Sets up a computer; the weekly update runs it too |
| `Publish-ClaudeRules.ps1` | Backs up a new version of my rules and settings |
| `Versions/Archive/` | Every version of my rules |

## Changing things

Ask Claude in a chat, for example *"add my Taxes folder to my hands-off list"*, *"add the X plugin to every computer"* or *"change my rules so you always explain things simply"*. Claude edits the file, raises the rules version and publishes it.

## License

MIT: free for anyone to use, change and share. See [LICENSE](LICENSE).
