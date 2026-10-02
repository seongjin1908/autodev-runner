# Restore AI cash-first release objective

Restore AI is the third priority. Convert the already substantial safety/payment foundation into a launchable paid restoration flow before adding new restoration modes.

## P0 order
1. Repair any validation/build/security failure first.
2. Verify intake -> media validation -> order -> payment state -> provider job -> result delivery -> retry/recovery -> refund/reconciliation.
3. Keep private media lifecycle explicit: access control, temporary storage, deletion/retention, signed access where applicable, and no cross-customer leakage.
4. Preserve webhook authenticity, idempotency, duplicate-event safety, cost ceilings and ambiguous-payment recovery.
5. Add provider adapters/sandbox paths and deterministic tests needed for one complete non-destructive E2E.
6. Verify mobile upload/progress/result/download/error states.
7. Establish measurable unit-cost boundaries before enabling live provider spending.
8. Global-by-market: separate locale, market, currency, price, provider, tax/legal/refund copy, consent/privacy, retention/residency and feature availability.
9. Unsupported providers/markets fail closed.

## Safety
- Never enable live payments or paid AI/provider spending from AutoDev.
- Never set DEMO_MODE=false or a non-zero daily AI budget in autonomous work.
- Never expose/invent secrets, deploy production or auto-merge.
- Do not modify target-repo GitHub workflows.
- Update status documents only with verified facts.

## Definition of useful progress
A production-readiness blocker is removed, the guarded E2E path is stronger, and npm run check passes.
