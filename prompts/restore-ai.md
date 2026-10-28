# Restore AI: One-Product Quality-First Launch Objective (2026-10-28)

**User intent:** stop counting commits as product progress. Ship ONE existing Korean `photo_restore` product at its existing 5,900 KRW price **only after** real photo quality, guarded staging, payment/refund and download evidence. No new restoration modes, overseas checkout, video, affiliate work, redesign-only batches, or launch promises.

## Single-writer and newest-code contract
- Inspect `AGENTS.md`, latest `AUTODEV_STATUS.md`, Draft PR #29 `feat/restore-local-quality-review-20261025`, recent PRs, CI and the independent owner's hourly coder run **before editing**. Source code prevails over stale documents and dated reference SHAs.
- Existing owner-controlled Restore AI hourly developer is the primary code writer. **Do not create a competing write to the same source/path if that task is in progress, or if its new PR/branch has not been reconciled.** Fail closed with a non-writing status rather than starting a duplicate AI call/PR. Independent read-only QA remains read-only.
- When safely the only active writer, select **one** outcome-changing quality or release blocker, complete implementation, reproduce and test. Reuse existing scripts, pipeline, payment safety infrastructure and photo recipes. Avoid tiny novel variants of already covered P0 test cases, extensive documentation-only batches, and repeated synthetic tests with no saleable-image gain.
- A new verified payment, privacy, customer-authorization, data-loss or duplicate-charge **P0** takes precedence over image features. Otherwise prioritize actual photo fidelity + completion of existing single-order workflow ahead of hypothetical P0 variants.

## Image quality: measure the thing the customer buys
- Test and route distinct existing classes: old_portrait (conservative identity-safe restoration), printed_scan (scratch/halftone), recent_blur (faithful deblur). Use existing experimental NAFNet, Dust-Scratch V2 and source-anchored fusion only as unverified candidates until real evidence authorizes changes.
- Keep original recognizable facial structure: eyes, nose, lips, face outline, expression, clothing, period detail, people count and framing. An invented sharp face is NOT correct restoration; original information may be irrecoverable.
- Before proposing automatic commercial model adoption, evaluate lawful **consented** cases FACE-01..05 and WALL-01..05 with comparison to existing baseline, at least 2 reviewers, and metrics from `docs/PHOTO_QUALITY_ACCEPTANCE_KR.md`. Do not move private photos or personal data into GitHub, CI or logs. If inputs/output and human reviewers unavailable, explicitly mark human quality **UNVERIFIED**, do not fabricate scores or add another meaningless score fixture.
- Do not confuse synthetic PSNR and passing `npm run check` with actual 9/10 face quality. Progress metric is `real_cases_reviewed / 10`, `real_cases_passed / 10`, `identity_drift_count`, unresolved source limitations, and verified production blockers, NOT number of PRs.

## Single paid-product launch proof
- Preserve existing server-side price and product rules. Verify from a protected nonproduction staging environment: authorized image upload, validated source, one order, Toss TEST capture/failed/canceled flow, paid AI adapter once only with bounded costs, image QC, private download/re-read, expired access refusal, and provider-confirmed refund/recovery. Simulations and localhost checks are prerequisites, not proof of real provider availability.
- Do not turn on additional product SKUs or scope creep. Fix only demonstrated blockers; avoid reworking stable payment logic for theoretical edge cases unless a new exploit/failing transaction is reproducible.
- No real customer's photos, production secret, real Toss charge/refund, paid fal/Topaz calls, remote Cloudflare mutation, PROD deployment, `main` merge, or pricing change absent explicit owner approval for that specific action. Preserve `DEMO_MODE=true`, `PAID_ONLY_AI=true`, `DAILY_AI_BUDGET_KRW=0`; never silently enable cost.
- If the private source repo Actions fail before runner assignment (no steps/runner), do NOT waste retries: use the available independent public runner on an immutable private source SHA for locked `npm ci`, full `npm run check`, target Python tests, and when applicable private staging preflight/local migrated-D1 HTTP smoke.
- Keep the current Draft PR #29 as guarded integration until real photo and staging/payment approvals. Only independently tested, conflict-free changes may be stacked into PR #29 with exact SHA/actual diff evidence.

## Report after every productive run
`source SHA | actual code/bug fixed | exact CI and real-photo evidence | cases passed/10 (or NOT TESTED) | one immediate next release blocker | paid/prod unchanged`. Do not claim 8.5/9/10, commerce readiness, or delivery date from guessed timelines. Work toward the customer buying a clearly better restored photo, not a larger repository.
