# Coston Partner Hub — isolated GitHub AutoDev

**Single-owner development lane:** seongjin1908/ddd-revenue-os, source branch `feat/coston-partner-hub-20261027`, existing parent Draft PR #90. This lane creates **review PRs targeting that feature branch**, not `main`, and never auto-merges.

Current goal: build reliable, reusable **single-tier** affiliate tracking for SajuMyeongkwae, Fortune One Page, Destiny Note US and Restore AI without disrupting their existing payment or AI fulfillment.

## Each run

1. Read the latest actual code under `partner-hub/`, its CI tests, README, docs, recent commits, and outstanding PR review. Do not assume previous features are verified by green CI when GitHub runners have failed before job startup.
2. Choose ONE demonstrable high-impact unfinished P0/P1 defect or security gate, with source evidence and a regression test. **Fix failed baseline first** rather than adding new features.
3. Write actual code only inside `partner-hub/src/`, `partner-hub/integrations/`, `partner-hub/tests/`, `partner-hub/public/`, `partner-hub/docs/`. Never modify other directories, workflow files, billing configuration, manifests, provider credentials or existing customer data.
4. Use `cd partner-hub && npm run check` as authoritative source-level validation. If baseline already fails, fix a reproducible baseline error or abstain. Do not bypass failing tests, weaken a security assertion or relabel an unverified result PASS.
5. Keep changes reviewable (maximum eight changed files). If no safe code change is justified, make no commit and leave a useful blocker report; do not create cosmetics-only churn.

## Product and safety requirements

- Direct attributed sale commission proposed at 30%, **not** payments to recruiting uplines. Never implement a second-level referral bonus.
- Only merchant-server-confirmed, live, captured, catalog-matching PayApp/PayPal/Toss transactions are valid. PayPal Sandbox, PayApp pending/refund-review and Restore demo mode are not live sales.
- Track unverified sales for reconciliation but **do not accrue payable cash commission** until truly independent buyer identity evidence exists. A browser email, phone number, cookie or self-attested hash is not independent identity proof.
- Preserve immutable merchant event ID, signed HMAC, outbox replay idempotence, anti-self-dealing, refunds/chargebacks, bank profile changes after payout reservation, currency separation and delayed buyer verification.
- Never expose bank details, session token, merchant secret, or raw customer PII. No open signup before terms/privacy approval.
- Existing partner hub links are OFF by default and app-specific gates stay OFF until real staging checkout integration is independently verified.
- **No actual bank transfer, withdrawal, payout-provider call, tax reporting submission or customer payment.** Only code-level bookkeeping and staging tests.
- No production deploy, app connector mutation, secret changes, `main` merge or Draft PR merge. Other projects have separate active writers: do not edit Saju, Restore AI core or AppDeploy app source.
- Use free AI models exclusively. If unavailable or blocked by GitHub Actions billing, record it and stop; never switch to paid models or retry indefinitely.

Success means a real reviewed source diff, relevant passing local/source CI tests when runner is available, and a draft review PR. Never claim that GitHub workflow setup itself is evidence that autonomous coding executed.
