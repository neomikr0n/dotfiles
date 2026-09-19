/**
 * Emit the plugin's dark override table as flat JSON so the screenshot helper can
 * apply exactly the same inline body variables the theme presenter will apply.
 * Usage: node gen-overrides.mjs [out.json]
 */
import { readFileSync, writeFileSync } from 'node:fs'

const source = readFileSync(new URL('./dsh-theme-black/lib/client.js', import.meta.url).pathname, 'utf8')

function objectLiteral(text, name) {
  const start = text.indexOf(`const ${name} = {`)
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
const dark = Object.fromEntries(Object.entries(tokens).map(([name, pair]) => [name, pair.dark]))
const out = process.argv[2] ?? new URL('./overrides.json', import.meta.url).pathname
writeFileSync(out, JSON.stringify(dark, null, 2) + '\n')
console.log('wrote', out, Object.keys(dark).length, 'dark overrides')
