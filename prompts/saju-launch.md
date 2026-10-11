# UNKIVE — P0 launch-hardening autonomous lane (hourly, ONE review PR)

You are operating on the **current release candidate source**, not the obsolete `autodev-v12` branch.
Before touching code, check the actual branch contents, `scripts/production-contract-check.mjs`, the latest P0 tests and in-flight PRs.

## Source and handoff
- Repository: `seongjin1908/daangn-saju-autodev`
- Base/source: `release/unkive-production-1791471961339` (a moving branch; never pin an old SHA).
- Another engineer/chat may update this release branch concurrently. If it changes, **stop** rather than force/rebase blindly.
- Make at most ONE small, independently reviewable PR at a time; the backlog guard refuses another while an open saju-core PR is awaiting integration.
- No merging and no AppDeploy deployment. A green test does not establish successful real-money PayApp checkout.

## Deliverable priority: P0 only
1. Broken/slow free-saju first-result display or irreproducible mobile flow.
2. Completed, verified PayApp order opening its WEB result promptly without repeated payment or entering the number again.
3. PDF response/download consistency; no truncated Korean, orphan evidence headings or huge unused page space.
4. Authenticated re-entry after reload, network failure or expired session, never confusing two orders.
5. Strict regression coverage for those flows and actual Standard/Premium rendered PDFs.

## Contract guardrails
- Never change `cron.json`, live workers, provider secrets, payment provider configuration, product prices, user/order DB migrations, billing logic, webhook signature checks or authorization rules in an autonomous batch.
- Do not modify `backend/index.ts`, payment/entitlement implementation or the protected production baseline checksum just to pass CI. File a narrow review proposal if a code change truly requires payment/backend modification.
- Do not add speculative dream, face, palm, compatibility, marketing or new paid products. Those are separately tracked and are not the launch blocker.
- Never invent payment success, test results, completion percentages, or deployment changes.
- Preserve deterministic engine, report content quality and the original consent and privacy rules. Synthetic fixtures only.
- Prefer changes to isolated frontend helpers, strict tests and PDF rendering presentation with reversible, clearly documented deltas.
- If the next improvement is already implemented or another PR owns it, **do no work**. Avoid duplicate code.

## Minimum quality requirements
- Every batch must include executable tests for its behavioral change.
- Maintain exact verified production contract hashes; don't edit guardrails merely to silence an assertion.
- Run the checked-in baseline validation and applicable synthetic browser/PDF tests.
- Never auto-merge; GitHub CI review and final QA are required before any production action.
- The canonical release branch may move during work; compare against the base again before proposing a PR.
