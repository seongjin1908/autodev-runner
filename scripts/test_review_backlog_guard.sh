#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
cat > "$TEMP/gh" <<'FAKE'
#!/usr/bin/env bash
if [[ "${MOCK_GH_FAIL:-false}" == "true" ]]; then exit 1; fi
printf '%s\n' "${MOCK_PR_JSON:-[]}"
FAKE
chmod +x "$TEMP/gh"
export PATH="$TEMP:$PATH" REPOSITORY="seongjin1908/daangn-saju-autodev" BASE_BRANCH="autodev-v12" BRANCH_MODE="run_scoped"
export WORK_BRANCH="autodev/saju-core/test-1" MAX_PENDING_SAJU_PRS=2
check() {
  local expected="$1"
  local actual=0
  bash "$ROOT/scripts/review_backlog_guard.sh" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected guard exit $expected, got $actual" >&2
    exit 1
  fi
}
MOCK_PR_JSON='[{"headRefName":"autodev/saju-core/one"},{"headRefName":"autodev/saju-core/two"},{"headRefName":"autodev/saju-global/three"}]' check 10
MOCK_PR_JSON='[{"headRefName":"autodev/saju-core/one"},{"headRefName":"autodev/saju-global/three"}]' check 0
MOCK_GH_FAIL=true check 10
WORK_BRANCH="autodev/saju-global/test-1" MOCK_PR_JSON='[{"headRefName":"autodev/saju-core/one"},{"headRefName":"autodev/saju-global/two"},{"headRefName":"autodev/saju-global/three"}]' check 10
WORK_BRANCH="autodev/face-lab/test-1" MOCK_GH_FAIL=true check 0
REPOSITORY="example/other" WORK_BRANCH="autodev/saju-core/test-1" MOCK_GH_FAIL=true check 0
echo 'PASS: saju backlog hold, empty backlog, remote API failure and other-project bypass'
