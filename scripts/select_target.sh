#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/config/projects.json"
TARGET="${TARGET:-auto}"

if [[ "$TARGET" == "auto" ]]; then
  SLOT_SECONDS="${AUTODEV_ROTATION_SLOT_SECONDS:-3600}"
  if ! [[ "$SLOT_SECONDS" =~ ^[0-9]+$ ]] || (( SLOT_SECONDS < 300 )); then
    echo "Invalid AUTODEV_ROTATION_SLOT_SECONDS: $SLOT_SECONDS" >&2
    exit 2
  fi
  EPOCH_SLOT="$(( $(date -u +%s) / SLOT_SECONDS ))"
  TARGET="$(python - "$CONFIG" "$EPOCH_SLOT" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1], encoding='utf-8'))
epoch=int(sys.argv[2])
projects=[p for p in cfg['projects'] if p.get('auto_enabled', True) and int(p.get('auto_weight', 1)) > 0]
if projects and any('auto_weight' in p for p in projects):
    projects=sorted(projects, key=lambda p:(-int(p.get('release_priority',0)), p['alias']))
    max_weight=max(int(p.get('auto_weight',1)) for p in projects)
    cycle=[]
    for level in range(max_weight):
        for p in projects:
            if int(p.get('auto_weight',1)) > level:
                cycle.append(p['alias'])
else:
    cycle=cfg.get('auto_rotation') or [p['alias'] for p in cfg['projects']]
if not cycle:
    raise SystemExit('No automatic development targets are enabled.')
print(cycle[epoch % len(cycle)])
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
    for k in [
        'alias','repository','work_branch','base_branch','prompt_file',
        'max_changed_files','recent_change_guard_minutes',
        'failure_hold_threshold','failure_hold_minutes',
        'auto_weight','release_priority'
    ]:
        f.write(f"{k}={p.get(k, '')}\n")
    f.write('validation_b64='+base64.b64encode(p['validation'].encode()).decode()+'\n')
print(f"Selected target: {p['alias']} (priority={p.get('release_priority',0)}, weight={p.get('auto_weight',1)})")
PY
