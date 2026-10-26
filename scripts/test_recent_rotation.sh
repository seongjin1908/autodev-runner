#!/usr/bin/env bash
# The rotation must find another eligible target instead of wasting a
# half-hour scheduled run on a recently edited source branch.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
cat > "$TEMP/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == pr && "${2:-}" == list ]]; then
  echo '[]'
  exit 0
fi
[[ "${1:-}" == api ]] || exit 11
case "${2:-}" in
  repos/*/git/ref/heads/*)
    echo "synthetic-sha"
    ;;
  repos/*/commits/*)
    if [[ -n "${MOCK_RECENT_COMMIT_PATH:-}" && "$2" == "$MOCK_RECENT_COMMIT_PATH" ]]; then
      date -u '+%Y-%m-%dT%H:%M:%SZ'
    else
      echo "2000-01-01T00:00:00Z"
    fi
    ;;
  repos/*)
    echo true
    ;;
  *)
    echo "Unknown simulated endpoint: $2" >&2
    exit 12
    ;;
esac
MOCK
chmod +x "$TEMP/gh"
export PATH="$TEMP:$PATH" GH_TOKEN="mock" TARGET="auto"
export GITHUB_OUTPUT="$TEMP/output"
: > "$GITHUB_OUTPUT"
bash "$ROOT/scripts/select_target.sh" > "$TEMP/first.log"
first="$(sed -n 's/^alias=//p' "$GITHUB_OUTPUT")"
repo="$(sed -n 's/^repository=//p' "$GITHUB_OUTPUT")"
branch="$(sed -n 's/^checkout_branch=//p' "$GITHUB_OUTPUT")"
test -n "$first" && test -n "$repo" && test -n "$branch"
export MOCK_RECENT_COMMIT_PATH="repos/$repo/commits/$branch"
: > "$GITHUB_OUTPUT"
set +e
bash "$ROOT/scripts/select_target.sh" > "$TEMP/second.log" 2>&1
code=$?
set -e
next="$(sed -n 's/^alias=//p' "$GITHUB_OUTPUT")"
grep -q "Skipping recently modified automatic target" "$TEMP/second.log"
# Accelerated rotation allows ONLY FastBrowse/Restore. A recently modified
# candidate must route to the other active lane, never to paused projects.
[[ "$first" == fastbrowse || "$first" == restore-ai ]]
test "$code" -eq 0
test -n "$next"
test "$first" != "$next"
[[ "$next" == fastbrowse || "$next" == restore-ai ]]
echo "PASS: recent target safely rotates to the other approved active lane"
