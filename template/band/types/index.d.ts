// A version string like "1.5.0"; null wherever it couldn't be read.
export type ToolVersion = { name: string; installed: string | null; latest: string | null; updatesItself: boolean }

// What changed in the rules between two versions, as whole lines.
export type WhatsNew = { from: string; to: string; added: string[]; removed: string[]; isPreview: boolean }

// A Projects folder, and whether everything in it is committed and pushed.
export type Project = { name: string; isBackedUp: boolean }

// One of your GitHub repos: its release tags, newest first, and whether it's in Projects on this computer.
export type Repo = { name: string; tags: string[]; isHere: boolean }

export type Status = {
  checkedAt: number
  local: string | null
  remote: string | null
  // Local CLAUDE.md differs from GitHub's without being behind it: edited but not published.
  isUnpublished: boolean
  // A plain sentence when the weekly update needs attention, else null.
  weekly: string | null
  weeklyLastRun: number | null
  projects: Project[]
  tools: ToolVersion[]
  // Changes from the last rules update, until you read them.
  whatsNew: WhatsNew | null
}

declare module 'claude-code' {
  interface PluginState {
    // reloadedTo: the version this chat last reloaded plugins for, so it does that once per version.
    // picked: the projects ticked in the Projects pane, each to its chosen release tag ('' when it has none).
    'setup-band': {
      status: Status | null
      isBusy: boolean
      pane: WhatsNew | null
      reloadedTo: string | null
      repos: Repo[] | null
      picked: Record<string, string>
      isGetting: boolean
      getLog: string[]
      // needsSetup: no settings file yet (Get-ClaudeRules.cmd hasn't run on this computer).
      needsSetup: boolean
    }
  }
}
