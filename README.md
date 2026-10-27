# Claude starter kit

A ready-made way of working with Claude on Windows: every project gets its own folder, a version number, a backup on GitHub and a download page, and Claude follows the same rules every time, on every computer you use.

You run it once. It gives you your own copy of everything, on your own GitHub account: your rules, your settings, the scripts that set up and update your computers, and a status band for Claude. After that you never need this kit again. It's all yours to change, and you change it by asking Claude.

## What you need

- Windows 10 or 11
- The **Claude** desktop app, installed and signed in
- A **GitHub** account. It's free: make one at [github.com/signup](https://github.com/signup) if you don't have one. GitHub is where your rules and projects are backed up.

Setup offers to install anything else it needs (GitHub's own tool, Git and Node.js). It asks first each time; type `y` and press Enter.

## Set it up

1. Open the [latest release](https://github.com/DontGoToCollege/claude-starter-kit/releases/latest) and download **Setup.cmd**.
2. Double-click it. If Windows shows a blue **"Windows protected your PC"** box, click **More info**, then **Run anyway**. Windows does that for any downloaded script.
3. If it says you're not signed in to GitHub, a browser window opens: sign in, and type in the code the black window shows.
4. It asks you three questions. Press Enter to take the suggested answer in [brackets]:
   - **Where your projects live.** The suggestion is a `Claude Projects` folder in your user folder.
   - **Public or private** for the projects Claude backs up to GitHub. See below before you answer.
   - **Anything Claude must never touch.** It shows the names of your GitHub repos and project folders; type any you want left alone for good, separated by commas, or just press Enter.
5. When it says **All set**, start a new chat in Claude.

If something goes wrong, it says what in one red sentence and nothing is lost. Fix that if you can, then double-click `Setup.cmd` again. Running it again is always safe: it keeps whatever it already made and adds only what's missing.

## Public or private? Read this first

Every project Claude makes for you gets its own GitHub repo. You choose what that means:

- **Private** (the suggestion): only you can see your projects on GitHub.
- **Public**: **anyone on the internet can see and download your project's code.** That's great for sharing things with friends, but don't pick it if your projects might hold anything personal.

You can change your mind later: ask Claude *"make new projects private from now on"*, or *"make my PhotoRenamer repo public"* for just one. Either way, Claude checks for passwords, keys and personal details before anything goes to GitHub.

## What you get

Two repos on your GitHub account, both also downloaded into your projects folder:

- **`claude-rules`** (always private). Holds:
  - **your rules** (`CLAUDE.md`): how Claude works for you, every version kept
  - **your settings**: your projects folder, public or private, and your hands-off list
  - **your plugin list** (`plugins.json`): the Claude plugins, tool servers and tools every computer of yours gets
  - **your own setup script** (`Get-ClaudeRules.cmd`): sets up any computer of yours and keeps it up to date
- **`setup-band`**, a Claude plugin of your own. It's a line above the prompt in Claude that shows whether your rules are current and your projects are backed up, with buttons for whatever needs you. **Projects** downloads any of your GitHub projects onto this computer.

Plus, on this computer:

- **Ponytail**, a Claude plugin that keeps the code Claude writes short and simple.
- **A weekly update.** A Windows task called *Claude rules weekly update* runs your own setup script every Sunday at noon (or at the next start if the computer was off). It brings this computer in line with your repos: your newest rules, plugins and tool servers.

## Using it

Just ask Claude for what you want, in plain words. A few examples:

- *"Make me a small app that resizes all the photos in a folder."* Claude makes the project's folder, writes it, gives it version 1.0.0, backs it up to GitHub and makes a download page.
- *"Add a dark mode and release it."* The new version goes up, and the old one is kept.
- *"Change my rules so you always explain things in simple words."* Claude edits your rules, raises their version and backs them up.
- *"What are my plugins?"*, or *"Add my Taxes folder to my hands-off list."*

## Making it your own

All of it is yours, so Claude can change any of it for you:

- **Plugins:** *"add the X plugin to all my computers"*. It goes in your `plugins.json`, and every computer gets it on its next update.
- **Tool servers (MCP)**, which give Claude new abilities: *"add the X tool server to my setup"*. They also go in `plugins.json`, and your setup script adds them to Claude on every computer. Connectors you add in Claude's own settings (like Gmail or Google Drive) already follow your Claude account everywhere, so they need nothing here.
- **Bands and other mods:** *"make me a band that shows…"*, or *"change my setup band to show only problems"*. Each mod gets its own project and repo, just like `setup-band`.
- **The setup itself:** *"make my setup script also install X"*. Anything a new computer needs goes into your own script.

## Bringing your existing projects in

Your older projects stay exactly as they are: Claude won't touch anything that existed before you set this up. To bring one in, ask for it by name, one at a time:

> *Bring my PhotoRenamer project into my setup. It's in Documents\PhotoRenamer.*

Claude copies it into its own folder in your projects folder (and asks before moving or deleting the original), adds a version number, a README and a license, then shows you what will go to GitHub before the first backup.

Anything you **never** want Claude to touch, even by mistake (say, a work repo, or a folder of personal papers), goes on your hands-off list. Name it in setup's third question, or ask Claude later: *"Add Taxes to my hands-off list."*

## On another computer

Open your own `claude-rules` repo on GitHub, go to its latest release, download `Get-ClaudeRules.cmd` and `Get-ClaudeRules.ps1` into the same folder, and double-click `Get-ClaudeRules.cmd`. Sign in with the same GitHub account. Your rules, settings, plugins and tool servers come along. (Double-clicking this kit's `Setup.cmd` there works too: it finds your repos and asks nothing.)

## Good to know

- **Nothing keeps coming from this kit.** After setup, your computers update only from your own repos. If this kit changes later, you don't get those changes, and you don't need them.
- **If you already had rules**, setup keeps your old `CLAUDE.md` next to the new one as `CLAUDE.md.bak-<date>`, in `C:\Users\<you>\.claude`. Ask Claude to merge anything you want to keep.
- **To stop the weekly update**, open Task Scheduler and delete *Claude rules weekly update*. To stop the setup band, ask Claude to switch it off in your `plugins.json`.
- **Where things are:** your rules at `C:\Users\<you>\.claude\CLAUDE.md`; your settings, the saved setup script and the weekly update's log (`last-run.log`) in `C:\Users\<you>\.claude\claude-rules\`.

## What's in this repo

| File | What it's for |
|---|---|
| `Setup.cmd` | The one file you download: gets the newest setup and runs it |
| `Setup.ps1` | The one-time setup: asks the questions and makes your two repos |
| `template/rules/` | What your `claude-rules` repo starts with, including your own setup and publish scripts |
| `template/band/` | What your `setup-band` repo starts with |
| `build.ps1` | For whoever runs the kit: archives a version before it's released |

## License

MIT: free for anyone to use, change and share. See [LICENSE](LICENSE).
