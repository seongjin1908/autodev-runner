# Fortune Atlas KR Core — autonomous product development lane

Goal: turn Fortune Atlas from a one-shot saju report into a daily-use Fortune OS while preserving the current deterministic engine, payment safety and content quality.

## Source of truth
- Repository: seongjin1908/daangn-saju-autodev
- Source/base: autodev-v12
- Current completed baseline includes Free Insight v21:
  - explicit gender selection
  - timeout/retry UX
  - cross-evidence personalization
  - same-day-stem discrimination
  - ~90-day deterministic flow
  - zero-cost guided follow-up
  - anonymous result feedback
- Do not redo completed work. Inspect the code first and advance the first genuinely incomplete milestone below.

## Product priority — advance ONE coherent milestone per run

### P0 — v22 Daily / Weekly / Monthly return loop
Build a zero-AI-cost return surface from existing deterministic timing engines.
Requirements:
- Today, This Week, This Month surfaces
- use existing chart/timing/monthly data; do not invent event certainty
- reusable result identity or safe saved-reading recovery without storing unnecessary birth data longer than policy allows
- clear "what to watch / what to do / what to avoid" consumer copy
- attribution events for revisit and period-view
- mobile-first UI
- deterministic tests and no jargon leakage
- avoid claiming exact future events

### P0 — v22.1 Saved reading / return entry
After daily surfaces exist:
- allow the user to reopen a still-valid saved reading without recalculating
- clear expiry/privacy behavior
- no account requirement in the first version unless technically necessary
- never expose access tokens in URL query
- prepare an account abstraction, but do not add external auth unless required

### P1 — v23 Contextual Chat foundation
Do NOT silently activate paid AI usage.
Build the safe architecture first:
- question input UX and domain classification
- chart snapshot + current timing + selected interest as grounded context
- abuse/rate-limit/cost guard
- deterministic fallback for supported guided questions
- provider interface behind an explicit runtime feature flag
- no production free-text AI calls unless explicitly enabled later
- answers must be grounded in the user's same chart snapshot and must not guarantee future events

### P1 — v24 Relationship graph / compatibility
After chat foundation:
- save partner/family/friend/business-partner profiles with explicit consent
- deterministic compatibility comparison using both charts
- relationship timing as relative indicators, not guaranteed events
- privacy boundaries and deletion path
- prepare for multiple named profiles
- do not expose sensitive data across profiles

### P1 — Retention analytics
Across every milestone:
- events must connect landing -> free result -> 90-day/daily view -> follow-up/chat -> product choice -> checkout -> purchase
- no PII in analytics event payloads
- creative/campaign attribution must remain intact for the ad system

### P2 — Native app readiness
Only after web retention foundations are stable:
- isolate native-safe API contracts
- result history / push-ready notification model / deep-link-safe routing
- prepare Capacitor/native wrapper boundaries without submitting to app stores
- do not add live Apple/Google billing without explicit approval

## Quality bar
- Preserve all existing Fortune Engine v18 checks.
- Preserve free-insight repetition/jargon/contradiction/same-stem gates.
- Preserve paid-result UX/payment/recovery behavior.
- Do not weaken thresholds to pass.
- Prefer deterministic calculations over generic AI prose.
- Consumer language first; technical evidence may be expandable.
- No fake accuracy percentages, fake testimonials or guaranteed future claims.
- Never change prices, live payment, secrets, provider configuration or production deploy.
- Never auto-merge.

## Batch discipline
- Inspect current code and existing PRs before editing.
- If the next milestone is already materially complete, move to the next incomplete milestone.
- One coherent user-value batch per run.
- Add or extend executable tests for the behavior you change.
- Keep KR core work isolated from Global i18n unless a shared abstraction is necessary and safe.
