#!/usr/bin/env python3
from pathlib import Path
import yaml,json,shutil,hashlib,subprocess
root=Path(__file__).resolve().parent
# Refuse to modify the config while Cider can overwrite it.
r=subprocess.run(['playerctl','-l'],capture_output=True,text=True)
if any('cider' in p.lower() for p in r.stdout.splitlines()): raise SystemExit('Cider is still open; configuration untouched.')
p=Path('/home/n30/.config/sh.cider.genten/spa-config.yml')
backup=root/'backup-cider-spa-config.yml'
if backup.exists(): raise SystemExit('Backup already exists; refusing overwrite.')
d=yaml.safe_load(p.read_text()); changes=[]
for path in [('audio','ciderAudio','enabled'),('audio','ciderAudio','ciderPPE'),('audio','atmos','enabled'),('audio','crossfade','enabled'),('audio','automix','enabled')]:
 node=d
 for key in path[:-1]: node=node[key]
 changes.append({'key':'.'.join(path),'before':node[path[-1]],'after':False}); node[path[-1]]=False
shutil.copy2(p,backup)
p.write_text(yaml.safe_dump(d,sort_keys=False,allow_unicode=True))
assert yaml.safe_load(p.read_text())==d
(root/'cider-changes.json').write_text(json.dumps({'path':str(p),'backup':str(backup),'after_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'changes':changes,'normalization_preserved':d['audio']['normalization'],'volume_preserved':d['audio']['volume']},indent=2)+'\n')
print(json.dumps(changes,indent=2))
