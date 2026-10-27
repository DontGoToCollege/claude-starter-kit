import { expect, test } from 'claude-code/testing'

const HOME = 'C:/Users/Friend'
const DIR = `${HOME}/Claude Projects`
// What Get-ClaudeRules.ps1 installs; hands-off names match whatever their case.
const SETTINGS = JSON.stringify({ owner: 'Friend', rulesRepo: 'Friend/claude-rules', projectsFolder: '~\\Claude Projects', newRepos: 'private', handsOff: ['taxes', 'WORK'] })

const ok = (stdout = '') => ({ value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } })

test('Projects: hands-off repos hidden, tick, pick a version, get it', async ($, on) => {
  const ran: string[] = []
  const store = new Map<string, unknown>()
  on('process.run', (_, e) => {
    const cmd = e.argv.join(' ')
    ran.push(cmd)
    if (cmd.startsWith('gh repo list')) return ok('PhotoApp\nTaxes\nNotes\nWork\nTimer\n')
    if (cmd.startsWith('gh release list -R Friend/PhotoApp')) return ok('v1.7.0\nv1.6.0\n')
    // Made out of order on GitHub: v0.5.1 is the newest though listed last.
    if (cmd.startsWith('gh release list -R Friend/Timer')) return ok('v0.5.0\nv0.1.0\nv0.5.1\n')
    if (cmd.startsWith('gh release view v1.6.0')) return ok('PhotoApp.exe\n')
    return ok()
  })
  on('env.get', (_, e) => ({ value: e.name === 'USERPROFILE' ? HOME : undefined }))
  // The engine hands paths on in the system's own form.
  on('fs.exists', (_, e) => ({ value: e.path.replace(/\\/g, '/') === `${DIR}/PhotoApp` }))
  on('fs.read', (_, e) => ({ value: e.path.endsWith('settings.json') ? SETTINGS : 'Rules version: 1.0.0\n' }))
  on('fs.list', () => ({ value: [] }))
  on('fs.stat', () => ({ value: { mtimeMs: 0 } as never }))
  on('store.get', (_, e) => ({ value: store.get(e.key) }))
  on('store.set', (_, e) => (store.set(e.key, e.value), { value: undefined }))
  on('clock.now', () => ({ value: 0 }))
  on('clock.every', () => ({ value: undefined as never }))
  on('command.register', () => ({ value: { command: 'setup-status' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.render', () => <Fragment />)
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  for (const surface of ['terminal', 'desktop'] as const) {
    const band = await $.ui.mount({ plugin: 'setup-band', surface, component: 'AbovePrompt', props: { hasSurvey: false } as never })
    await band.press({ key: 'projects' })
    await band.unmount()

    const ui = await $.ui.mount({
      plugin: 'setup-band',
      surface,
      component: 'Pane',
      requestId: 'setup-projects',
      props: { title: 'Get projects', isFocused: true, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
    })
    expect(await ui.find({ key: 'pick-Taxes' })).toBeUndefined()
    expect(await ui.find({ key: 'pick-Work' })).toBeUndefined()
    expect((await ui.find({ key: 'pick-Notes' }))?.text).toContain('☐ Notes (not here yet)')
    // Notes has no releases here: no version picker.
    expect(await ui.find({ key: 'version-Notes' })).toBeUndefined()

    if (surface === 'desktop') {
      // Picking a version ticks the project.
      await ui.select({ key: 'version-PhotoApp', value: 'v1.6.0' })
      await ui.press({ key: 'pick-Notes' })
      await ui.press({ key: 'pick-Timer' })
      expect((await ui.find({ key: 'pick-PhotoApp' }))?.text).toContain('☑ PhotoApp')
      ran.length = 0
      await ui.press({ key: 'get' })
      expect(ran).toContain(`git -C ${DIR}/PhotoApp status --porcelain`)
      expect(ran).toContain(`git -C ${DIR}/PhotoApp pull --ff-only`)
      expect(ran).toContain(`gh release download v1.6.0 -R Friend/PhotoApp -p PhotoApp.exe -O ${DIR}/PhotoApp/Versions/Archive/PhotoApp-1.6.0.exe`)
      expect(ran).toContain(`gh release download v1.6.0 -R Friend/PhotoApp -p PhotoApp.exe -O ${DIR}/PhotoApp/PhotoApp.exe --clobber`)
      expect(ran).toContain(`gh repo clone Friend/Notes ${DIR}/Notes`)
      expect(ran.some(c => c.startsWith('gh release view v0.5.1 -R Friend/Timer'))).toBe(true)
      expect((await ui.find({ type: 'Text', text: /PhotoApp: code up to date; PhotoApp.exe 1.6.0/ })) !== undefined).toBe(true)
      expect((await ui.find({ type: 'Text', text: /Notes: downloaded\./ })) !== undefined).toBe(true)
    }
    await ui.unmount()
  }
})
