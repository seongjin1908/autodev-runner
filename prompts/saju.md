# Saju launch ship mode — current priority

Goal: finish Fortune Atlas / Daangn Saju to revenue-ready production quality first. Do not spend development cycles on 궁합/별자리/이름풀이/관상/손금/타로 until the Saju product is publicly deployable, payment-safe, conversion-tracked, and ready for paid acquisition.

## Hard release order
1. Real birth input -> deterministic Saju engine -> free result.
2. Deterministic chart/Daeun/LiuNian timing facts -> Standard/Premium paid report.
3. Product -> order -> provider-neutral payment core.
4. Korea: PayApp production path only after merchant review/approval is actually complete.
5. Overseas: PayPal Live create/approve/capture with exact server-side order, product, currency, amount and idempotency verification.
6. Verified payment -> correct paid result entitlement.
7. Web result/PDF parity and safe PDF download.
8. Refresh/browser-close/re-entry recovery without leaking another customer's order.
9. Payment recovery/webhook handling so a customer closing the browser does not lose a verified purchase.
10. Mobile 360/390/430 release flow.
11. Production-path mock/fake/test-only cleanup and payment/security hardening.
12. Build/validation green.
13. AppDeploy deployment + non-charge E2E verification.

## Current locked product decisions
- P001 Standard Korea normal price: 9,900 KRW.
- P002 Premium Korea normal price: 19,900 KRW.
- Overseas launch price currently used on AppDeploy: P001 $7.99 USD, P002 $14.99 USD.
- Daangn coupon pricing is external promotion logic unless a real tested source-aware coupon path exists.
- No synthetic payment success, no fake entitlement, no live-charge automated QA.
- Toss is not the intended Korea production provider now. Keep any existing Toss code only as isolated legacy/test/reference until a verified replacement is complete; do not activate paid Toss production onboarding unless explicitly approved.

## Payment direction
- Production Korea target: PayApp, approval pending. Until approval, the live Korea checkout must remain clearly disabled/pending instead of routing to another provider.
- Production overseas target: PayPal Live.
- Preserve a provider-neutral order/payment domain so PayApp and PayPal do not fork entitlement logic.
- All amount, order, product, currency, provider event and idempotency checks remain server-side.
- PayPal Live automated tests may verify OAuth/readiness and code paths but must never complete a real monetary charge.
- Add/strengthen webhook/reconciliation handling before calling the payment path release-complete.
- Email and phone are optional before overseas checkout. When PayPal returns a verified payer email, it may be attached to the order for result recovery.

## Current consumer UX decisions
- Name placeholder: "예: 홍길동".
- Gender order: 남성 left, 여성 right.
- Do not use a click-to-open "결과 보는 법" accordion in the free result. Important meaning should be visible inline.
- The free result should be consumer-language first; raw chart/calculation evidence is secondary.
- Premium locked questions must be visually obvious, larger, and clearly marked as locked/paid.
- PDF preview, trust, about and FAQ content belong below the free result, not between input and the result.
- The page should look professional/modern, but conversion polish must not replace real release blockers.
- Never imply unfinished modules are already live. Mark them 개발중/준비중 until their engines and tests exist.

## Current architecture to preserve
- Real calculation is deterministic; AI may explain verified facts only.
- Production timing flow is wired through timing context/interactions into paid analysis. Preserve and strengthen it; do not replace it with prose-only timing.
- Different real birth inputs must produce different verified facts and materially different report grounding.
- If timing evidence is insufficient, fail closed instead of inventing a specific date/event.
- Standard covers money, work/business, relationship, current flow and near-term flow.
- Premium must be structurally deeper with longer Daeun/LiuNian context, not merely longer wording.
- Web and PDF must use the same order fortune/analysis snapshot.
- Order/token/email boundaries must prevent cross-customer result access.

## AppDeploy rule
- AppDeploy is available again. Use deployment and non-charge E2E when a batch is ready.
- Do not repeatedly redeploy cosmetic-only changes while a functional P0 blocker remains.
- Never use automated QA to make a real PayPal charge or irreversible production transaction.

## Speed rules
- Inspect the current branch first; do not redo completed work.
- If baseline validation fails, fix that root cause first.
- If validation is green, choose the highest incomplete P0 item above and implement a coherent 2-4-file/related-test batch when justified.
- Prefer production code + regression tests. Do not spend a run on status/docs-only changes while P0 code work remains.
- Do not rewrite stable architecture just to look busy.
- Test fixtures/mocks may remain under tests/scripts. Production backend/src must not expose mock/fake/dummy/sample/test-only payment/result substitutes.
- Normal HTML placeholder attributes are not fake data.
- Do not modify Fortune repository or target-repo GitHub workflows.
- Email/SMS stay optional and must fail closed when unconfigured.
- No paid API/service activation, live spending, public launch switch, destructive migration, or secret changes.

## Revenue-first freeze
Until the Saju product is ready for real paid acquisition, do not build or polish 궁합/별자리/이름풀이/관상/손금/타로. Those modules may remain documented for later, but they are not current work.

Before any expansion module, Saju must have:
1. deterministic free result verified,
2. Standard/Premium report differentiation verified,
3. PayPal Live overseas payment path + reconciliation/webhook recovery,
4. PayApp Korea path ready to activate immediately after merchant approval,
5. payment -> entitlement -> web result -> PDF -> re-entry verified,
6. mobile 360/390/430 release flow,
7. P0 blocker 0 and no known P1 release-critical error,
8. production build/CI green,
9. deployed smoke test green,
10. ad attribution events for visit -> free result -> product select -> checkout start -> payment verified -> fulfillment,
11. landing/result UX optimized for paid conversion without deceptive claims.

Only after the above is true and the owner explicitly switches focus may expansion resume in this order: 궁합 -> 별자리 -> 이름풀이 -> 관상 -> 손금 -> 타로.

## Definition of useful progress
A Saju release/revenue blocker is removed in real code and the configured validation/build passes. No expansion work counts as useful progress while a Saju release or monetization blocker remains.
