/**
 * Capture a screenshot of the local DSH Web GUI without knowing its launch token.
 *
 * The browser-session signing secret is durable in $DSH_HOME/.credentials.yaml,
 * so a valid `dsh-auth-<hash(host)>` cookie can be minted locally and handed to
 * headless Chrome over CDP.
 *
 * Usage: node shot.mjs <out.png> [width] [height]
 */
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs'
import { createHash, createHmac } from 'node:crypto'
import { spawn } from 'node:child_process'
import { homedir } from 'node:os'
import { join } from 'node:path'

const OUT = process.argv[2] ?? 'shot.png'
const WIDTH = Number(process.argv[3] ?? 1680)
const HEIGHT = Number(process.argv[4] ?? 1000)
/** Optional tokenised URL; `-` (or omitted) mints a cookie for the live GUI. */
const EXPLICIT_URL = process.argv[5] === undefined || process.argv[5] === '' || process.argv[5] === '-' ? undefined : process.argv[5]
/** Optional sidebar/session label to click before capturing. */
const CLICK_TEXT = process.argv[6]
/** Pass `stock` to capture the page without the inline theme dry-run. */
const STOCK = process.argv[7] === 'stock'
const ORIGIN = 'http://127.0.0.1:3080'
const AUTHORITY = '127.0.0.1:3080'
const WORK = '/home/n30/dotfiles/.config/.dsh-theme-work'
const PROFILE = join(WORK, 'chrome-profile')
const DEBUG_PORT = 9333

const b64url = (buf) => Buffer.from(buf).toString('base64').replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/u, '')

let cookieName
let cookieValue
let cookieExpiresAt
if (EXPLICIT_URL === undefined) {
  const credentials = readFileSync(join(homedir(), '.dsh', '.credentials.yaml'), 'utf8')
  const secretMatch = /secret:\s*([A-Za-z0-9_-]{40,})/.exec(credentials)
  if (secretMatch === null) throw new Error('no browser-session secret found')
  const secret = Buffer.from(secretMatch[1].replaceAll('-', '+').replaceAll('_', '/') + '=', 'base64')
  if (secret.byteLength !== 32) throw new Error(`unexpected secret length ${String(secret.byteLength)}`)
  const issuedAt = Date.now()
  cookieExpiresAt = issuedAt + 7 * 24 * 3600 * 1000
  const body = b64url(Buffer.from(JSON.stringify({ version: 1, authority: AUTHORITY, issuedAt, expiresAt: cookieExpiresAt }), 'utf8'))
  cookieValue = `v1.${body}.${b64url(createHmac('sha256', secret).update(body).digest())}`
  cookieName = 'dsh-auth-' + b64url(createHash('sha256').update(AUTHORITY).digest())
}

rmSync(PROFILE, { recursive: true, force: true })
mkdirSync(PROFILE, { recursive: true })

const chrome = spawn('google-chrome-stable', [
  '--headless=new',
  '--no-sandbox',
  '--disable-gpu',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-dev-shm-usage',
  '--force-color-profile=srgb',
  '--hide-scrollbars',
  `--user-data-dir=${PROFILE}`,
  `--remote-debugging-port=${String(DEBUG_PORT)}`,
  `--window-size=${String(WIDTH)},${String(HEIGHT)}`,
  'about:blank',
], { stdio: ['ignore', 'ignore', 'ignore'] })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function waitForDevtools() {
  for (let i = 0; i < 100; i += 1) {
    try {
      const res = await fetch(`http://127.0.0.1:${String(DEBUG_PORT)}/json/version`)
      if (res.ok) return await res.json()
    } catch {}
    await sleep(200)
  }
  throw new Error('devtools endpoint never came up')
}

const version = await waitForDevtools()
const ws = new WebSocket(version.webSocketDebuggerUrl)
await new Promise((resolve, reject) => {
  ws.addEventListener('open', resolve, { once: true })
  ws.addEventListener('error', reject, { once: true })
})

