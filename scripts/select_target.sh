#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/config/projects.json"
TARGET="${TARGET:-auto}"

COUNT="$(python - "$CONFIG" <<'PY'
import json,sys
print(len(json.load(open(sys.argv[1], encoding='utf-8'))['projects']))
PY
)"
if [[ "$TARGET" == "auto" ]]; then
  INDEX="$((10#$(date -u +%H) % COUNT))"
  TARGET="$(python - "$CONFIG" "$INDEX" <<'PY'
import json,sys
print(json.load(open(sys.argv[1], encoding='utf-8'))['projects'][int(sys.argv[2])]['alias'])
PY
)"
fi

python - "$CONFIG" "$TARGET" "$GITHUB_OUTPUT" <<'PY'
import base64,json,sys
cfg,target,out=sys.argv[1:4]
projects=json.load(open(cfg, encoding='utf-8'))['projects']
p=next((x for x in projects if x['alias']==target), None)
if not p:
    raise SystemExit(f'Unknown target: {target}')
with open(out,'a',encoding='utf-8') as f:
    for k in ['alias','repository','work_branch','base_branch','prompt_file','max_changed_files','recent_change_guard_minutes']:
        f.write(f"{k}={p[k]}\n")
    f.write('validation_b64='+base64.b64encode(p['validation'].encode()).decode()+'\n')
print(f"Selected target: {p['alias']}")
PY
