# Saju launch ship mode — current priority

Goal: finish the existing Daangn Saju product for real release. Do not add speculative features.

## Hard release order
1. Real birth input -> deterministic Saju engine -> free result.
2. Deterministic chart/Daeun/LiuNian timing facts -> Standard/Premium paid report.
3. Product -> order -> Toss checkout -> server-side payment verification.
4. Verified payment -> correct paid result entitlement.
5. Web result/PDF parity and safe PDF download.
6. Refresh/browser-close/re-entry recovery without leaking another customer's order.
7. Mobile 360/390/430 release flow.
8. Production-path mock/fake/test-only cleanup and payment/security hardening.
9. Build/validation green.
10. AppDeploy deployment/E2E only when credits are available.

## Current locked product decisions
- P001 Standard normal price: 9,900 KRW.
- P002 Premium normal price: 19,900 KRW.
- Never restore stale 5,900/9,900 base pricing.
- Daangn coupon pricing is external promotion logic unless a real tested source-aware coupon path exists.
- No synthetic payment success, no test-provider route in production, no fake entitlement.

## Current architecture to preserve
- Real calculation is deterministic; AI may explain verified facts only.
- Production timing flow is wired through timing context/interactions into paid analysis. Preserve and strengthen it; do not replace it with prose-only timing.
- Different real birth inputs must produce different verified facts and materially different report grounding.
- If timing evidence is insufficient, fail closed instead of inventing a specific date/event.
- Standard covers money, work/business, relationship, current flow and near-term flow.
- Premium must be structurally deeper with longer Daeun/LiuNian context, not merely longer wording.
- Web and PDF must use the same order fortune/analysis snapshot.
- Order/token/email boundaries must prevent cross-customer result access.
- Toss amount/order/paymentKey/idempotency checks must remain server-side and exact.

## AppDeploy credit rule
AppDeploy is currently credit-blocked until the known reset window. Do not spend a batch retrying deployment while blocked.
Use GitHub code + deterministic tests + build as the working control plane.
When deployment is available again, deployment/E2E becomes the highest remaining external verification step.

## Speed rules
- Inspect the current branch first; do not redo completed work.
- If baseline validation fails, fix that root cause first.
- If validation is green, choose the highest incomplete P0 item above and implement a coherent 2-4-file/related-test batch when justified.
- Prefer production code + regression tests. Do not spend a run on status/docs-only changes while P0 code work remains.
- Do not rewrite stable architecture just to look busy.
- Do not add new providers, new product families, broad refactors, admin features, SEO work, or cosmetic polish unless required to remove a release blocker.
- Test fixtures/mocks may remain under tests/scripts. Production backend/src must not expose mock/fake/dummy/sample/test-only payment/result substitutes.
- Normal HTML placeholder attributes are not fake data.
- Do not modify Fortune repository or target-repo GitHub workflows.
- Email/SMS stay optional and must fail closed when unconfigured.
- No paid API/service activation, live spending, public launch switch, destructive migration, or secret changes.

## Definition of useful progress
A release blocker is removed in real code and the configured validation/build passes.

If all GitHub-verifiable P0 items are already complete, strengthen the smallest missing regression proof for payment/result/PDF/re-entry/mobile rather than inventing a new feature.
