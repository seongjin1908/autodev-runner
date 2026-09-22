# Restore AI recovery batch objective

Priority:
1. Repair the current validation failure before new features.
2. Then complete 2-4 tightly compatible P0/P1 items as one batch.
3. Never enable live payments.
4. Never enable paid AI spending.
5. Never set DEMO_MODE=false.
6. Never set non-zero DAILY_AI_BUDGET_KRW.
7. Preserve payment, webhook, auth, idempotency, media validation, recovery, and cost guards.
8. Do not deploy production.
9. Do not modify GitHub workflows.
10. Update AUTODEV_STATUS.md only with verified facts.
11. Finish with npm run check passing.
