#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$ROOT/prepare_rea_worker.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/target/.agents/skills/rea-feature-audit" "$TMP/bin"
printf 'authorized owned source only\n' > "$TMP/target/.agents/skills/rea-feature-audit/SKILL.md"
cat > "$TMP/bin/node" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == '--version' ]]; then printf 'v22.19.0\n'; else exec "${REAL_NODE}" "$@"; fi
SH
cat > "$TMP/bin/opencode" <<'SH'
#!/usr/bin/env bash
[[ "$1 $2" == 'mcp list' ]] || exit 10
python - <<'PY'
import json,os
c=json.loads(os.environ['OPENCODE_CONFIG_CONTENT'])
assert c['mcp']['rea']['command']==['npx','-y','rea-agents@6.5.0','mcp']
assert c['preserved']=='yes'
PY
if [[ "$FAKE_REA_STATE" == connected ]]; then echo '✓ rea connected'; else echo '✗ rea failed'; fi
SH
chmod +x "$TMP/bin/"*
REAL_NODE="$(command -v node)"; export REAL_NODE
export PATH="$TMP/bin:$PATH"
cd "$TMP/target"
export OPENCODE_CONFIG_CONTENT='{"preserved":"yes"}'
export FAKE_REA_STATE=connected
source "$SCRIPT"
[[ "$REA_MCP_CONNECTED" == true ]]
[[ "$(python -c 'import json,os;print(json.loads(os.environ["OPENCODE_CONFIG_CONTENT"])["preserved"])')" == yes ]]
export FAKE_REA_STATE=failed
export OPENCODE_CONFIG_CONTENT='{"preserved":"yes"}'
source "$SCRIPT"
[[ "$REA_MCP_CONNECTED" == false ]]
[[ "$OPENCODE_CONFIG_CONTENT" == '{"preserved":"yes"}' ]]
export REA_AUTODEV_MODE=off
export FAKE_REA_STATE=connected
source "$SCRIPT"
[[ "$REA_MCP_CONNECTED" == false ]]
[[ "$OPENCODE_CONFIG_CONTENT" == '{"preserved":"yes"}' ]]
unset REA_AUTODEV_MODE
rm -f .agents/skills/rea-feature-audit/SKILL.md
source "$SCRIPT"
[[ "$REA_MCP_CONNECTED" == false ]]
echo 'PASS REA runtime connected/fallback/disabled/unlicensed target cases'
