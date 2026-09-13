# Audio

- **audio_context.md**: inventario e informe técnico del sistema. Sus datos corresponden a las revisiones indicadas en el documento; no lee ajustes actuales del RME.
- **audio.html**: presentación visual autónoma; contiene la fotografía de los HE1000se.
- **manuales/**: documentación de RME, Aune, Eversolo y CyberPower. La ficha del CyberPower terminado en «a» se conserva sólo como comparación, no como manual de tu unidad.
- **fichas/**: documentos ilustrados elaborados para cables y transformador; no son manuales oficiales del fabricante.
- **presets/**: archivos de ecualización importables en ADI-2 Remote. Se conservan V2, V3, V3.1 y V4; guardar un archivo aquí no lo activa en el DAC.
- **imagenes/**: fotografías de productos y etiqueta original del transformador, usadas como evidencia o ilustraciones.
- **musica/**: tus listas de álbumes y canciones.
- **old/**: informes históricos y la presentación HTML anterior. Se conservan como antecedentes, no como configuración vigente.

## Control por teclado

El script no depende de esta carpeta. Vive en `/home/n30/dotfiles/share/scripts/`:

- `rme-volume`: comando de entrada; compila el controlador cuando es necesario y llama al indicador.
- `rme-volume.c`: control USB-MIDI, límites de volumen, mute y sesión bajo demanda.
- `rme-osd` y `rme-osd-ui/shell.qml`: avisos y barra central de Quickshell.
- `rme-volume-tests.c`: pruebas de codificación MIDI y límites; no controla el aparato durante las pruebas.
- `rme-volume.md`: documentación técnica y registro de cambios.
- `swayosd-on-demand`: compatibilidad con las teclas antiguas de brillo/Caps Lock.

Limpieza: se enviaron a la papelera dos respaldos intermedios del informe y una copia idéntica de audio_rules. Se conservaron los documentos originales, presets y fuentes.
