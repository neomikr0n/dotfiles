/**
 * Sanity-check the dsh-theme-black override table against the shipped palettes:
 *
 *  1. every `light` value must equal the stock light declaration (light mode is
 *     left untouched — that is the whole point of shipping the original value);
 *  2. every `dark` value must be no lighter than the stock dark declaration.
 *
 * Usage: node check-tokens.mjs [path/to/client.js]
 */
import { readFileSync } from 'node:fs'

const PLUGIN = process.argv[2] ?? new URL('./dsh-theme-black/lib/client.js', import.meta.url).pathname
const THEME = '/usr/lib/deepseek-harness/node_modules/@deepseek-ai/dsh-client-ui-theme/lib/client.js'

const source = readFileSync(PLUGIN, 'utf8')
const theme = readFileSync(THEME, 'utf8')

/** Pull `const NAME = { ... };` out of the bundle and evaluate the literal. */
function objectLiteral(text, name) {
  const start = text.indexOf(`const ${name} = {`)
  if (start === -1) throw new Error(`no ${name} in ${PLUGIN}`)
  const open = text.indexOf('{', start)
  let depth = 0
  for (let i = open; i < text.length; i += 1) {
    if (text[i] === '{') depth += 1
    else if (text[i] === '}') {
      depth -= 1
      if (depth === 0) return new Function(`return ${text.slice(open, i + 1)}`)()
    }
  }
  throw new Error(`unbalanced ${name}`)
}

const tokens = { ...objectLiteral(source, 'SURFACE_SCALE'), ...objectLiteral(source, 'EXCEPTIONS') }

/** Collect `--token: value` declarations from every selector block matching `pattern`. */
function collect(pattern) {
  const found = {}
  for (const match of theme.matchAll(pattern)) {
    for (const decl of match[1].split(';')) {
      const at = decl.indexOf(':')
      if (at === -1) continue
      const name = decl.slice(0, at).trim()
      if (name.startsWith('--')) found[name] = decl.slice(at + 1).trim()
    }
  }
  return found
}

const lightStock = collect(/(?<![\[\w])body\{([^}]*)\}/g)
const darkStock = {}
for (const match of theme.matchAll(/body\[data-ds-dark-theme\]\{([^}]*)\}/g)) {
  for (const decl of match[1].split(';')) {
    const at = decl.indexOf(':')
    if (at === -1) continue
    const name = decl.slice(0, at).trim()
    if (name.startsWith('--')) darkStock[name] = decl.slice(at + 1).trim()
  }
}

/** Resolve `var(--x)` chains against a declaration table, then parse `#rgb`/`#rrggbb`. */
function resolve(value, table, seen = new Set()) {
  const ref = /^var\((--[a-z0-9-]+)\)$/.exec(value)
  if (ref !== null) {
    const name = ref[1]
    if (seen.has(name) || table[name] === undefined) return undefined
    seen.add(name)
    return resolve(table[name], table, seen)
  }
  const hex = /^#([0-9a-f]{3,8})$/i.exec(value)
  if (hex === null) return undefined
  const digits = hex[1].length <= 4
    ? [...hex[1]].map((c) => c + c).join('')
    : hex[1]
  return { r: parseInt(digits.slice(0, 2), 16), g: parseInt(digits.slice(2, 4), 16), b: parseInt(digits.slice(4, 6), 16) }
}
const luminance = (rgb) => 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
/** Stock value for a token in one mode: the dark block wins where it declares the token. */
const stockFor = (mode, name) => (mode === 'dark' ? darkStock[name] ?? lightStock[name] : lightStock[name])

let failures = 0
console.log('token'.padEnd(42), 'mode'.padEnd(6), 'stock', '->', 'override')
for (const [name, pair] of Object.entries(tokens)) {
  for (const mode of ['light', 'dark']) {
    const stock = stockFor(mode, name)
    if (stock === undefined) { console.log(`${name} ${mode}: no stock declaration`); continue }
    const same = stock === pair[mode]
    const stockRgb = resolve(stock, { ...lightStock, ...darkStock })
    const nextRgb = resolve(pair[mode], { ...lightStock, ...darkStock })
    const darker = stockRgb !== undefined && nextRgb !== undefined ? luminance(nextRgb) - luminance(stockRgb) : undefined
    const flag = mode === 'light'
      ? (same ? 'ok' : (failures += 1, 'MISMATCH'))
      : (darker === undefined ? 'ok(string)' : darker < -0.5 ? `ok(${darker.toFixed(1)} darker)` : (same ? 'ok(same)' : (failures += 1, `NOT DARKER (${darker.toFixed(1)})`)))
    console.log(name.padEnd(42), mode.padEnd(6), stock.slice(0, 22).padEnd(22), '->', pair[mode].slice(0, 22).padEnd(22), flag)
  }
}
console.log('\ntokens:', Object.keys(tokens).length, '| failures:', failures)
process.exitCode = failures === 0 ? 0 : 1
