import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Project, Repo, Status, ToolVersion, WhatsNew } from '../types'

const PROJECTS_PANE = 'setup-projects'
const TASK = 'Claude rules weekly update'
const NEWS_PANE = 'setup-whats-new'
const DETAILS_PANE = 'setup-details'
const TOOLS_EVERY_MS = 30 * 60 * 1000 // tool versions: npm and GitHub lookups
const AFTER_TURN_MS = 60 * 1000 // after a reply: catches rules Claude just published in this chat
const WEEKLY_LATE_DAYS = 8
const NAMES_SHOWN = 5 // longer lists of names end in "and N more"; Details has them all

const status = atom({ plugin: 'setup-band', key: 'status' } as const, null)
const isBusy = atom({ plugin: 'setup-band', key: 'isBusy' } as const, false)
const pane = atom({ plugin: 'setup-band', key: 'pane' } as const, null)
const reloadedTo = atom({ plugin: 'setup-band', key: 'reloadedTo' } as const, null)
const repos = atom({ plugin: 'setup-band', key: 'repos' } as const, null)
const picked = atom({ plugin: 'setup-band', key: 'picked' } as const, {})
const isGetting = atom({ plugin: 'setup-band', key: 'isGetting' } as const, false)
const getLog = atom({ plugin: 'setup-band', key: 'getLog' } as const, [])
const needsSetup = atom({ plugin: 'setup-band', key: 'needsSetup' } as const, false)

type Seen = { version: string; text: string }
type Settings = { owner: string; rulesRepo: string; projectsFolder: string; handsOff: string[] }
// One thing that needs you. `key` stays the same while the problem lasts, so it's announced once.
type Issue = { key: string; text: string; ask?: { label: string; prompt: string } }

