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

  mapfile -t AUTO_CYCLE < <(python - "$CONFIG" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1], encoding='utf-8'))
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
for alias in cycle:
    print(alias)
PY
  )

  if (( ${#AUTO_CYCLE[@]} == 0 )); then
    echo "No automatic development targets are enabled." >&2
    exit 3
  fi

  START_INDEX="$(( EPOCH_SLOT % ${#AUTO_CYCLE[@]} ))"
  SELECTED_TARGET=""
  for (( offset=0; offset<${#AUTO_CYCLE[@]}; offset++ )); do
    index="$(( (START_INDEX + offset) % ${#AUTO_CYCLE[@]} ))"
    candidate="${AUTO_CYCLE[$index]}"

    if [[ -z "${GH_TOKEN:-}" ]]; then
      SELECTED_TARGET="$candidate"
      break
    fi

    IFS='|' read -r candidate_repo candidate_branch < <(python - "$CONFIG" "$candidate" <<'PY'
import json,sys
cfg,target=sys.argv[1:3]
p=next((x for x in json.load(open(cfg, encoding='utf-8'))['projects'] if x['alias']==target), None)
if not p:
    raise SystemExit(f'Unknown target: {target}')
branch = p['work_branch'] if p.get('branch_mode','fixed') != 'run_scoped' else (p.get('source_branch') or p['base_branch'])
print(f"{p['repository']}|{branch}")
PY
    )

    set +e
    push_allowed="$(gh api "repos/$candidate_repo" --jq '.permissions.push // false' 2>/dev/null)"
    repo_rc=$?
    gh api "repos/$candidate_repo/git/ref/heads/$candidate_branch" --jq .object.sha >/dev/null 2>&1
    branch_rc=$?
    set -e

    if [[ "$repo_rc" -eq 0 && "$branch_rc" -eq 0 && "$push_allowed" == "true" ]]; then
      SELECTED_TARGET="$candidate"
      break
    fi
    echo "Skipping inaccessible automatic target: $candidate ($candidate_repo@$candidate_branch)" >&2
  done

  if [[ -z "$SELECTED_TARGET" ]]; then
    echo "No accessible automatic development target is available for the configured repository token." >&2
    exit 4
  fi
  TARGET="$SELECTED_TARGET"
fi
python - "$CONFIG" "$TARGET" "$GITHUB_OUTPUT" <<'PY'
import base64,json,os,re,sys
cfg,target,out=sys.argv[1:4]
projects=json.load(open(cfg, encoding='utf-8'))['projects']
p=next((x for x in projects if x['alias']==target), None)
if not p:
    raise SystemExit(f'Unknown target: {target}')
if p.get('development_status') == 'hold':
    raise SystemExit(f"Target is on HOLD: {target} ({p.get('hold_reason','no reason provided')})")
branch_mode=p.get('branch_mode','fixed')
configured_work=p['work_branch']
checkout_branch=configured_work
work_branch=configured_work
if branch_mode == 'run_scoped':
    run_id=os.environ.get('GITHUB_RUN_ID','local')
    attempt=os.environ.get('GITHUB_RUN_ATTEMPT','1')
    safe_alias=re.sub(r'[^A-Za-z0-9._-]+','-',p['alias']).strip('-') or 'target'
    work_branch=f"autodev/{safe_alias}/{run_id}-{attempt}"
    checkout_branch=p.get('source_branch') or p['base_branch']

with open(out,'a',encoding='utf-8') as f:
    values={
        **p,
        'work_branch': work_branch,
        'checkout_branch': checkout_branch,
        'branch_mode': branch_mode,
    }
    for k in [
        'alias','repository','work_branch','checkout_branch','branch_mode','base_branch','prompt_file',
        'max_changed_files','max_branch_ahead','recent_change_guard_minutes',
        'failure_hold_threshold','failure_hold_minutes',
        'auto_weight','release_priority'
    ]:
        f.write(f"{k}={values.get(k, '')}\n")
    f.write('validation_b64='+base64.b64encode(p['validation'].encode()).decode()+'\n')
print(f"Selected target: {p['alias']} (priority={p.get('release_priority',0)}, weight={p.get('auto_weight',1)})")
PY
