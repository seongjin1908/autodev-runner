# FastBrowse OS — autonomous development contract (isolated private repository)

## Mission
Develop seongjin1908/fastbrowse-os as a commercial Windows desktop AI assistant. The user must not repeatedly download ZIPs, upload screenshots, or debug code manually. FastBrowse recognizes the current app, interprets explicit commands, executes consented local tasks, records opt-in demonstrations, replays them quickly and reports verified results. Prioritize a usable Windows alpha over a broad feature list.

## Canonical working state
- The ONLY target is the private repository `seongjin1908/fastbrowse-os`; no modifications to any other target.
- Use the existing reviewed branch `agent/windows-interruptible-waits-20261026` / Draft PR #5. Do not open duplicate PRs while this lane is under development.
- Read AGENTS.md, latest branch source/tests, Issues #1-4 and PR #5 before selecting a task. Actual Windows success and EXE packaging remain unverified.
- Source files: desktop/main.py, windows_adapter.py, planner.py, vision.py, teach.py, replay_safety.py, execute_safety.py; tests/; browser-api.

## P0/P1 work order
1. Fix a reproducible baseline failure or shipping blocker first, especially Python 3.12 support, dependencies, startup, Windows focus targeting, emergency F8 stop and protected-screen handling.
2. Ensure the local Python UI can safely pick a target app and perform one real workflow (Notepad: read→type→save→verify) with explicit approval, no real user files.
3. Improve opt-in Teach mode beyond coordinate-only recordings: versioned repeatable skills, robust target identification, validation of postconditions, stop and bounded recovery. Preserve privacy exclusions.
4. Prefer UI Automation and deterministic actions over model calls; only use local vision when needed. Measure p50/p95 task completion and work on actually measured latency bottlenecks.
5. Keep Windows build tooling and package import paths correct; add portable regression tests and an honest Windows acceptance gate.

## Self-recovery without unsafe shortcuts
- At each scheduled run, inspect the existing PR and branch, and choose the first highest-value *reproducible* issue. Do not repeat the same ineffective fix.
- When a local test fails: diagnose failure, revert the bad attempt and try one bounded different fix with new regression tests. A failure to finish one issue must not trigger unrelated rewrites or a fake PASS.
- When the optional free model is unavailable (429, 5xx, timeout, provider failure), record the failure category, stop that model attempt and allow the existing approved $0 fallback; next GitHub schedule will retry without a user request. No paid models or hidden credits.
- When GitHub Actions cannot start (billing/account permissions), source code cannot repair GitHub billing. Preserve work and resume only when GitHub runner can execute; never claim active autonomous coding without a verified workflow run/commit.
- Do not disable/relax failed tests, blanket-ignore exceptions, bypass Windows permissions, or replace real implementation with mock-only changes.
- Never write secret files, .github workflows, API credentials; never auto merge to main, deploy, sign release, publish, purchase, send emails or messages, operate customer accounts, or collect private screenshots.
- Keep code changes in focused batches with a regression test and run source validation; report exact PR/commit and why Windows live testing is still pending.

## Useful completed iteration
A real source change that removes a Windows or automation blocker, guarded tests pass, one existing PR receives the commit, and no extra billable API/CI work is introduced. No contribution is claimed for an issue-only run, repeated failure, empty diff or superficial documentation.
