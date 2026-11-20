# claude-starter-kit: notes for Claude

Build, test and release recipes, decisions and gotchas, kept in the repo so every computer has them.

`%USERPROFILE%\Music\Claude\Projects\claude-starter-kit` is the public repo DontGoToCollege/claude-starter-kit, started 2026-10-27. 1.1.0 is current. The owner's own claude-rules and rules-band are separate and untouched.

- **The owner's goal (2026-10-27):** friends run the kit **once** and are then fully self-sufficient. Nothing should keep pulling from the owner (no automations, no update-from-kit). Feedback from friends comes back through the owner.
- **Setup.cmd** (the release asset, CRLF) downloads the latest tag's Setup.ps1 to %TEMP% and runs it.
  - Setup.ps1 asks three questions, or reads settings.json from an existing repo.
  - It makes `<login>/claude-rules` (always private) and `<login>/setup-band` (the friend's public/private choice) from `template/rules` and `template/band`, filling in the `{{BLANKS}}`. It adds only missing files, upgrades a 1.0.0 plugins.json, and makes a v1.0.0 Release.
  - Then it runs the friend's own Get-ClaudeRules.ps1 from their clone.
  - It refuses a claude-rules repo that has no settings.json, which keeps the owner's own repo safe.
- **The friend's Get-ClaudeRules.ps1** is the owner's script made generic. It adds `mcpServers` from plugins.json (`on` + `config`) through `claude mcp add-json`, quoting the command line by hand (Start-Process). PowerShell 5.1 breaks JSON that holds spaces; tested 2026-10-27 with CLAUDE_CONFIG_DIR set to a scratch folder.
- **Release:** raise `$KitVersion` in Setup.ps1, run `.\build.ps1` (archives a zip, refuses an existing one), commit, push, `gh release create v<v> Setup.cmd`.
- **Checks:** fill the templates into scratch, then ParseFile the .ps1 files, and run `claude plugin validate` and `claude plugin test` on the filled band. tsc with a scratch tsconfig (see rules-band-project).

**Why:** a friend gets the kit only once, so a release has to work the first time.
**How to apply:** port the owner's later fixes into template/ only when new friends need them; existing friends never receive them.