const versionIn = (text: string) => text.match(/Rules version: (\d+\.\d+\.\d+)/)?.[1] ?? null
const linesOf = (text: string) => text.replace(/\r/g, '').split('\n').map(l => l.trimEnd())
const isSameText = (a: string, b: string) => linesOf(a).join('\n').trim() === linesOf(b).join('\n').trim()
const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`
const someNames = (names: string[]) =>
  names.length <= NAMES_SHOWN ? names.join(', ') : `${names.slice(0, NAMES_SHOWN).join(', ')} and ${names.length - NAMES_SHOWN} more`

// Relative, so it needs no time zone: "just now", "12 min ago", "3 h ago", "2 days ago".
function ago(ms: number, now: number) {
  const min = Math.floor((now - ms) / 60_000)
  if (min < 1) return 'just now'
  if (min < 60) return `${min} min ago`
  if (min < 48 * 60) return `${Math.floor(min / 60)} h ago`
  return `${Math.floor(min / 1440)} days ago`
}

// Negative when a is older than b.
function compare(a: string, b: string) {
  const x = a.split('.').map(Number)
  const y = b.split('.').map(Number)
  for (let i = 0; i < 3; i++) {
    if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) - (y[i] ?? 0)
  }
  return 0
}

const isNewer = (t: ToolVersion) => t.installed !== null && t.latest !== null && compare(t.installed, t.latest) < 0
// Installed, and either newest or a plugin Claude updates by itself (its wait isn't shown).
const isCurrent = (t: ToolVersion) => t.installed !== null && (t.updatesItself || !isNewer(t))

// Whole lines added and taken out, ignoring the version line itself.
function diff(from: string, fromText: string, to: string, toText: string, isPreview: boolean): WhatsNew {
  const keep = (l: string) => l !== '' && !l.startsWith('Rules version:')
  const a = new Set(linesOf(fromText).filter(keep))
  const b = new Set(linesOf(toText).filter(keep))
  return { from, to, isPreview, added: [...b].filter(l => !a.has(l)), removed: [...a].filter(l => !b.has(l)) }
}

const isBehind = (s: Status) => s.local !== null && s.remote !== null && compare(s.local, s.remote) < 0
const reaOf = (s: Status) => s.tools.find(t => !t.updatesItself)
const reaNeedsUpdate = (s: Status) => {
  const rea = reaOf(s)
  return rea !== undefined && (rea.installed === null || isNewer(rea))
}

// Everything that needs you, in plain words. Plugins that update themselves aren't problems.
function issuesOf(s: Status): Issue[] {
  const issues: Issue[] = []
  if (s.remote === null) {
    issues.push({
      key: 'offline',
      text: "Couldn't reach GitHub to check the rules.",
      ask: { label: 'Ask Claude', prompt: "The rules band can't reach GitHub to check my Claude rules. Find out why and fix it." },
    })
  }
  if (isBehind(s)) issues.push({ key: `behind:${s.remote}`, text: `Rules ${s.remote} is out; this computer has ${s.local}.` })
  if (s.isUnpublished) {
    issues.push({
      key: 'unpublished',
      text: "Your rules have changes that aren't on GitHub yet.",
      ask: { label: 'Ask Claude to publish', prompt: 'Publish my Claude rules changes: raise the Rules version in CLAUDE.md and run ~/.claude/claude-rules/Publish-ClaudeRules.ps1.' },
    })
  }
  if (s.weekly !== null) issues.push({ key: `weekly:${s.weekly}`, text: s.weekly })
  const notBackedUp = s.projects.filter(p => !p.isBackedUp).map(p => p.name)
  if (notBackedUp.length > 0) {
    issues.push({
      key: `backup:${notBackedUp.join(',')}`,
      text: `Not backed up to GitHub: ${someNames(notBackedUp)}.`,
      ask: {
        label: 'Ask Claude to back up',
        prompt: `Back up ${notBackedUp.join(', ')} to GitHub: check what's going public, commit with clear messages and push (create the repo first where there isn't one).`,
      },
    })
  }
  const rea = reaOf(s)
  if (rea !== undefined && reaNeedsUpdate(s)) {
    issues.push({ key: `rea:${rea.latest}`, text: rea.installed === null ? "REA isn't installed." : `REA ${rea.latest} is out: press Update now.` })
  }
  const missing = s.tools.filter(t => t.updatesItself && t.installed === null).map(t => t.name)
  if (missing.length > 0) issues.push({ key: `missing:${missing.join(',')}`, text: `Not installed yet: ${someNames(missing)}. Start a new chat to let Claude install it.` })
  return issues
}

async function run($: EngineInterface, argv: string[], timeoutMs = 30_000) {
  return $.process.run(argv, { timeoutMs }).then(
    r => ({ isOk: r.exitCode === 0, out: r.stdout + r.stderr, stdout: r.stdout }),
    () => ({ isOk: false, out: '', stdout: '' }),
  )
}

// gh is signed in for your repos (Get-ClaudeRules sets it up).
async function ghFile($: EngineInterface, repo: string, path: string) {
  const r = await run($, ['gh', 'api', `repos/${repo}/contents/${path}`, '-H', 'Accept: application/vnd.github.raw'])
  return r.isOk ? r.stdout : null
}

async function homeDir($: EngineInterface) {
  return (await $.env.get('USERPROFILE')) ?? (await $.env.get('HOME')) ?? ''
}

// Written by Setup.cmd on first run; null until then. `projectsFolder` may start with ~ for the home folder.
async function settingsOf($: EngineInterface, home: string): Promise<Settings | null> {
  const text = await $.fs.read(`${home}/.claude/claude-rules/settings.json`).catch(() => null)
  if (text === null) return null
  try {
    const s = JSON.parse(text.replace(/^﻿/, '')) as Partial<Settings>
    if (typeof s.owner !== 'string' || typeof s.projectsFolder !== 'string') return null
    return {
      owner: s.owner,
      rulesRepo: s.rulesRepo ?? `${s.owner}/claude-rules`,
      projectsFolder: s.projectsFolder.replace(/^~(?=[\\/]|$)/, home).replace(/\\/g, '/'),
      // GitHub names ignore case, so the list does too. Never listed, cloned or touched.
      handsOff: (s.handsOff ?? []).map(n => n.toLowerCase()),
    }
  } catch {
    return null
  }
}

// Remembers the rules last seen here; when they move to a newer version, keeps what changed until it's read.
async function trackWhatsNew($: EngineInterface, local: string | null, localText: string | null, remote: string | null, remoteText: string | null) {
  if (local !== null && localText !== null) {
    const seen = (await $.store.get('seen')) as Seen | undefined
    if (seen === undefined || compare(seen.version, local) !== 0) {
      if (seen !== undefined && compare(seen.version, local) < 0) {
        await $.store.set('whatsNew', diff(seen.version, seen.text, local, localText, false))
      }
      await $.store.set('seen', { version: local, text: localText })
    }
  }
  const unread = (await $.store.get('whatsNew')) as WhatsNew | undefined
  if (unread !== undefined) return unread
  // Behind GitHub: a preview of what an update brings.
  if (local !== null && remote !== null && localText !== null && remoteText !== null && compare(local, remote) < 0) {
    return diff(local, localText, remote, remoteText, true)
  }
  return null
}

async function weeklyState($: EngineInterface, home: string, now: number) {
  if (!(await run($, ['schtasks', '/Query', '/TN', TASK])).isOk) {
    return { weekly: "The weekly update isn't set up on this computer.", weeklyLastRun: null }
  }
  const log = `${home}/.claude/claude-rules/last-run.log`
  const stat = await $.fs.stat(log).catch(() => null)
  if (stat === null) return { weekly: null, weeklyLastRun: null } // set up, first run still to come
  const text = await $.fs.read(log).catch(() => '')
  const bad = linesOf(text).find(l => l.startsWith('Something went wrong:') || l.startsWith('Skipped'))
  const days = Math.floor((now - stat.mtimeMs) / 86_400_000)
  const weekly =
    bad !== undefined ? `The last weekly update had a problem: ${bad.replace(/^Something went wrong:\s*/, '')}`
    : days > WEEKLY_LATE_DAYS ? `The weekly update last ran ${days} days ago.`
    : null
  return { weekly, weeklyLastRun: stat.mtimeMs }
}

// Backed up: git has no uncommitted changes and nothing unpushed. All folders at once.
async function projectsIn($: EngineInterface, dir: string): Promise<Project[]> {
  const entries = await $.fs.list(dir).catch(() => [])
  const folders = entries.filter(entry => entry.kind === 'dir' && !entry.name.startsWith('.'))
  return Promise.all(
    folders.map(async entry => {
      const r = await run($, ['git', '-C', `${dir}/${entry.name}`, 'status', '--porcelain', '--branch'])
      const [head = '', ...changes] = r.stdout.split('\n').filter(Boolean)
      return { name: entry.name, isBackedUp: r.isOk && changes.length === 0 && head.includes('...') && !head.includes('[ahead') }
    }),
  )
}

// The newest version folder Claude keeps for a plugin, leaving out ones it has replaced.
async function installedVersion($: EngineInterface, dir: string) {
  const entries = await $.fs.list(dir).catch(() => [])
  const versions = entries.filter(entry => entry.kind === 'dir' && /^\d+\.\d+\.\d+$/.test(entry.name))
  const isLive = await Promise.all(versions.map(entry => $.fs.exists(`${dir}/${entry.name}/.orphaned_at`).then(isOld => !isOld)))
  const live = versions.filter((_, i) => isLive[i]).map(entry => entry.name)
  return live.sort(compare).at(-1) ?? null
}

type PluginList = {
  extraKnownMarketplaces?: Record<string, { source?: { repo?: string } }>
  enabledPlugins?: Record<string, boolean>
  tools?: Record<string, boolean>
}

async function pluginVersion($: EngineInterface, home: string, list: PluginList, id: string): Promise<ToolVersion> {
  const [name = id, market = ''] = id.split('@')
  const repo = list.extraKnownMarketplaces?.[market]?.source?.repo
  const [installed, latest] = await Promise.all([
    installedVersion($, `${home}/.claude/plugins/cache/${market}/${name}`),
    repo === undefined ? Promise.resolve(null) : latestPluginVersion($, repo, name).catch(() => null),
  ])
  return { name, installed, latest, updatesItself: true }
}

// The version on GitHub. A marketplace can keep the plugin in a subfolder, as the starter kit keeps this band in band/.
async function latestPluginVersion($: EngineInterface, repo: string, name: string) {
  const market = await ghFile($, repo, '.claude-plugin/marketplace.json')
  const plugins = market === null ? [] : ((JSON.parse(market) as { plugins?: { name: string; source?: unknown }[] }).plugins ?? [])
  const source = plugins.find(p => p.name === name)?.source
  const dir = typeof source === 'string' ? source.replace(/^\.\/?/, '').replace(/\/$/, '') : ''
  const manifest = await ghFile($, repo, dir === '' ? '.claude-plugin/plugin.json' : `${dir}/.claude-plugin/plugin.json`)
  return manifest === null ? null : ((JSON.parse(manifest) as { version?: string }).version ?? null)
}

async function reaVersion($: EngineInterface): Promise<ToolVersion> {
  const appData = (await $.env.get('APPDATA')) ?? ''
  const [installed, latest] = await Promise.all([
    $.fs.read(`${appData}/npm/node_modules/rea-agents/package.json`).then(t => (JSON.parse(t) as { version?: string }).version ?? null, () => null),
    run($, ['cmd', '/d', '/c', 'npm', 'view', 'rea-agents', 'version'], 60_000),
  ])
  return { name: 'REA', installed, latest: latest.isOk ? latest.stdout.trim() || null : null, updatesItself: false }
}

// What plugins.json switches on, installed here against newest; every lookup at once.
async function toolVersions($: EngineInterface, home: string, rulesRepo: string) {
  const text = await ghFile($, rulesRepo, 'plugins.json')
  if (text === null) return null
  const list = JSON.parse(text) as PluginList
  const ids = Object.entries(list.enabledPlugins ?? {}).filter(([, isOn]) => isOn).map(([id]) => id)
  return Promise.all([
    ...(list.tools?.rea === true ? [reaVersion($)] : []),
    ...ids.map(id => pluginVersion($, home, list, id)),
  ])
}

let checkedAt = -Infinity
let toolsAt = -Infinity
let tools: ToolVersion[] = []
let notify = true
// The chat's own replies under way (not subagents'): plugins are only reloaded between them.
const runningTurns = new Set<string>()

// When Claude has installed a newer copy of this band than the one this chat runs (the weekly update, Update now,
// or another chat), reloads plugins so a chat left open picks the update up. Only for an installed copy, whose
// folder ends in its version: a working copy is read from its own folder and needs no reload.
async function reloadIfNewer($: EngineInterface) {
  const root = $.plugin.root.replace(/\\/g, '/')
  const running = root.match(/\/plugins\/cache\/[^/]+\/[^/]+\/(\d+\.\d+\.\d+)$/)?.[1]
  if (running === undefined || runningTurns.size > 0) return
  const newest = await installedVersion($, root.slice(0, root.lastIndexOf('/')))
  if (newest === null || compare(running, newest) >= 0 || (await read($, reloadedTo)) === newest) return
  await update($, reloadedTo, () => newest)
  $.ui.toast(`setup-band ${newest} is installed: reloading this chat's plugins.`)
  await $.command.run({ command: 'reload-plugins', args: '--force' }).catch(() => undefined)
}

