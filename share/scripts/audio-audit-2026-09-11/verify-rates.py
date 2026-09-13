#!/usr/bin/env python3
"""Silent physical-output sample-rate negotiation test; never changes volume."""
from pathlib import Path
import subprocess as s,time,wave,json
root=Path(__file__).resolve().parent
sink='alsa_output.pci-0000_00_1f.3.iec958-stereo'
players=s.check_output(['playerctl','-l'],text=True).splitlines()
resume=[]
for player in players:
 if 'cider' in player.lower():
  status=s.run(['playerctl','-p',player,'status'],capture_output=True,text=True)
  if status.stdout.strip()=='Playing': resume.append(player)
results=[]
try:
 for player in resume: s.run(['playerctl','-p',player,'pause'],check=True)
 time.sleep(6)
 for rate in [44100,48000,96000,192000]:
  wav=Path('/tmp')/f'audio-audit-silence-{rate}.wav'
  with wave.open(str(wav),'wb') as w:
   w.setnchannels(2); w.setsampwidth(3); w.setframerate(rate); w.writeframes(bytes(rate*4*6))
  p=s.Popen(['pw-play','--target',sink,str(wav)],stdout=s.PIPE,stderr=s.PIPE,text=True)
  time.sleep(1.5)
  hw=Path('/proc/asound/card0/pcm1p/sub0/hw_params').read_text()
  settings=s.run(['pw-metadata','-n','settings'],capture_output=True,text=True).stdout
  out,err=p.communicate(timeout=10)
  row={'requested_rate':rate,'hw_params':hw,'metadata':settings,'returncode':p.returncode,'stderr':err,'matches':f'rate: {rate} ' in hw}
  results.append(row); print(json.dumps(row),flush=True)
  time.sleep(6)
finally:
 for player in resume: s.run(['playerctl','-p',player,'play'],check=False)
 (root/'rate-tests.json').write_text(json.dumps(results,indent=2)+'\n')
