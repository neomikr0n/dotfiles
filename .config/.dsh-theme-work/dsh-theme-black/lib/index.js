/**
 * dsh-theme-black — host half.
 *
 * The palette lives entirely in the browser half (`./client`), which stacks a
 * token override layer over the built-in dark theme. The host half exists only
 * so the profile Loader has an entry to mount: client-modules scans enabled
 * Loader entries for their `dsh.client` declaration and serves the bundle, and
 * the entry is what makes that scan see this package.
 *
 * @module dsh-theme-black
 */

/** Cordis plugin name. */
export const name = 'dsh-theme-black'

/** No host service is required; the palette is a browser-side override. */
export const inject = []

/** Host half does nothing. */
export function apply() {}
