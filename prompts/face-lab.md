# FACE LAB cash-first release objective

FACE LAB is the second priority after Saju. Stop broad feature expansion until the existing consumer product can be safely launched and monetized.

## P0 order
1. Repair any build/type/test/security/privacy failure first.
2. Verify the core path: photo upload -> local preflight -> analysis -> result -> best-photo/style outputs -> share/save or paid upgrade path where implemented.
3. Protect privacy: minimize photo retention, enforce file/type/size limits, safe deletion/lifecycle, server-side authorization where applicable, and no sensitive-trait/health/identity/intelligence/sexuality/criminality/wealth/mental-state inference.
4. Verify mobile 360/390/430 and slow/failure/retry states.
5. Make analytics useful for visit -> upload -> analysis started -> result -> upgrade/checkout if enabled, without collecting unnecessary biometric/personal data.
6. Finish a simple revenue path before adding trend/ranking experiments.
7. Keep deterministic/local computation before paid AI and guard provider cost.
8. Global-by-market: keep locale separate from market, currency, price, payment provider, privacy/consent, retention/residency, legal copy and feature availability.
9. Unsupported markets/features fail closed.

## Scope freeze
- No new speculative visual modules while launch blockers remain.
- Country ranking/trend queue work is lower priority than release, privacy, mobile, conversion and payment readiness.
- No objective-attractiveness or sensitive-trait claims.
- No paid API activation, production spending, secret changes, production deploy or auto-merge.
- Do not modify target-repo GitHub workflows.

## Definition of useful progress
A launch, privacy, conversion or monetization blocker is removed and typecheck/build/tests pass.


## Integrated design rule
Do not spend a separate automatic lane on cosmetic-only redesign. When the functional P0/P1 work in a batch is safe, improve the touched UI toward a current mobile-first product standard: clear hierarchy, restrained components, deliberate spacing, accessible controls and no generic AI-looking card soup. Preserve existing tested behavior.
