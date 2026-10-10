#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
cat > "$TEMP/gh" <<'FAKE'
#!/usr/bin/env bash
cat <<'JSON'
[
 {"number":96,"title":"UNKIVE brand","headRefName":"brand/unkive-premium-v1","mergeable":"MERGEABLE"},
 {"number":107,"title":"compatibility","headRefName":"autodev/saju-core/example","mergeable":"MERGEABLE"},
 {"number":93,"title":"i18n","headRefName":"autodev/saju-global/example","mergeable":"MERGEABLE"},
 {"number":12,"title":"unrelated","headRefName":"other/branch","mergeable":"MERGEABLE"}
]
JSON
FAKE
chmod +x "$TEMP/gh"
export PATH="$TEMP:$PATH" REPOSITORY="seongjin1908/daangn-saju-autodev" BASE_BRANCH="autodev-v12" GITHUB_STEP_SUMMARY="$TEMP/summary"
bash "$ROOT/scripts/saju_review_queue.sh"
grep -q 'UNKIVE review queue' "$GITHUB_STEP_SUMMARY"
grep -q 'Backlog: core=1, global=1' "$GITHUB_STEP_SUMMARY"
grep -q 'UNVERIFIED' "$GITHUB_STEP_SUMMARY"
grep -q 'pull/96' "$GITHUB_STEP_SUMMARY"
if grep -q 'unrelated' "$GITHUB_STEP_SUMMARY"; then echo "unrelated PR leaked"; exit 1; fi
echo 'PASS: UNKIVE review summary without CI read scope, queue and source filtering'
