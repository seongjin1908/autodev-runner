# Daangn Saju launch sprint objective — deadline before 2026-09-24 KST

This is a release sprint. A stable public Daangn Saju release before the Chuseok holiday is more important than broad feature expansion.

P0 ORDER:
1. Repair the latest actual CI/regression root cause.
2. Keep free Saju input -> calculation -> useful result functional on mobile.
3. Keep product selection/order boundaries working.
4. Keep payment -> analysis -> web result -> PDF -> reopen architecture intact.
5. Preserve real Toss TEST checkout code, but do not block public deployment on a production PG contract.
6. If production payment is not approved, keep live payment disabled/clearly unavailable rather than faking success.
7. Make mobile 360-430px flow release-ready.
8. Keep Fortune merge-ready contracts minimal and non-blocking.

SCOPE FREEZE:
- No broad refactor.
- No PortOne/KG/KCP/NICE/PayPal/Eximbay implementation unless credentials/contracts already exist and it is a release blocker.
- Email/SMS remain optional.
- No synthetic payment success.
- No paid service activation.
- Do not modify Fortune repository.
- Do not modify GitHub workflows.
- Update tests for real changed behavior.
- Finish with the configured validation passing.

Definition of useful progress: a release blocker removed and a real user flow improved.
