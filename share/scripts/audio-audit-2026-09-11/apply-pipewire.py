#!/usr/bin/env python3
"""Audited PipeWire changes; snapshots originals and refuses repeated application."""
from pathlib import Path
import hashlib, json, shutil, difflib, sys
root=Path(__file__).resolve().parent
base=Path('/home/n30/.config/pipewire')
main=base/'pipewire.conf.d/99-rme-fix.conf'
old=main.read_text()
new=old.replace('default.clock.rate          = 192000','default.clock.rate          = 48000').replace('[ 44100 48000 88200 96000 176400 192000 ]','[ 44100 48000 88200 96000 192000 ]').replace('default.clock.quantum       = 1024','default.clock.quantum       = 256').replace('default.clock.min-quantum   = 512','default.clock.min-quantum   = 128').replace('default.clock.max-quantum   = 2048','default.clock.max-quantum   = 512').replace('# Reducimos a un Quantum dinámico para permitir que el buffer se recupere','# Mantiene las duraciones previas de buffer al pasar de 192 a 48 kHz.').replace('    # Desactivamos el forzado agresivo que causa clipping en USB\n    node.force-quantum = 0\n    node.force-rate    = 0\n','    # Los clientes pueden solicitar otra frecuencia cuando el grafo esta inactivo.\n    # 176.4 kHz no figura en las capacidades del transmisor SPDIF ALC1220.\n')
changes={
 main:new,
 base/'pipewire-pulse.conf.d/force-192k.conf':'''# Nombre historico. Ya no fuerza la frecuencia ni el quantum de las aplicaciones.
# Conversiones de clientes PulseAudio: se configuran en pipewire-pulse.
stream.properties = {
    resample.quality = 10
}
''',
 base/'client.conf.d/resampling.conf':'''# Clientes nativos de PipeWire. Conserva la frecuencia solicitada por la aplicacion.
# Calidad 10 prioriza filtrado cuando convertir es necesario; no garantiza audibilidad.
stream.properties = {
    resample.quality = 10
    node.latency = 2048/192000
}
''',
}
for p,new in changes.items():
 print(''.join(difflib.unified_diff(p.read_text().splitlines(True),new.splitlines(True),fromfile=str(p),tofile=str(p))))
if '--apply' not in sys.argv: sys.exit(0)
manifest=root/'pipewire-backup-manifest.json'
if manifest.exists(): raise SystemExit('Backup already exists; refusing to overwrite it.')
backup=root/'backup-pipewire'; backup.mkdir(exist_ok=True)
entries=[]
for i,(p,new) in enumerate(changes.items()):
 resolved=p.resolve(); dest=backup/f'{i}-{p.name}'
 shutil.copy2(resolved,dest)
 entries.append({'path':str(resolved),'backup':str(dest),'before_sha256':hashlib.sha256(resolved.read_bytes()).hexdigest(),'after_sha256':hashlib.sha256(new.encode()).hexdigest()})
manifest.write_text(json.dumps(entries,indent=2)+'\n')
for p,new in changes.items(): p.write_text(new)
print('Applied. Original files saved; services not restarted by this script.')
