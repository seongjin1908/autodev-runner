# Fortune Atlas cash-first release objective

Fortune Atlas / Daangn Saju is the highest-priority revenue product. Treat Fortune Atlas as the shared platform core with market-specific KR/Daangn and global surfaces. Do not build unrelated expansion modules while any release/revenue blocker remains.

## P0 order
1. Repair failing CI/release audits and keep them green.
2. Preserve deterministic Saju/Myeongri calculations and regression coverage.
3. Complete the real customer path: birth input -> free result -> product choice -> payment -> entitlement -> paid web result -> PDF -> reopen/recovery.
4. Korea: PayApp path must be verified from current code/provider evidence; do not assume approval or readiness.
5. Overseas: provider-neutral payment core with PayPal path where configured, exact server-side order/product/currency/amount/idempotency verification, and no automated real charges.
6. Make mobile 360/390/430 usable with no horizontal overflow, CTA overlap, unreadable product cards, or inaccessible paid-result/PDF controls.
7. Keep WEB/PDF parity from the same verified order snapshot.
8. Preserve attribution from landing -> free result -> product select -> checkout -> verified payment -> fulfillment.
9. Keep market and locale separate. KR/US/JP/TW/ES/BR/GLOBAL may have different price, currency, provider, legal copy, consent, upsell and availability.
10. Unsupported markets or providers must fail closed.

## Scope freeze
- No broad refactor.
- No 궁합/별자리/이름풀이/관상/손금/타로 while core Saju release blockers remain.
- No cosmetic-only batch while a functional blocker exists.
- No fake payment success, synthetic entitlement, live-charge automated QA, paid AI/API activation, secret changes, production deploy or auto-merge.
- Do not modify target-repo GitHub workflows.
- Do not duplicate logic between KR and global surfaces when a shared core can safely serve both.

## Definition of useful progress
A real release/revenue blocker is removed, regression coverage is strengthened, and configured validation passes. Code volume alone is not progress.


## Integrated design rule
Do not spend a separate automatic lane on cosmetic-only redesign. When the functional P0/P1 work in a batch is safe, improve the touched UI toward a current mobile-first product standard: clear hierarchy, restrained components, deliberate spacing, accessible controls and no generic AI-looking card soup. Preserve existing tested behavior.
