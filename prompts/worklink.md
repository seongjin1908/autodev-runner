# WORKLINK — active private-source autonomous development lane

This target is **registered and auto_enabled** in `config/projects.json`. Private repository `seongjin1908/worklink` already exists. React/Vite source was imported and merged in WORKLINK PR #1, and the integrated P0 backend/API client merged into `main` via WORKLINK PR #5 after independent CI. The approved development source and PR base is now `main`. Never restart import, call an existing demo a live marketplace, or modify unrelated repositories. The central runner is public: no proprietary product files, credentials, personal data, or real job postings may be copied here. Success requires an actual validated source diff and product PR; a completed scheduled job or a model attempt alone is not progress.

## Product and source of truth
- Product: WORKLINK, Korean domestic multilingual day-work recruitment information / shift operations SaaS.
- Existing interactive frontend-only **demo**: https://worklink-ifzhuo.v2.appdeploy.ai/ (AppDeploy ID `worklink-ifzhuo`).
- Demo functions: Korean, Mandarin Chinese, Uzbek and Vietnamese interfaces; mock jobs; pickup choices; local-only applications/messages/community; employer lead tracking; fee estimator; three-strike simulation.
- These browser-only previews are NOT phone authenticated, server-persisted multiuser messaging, actual hiring, phone calls, wage payments or real-money processing. Do not claim otherwise.
- Preserve OTHER products (SECOND, UNKIVE, CYBER GUARDIAN) and their repositories / branches / deployments without modifications.

## Execution sequence (quality gates, not fake percentages)
1. **Inspect existing source and CI first**: WORKLINK import is already present in PR #1; do not re-import. Inspect source branch and WORKLINK PRs #1/#2/#3/#4, avoid duplicate implementation, preserve proven phone/job checks, SQLite API, two-account isolation manual eligibility gate, and memory-only same-origin API client; do not regenerate server/core.mjs or src/lib/pilot-api.mjs from scratch. Reproduce `npm run typecheck && npm test && npm run build` before changing code. Use the existing public central runner's private-source checkout for independent CI when private-repo Actions are blocked by GitHub billing/runner restrictions. Do not claim `npm ci` until a committed package-lock exists; use `npm install --no-audit --no-fund` for bootstrap.
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
- Every batch: smallest coherent source change, strict `git diff --check`, `npm ci` only when a tracked lockfile exists (otherwise `npm install --no-audit --no-fund`), TypeScript, unit tests, build, synthetic E2E where available; PR notes with exact evidence and user-facing effect.
- Respect runner collision guard, limits, free model fallback. If all model providers fail, report `provider_unavailable` — not progress.
- Do not auto-merge, auto-deploy to production, provision real paid services, migrate live personal data or claim commercial readiness.
- UI polish alone is not completion. Completion means functioning independently verified external accounts and tested legal operating posture.

## Verified open-source integration order (avoid dependency churn)
- Existing React, Vite, Tailwind CSS, and Lucide React form the UI baseline. Keep layout intact unless accessibility/performance changes justify it.
- Consider MIT shadcn/ui and Radix Primitives only when an actual accessible dialog/select/popover is needed; do not replace the whole UI or omit license notices.
- Consider MIT libphonenumber-js for +82/+86/+84/+998 international number formats. Valid syntax NEVER proves phone ownership.
- Consider MIT i18next and react-i18next for four existing languages; no external translation API automatically enabled.
- Consider MIT TanStack Query only after real frontend-backend integration for cache/polling; it does not confer authentication.
- Node built-in SQLite remains the zero-dependency localhost pilot, not a publicly hardened database without operational review and backup.
- Open source alone does not provide free SMS or dependable free live voice translation. Report realistic provider costs before activation.
- Next real gap: deployment-independent, same-origin frontend API client with memory-only bearer credentials, role-bound job/chat screens, and browser integration tests.
