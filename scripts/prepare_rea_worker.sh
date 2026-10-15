#!/usr/bin/env bash
# Source this script from develop_target.sh after OpenCode installation.
# Optional REA MCP registration is ephemeral; it never changes a target checkout.
rea_worker_setup() {
  REA_MCP_CONNECTED=false
  export REA_MCP_CONNECTED
  local mode="${REA_AUTODEV_MODE:-auto}"
  if [[ "$mode" == "off" || "$mode" == "false" || "$mode" == "0" ]]; then
    echo 'REA: disabled by runner setting.'
    return 0
  fi
  if [[ ! -f .agents/skills/rea-feature-audit/SKILL.md ]]; then
    echo 'REA: no authorized feature-audit skill in the selected target; continuing without MCP.'
    return 0
  fi
  if ! command -v opencode >/dev/null || ! command -v node >/dev/null; then
    echo 'REA: missing OpenCode/Node; continuing without MCP.'
    return 0
  fi
  local node_version
  node_version="$(node --version 2>/dev/null || true)"
  if ! python - "$node_version" <<'PY'
import re,sys
m=re.fullmatch(r'v(\d+)\.(\d+)\.\d+',sys.argv[1])
if not m: raise SystemExit(1)
major, minor=map(int,m.groups())
raise SystemExit(0 if (major==22 and minor>=19) or (major==24 and minor>=11) or major==26 else 1)
PY
  then
    echo "REA: unsupported Node $node_version (needs 22.19+, 24.11+, or 26.x); continuing without MCP."
    return 0
  fi
  local original="${OPENCODE_CONFIG_CONTENT-}" had_original=false candidate
  [[ ${OPENCODE_CONFIG_CONTENT+x} ]] && had_original=true
  if ! candidate="$(python - <<'PY'
import json, os
raw=os.environ.get('OPENCODE_CONFIG_CONTENT','{}')
config=json.loads(raw)
if not isinstance(config,dict): raise ValueError('OpenCode config must be a JSON object')
mcp=config.setdefault('mcp',{})
if not isinstance(mcp,dict): raise ValueError('OpenCode MCP config must be a JSON object')
mcp['rea']={'type':'local','command':['npx','-y','rea-agents@6.5.0','mcp'],'enabled':True,'timeout':30000}
print(json.dumps(config,separators=(',',':')))
PY
)"; then
    echo 'REA: unable to safely merge existing OpenCode config; continuing unchanged.'
    return 0
  fi
  export OPENCODE_CONFIG_CONTENT="$candidate"
  # A real OpenCode MCP handshake, not just a config-file existence check.
  local log="${RUNNER_TEMP:-/tmp}/autodev-rea-mcp-list.log"
  if timeout 65s opencode mcp list >"$log" 2>&1 &&
    sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g' "$log" | grep -Eiq 'rea[[:space:]:._-]+connected([[:space:]]|$)'; then
    REA_MCP_CONNECTED=true
    export REA_MCP_CONNECTED
    echo 'REA: OpenCode MCP connected (actual REA tool use still unverified).'
  else
    if [[ "$had_original" == true ]]; then
      export OPENCODE_CONFIG_CONTENT="$original"
    else
      unset OPENCODE_CONFIG_CONTENT
    fi
    echo 'REA: MCP handshake unavailable; preserving original free-model worker.'
  fi
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "REA_MCP_CONNECTED=$REA_MCP_CONNECTED" >> "$GITHUB_ENV"
  fi
  return 0
}
rea_worker_setup
