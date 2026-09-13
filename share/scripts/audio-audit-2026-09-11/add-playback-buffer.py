from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parent
manifest=root/'pipewire-backup-manifest.json'; entries=json.loads(manifest.read_text())
main=Path(entries[0]['path']); text=main.read_text()
text=text.replace('default.clock.quantum       = 256','default.clock.quantum       = 1024').replace('default.clock.min-quantum   = 128','default.clock.min-quantum   = 512').replace('default.clock.max-quantum   = 512','default.clock.max-quantum   = 2048').replace('# Mantiene las duraciones previas de buffer al pasar de 192 a 48 kHz.','# Margen de planificacion para reproduccion: 21.33 ms base a 48 kHz.\n    # Minimo 10.67 ms y maximo 42.67 ms; no es una mejora tonal.')
main.write_text(text)
entries[0]['after_sha256']=hashlib.sha256(main.read_bytes()).hexdigest()
manifest.write_text(json.dumps(entries,indent=2)+'\n')
print('Playback buffer defaults updated; no fixed sample rate.')
