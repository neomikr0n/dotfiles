#!/usr/bin/env bash
# check.sh <html> — extract every <script> block and syntax-check it.
set -uo pipefail
f="${1:-/home/n30/dotfiles/context/audio/audio_deepseek.html}"
python3 - "$f" <<'PY'
import re, subprocess, sys, tempfile, os
src = open(sys.argv[1], encoding='utf-8').read()
blocks = re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', src, re.S | re.I)
print(f"found {len(blocks)} inline <script> block(s)")
ok = True
for i, b in enumerate(blocks, 1):
    if not b.strip():
        print(f"  [{i}] empty - skipped"); continue
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as t:
        t.write(b); p = t.name
    r = subprocess.run(['node', '--check', p], capture_output=True, text=True)
    if r.returncode == 0:
        print(f"  [{i}] {len(b)} chars  SYNTAX OK")
    else:
        ok = False
        print(f"  [{i}] {len(b)} chars  SYNTAX FAIL")
        print('      ' + (r.stderr.strip().splitlines() or ['?'])[-1])
    os.unlink(p)
sys.exit(0 if ok else 1)
PY
