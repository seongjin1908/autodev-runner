# CYBER GUARDIAN AI — zero-budget guarded coding lane
# Highest-priority security product is GUARD AI + BLUE AI, not an offensive tool.

## Repository and existing code
- Repository: seongjin1908/cyber-guardian-ai (private); source branch main.
- Read AGENTS.md, AUTODEV_QUEUE.md, SECURITY.md and relevant existing code before any modifications.
- Existing working assets: gateway/runtime.js, gateway/server.js, guard-policy.js, guardian.js, index.html, tests/*.test.js and GATEWAY_RUNBOOK.md.
- Do not recreate the app. Never touch unrelated repositories. If design/evidence docs in an unmerged PR exist, do not assume they are in main.
- The repository has existing unmerged PRs #7, #10 and #11 as of 2026-10-13. Do not duplicate their scope or overwrite them. CI on private repo has recently failed without executed job steps. The public runner's own validation is distinct from that CI; never claim private CI success without evidence.

## FIRST TASK EACH RUN — actually improve safe working code
1. Inspect current main HEAD, existing queue, and source; identify ONE small security defect or distinct unimplemented P0 acceptance criterion.
2. Prefer non-duplicative GUARD improvements: safe local schema validation, evidence provenance, rejection of untrusted model-policy overrides, deterministic tenant isolation, denial handling, test coverage for malformed event inputs or BLUE evidence consistency. If a corresponding open PR already exists, choose a different issue.
3. Correct the code and write explicit normal AND adversarial regression tests. Actual tests must execute and pass.
4. Where appropriate, link blocked GUARD calls to synthetic BLUE findings, but never invent breaches, accuracy percentages or real customer events.
5. Report measurable results and unimplemented controls in the PR. Do not add speculative documents in place of code.

## Immutable safety boundaries
- RED AI is for OWNER-CONTROLLED isolated synthetic labs or individually documented written-scope authorization ONLY; focus this lane on DEFENSIVE GUARD + BLUE.
- No exploit payloads against real targets, no vulnerability scanning of external companies, no unauthorized access, theft, persistence, exfiltration, ransomware, DDoS, bank transfer or spacecraft/satellite uplink or control.
- No raw customer logs, private identities, keys, credentials or sensitive data sent to models or issue bodies. All examples are synthetic.
- No actual third-party tools or dynamic shell commands executing based on an LLM response. All allowed adapters must be exact allowlisted and READ ONLY.
- Do NOT change GitHub workflow, policies to permit action, auth secrets, network settings, production deployments, cloud, billing or payments. Never auto-merge.
- Do not connect real security systems. Enterprise usage requires independent qualified security review, customer authorization, trusted identity and durable audit.
- API cost must remain zero; do not activate paid fallback or a chargeable service. Prefer Node 22 built-ins, deterministic policies, no extra dependencies.
- Preserve security invariants: fail closed for unknown tenant/agent/tool/scope/expired token/missing audit capacity; no untrusted content in security authority; per-tenant quotas and audit evidence.

## Change and verification rules
- Work on the runner-created run-scoped branch only. Limit to 8 small source/test files; never modify .github, secrets, tokens, .env.
- Run the full prescribed validation: Node syntax checks and `node --test tests/*.test.js`.
- A passing Node test suite does NOT imply independent professional audit, enterprise readiness or world-leading performance.
- If the baseline is failing or a test is flaky, repair that first; do not bypass tests, loosen authorization policy or mask failures.
- Avoid unbounded loops, dependency additions and flaky network tests; all tests local/offline.
- Output a reviewable PR only after validation; do not auto-merge, auto-deploy or claim automatic investment outcomes.

## Product quality focus
Target a secure, low-cost AI agent security gateway: trusted tool registration, authenticated request processing, deterministic ALLOW/DENY/REVIEW_REQUIRED, privacy safeguards, client and tenant isolation, evidence-linked BLUE alerts, clear reports, and objective benign/suspicious benchmarks. Existing competition already covers runtime AI security; superiority must be independently measured.