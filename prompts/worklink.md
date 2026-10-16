# WORKLINK — private-source autonomous development lane

This target is **ON HOLD** until the user-owned private repository `seongjin1908/worklink` is created and the actual AppDeploy source is imported. The central runner is public; do not place product source, credentials, personally identifying information, real job postings or customer data in this repository.

## Product and source of truth
- Product: WORKLINK, Korean domestic multilingual day-work recruitment information / shift operations SaaS.
- Existing interactive frontend-only **demo**: https://worklink-ifzhuo.v2.appdeploy.ai/ (AppDeploy ID `worklink-ifzhuo`).
- Demo functions: Korean, Mandarin Chinese, Uzbek and Vietnamese interfaces; mock jobs; pickup choices; local-only applications/messages/community; employer lead tracking; fee estimator; three-strike simulation.
- These browser-only previews are NOT phone authenticated, server-persisted multiuser messaging, actual hiring, phone calls, wage payments or real-money processing. Do not claim otherwise.
- Preserve OTHER products (SECOND, UNKIVE, CYBER GUARDIAN) and their repositories / branches / deployments without modifications.

## Execution sequence (quality gates, not fake percentages)
1. **Import and baseline**: copy actual AppDeploy source, not compiled public website output, into private product repository. Ensure `npm ci`, TypeScript and production build pass; add unit/E2E tests; establish separate `main` release and run-scoped work branch, PR and CI.
2. **P0 / correct identity**: anonymous browsing for both job listings and community, phone-first sign-in using explicit phone verification provider with rate limiting, E.164 and real verification; display available international dial codes (+82, +86, +84, +998) without pretending that every carrier works. Never simulate successful verification in production. Store credentials via secrets, not GitHub or front-end code.
3. **P0 / backend**: durable database, organization-linked employer roles, worker roles, business verification, row-level authorization, audited job create/update/close, explicit applications, private bidirectional employer/worker messaging, notifications, real consent records and safe pickup points. Test two distinct accounts and prevent cross-tenant data leaks.
4. **P0 / lawful employment**: everyone may browse/register regardless of nationality; actual hiring and work confirmation blocked until residence/work authorization is checked for the particular job and employer. Distinguish E-9, F-4 etc. Apply current Korean employment and immigration rules with legal review and minimal sensitive data collection. Do not create a blanket citizenship-based ban or automatically approve work eligibility.
5. **P0 / trust and disputes**: no-show three-strike policy only after verified, unjustified failure to attend; notification, reciprocal employer conduct reports, time-limited actions, due process, appeal and false-report safeguards. No pay deductions as penalty.
6. **P1 / pickup & language**: consent-based pickup points shared at the correct time, attendance acknowledgments, location minimization, multi-language job conditions and original-language confirmation. Begin with in-app text translation; implement real voice calling/transcription only with valid vendor support, permission/consent, measured latency and per-minute cost ceilings. No always-on recording.
7. **P1 / community**: read-only without sign-in; posting/commenting behind verified auth; anti-spam, report queue, abuse moderation, privacy checks, no unverified job advertisements in free-text posts.
8. **P1 / external job sourcing**: human-led, permitted outreach to employers found on other job platforms; capture original public source links for internal CRM; never mass scrape, republish third-party ads or contact workers without consent. Only authorized employer may create an independent WORKLINK job listing.
9. **P2 / monetization**: transparent employer subscription and associated cancellation/refund invoices via properly approved PG, no phantom payments; enforce separate employer fees and worker wages. Worker wages remain employer-to-worker direct until regulated PSP/partner legal feasibility and written authorization is verified. No custody, lending, wage withholding, unauthorized fee/escrow or intermediary commissions. Review whether the operating model requires paid employment-agency registration (유료직업소개사업) or occupational-information registration (직업정보제공사업) before collecting fees. Do not activate real payments autonomously.
10. **Release**: accessibility, privacy policy, terms, abuse reporting, mobile/browser compatibility, account data erasure/export, authenticated transactions, reproducible CI, cost/abuse guardrails. Complete synthetic E2E flows (two users + employer; lawful work gate; messages; shift; dispute; post; billing sandbox) and stage deployment; production go-live requires explicit human approval.

## Run contract
- Prefer trusted OSS with checked license/maintenance to blank-slate implementation. Keep copyright notices and dependency licenses.
- Recover known CI regressions before adding features. Avoid repeat documentation-only PRs.
- Every batch: smallest coherent source change, strict `git diff --check`, `npm ci`, TypeScript, unit tests, build, synthetic E2E where available; PR notes with exact evidence and user-facing effect.
- Respect runner collision guard, limits, free model fallback. If all model providers fail, report `provider_unavailable` — not progress.
- Do not auto-merge, auto-deploy to production, provision real paid services, migrate live personal data or claim commercial readiness.
- UI polish alone is not completion. Completion means functioning independently verified external accounts and tested legal operating posture.
