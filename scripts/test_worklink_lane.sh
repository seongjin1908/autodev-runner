#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1])
cfg=json.loads((r/'config/projects.json').read_text())
p=next(x for x in cfg['projects'] if x['alias']=='worklink')
assert p['repository']=='seongjin1908/worklink'
assert p['auto_enabled'] and p['auto_weight']>0
assert p['base_branch']==p['source_branch']=='main'
assert p['branch_mode']=='run_scoped'
assert p['max_branch_ahead']==0
assert 'npm test' in p['validation'] and 'npm run build' in p['validation']
prompt=(r/p['prompt_file']).read_text()
assert 'PR #5' in prompt and 'private-source' in prompt
wf=(r/'.github/workflows/worklink-free-dispatch.yml').read_text()
assert 'cron:' in wf and 'target=worklink' in wf
assert 'actions: write' in wf and 'autodev.yml' in wf
assert 'gh workflow run' in wf
assert 'seongjin1908/autodev-runner' in wf
assert 'paid' in wf.lower()
print('PASS: WORKLINK latest validated P0 lane and scheduled free dispatch')
PY