let nextId = 0
const pending = new Map()
const events = []
ws.addEventListener('message', (event) => {
  const msg = JSON.parse(event.data)
  if (msg.id !== undefined && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id)
    pending.delete(msg.id)
    if (msg.error !== undefined) reject(new Error(JSON.stringify(msg.error)))
    else resolve(msg.result)
  } else if (msg.method !== undefined) events.push(msg)
})
function send(method, params = {}, sessionId) {
  nextId += 1
  const id = nextId
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    ws.send(JSON.stringify({ id, method, params, ...(sessionId === undefined ? {} : { sessionId }) }))
  })
}

const { targetId } = await send('Target.createTarget', { url: 'about:blank' })
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true })
const page = (method, params) => send(method, params, sessionId)

await page('Network.enable')
await page('Page.enable')
await page('Runtime.enable')
await page('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false })
if (EXPLICIT_URL === undefined) {
  await page('Network.setCookie', {
    name: cookieName,
    value: cookieValue,
    domain: '127.0.0.1',
    path: '/',
    httpOnly: true,
    sameSite: 'Strict',
    expires: cookieExpiresAt / 1000,
  })
}
await page('Page.navigate', { url: EXPLICIT_URL ?? ORIGIN + '/' })

// Wait for the shell to mount, then let the plugin bundles settle.
let mounted = false
for (let i = 0; i < 120; i += 1) {
  await sleep(250)
  const res = await page('Runtime.evaluate', {
    expression: 'document.body && document.body.getAttribute("data-ds-dark-theme") !== null && document.body.children.length > 0',
    returnByValue: true,
  })
  if (res.result?.value === true) { mounted = true; break }
}
await sleep(3500)

// Dismiss the first-run "add an API key" dialog so the surfaces are unobstructed.
await page('Runtime.evaluate', {
  expression: `(() => {
    const buttons = [...document.querySelectorAll('button')]
    const target = buttons.find((b) => /configure later|más tarde|mas tarde/i.test(b.textContent || ''))
    if (target) { target.click(); return 'clicked' }
    const dialog = document.querySelector('[role="dialog"]')
    if (dialog) { dialog.remove(); return 'removed' }
    return 'none'
  })()`,
  returnByValue: true,
})
await sleep(1200)

// Optional dry-run: apply the plugin's dark token layer inline, exactly as the
// theme presenter will once the plugin is loaded by the server.
if (!STOCK && existsSync(join(WORK, 'overrides.json'))) {
  const tokens = JSON.parse(readFileSync(join(WORK, 'overrides.json'), 'utf8'))
  const applied = await page('Runtime.evaluate', {
    expression: `(() => { const t = ${JSON.stringify(tokens)}; for (const [k, v] of Object.entries(t)) document.body.style.setProperty(k, v); return Object.keys(t).length })()`,
    returnByValue: true,
  })
  console.log('inline overrides applied:', applied.result.value)
  await sleep(600)
}

// Optional: open a sidebar session/pane so the conversation surfaces render.
if (CLICK_TEXT !== undefined) {
  const clicked = await page('Runtime.evaluate', {
    expression: `(() => {
      const wanted = ${JSON.stringify(CLICK_TEXT)}
      const hits = [...document.querySelectorAll('*')].filter((el) => (el.textContent || '').trim() === wanted)
      const target = hits.sort((a, b) => a.textContent.length - b.textContent.length)[0]
      if (!target) return 'not found'
      const clickable = target.closest('button,[role="button"],a,li,div') || target
      clickable.click()
      return 'clicked ' + clickable.tagName
    })()`,
    returnByValue: true,
  })
  console.log('click:', clicked.result.value)
  await sleep(4000)
}

const probe = await page('Runtime.evaluate', {
  expression: 'JSON.stringify({ attr: document.body.getAttribute("data-ds-dark-theme"), base: getComputedStyle(document.body).getPropertyValue("--dsw-alias-bg-base").trim(), sidebar: getComputedStyle(document.body).getPropertyValue("--dsw-specific-sidebar-fill").trim(), bg: getComputedStyle(document.body).backgroundColor, title: document.title, text: (document.body.innerText||"").slice(0,80) })',
  returnByValue: true,
})
console.log('probe:', mounted ? probe.result.value : 'NOT MOUNTED ' + String(probe.result.value))

const shot = await page('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false })
writeFileSync(OUT, Buffer.from(shot.data, 'base64'))
console.log('wrote', OUT)

ws.close()
chrome.kill('SIGKILL')
