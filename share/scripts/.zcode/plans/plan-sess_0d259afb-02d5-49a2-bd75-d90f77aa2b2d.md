Ejecutar el skill **script-reviewer** sobre `dsh-chrome-open.sh` (12 líneas, arranca `dsh web` si no corre y abre Chrome con token del log).

Pasos:
1. Ejecutar `shellcheck -f json dsh-chrome-open.sh` (bloqueado en modo plan) y mapear cada resultado a hallazgos con su código SC####.
2. Combinar shellcheck con mi análisis propio ya realizado (hallazgos preliminares: token sin validar/obsoleto del log fijo en /tmp, `sleep 3` ciego sin confirmar que dsh arrancó, sin `set -euo pipefail`, sin `command -v` para lsof/dsh/chrome, shebang `#!/bin/bash` → `env bash`).
3. Análisis cualitativo: sugerencias creativas (polling de salud en vez de sleep fijo, validación/reintento del token, log en `$XDG_RUNTIME_DIR` con trap de limpieza, flags tipo `--print-url`) y puntos ciegos (carreras entre instancias sobre el log, token obsoleto si dsh ya corría, puerto 3080 ocupado por otro proceso, dsh queda huérfano si el script se interrumpe).
4. Construir el JSON de hallazgos (score inicial ~68), guardarlo en `/tmp/script-review-$$.json`.
5. Generar el informe con `python3 ~/.agents/skills/script-reviewer/assets/generate_report.py <json> -o /home/n30/dotfiles/share/scripts/dsh-chrome-open-informe.html`, borrar el JSON temporal y reportar la ruta del HTML.

No se modifica el script original; el entregable es solo el informe HTML.