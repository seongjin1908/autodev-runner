# REA Cloud Lab — validated 2026-10-15

## Verified smoke test
- GitHub Actions: https://github.com/seongjin1908/autodev-runner/actions/runs/38684718050
- Workflow: `.github/workflows/rea-cloud-lab.yml` (default branch `main`)
- Result: **success**, run ID `38684718050`, synthetic owned fixture only
- Steps: Node 24.11.0, procps available, pinned `rea-agents@6.5.0`, static JavaScript analysis, JSON parse, evidence archive upload — all passed.
- Artifact: `rea-owned-demo-analysis` (run UI; 1-day retention), generated with fake project fixture only.

## How to run without installing anything on your PC
Open GitHub > `seongjin1908/autodev-runner` > Actions > **REA Cloud Lab - owned fixture only** > Run workflow > `main` > Run workflow.
This starts a **fresh** temporary Linux runner for the same owned test fixture. It does not install or register the MCP in your local Codex, desktop, or persistent remote Codex session. It does not analyze other applications.

## Architecture and safeguards
- GitHub Actions is the **ephemeral REA CLI execution host**.
- Existing product repositories, payment deployments, AutoDev selection, secrets and schedules are untouched.
- This workflow is triggered only by manual dispatch or changes to itself/the synthetic fixture. It does not run on a regular schedule.
- It uses read-only GitHub permissions, no persisted checkout token, no cross-repo PAT, no secrets, no customer data, no untrusted binary, no arbitrary user-supplied URLs, no auto-merge and no production deployment.
- No autonomous agent gets to execute third-party code or run REA against competitor binaries.
- Versions are pinned to REA 6.5.0 for this tested smoke, using npm with lifecycle scripts disabled. Review upstream supply-chain changes before upgrading.

## Next stage (NOT yet complete)
A scoped bridge must transfer evidence files into the existing development process for manual review and a product-specific PR. This is intentionally not automatic to avoid granting high-risk access across repositories. REA does not become an always-on Codex MCP server just because its CLI runs in a GitHub-hosted job.
Prioritize UNKIVE public-user-experience comparisons, followed by controlled analysis of authorized owned demos. Original implementation and rights review are required before any product feature is merged.
