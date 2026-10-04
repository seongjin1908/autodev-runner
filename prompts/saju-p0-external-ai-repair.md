# Fortune Atlas P0 #28 — paid fulfillment 30-second runtime recovery

You are an independent coding agent reviewing a live production incident. Work only on the isolated branch checked out for you.

## Confirmed incident
- AppDeploy hard-kills a backend handler at 30,000 ms.
- The paid fulfillment worker has repeatedly returned HTTP 504 at that exact limit.
- P001 Standard is already deterministic/runtime-safe on the current development branch.
- P002 Premium currently creates multiple AI sections inside one fulfillment invocation and can remain PROCESSING / ANALYZING after a hard timeout.
- P004 Signature is even heavier and must not be "fixed" by silently downgrading the paid product.
- The live emergency patch can expose a deterministic P002 web result after a stale timeout. Treat that as an emergency safety net, not the final architecture.

## Your task
Implement a durable, reviewable fix for issue #28: split paid fulfillment into persisted phases that can survive a process kill and resume without restarting completed work.

Desired state machine:
PAYMENT_VERIFIED / QUEUED
→ ANALYSIS_CORE
→ ANALYSIS_DOMAINS
→ ANALYSIS_TIMING
→ P004_SIGNATURE_EXTENSION (P004 only)
→ P004_CUSTOM_QNA (P004 only)
→ ANALYSIS_READY
→ PDF_RENDERING
→ STORING
→ COMPLETE

You may adapt names to the existing architecture, but the behavior must be equivalent.

## Hard requirements
- Never use browser redirect/return as payment proof.
- Preserve existing server-side PayApp/PayPal verification.
- Persist each expensive completed phase before starting the next one.
- One invocation must do bounded work; do not wait on the full Premium/Signature report in one handler.
- A retry must resume the first incomplete phase, not regenerate completed phases.
- Concurrent cron + browser polling must not duplicate an expensive phase; use existing DB primitives and a lease/version/CAS-style guard if possible.
- Once enough analysis exists for a valid web result, the authenticated status API should expose it even while PDF is pending.
- PDF generation/storage must be a later independent phase.
- Do not silently turn P004 Signature into a short deterministic preview.
- Keep the existing deterministic P001 path.
- Preserve the current P002 stale deterministic fallback as an emergency escape hatch unless the new staged architecture makes it provably unnecessary.
- Do not add a paid provider, paid AI, new dependency, secret, workflow, or production deployment.
- Do not modify .github files.
- Add or update executable regression coverage for timeout/resume/idempotency where the repository's test structure allows.
- Keep the change small enough to review. Prefer backend/index.ts, backend/analysis.ts and existing test/validation scripts.

## Regression scenarios
1. P002 core phase finishes, process dies, next run starts at domains without rerunning core.
2. P002 web result can become visible before PDF completion.
3. P004 resumes across its extra phases without restarting base Premium phases.
4. Duplicate browser polls do not create duplicate AI phase calls.
5. Cron and browser recovery racing converge to one phase result.
6. PAYMENT_VERIFIED never regresses to CREATED.
7. COMPLETED is idempotent.
8. A 30-second process kill does not strand an order forever at ANALYZING.

Do not claim production success. Produce code + tests only.