// `mayReload`: only from the timer or a button, never while a hook of a reply is running.
async function check($: EngineInterface, withTools: boolean, mayReload = false) {
  const now = await $.clock.now()
  checkedAt = now
  const home = await homeDir($)
  const settings = await settingsOf($, home)
  await update($, needsSetup, () => settings === null)
  if (settings === null) return
  const toolsDue = withTools || now - toolsAt > TOOLS_EVERY_MS
  if (toolsDue) toolsAt = now
  const [localText, remoteText, weekly, projects, freshTools] = await Promise.all([
    $.fs.read(`${home}/.claude/CLAUDE.md`).catch(() => null),
    ghFile($, settings.rulesRepo, 'CLAUDE.md'),
    weeklyState($, home, now),
    projectsIn($, settings.projectsFolder),
    toolsDue ? toolVersions($, home, settings.rulesRepo).catch(() => null) : Promise.resolve(null),
  ])
  tools = freshTools ?? tools
  const local = localText === null ? null : versionIn(localText)
  const remote = remoteText === null ? null : versionIn(remoteText)
  const isUnpublished =
    localText !== null && remoteText !== null && !isSameText(localText, remoteText) &&
    (local === null || remote === null || compare(local, remote) >= 0)
  const found: Status = {
    checkedAt: now,
    local,
    remote,
    isUnpublished,
    ...weekly,
    projects,
    tools,
    whatsNew: await trackWhatsNew($, local, localText, remote, remoteText),
  }
  await update($, status, () => found)
  await announce($, issuesOf(found))
  if (mayReload) await reloadIfNewer($)
}

