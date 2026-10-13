#!/usr/bin/env bash
# Offline smoke tests for the private-target credential preflight.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "api" ]] || exit 55
if [[ "$2" == *"/contents/guard-policy.js?ref=main" ]]; then
  [[ "${MOCK_CAN_READ:-false}" == "true" ]] || exit 56
  echo "mock-blob-sha"
  exit 0
fi
if [[ "$2" == "repos/seongjin1908/cyber-guardian-ai" ]]; then
  if [[ "${MOCK_CAN_PUSH:-false}" == "true" ]]; then echo true; else echo false; fi
  exit 0
fi
exit 57
GH
chmod +x "$TMP/gh"
PASS=0
expect_code(){
  local expected="$1" title="$2";shift 2
  local rc=0
  ( env PATH="$TMP:$PATH" "$@" bash "$ROOT/scripts/preflight_target_access.sh" ) >"$TMP/output.log" 2>&1 || rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "FAIL $title (expected=$expected actual=$rc)"
    cat "$TMP/output.log"
    exit 1
  fi
  PASS=$((PASS+1))
  echo "PASS: $title (exit $rc)"
}
expect_code 0 "unrelated project unchanged" ALIAS=second
expect_code 11 "missing token fails" ALIAS=cyber-guardian GH_TOKEN= REPOSITORY=seongjin1908/cyber-guardian-ai CHECKOUT_BRANCH=main
expect_code 12 "wrong target fails" ALIAS=cyber-guardian GH_TOKEN=mock-only REPOSITORY=invalid/other CHECKOUT_BRANCH=main
expect_code 13 "wrong branch fails" ALIAS=cyber-guardian GH_TOKEN=mock-only REPOSITORY=seongjin1908/cyber-guardian-ai CHECKOUT_BRANCH=feature/other
expect_code 14 "missing private repository read scope fails" ALIAS=cyber-guardian GH_TOKEN=mock-only REPOSITORY=seongjin1908/cyber-guardian-ai CHECKOUT_BRANCH=main MOCK_CAN_READ=false
expect_code 15 "read-only token cannot push" ALIAS=cyber-guardian GH_TOKEN=mock-only REPOSITORY=seongjin1908/cyber-guardian-ai CHECKOUT_BRANCH=main MOCK_CAN_READ=true MOCK_CAN_PUSH=false
expect_code 0 "correctly scoped mock token passes" ALIAS=cyber-guardian GH_TOKEN=mock-only REPOSITORY=seongjin1908/cyber-guardian-ai CHECKOUT_BRANCH=main MOCK_CAN_READ=true MOCK_CAN_PUSH=true
echo "$PASS offline preflight checks passed"
