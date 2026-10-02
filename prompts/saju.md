# Daangn Saju / Fortune Atlas KR cash-first ship mode

Goal: finish the Korea revenue path while preserving compatibility with the shared Fortune Atlas global core.

## Hard release order
1. Real birth input -> deterministic Saju engine -> free result.
2. Standard/Premium/Signature product rules grounded in the current repository configuration.
3. Product -> order -> provider-neutral payment core.
4. Verify the current PayApp production/readiness state from source and provider evidence; never assume pending or approved from stale documentation.
5. Verified provider result -> server-side payment verification -> correct entitlement.
6. Paid web result -> PDF -> refresh/browser-close/re-entry recovery.
7. Web/PDF use the same analysis snapshot and cannot leak another customer's order.
8. Payment return, webhook/reconciliation, retries and idempotency remain safe.
9. Mobile 360/390/430 end-to-end flow.
10. P0 release blocker zero; no known P1 release-critical error.
11. Attribution events for visit -> free result -> product select -> checkout start -> payment verified -> fulfillment.
12. Keep the shared core ready for international markets without equating locale with market.

## Global architecture rule
- KR is one market surface, not a forked product engine.
- Keep market, locale, currency, price, provider, tax/legal copy, consent/privacy, upsell and feature availability separately configurable.
- Overseas payment/report logic belongs in shared/provider-neutral contracts where possible.
- Do not copy KR-only assumptions into US/JP/TW/ES/BR/GLOBAL.

## Revenue-first freeze
Until the above flow is verified, do not spend runs on new fortune categories, decorative UI, speculative modules or status-only edits.

## Safety
- No fake payment success or unverified entitlement.
- No automated real monetary charge.
- No paid API/service activation, ad spend, public launch switch, secret changes or auto-merge.
- Email/SMS remain optional and fail closed when unconfigured.
- Deterministic calculation facts come first; explanations must not invent unsupported timing/events.
- Do not modify target-repo GitHub workflows.

## Definition of useful progress
A Korea release/revenue blocker is removed in source/tests and the configured release gate/build passes.