// A pop-up for each problem the first time it's seen (not for a dropped connection), once.
async function announce($: EngineInterface, issues: Issue[]) {
  const told = ((await $.store.get('told')) as string[] | undefined) ?? []
  const fresh = issues.filter(i => i.key !== 'offline' && !told.includes(i.key))
  if (notify && fresh.length > 0) {
    $.ui.toast(fresh.length === 1 ? `Claude setup: ${fresh[0]?.text}` : `Claude setup: ${plural(fresh.length, 'thing')} need you; see the band above the prompt.`)
  }
  // Only problems still there are remembered, so one that comes back is announced again.
  await $.store.set('told', issues.map(i => i.key))
}

// The always-there button: runs the same script the weekly task runs (logging where the task logs), then checks
// everything again at once. With `isCheckOnly` (unpublished rule edits, which the script would replace) it only checks.
async function updateNow($: EngineInterface, isCheckOnly: boolean) {
  if (await read($, isBusy)) return
  await update($, isBusy, () => true)
  const dir = `${await homeDir($)}/.claude/claude-rules`
  let note = ''
  if (!isCheckOnly) {
    if (await $.fs.exists(`${dir}/Get-ClaudeRules.ps1`)) {
      const r = await run($, ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', `${dir}/Get-ClaudeRules.ps1`, '-Quiet'], 600_000)
      await $.fs.write(`${dir}/last-run.log`, r.out).catch(() => undefined)
      if (!r.isOk) note = 'The update ran into a problem: the band says what.'
      else if (/Installed rules|Set plugins|Set up REA/.test(r.out)) note = 'Updated. A new chat loads any new plugin or REA version.'
    } else {
      note = 'Run Setup.cmd once on this computer first.'
    }
  }
  await check($, true, true)
  const s = await read($, status)
  const count = s === null ? 0 : issuesOf(s).length
  $.ui.toast(note !== '' ? note : count === 0 ? 'Checked: all good.' : `Checked: ${plural(count, 'thing')} need you.`)
  await update($, isBusy, () => false)
}

// Puts a request in the prompt box for you to read and send; keeps anything already typed.
async function askClaude($: EngineInterface, prompt: string) {
  const { text } = await $.prompt.read()
  await $.prompt.fill({ text: text.trim() === '' ? prompt : `\n${prompt}`, mode: 'append' })
}

async function openWhatsNew($: EngineInterface, news: WhatsNew) {
  await update($, pane, () => news)
  await $.ui.open({ id: NEWS_PANE, title: `${news.isPreview ? "What's in" : "What's new in"} rules ${news.to}` })
  if (!news.isPreview) {
    await $.store.delete('whatsNew')
    await update($, status, s => (s === null ? s : { ...s, whatsNew: null }))
  }
}

// The version of the band this chat runs, from its own manifest.
async function runningVersion($: EngineInterface) {
  return $.fs
    .read(`${$.plugin.root}/.claude-plugin/plugin.json`)
    .then(t => (JSON.parse(t) as { version?: string }).version ?? '?', () => '?')
}

async function openDetails($: EngineInterface) {
  await $.ui.open({ id: DETAILS_PANE, title: 'Claude setup' })
}

// The Details pane: everything the band knows, as Markdown tables.
function detailsOf(s: Status, now: number, running: string) {
  const rulesState = s.remote === null ? "couldn't check GitHub" : s.isUnpublished ? 'edited, not published' : isBehind(s) ? 'behind' : '✓'
  const weeklyState = s.weekly ?? (s.weeklyLastRun === null ? 'set up; first run still to come' : '✓')
  const toolRows = s.tools.map(t => {
    const state = t.installed === null ? 'not installed' : isCurrent(t) ? '✓' : `${t.latest} is out: press Update now`
    return `| ${t.name} | ${t.installed ?? '-'} | ${state} |`
  })
  const backedUp = s.projects.filter(p => p.isBackedUp).length
  const projectRows = [...s.projects]
    .sort((a, b) => Number(a.isBackedUp) - Number(b.isBackedUp) || a.name.localeCompare(b.name))
    .map(p => `| ${p.name} | ${p.isBackedUp ? '✓' : 'not backed up'} |`)
  return [
    `**Rules:** ${s.local ?? 'none'} here, ${s.remote ?? '?'} on GitHub · ${rulesState}`,
    '',
    `**Weekly update:** ${s.weeklyLastRun === null ? 'no run yet' : `last ran ${ago(s.weeklyLastRun, now)}`} · ${weeklyState}`,
    '',
    `**Last checked:** ${ago(s.checkedAt, now)} · this chat runs setup-band ${running}`,
    '',
    `**Plugins and tools** (${s.tools.filter(isCurrent).length} of ${s.tools.length} current)`,
    '',
    '| Name | Version | |',
    '|---|---|---|',
    ...toolRows,
    '',
    `**Projects** (${backedUp} of ${s.projects.length} backed up)`,
    '',
    '| Project | |',
    '|---|---|',
    ...projectRows,
  ].join('\n')
}

const linesIn = (text: string) => text.split('\n').map(l => l.trim()).filter(Boolean)

// Your GitHub repos (hands-off ones left out), each with its release tags; every lookup at once.
async function loadRepos($: EngineInterface) {
  const settings = await settingsOf($, await homeDir($))
  if (settings === null) {
    await update($, getLog, () => ['Run Setup.cmd once on this computer first.'])
    await update($, repos, r => r ?? [])
    return
  }
  const { owner, handsOff, projectsFolder: dir } = settings
  const list = await run($, ['gh', 'repo', 'list', owner, '--limit', '200', '--json', 'name', '--jq', '.[].name'], 60_000)
  if (!list.isOk) {
    await update($, getLog, () => ["Couldn't reach GitHub to list your projects."])
    await update($, repos, r => r ?? [])
    return
  }
  const names = linesIn(list.stdout).filter(n => !handsOff.includes(n.toLowerCase())).sort((a, b) => a.localeCompare(b))
  const found: Repo[] = await Promise.all(
    names.map(async name => {
      const [tags, isHere] = await Promise.all([
        run($, ['gh', 'release', 'list', '-R', `${owner}/${name}`, '--limit', '50', '--json', 'tagName', '--jq', '.[].tagName'], 60_000),
        $.fs.exists(`${dir}/${name}`),
      ])
      // GitHub lists releases by when each was made, which isn't always version order.
      const newestFirst = (a: string, b: string) => compare(b.replace(/^v/, ''), a.replace(/^v/, ''))
      return { name, tags: tags.isOk ? linesIn(tags.stdout).sort(newestFirst) : [], isHere }
    }),
  )
  await update($, repos, () => found)
}

async function openProjects($: EngineInterface) {
  await $.ui.open({ id: PROJECTS_PANE, title: 'Get projects' })
  void loadRepos($)
}

// One project into Projects: cloned, or its code brought up to date when nothing in it is unsaved; then the chosen
// release's programs to the project root, each also kept in Versions/Archive (never overwriting one there).
async function getProject($: EngineInterface, owner: string, dir: string, name: string, tag: string) {
  const path = `${dir}/${name}`
  const repo = `${owner}/${name}`
  let code: string
  if (!(await $.fs.exists(path))) {
    if (!(await run($, ['gh', 'repo', 'clone', repo, path], 600_000)).isOk) return `${name}: couldn't download it.`
    code = 'downloaded'
  } else {
    const changes = await run($, ['git', '-C', path, 'status', '--porcelain'])
    code =
      !changes.isOk ? 'not a git folder, code left as is'
      : changes.stdout.trim() !== '' ? 'has unsaved changes, code left as is'
      : (await run($, ['git', '-C', path, 'pull', '--ff-only'], 300_000)).isOk ? 'code up to date'
      : "couldn't update the code"
  }
  if (tag === '') return `${name}: ${code}.`
  const assets = await run($, ['gh', 'release', 'view', tag, '-R', repo, '--json', 'assets', '--jq', '.assets[].name'], 60_000)
  const version = tag.replace(/^v/, '')
  const got: string[] = []
  for (const asset of linesIn(assets.stdout)) {
    const dot = asset.lastIndexOf('.')
    const archived = `${path}/Versions/Archive/${dot > 0 ? `${asset.slice(0, dot)}-${version}${asset.slice(dot)}` : `${asset}-${version}`}`
    if (!(await $.fs.exists(archived))) {
      await run($, ['gh', 'release', 'download', tag, '-R', repo, '-p', asset, '-O', archived], 600_000)
    }
    const r = await run($, ['gh', 'release', 'download', tag, '-R', repo, '-p', asset, '-O', `${path}/${asset}`, '--clobber'], 600_000)
    if (r.isOk) got.push(asset)
  }
  const program = !assets.isOk ? `couldn't read release ${tag}` : got.length > 0 ? `${got.join(', ')} ${version}` : `no program in ${tag}`
  return `${name}: ${code}; ${program}.`
}

// The Run button: each ticked project in turn, a line each as it finishes.
async function getPicked($: EngineInterface) {
  if (await read($, isGetting)) return
  const chosen = Object.entries(await read($, picked))
  const settings = await settingsOf($, await homeDir($))
  if (chosen.length === 0 || settings === null) return
  await update($, isGetting, () => true)
  await update($, getLog, () => [])
  for (const [name, tag] of chosen) {
    const line = await getProject($, settings.owner, settings.projectsFolder, name, tag)
    await update($, getLog, log => [...log, line])
  }
  await update($, isGetting, () => false)
  $.ui.toast(`Got ${plural(chosen.length, 'project')}: see the Get projects pane.`)
  await loadRepos($)
  void check($, false)
}

export const register: Register = (on, options) => {
  const everyMs = Math.max(1, Number(options.checkMinutes ?? 5)) * 60 * 1000
  const isProblemsOnly = options.show === 'problems only'
  notify = options.notify !== false

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'setup-status', description: 'Show the Claude setup details: rules, weekly update, plugins, tools and backups' })
    runningTurns.clear()
    void check($, true)
    $.clock.every(everyMs, () => void check($, false, true))
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined) runningTurns.add(e.turnId)
    return next(e)
  })

  on('command.run', { command: 'setup-status' }, async $ => {
    await openDetails($)
    return { text: 'Opened the Claude setup details.' }
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) runningTurns.delete(e.turnId)
    const done = await next(e)
    if ((await $.clock.now()) - checkedAt > AFTER_TURN_MS) await check($, false)
    return done
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    if (await read($, needsSetup)) {
      return (
        <Box flexDirection="column">
          {await next(e)}
          <Text color="warning">Claude setup isn't finished on this computer: run Setup.cmd from the starter kit once.</Text>
        </Box>
      )
    }
    const s = await read($, status)
    if (s === null) return next(e)
    const issues = issuesOf(s)
    const isFine = issues.length === 0
    if (isFine && isProblemsOnly && s.whatsNew === null) return next(e)

    const busy = await read($, isBusy)

    // A count for the tools that are current; the rest have their own issue line.
    const current = s.tools.filter(isCurrent).length
    const toolsText = current > 0 ? `${plural(current, 'tool')} current` : ''

    const news = s.whatsNew
    // A desktop draws every Button as a native button, taller than a text row, so buttons never share a row
    // with text: they all go in one spaced row of their own, wrapping when there are many.
    const buttons = [
      busy ? (
        <Text dimColor>{s.isUnpublished ? 'Checking…' : 'Updating…'}</Text>
      ) : (
        <Button
          key="update"
          label={s.isUnpublished ? 'Check now' : 'Update now'}
          onPress={() => updateNow($, s.isUnpublished)}
        />
      ),
      ...issues.map(issue => {
        const ask = issue.ask
        return ask === undefined ? null : <Button key={`ask-${issue.key}`} label={ask.label} onPress={() => askClaude($, ask.prompt)} />
      }),
      news !== null && (
        <Button
          key="whats-new"
          label={`${news.isPreview ? "What's in" : "What's new in"} ${news.to}`}
          onPress={() => openWhatsNew($, news)}
        />
      ),
      <Button key="details" label="Details" onPress={() => openDetails($)} />,
      <Button key="projects" label="Projects" onPress={() => openProjects($)} />,
    ]

    return (
      <Box flexDirection="column">
        {await next(e)}
        <Text dimColor>
          Rules {s.local ?? 'unknown'}
          {toolsText !== '' && ` · ${toolsText}`}
          {isFine && <Text color="success"> · ✓ all good</Text>}
        </Text>
        {issues.map(issue => (
          <Text color="warning">{issue.text}</Text>
        ))}
        <Box flexDirection="row" flexWrap="wrap" alignItems="center" gap={1} marginTop={1}>
          {buttons}
        </Box>
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: NEWS_PANE }, async ($, e) => {
    const news = await read($, pane)
    const { Markdown, Text } = $.ui.resolve(e)
    if (news === null) return <Text dimColor>Nothing new.</Text>
    const parts = [
      `**Rules ${news.from} → ${news.to}**${news.isPreview ? ' (comes with the next update)' : ''}`,
      news.added.length > 0 ? `\n**New or changed:**\n\n${news.added.join('\n')}` : '',
      news.removed.length > 0 ? `\n**Taken out:**\n\n${news.removed.join('\n')}` : '',
      news.added.length + news.removed.length === 0 ? '\nOnly the version number changed.' : '',
    ]
    return <Markdown text={parts.join('\n')} />
  })

  on('ui.render', { component: 'Pane', requestId: DETAILS_PANE }, async ($, e) => {
    const s = await read($, status)
    const { Markdown, Text } = $.ui.resolve(e)
    if (s === null) return <Text dimColor>Still checking…</Text>
    return <Markdown text={detailsOf(s, await $.clock.now(), await runningVersion($))} />
  })

  // A row per project: a tick box (a Button; there is no checkbox element) and, where it has releases, which one.
  // Picking a version ticks the project too. The mobile app draws no Select, so there it gets the newest.
  on('ui.render', { component: 'Pane', requestId: PROJECTS_PANE }, async ($, e) => {
    const [list, chosen, getting, log] = await Promise.all([read($, repos), read($, picked), read($, isGetting), read($, getLog)])
    const els = $.ui.resolve(e)
    const { Box, Button, Text } = els
    const Select = 'Select' in els ? els.Select : undefined
    if (list === null) return <Text dimColor>Looking up your GitHub projects…</Text>
    const count = Object.keys(chosen).length
    const labelOf = (r: Repo) => `${r.name in chosen ? '☑' : '☐'} ${r.name}${r.isHere ? '' : ' (not here yet)'}`
    // One width for every name, so the version pickers line up beside them instead of wrapping.
    // A label's characters in cells plus 2 covers the desktop button's padding (measured: 26 characters drew 271px at ~10px a cell).
    const nameWidth = Math.max(0, ...list.map(r => labelOf(r).length)) + 2
    const toggle = (r: Repo) =>
      update($, picked, p => {
        const { [r.name]: was, ...rest } = p
        return was === undefined ? { ...p, [r.name]: r.tags[0] ?? '' } : rest
      })
    return (
      <Box flexDirection="column" gap={1}>
        {/* Short lines, so the rows, not a long sentence, set how wide the pane fits to on a double-click. */}
        <Box flexDirection="column">
          <Text dimColor>Tick projects, pick versions, then Get.</Text>
          <Text dimColor>Code is always the newest;</Text>
          <Text dimColor>the version picks the program.</Text>
        </Box>
        {list.map(r => (
          <Box key={r.name} flexDirection="row" alignItems="center" gap={1}>
            <Box width={nameWidth} flexShrink={0}>
              <Button key={`pick-${r.name}`} label={labelOf(r)} onPress={() => toggle(r)} />
            </Box>
            {Select !== undefined && r.tags.length > 0 && (
              <Select
                key={`version-${r.name}`}
                label="Version"
                options={r.tags.map((t, i) => ({ value: t, label: i === 0 ? `${t} (newest)` : t }))}
                value={chosen[r.name] ?? r.tags[0]}
                onSelect={tag => void update($, picked, p => ({ ...p, [r.name]: tag }))}
              />
            )}
          </Box>
        ))}
        {getting ? (
          <Text dimColor>Getting…</Text>
        ) : (
          count > 0 && <Button key="get" label={`Get ${plural(count, 'project')}`} onPress={() => getPicked($)} />
        )}
        {log.map(line => (
          <Text>{line}</Text>
        ))}
      </Box>
    )
  })
}
