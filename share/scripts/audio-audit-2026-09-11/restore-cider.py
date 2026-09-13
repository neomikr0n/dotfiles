#!/usr/bin/env python3
"""Restore only five audited Cider settings, retaining other current preferences."""
from pathlib import Path
import subprocess,json,yaml,shutil,time
root=Path(__file__).resolve().parent
r=subprocess.run(['playerctl','-l'],capture_output=True,text=True)
if any('cider' in x.lower() for x in r.stdout.splitlines()): raise SystemExit('Close Cider normally before restoring these settings.')
m=json.loads((root/'cider-changes.json').read_text()); p=Path(m['path']); d=yaml.safe_load(p.read_text())
for item in m['changes']:
 node=d; keys=item['key'].split('.')
 for key in keys[:-1]: node=node[key]
 node[keys[-1]]=item['before']
shutil.copy2(p,root/f'cider-before-restore-{time.time_ns()}.yml')
p.write_text(yaml.safe_dump(d,sort_keys=False,allow_unicode=True))
print('Five original settings restored. Open Cider to activate them.')
