/**
 * Fetch an authenticated DSH page/asset with a locally minted browser-session cookie.
 * Usage: node fetch-auth.mjs <path> [outfile]
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { createHash, createHmac } from 'node:crypto'
import { homedir } from 'node:os'
import { join } from 'node:path'

const PATH_ARG = process.argv[2] ?? '/'
const OUT = process.argv[3]

const b64url = (buf) => Buffer.from(buf).toString('base64').replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/u, '')
const credentials = readFileSync(join(homedir(), '.dsh', '.credentials.yaml'), 'utf8')
const secret = Buffer.from(/secret:\s*([A-Za-z0-9_-]{40,})/.exec(credentials)[1].replaceAll('-', '+').replaceAll('_', '/') + '=', 'base64')
const authority = '127.0.0.1:3080'
const issuedAt = Date.now()
const body = b64url(Buffer.from(JSON.stringify({ version: 1, authority, issuedAt, expiresAt: issuedAt + 3600000 }), 'utf8'))
const value = `v1.${body}.${b64url(createHmac('sha256', secret).update(body).digest())}`
const name = 'dsh-auth-' + b64url(createHash('sha256').update(authority).digest())

const res = await fetch('http://' + authority + PATH_ARG, { headers: { cookie: `${name}=${value}` } })
const text = await res.text()
if (OUT !== undefined) writeFileSync(OUT, text)
console.log('status', res.status, 'content-type', res.headers.get('content-type'), 'bytes', text.length)
if (OUT === undefined) console.log(text.slice(0, 4000))
