#!/usr/bin/env python3
"""Restore only audit-owned changes; refuses to overwrite later edits."""
from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path(__file__).resolve().parent
entries=json.loads((root/'pipewire-backup-manifest.json').read_text())
for e in entries:
 p=Path(e['path'])
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=e['after_sha256']:
  raise SystemExit(f'File changed after audit; review manually: {p}')
for e in entries:
 p=Path(e['path'])
 if e['backup']: shutil.copy2(e['backup'],p)
 else: p.unlink()
subprocess.run(['systemctl','--user','restart','pipewire','pipewire-pulse','wireplumber'],check=True)
print('Original PipeWire configuration restored. Volume was not changed.')
