# How I work

Rules version: 1.0.0

My GitHub account is `{{GITHUB_NAME}}`. Everything below is mine to change: the rules, the settings, the setup scripts and the band all live in my own repos.

## This file's backup
- This file is backed up in my **private** repo `github.com/{{RULES_REPO}}`, with every version kept in `Versions/Archive`. My settings (projects folder, public or private, hands-off list) are in `~\.claude\claude-rules\settings.json`, backed up in the same repo.
- After any change to this file or to `settings.json`: raise the `Rules version` line above, then run `Publish-ClaudeRules.ps1` from the repo folder (`{{PROJECTS_FOLDER}}\claude-rules`; on a computer without it, run `gh repo clone {{RULES_REPO}}` there first). It archives the version, pushes it and makes a Release. Publish before running `Get-ClaudeRules.ps1`, or the script replaces the unpublished edits with GitHub's copy (it keeps them as `CLAUDE.md.bak-<date>`).
- To set up a computer, or bring it up to date, run `Get-ClaudeRules.cmd` from my rules repo's latest Release (or `Get-ClaudeRules.ps1 -Version 1.0.0` for an older version of the rules). It backs up the local copies before replacing them.
- `Get-ClaudeRules.cmd` is the one thing I run on a new computer: it installs what's missing (GitHub CLI, Git, Node.js) after a y/n, signs in, sets git's name and email, and sets up everything below. Keep it that way: anything new a computer needs goes into the script, explained in plain words, never into a manual step. Failures end in one plain sentence (its `trap`), and running it again is always safe. After changing the script, commit and push it in my rules repo; the weekly task picks up the newest copy.
- `plugins.json` in my rules repo is the master list of what every computer of mine gets, and every computer follows it when the script runs:
  - **Plugins:** each one under `enabledPlugins` is `true` (on) or `false` (off). To add one, put its marketplace under `extraKnownMarketplaces` with `"autoUpdate": true` and its name under `enabledPlugins` as `true`.
  - **Tool servers (MCP):** each one under `mcpServers` has `"on": true` or `false` and its `"config"` (for example `{ "type": "stdio", "command": "npx", "args": ["-y", "<package>"] }`). The script adds the ones that are on to Claude for every chat and takes out the ones that are off. Never put a password, key or token in `config`: ask me to enter it on each computer instead. Connectors added in Claude's own settings belong to my Claude account and follow me to every computer by themselves, so they don't go here.
  - **Tools** that are neither (like REA, under `tools`) also need an install-or-update step in `Get-ClaudeRules.ps1`.
  - When I stop using something, set it to `false` and push. Never delete its line: the list is my record of everything and its status. When I ask about my plugins or tools, show the list from `plugins.json` with each one's on/off status.
- Mods Claude writes for me (bands, panes, status lines; `setup-band` at `github.com/{{BAND_REPO}}` is the first) are projects like any other: their own folder in the projects folder, their own repo with a `.claude-plugin/marketplace.json` so Claude can install them, and an entry in `plugins.json` with `"autoUpdate": true`. Raise `version` in the mod's `plugin.json` for every change, since installed copies only update when it changes.
  - A mod that draws above the prompt must include `await next(e)` in what it returns, or it hides other mods' bands. On the desktop app, buttons are native and taller than a text row: give them a row of their own, never beside text.
  - setup-band shows above the prompt whether this setup is current and backed up. It reads `~\.claude\claude-rules\settings.json`, and reloads open chats once a newer copy of itself is installed.
- Everything stays current by itself: plugins with `"autoUpdate": true` update inside Claude, and the script sets up a weekly Windows task ("Claude rules weekly update") that runs its newest copy with `-Quiet`. Its log is `~\.claude\claude-rules\last-run.log`. If something seems out of date on a computer, check that log first.

## Where projects live
- Every new project gets its own folder: `{{PROJECTS_FOLDER}}\<Project Name>` (`~` is my user folder).
- If a chat starts in the projects folder itself or in a temporary session folder, create the project's folder and move the session into it before writing any files. Never build a project inside the shared projects folder.

## Versioning
- Every project has a version number in its source (e.g. `VERSION = "1.0.0"`), raised for each release.
- The current release sits at the project root (e.g. `MyApp.exe`). Every build is also kept as `<Project>\Versions\Archive\<Name>-<version>.<ext>`.
- Never overwrite or delete an archived build. Give each project a build step that refuses to rebuild a version that's already archived.

## GitHub (backup and sharing)
- Every project gets its own **{{REPO_VISIBILITY}}** repo at `github.com/{{GITHUB_NAME}}/<Project Name>`, created with the `gh` CLI (already signed in). {{VISIBILITY_NOTE}} The local `Versions\Archive` stays the full archive.
- Commits use my private GitHub address already set in git (`{{NOREPLY_EMAIL}}`); never put a real email in a commit.
- Before every push, check what's going to GitHub: no passwords, keys, tokens, personal paths, Wi-Fi names, IP addresses or personal data in the files.
- Built programs (.exe etc.) never go in the code history: `.gitignore` them along with `Versions/`, and attach each release's program to a GitHub Release instead (`gh release create v<version> <file>`).
- Each project has a plain-language `README.md` (what it is, how to download and use it). Commit and push after each meaningful change, and publish a Release for each new version.
- Every repo is MIT-licensed by default: add a standard MIT `LICENSE` file with "Copyright (c) <year> {{GITHUB_NAME}}" (my GitHub name, not my real name).
- Every `README.md` ends with this exact License section, word for word, with "LICENSE" linking to the repo's `LICENSE` file:

  ```markdown
  ## License

  MIT: free for anyone to use, change and share. See [LICENSE](LICENSE).
  ```

## What Claude may work on
- **New projects are always in scope.** Anything I start with Claude from now on, on any computer, gets the full treatment above (folder, versioning, GitHub repo, releases) with no extra permission needed. This section never blocks new work.
- **Also in scope:** anything I ask Claude to bring into this setup, and anything I ask Claude to work on by name. Bringing a project in means: give it its own folder under the projects folder (copy it there, and ask before moving or deleting the original), then add versioning, a README, a LICENSE and its GitHub repo as above. Show me what will go to GitHub before the first push.
- **Hands off:** things that existed before I set this up ({{START_DATE}}) and haven't been brought in. Never touch these on GitHub or on disk: no cloning, commits, pushes, issues, releases, settings, renames, visibility changes or deletes.
- **Hands-off list:** the names under `handsOff` in `~\.claude\claude-rules\settings.json` are never touched, even if I ask in passing; read it before changing any existing repo or folder. When I say to leave something alone for good, add its name there and publish.
- Ask first only when an *existing* repo or folder that isn't covered above would be changed. Never ask about new work.
