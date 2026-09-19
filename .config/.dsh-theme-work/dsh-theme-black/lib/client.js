window.__ModuleLoader__.load({
	id: "dsh-theme-black",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

		//#region paleta
		/**
		 * Escala de superficies del tema oscuro.
		 *
		 * El tema `dark` de fábrica deriva cada superficie de la escala estática
		 * `--dsw-static-neutral-bluish-*` (950 = fondo base … 800 = capa 3), así que
		 * bajando esa escala se oscurecen de golpe el fondo, el sidebar, las capas,
		 * los menús, los inputs, los toasts y todo el CSS de plugins que la usa
		 * directamente. `light` repite el valor original a propósito: la escala es
		 * compartida por ambos esquemas y sólo queremos tocar el oscuro.
		 */
		const SURFACE_SCALE = {
			"--dsw-static-neutral-bluish-950": { light: "#151517", dark: "#000000" },
			"--dsw-static-neutral-bluish-900": { light: "#1b1b1c", dark: "#0a0a0c" },
			"--dsw-static-neutral-bluish-875": { light: "#232324", dark: "#111114" },
			"--dsw-static-neutral-bluish-850": { light: "#2c2c2e", dark: "#18181c" },
			"--dsw-static-neutral-bluish-800": { light: "#353638", dark: "#202026" },
			"--dsw-static-neutral-bluish-750": { light: "#43454a", dark: "#2a2a31" },
			"--dsw-static-neutral-bluish-700": { light: "#61666b", dark: "#36363f" }
		};

		/**
		 * Tokens que no salen de esa escala: usan la escala neutra, un literal o un
		 * degradado propio del modo oscuro. Cada uno se ajusta aquí.
		 */
		const EXCEPTIONS = {
			/* Etiqueta atenuada: la escala la habría dejado ilegible sobre negro. */
			"--dsw-alias-label-dimmed": { light: "var(--dsw-static-neutral-bluish-200)", dark: "#4c4e56" },
			/* Selección múltiple (escala neutra en oscuro). */
			"--dsw-alias-bg-multi-select": { light: "var(--dsw-static-neutral-bluish-60)", dark: "#18181c" },
			/* Código en línea del markdown (escala neutra en oscuro). */
			"--dsw-alias-markdown-inline-code": { light: "var(--dsw-static-neutral-50)", dark: "#141418" },
			/* Degradados literales del bloque "pensando". */
			"--dsw-linear-gradient-think": {
				light: "linear-gradient(180deg, #fff 20.19%, #fff0 100%)",
				dark: "linear-gradient(180deg, #000 20.19%, #0000 100%)"
			},
			"--dsw-linear-think-select": {
				light: "linear-gradient(180deg, #f5f6f7 20.19%, #f5f6f700 100%)",
				dark: "linear-gradient(180deg, #111114 20.19%, #11111400 100%)"
			}
		};

		/** Capa completa de overrides que se apila sobre el tema activo. */
		const TOKENS = { ...SURFACE_SCALE, ...EXCEPTIONS };

		/** Identidad de la capa (una capa por fuente; re-registrar reemplaza la anterior). */
		const LAYER_SOURCE = "dsh-theme-black";

		/** Servicio requerido: el registro de temas del cliente, que aplica los tokens al `body`. */
		const inject = ["theme"];

		/**
		 * Apila la capa de tokens sobre el tema activo. `overrideTokens` la funde en el
		 * snapshot que publica el presentador de ui-layout, así que los valores llegan
		 * como variables inline en `body` y ganan a la hoja `body[data-ds-dark-theme]`.
		 * @param ctx - contexto de cliente de Cordis.
		 */
		function apply(ctx) {
			ctx.effect(
				() => ctx.theme.overrideTokens(LAYER_SOURCE, TOKENS),
				"dsh-theme-black: capa de paleta"
			);
		}
		//#endregion

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
