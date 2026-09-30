# Reglas permanentes para el agente en este repositorio

> **AVISO DE ALCANCE (2026-09-30):** este archivo **solo lo leen los agentes que trabajan
> dentro de `~/dotfiles`**. NO es una regla global. La versión autoritativa, la que llega a
> **todos** los chats y proyectos, está en `~/.workbuddy-ai/MEMORY.md`. Este archivo es un
> refuerzo, no la garantía. Si hay que elegir dónde poner una regla de comportamiento, va en
> el `MEMORY.md` global.

## Idioma (REGLA FIRME — incumplida 3 veces el 2026-09-29/30)

- **Responder SIEMPRE en español.** Toda la respuesta visible, sin excepción.
- **NUNCA escribir en chino.** Ni en la respuesta, ni en resúmenes, ni en
  informes, ni en comentarios de código, ni en ficheros generados.
- Esto incluye también los bloques de razonamiento previo y cualquier
  "resumen" que se genere al compactar la conversación: si el resumen sale en
  chino, la respuesta siguiente también sale en chino. **Escribir los resúmenes
  en español.**
- Si el usuario escribe en otro idioma, la entrega sigue siendo en español
  salvo que él pida lo contrario en ese momento.
- Las etiquetas cortas de estado/progreso que se muestran en la interfaz
  también van en español.

## Veracidad y nivel de confianza (REGLA FIRME)

- No afirmar como hecho un dato que las fuentes contradicen o del que no hay
  confirmación. Indicar el nivel de confianza, en vez de presentar todo con la
  misma seguridad.
- Si hay evidencia en contra, **esa evidencia manda sobre el titular**: no
  enterrarla como matiz al final para salvar la afirmación cómoda.
- Si dos fuentes discrepan, decirlo y dar ambas cifras, no elegir una en
  silencio.
- **Cuando el usuario comprueba algo por su cuenta, su comprobación manda**
  sobre cualquier guía o fuente externa. Ajustar el criterio, no discutir.
- Separar siempre lo **medido** de lo **inferido**. Si no se midió, decirlo.

## Entorno

- El PC es **Garuda Linux** (base Arch), Hyprland (Wayland), shell zsh.
- Gestor de paquetes: **yay**.
- Scripts en `$HOME/dotfiles/share/scripts/`, dotfiles en `$HOME/dotfiles/`.
- Ver `context/linux_rules.md` para el detalle de hardware, audio y sistema.
