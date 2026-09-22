# Fortune launch sprint objective — deadline before 2026-09-24 KST

This is a release sprint. Shipping a stable public Fortune release before the Chuseok holiday is more important than broad feature expansion.

P0 ORDER:
1. Repair the current real CI/build failure and keep it repaired.
2. Preserve accurate Fortune/Saju core calculations and existing regression coverage.
3. Ensure the main mobile user flow works at 360-430px.
4. Ensure free reading -> result -> repeat/reopen flow is functional.
5. Keep premium/payment boundaries clean, but do not block the public release on a new paid PG contract.
6. Keep a deployable functional preview/release candidate.

SCOPE FREEZE:
- No broad refactor.
- No CI polishing after CI is healthy unless it blocks release.
- No new speculative modules.
- No paid AI/API activation.
- No live payment activation without approved production credentials.
- No production deployment from this coding worker.
- Do not modify GitHub workflows.
- Keep Daangn Saju as a separate repository.
- Update tests only for real changed behavior.
- Finish with the configured validation passing.

Definition of useful progress: a user-facing release blocker removed, not a cosmetic commit.
