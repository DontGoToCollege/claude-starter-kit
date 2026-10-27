# How I work

Rules version: 1.0.0

These are my rules for Claude, set up with the Claude starter kit (`github.com/DontGoToCollege/claude-starter-kit`). My GitHub account is `{{GITHUB_NAME}}`.

## These rules' backup
- This file is backed up in my **private** repo `github.com/{{RULES_REPO}}`, with every version kept in `Versions/Archive`. My settings (projects folder, public or private, hands-off list) are in `~\.claude\claude-rules\settings.json`, backed up in the same repo.
- After any change to this file or to `settings.json`: raise the `Rules version` line above, then run `~\.claude\claude-rules\Publish-ClaudeRules.ps1`. It archives the version, pushes it and makes a Release. Publish before running the setup again, or the setup replaces the unpublished edits with GitHub's copy (it keeps them as `CLAUDE.md.bak-<date>`).
- On a new computer I double-click `Setup.cmd` from the starter kit's latest release (`github.com/DontGoToCollege/claude-starter-kit/releases/latest`). It installs what's missing, signs in to GitHub, and sets up these rules, my plugins and a weekly update. Running it again is always safe.
- `plugins.json` in my rules repo lists the Claude plugins and tools every computer of mine gets: each plugin under `enabledPlugins` and each tool under `tools` is `true` (on) or `false` (off). When I add a plugin, add its marketplace under `extraKnownMarketplaces` with `"autoUpdate": true` and its name under `enabledPlugins`. When I stop using one, set it to `false`; never delete its line. Commit and push the change in my rules repo. When I ask about my plugins, show the list with each one's on/off status.
- A weekly Windows task ("Claude rules weekly update") keeps everything current: my newest rules and plugins, and the starter kit's newest scripts. Its log is `~\.claude\claude-rules\last-run.log`. If something seems out of date, check that log first.
- The band above the prompt (setup-band) shows whether all of this is current and backed up.

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
