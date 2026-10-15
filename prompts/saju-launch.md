# UNKIVE — competition-first P0 autonomous launch lane

You work on the moving `release/unkive-production-1791471961339` branch of `seongjin1908/daangn-saju-autodev`. The user's overriding business goal is simple: **same-birth-data, same-purchase-scope saju reports must be judged better than real competitors**, not just pass build, look long, or accumulate PRs.

## Mandatory safety and active-work inspection
- Check the actual latest release HEAD, open PRs, current QA, CI and `scripts/production-contract-check.mjs` before coding.
- In-flight PR #201 (free result/session) was based on an older release and conflict-prone. PR #202 (paid-order re-entry) has a known edit-during-pending-request race noted in its GitHub review comment. Do not duplicate or bypass their pending review; if merged or fixed meanwhile re-evaluate current state.
- Only one small cohesive review PR per run. Never merge or deploy automatically, force/rebase across new HEAD, bypass review backlog guards, or change payments/secrets/customer records.
- PR build PASS and `synthetic` editorial checks never equal competitor-superiority PASS or live-payment PASS.

## Development priority — close one meaningful deficiency per run
1. **P0 content quality**: remove generic boilerplate and repeated cross-profile sentences from actual FREE, Standard, Premium and Signature result pipelines; strengthen chart-derived, year-specific reasoning linked to the user's money, work, business, relationship or other chosen interest.
2. **P0 question-level distinctness**: ensure five paid question answers use different natal and annual evidence, different concrete contexts and next steps; do not copy the same advice across profiles/topics. Investigate existing `scripts/unkive-offline-editorial-benchmark.ts`: prior baseline was 80 synthetic reports/400 answers with **203 cross-profile similarity findings**, NOT a passing competitive test. For any content fix, run the same-condition before/after audit and report numerator/denominator and sample differences; do not lower similarity thresholds to claim improvement.
3. **P0 paid value**: Standard 2-year vs Premium 5-year vs Signature 10-year reports must genuinely change depth and evidence, not merely repeat chapters or increase page count. Avoid speculative claims of guaranteed approvals, income, marriage, or event dates. Reuse calculated timing evidence only when it exists.
4. **P0 consumer readability**: reduce jargon and repetitive cautions while retaining legally needed uncertainty. Favor straightforward conclusions, calculated personal reasons, concrete conditional scenes and clear tradeoffs; never invent a user's real life story.
5. **P0 shipping reliability**: preserve or fix first-result rendering, paid result delivery, PDF full-text retention, re-entry security and previously established KST solar-term policy where genuinely broken. Payment/privacy regressions override lower-priority new features.

## Competitive test is an evidence gate, not self-promotion
- Compare at least five identical synthetic or explicitly consented birth profiles across two or more competitors, at least two equivalent FREE/paid scopes, using three independent blinded human judges per paired report. Overall UNKIVE preference >=70%, and >=60% within each competitor and product tier. This is a **target**, not a known result.
- Only original lawful/authorized captured competitor outputs and actual UNKIVE AI outputs count as product evidence. Public product descriptions, copied marketing claims, deterministic admin previews, self-generated competitor answers and synthetic graders **cannot** establish superiority.
- Do not store raw competitor reports, identifying birth details or paid analysis outputs in GitHub. Keep evidence locally/private and report aggregate results and provenance. Never invent citations, tester opinions, or a PASS.
- If real side-by-side outputs/independent judges are unavailable in the runner, say `COMPETITOR_COMPARISON_NOT_EVALUATED` and instead improve deterministic reliability and compile an auditable evaluation flow. Do NOT replace required reports with simulations.

## Batch acceptance
- Add executable regression tests for the user-facing change. Maintain existing immutable source hashes and approved review-hunk contracts. Test frontend/backend types, full launch regression including recovered paid orders, synthetic PDF layout and calculated chart boundaries.
- Keep code minimal, do not weaken thresholds, avoid new dependencies or paid-model/provider calls, and never modify `backend/index.ts`, payment callbacks, pricing, protected hashes, release secrets, user data, or cron without separate authorized review.
- Never create docs-only or test-only PRs as proof of product improvement: one meaningful implementation and its executable regression per batch.
- Do not chase daily horoscopes, compatibility, dreams, face/palm, international launches or marketing while paid-result quality is below the competitive target.
- Never auto-merge or deploy. A human-verified PR and independent pinned-head CI are prerequisites for any production action.

Final report: exact starting HEAD, touched files, behavior changed, before/after repeat indicators, test commands/results, CI URL, competing work avoided, real-AI output verified yes/no, competitor comparison verdict and missing evidence, deployment unchanged.
