#!/usr/bin/env bash
# Zero-AI review queue summary. Runs only on backlog hold, never merges or deploys.
set -euo pipefail
if [[ "${REPOSITORY:-}" != "seongjin1908/daangn-saju-autodev" ]]; then
  exit 0
fi
BASE_BRANCH="${BASE_BRANCH:-autodev-v12}"
OUTPUT="${GITHUB_STEP_SUMMARY:-/tmp/saju-review-queue.md}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
if ! gh pr list -R "$REPOSITORY" --state open --base "$BASE_BRANCH" --limit 100 --json number,title,headRefName,mergeable,statusCheckRollup > "$TMP"; then
  echo "Review queue unavailable (GitHub API error); no model run." >> "$OUTPUT"
  exit 0
fi
python3 - "$REPOSITORY" "$TMP" "$OUTPUT" <<'PY'
import json, sys
from pathlib import Path
repo, input_path, output = sys.argv[1:]
items=json.loads(Path(input_path).read_text(encoding="utf-8"))
assert isinstance(items,list)
def kind(x):
    name=str(x.get("headRefName", ""))
    if x.get("number")==96 or name.startswith("brand/unkive"): return "brand"
    if name.startswith("autodev/saju-core/"): return "core"
    if name.startswith("autodev/saju-global/"): return "global"
    return None
def check_summary(x):
    checks=x.get("statusCheckRollup") or []
    if not isinstance(checks,list): return "UNKNOWN"
    if not checks: return "UNVERIFIED"
    statuses=[str(y.get("conclusion") or y.get("state") or y.get("status") or "").upper() for y in checks if isinstance(y,dict)]
    if any(y in ("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT") for y in statuses): return "FAIL"
    if any(y in ("IN_PROGRESS", "PENDING", "QUEUED", "EXPECTED") for y in statuses): return "PENDING"
    if statuses and all(y in ("SUCCESS", "NEUTRAL", "SKIPPED") for y in statuses): return "PASS"
    return "CHECK"
rows=[x for x in items if kind(x)]
priority={"brand":0,"core":1,"global":2}
rows.sort(key=lambda x:(priority[kind(x)], 0 if check_summary(x)=="PASS" else 1, x.get("number",0)))
out=["## UNKIVE review queue — new AI generation held", "",
     "No auto-merge, no charge, no production deploy. Review verified existing work first.", "",
     "| Lane | PR | CI | Merge readiness |", "|---|---|---|---|"]
for x in rows:
    number=int(x.get("number",0))
    title=str(x.get("title","")).replace("|","/").replace("\n"," ")[:72]
    mergeable=str(x.get("mergeable","UNKNOWN"))
    out.append(f"| {kind(x)} | [#{number} {title}](https://github.com/{repo}/pull/{number}) | {check_summary(x)} | {mergeable} |")
core=sum(kind(x)=="core" for x in rows)
global_=sum(kind(x)=="global" for x in rows)
out+=["",f"Backlog: core={core}, global={global_}. Review candidates (not an automated approval): PR #96 brand; P0 free/reopen/payment/PDF first; all compatibility only after core lifecycle QA.", ""]
with Path(output).open("a",encoding="utf-8") as f:
    f.write("\n".join(out)+"\n")
print(f"Review-only queue generated: core={core}, global={global_}, total={len(rows)}")
PY
