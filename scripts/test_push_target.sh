#!/usr/bin/env bash
set -euo pipefail

# Local, credential-free regression for runner push safety.
# Target checkout exists only inside CI, not in a real production repo.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
TARGET_DIR="$ROOT_DIR/target"
if [[ -e "$TARGET_DIR" ]]; then
  echo "Refusing to overwrite an existing target checkout" >&2
  exit 1
fi
cleanup() {
  rm -rf "$TMP" "$TARGET_DIR"
}
trap cleanup EXIT
git init --quiet --bare "$TMP/remote.git"
git init --quiet -b main "$TARGET_DIR"
git -C "$TARGET_DIR" config user.name "Autodev CI"
git -C "$TARGET_DIR" config user.email "autodev-ci@example.invalid"
printf "baseline\n" > "$TARGET_DIR/change.txt"
git -C "$TARGET_DIR" add change.txt
git -C "$TARGET_DIR" commit --quiet -m baseline
git -C "$TARGET_DIR" remote add origin "$TMP/remote.git"
git -C "$TARGET_DIR" push --quiet -u origin main
BASE_SHA="$(git -C "$TARGET_DIR" rev-parse HEAD)"
WORK_BRANCH="autodev/saju-core/ci-run-1"
git -C "$TARGET_DIR" switch --quiet -c "$WORK_BRANCH"
printf "validated change\n" >> "$TARGET_DIR/change.txt"
git -C "$TARGET_DIR" commit --quiet -am "verified auto code"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "auth setup-git"|"pr create") exit 0 ;;
  "pr list") printf '[]\n'; exit 0 ;;
  *) echo "Unexpected gh operation: $*" >&2; exit 5 ;;
esac
MOCK
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH"
export WORK_BRANCH BASE_BRANCH=main REPOSITORY=example/example START_SHA="$BASE_SHA"

# Scenario 1: remote run-scoped ref absent; guarded push MUST succeed.
test -z "$(git -C "$TARGET_DIR" ls-remote --heads origin "refs/heads/$WORK_BRANCH")"
bash "$ROOT_DIR/scripts/push_target.sh" >"$TMP/first.log" 2>&1
LOCAL_HEAD="$(git -C "$TARGET_DIR" rev-parse HEAD)"
REMOTE_HEAD="$(git -C "$TARGET_DIR" ls-remote --heads origin "refs/heads/$WORK_BRANCH" | awk '{print $1}')"
if [[ "$REMOTE_HEAD" != "$LOCAL_HEAD" ]]; then
  echo "Validated branch was not pushed" >&2
  cat "$TMP/first.log"
  exit 1
fi

# Scenario 2: someone created the remote branch; stale START_SHA MUST fail,
# not turn the entire workflow green while silently discarding a batch.
printf "second\n" >> "$TARGET_DIR/change.txt"
git -C "$TARGET_DIR" commit --quiet -am "second local batch"
if bash "$ROOT_DIR/scripts/push_target.sh" >"$TMP/second.log" 2>&1; then
  echo "Remote collision incorrectly returned success" >&2
  cat "$TMP/second.log"
  exit 1
fi
grep -q 'Remote branch advanced during the run' "$TMP/second.log"
UNCHANGED_REMOTE="$(git -C "$TARGET_DIR" ls-remote --heads origin "refs/heads/$WORK_BRANCH" | awk '{print $1}')"
test "$UNCHANGED_REMOTE" = "$REMOTE_HEAD"
echo "PASS: first run-scoped batch pushed, remote collision fails and keeps branch unchanged"
