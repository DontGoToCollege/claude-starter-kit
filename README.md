# Claude starter kit

A ready-made way of working with Claude on Windows: every project gets its own folder, a version number, a backup on GitHub and a download page, and Claude follows the same rules every time, on every computer you use.

You set it up once by double-clicking one file. After that you just talk to Claude ("make me a little app that renames my photos"), and it handles the folders, versions and backups for you.

## What you need

- Windows 10 or 11
- The **Claude** desktop app, installed and signed in
- A **GitHub** account. It's free: make one at [github.com/signup](https://github.com/signup) if you don't have one. GitHub is where your rules and projects are backed up.

Setup offers to install anything else it needs (GitHub's own tool, Git and Node.js). It asks first each time; type `y` and press Enter.

## Set it up

1. Open the [latest release](https://github.com/DontGoToCollege/claude-starter-kit/releases/latest) and download **Setup.cmd**.
2. Double-click it. If Windows shows a blue **"Windows protected your PC"** box, click **More info**, then **Run anyway**. Windows does that for any downloaded script.
3. If it says you're not signed in to GitHub, a browser window opens: sign in, and type in the code the black window shows.
4. The first time, it asks you three questions. Press Enter to take the suggested answer in [brackets]:
   - **Where your projects live.** The suggestion is a `Claude Projects` folder in your user folder.
   - **Public or private** for the projects Claude backs up to GitHub. See below before you answer.
   - **Anything Claude must never touch.** It shows the names of your GitHub repos and project folders; type any you want left alone for good, separated by commas, or just press Enter.
5. When it says **All set**, start a new chat in Claude.

If something goes wrong, it says what in one red sentence and nothing is lost. Fix that if you can, then double-click `Setup.cmd` again. Running it again is always safe.

## Public or private? Read this first

Every project Claude makes for you gets its own GitHub repo. You choose what that means:

- **Private** (the suggestion): only you can see your projects on GitHub.
- **Public**: **anyone on the internet can see and download your project's code.** That's great for sharing things with friends, but don't pick it if your projects might hold anything personal.

You can change your mind later: ask Claude *"make new projects private from now on"*, or *"make my PhotoRenamer repo public"* for just one. Either way, Claude checks for passwords, keys and personal details before anything goes to GitHub.

## What you get

- **Your rules.** A file called `CLAUDE.md` that tells Claude how you work. It's saved in your own private GitHub repo called `claude-rules`, so every computer of yours uses the same rules. Every version is kept.
- **A status line above the prompt in Claude** (the "setup band"). It shows whether your rules are current and your projects are backed up, with buttons for whatever needs you. **Projects** downloads any of your GitHub projects onto this computer.
- **Ponytail**, a Claude plugin that keeps the code Claude writes short and simple.
- **A weekly update.** A Windows task called *Claude rules weekly update* runs every Sunday at noon (or at the next start if the computer was off) and keeps everything current by itself.

## Using it

Just ask Claude for what you want, in plain words. A few examples:

- *"Make me a small app that resizes all the photos in a folder."* Claude makes the project's folder, writes it, gives it version 1.0.0, backs it up to GitHub and makes a download page.
- *"Add a dark mode and release it."* The new version goes up, and the old one is kept.
- *"What are my plugins?"*, or *"Add my Taxes folder to my hands-off list."*
- *"Change my rules so you always explain things in simple words."* Claude edits your rules, raises their version and backs them up.

## Bringing your existing projects in

Your older projects stay exactly as they are: Claude won't touch anything that existed before you set this up. To bring one in, ask for it by name, one at a time:

> *Bring my PhotoRenamer project into my setup. It's in Documents\PhotoRenamer.*

Claude copies it into its own folder in your projects folder (and asks before moving or deleting the original), adds a version number, a README and a license, then shows you what will go to GitHub before the first backup.

Anything you **never** want Claude to touch, even by mistake (say, a work repo, or a folder of personal papers), goes on your hands-off list. Name it in setup's third question, or ask Claude later: *"Add Taxes to my hands-off list."*

## On another computer

Double-click `Setup.cmd` there too and sign in with the same GitHub account. It finds your `claude-rules` repo and asks nothing: your rules, settings and plugins come along by themselves.

## Good to know

- **Who updates what.** Your rules and settings are yours, in your private repo. The setup scripts and the setup band come from this starter kit, and the weekly update installs its newest release without asking. So only use this kit if you trust the person who runs it.
- **If you already had rules**, setup keeps your old `CLAUDE.md` next to the new one as `CLAUDE.md.bak-<date>`, in `C:\Users\<you>\.claude`. Ask Claude to merge anything you want to keep.
- **To stop the weekly update**, open Task Scheduler and delete *Claude rules weekly update*. To stop the setup band, turn it off in Claude's plugin settings, or ask Claude to switch it off in your `plugins.json`.
- **Where things are:** your rules at `C:\Users\<you>\.claude\CLAUDE.md`; your settings, the scripts and the weekly update's log (`last-run.log`) in `C:\Users\<you>\.claude\claude-rules\`.

## What's in this repo

| File | What it's for |
|---|---|
| `Setup.cmd` | The one file you download: gets the newest setup and runs it |
| `Get-ClaudeRules.ps1` | The setup itself, and what the weekly update runs |
| `Publish-ClaudeRules.ps1` | Backs up a new version of your rules to your repo |
| `template/` | What your own `claude-rules` repo starts with |
| `band/` | The setup band, a Claude plugin |
| `build.ps1` | For whoever runs the kit: archives a version before it's released |

## License

MIT: free for anyone to use, change and share. See [LICENSE](LICENSE).
