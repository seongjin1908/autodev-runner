# WORKLINK repository onboarding checkpoint — 2026-10-16

## Verified state
- Public control plane: `seongjin1908/autodev-runner`, existing scheduled `.github/workflows/autodev.yml`.
- WORKLINK demo: `https://worklink-ifzhuo.v2.appdeploy.ai/`; AppDeploy ID `worklink-ifzhuo`; **frontend-only**. AppDeploy is currently the source of product source files.
- `seongjin1908/worklink` **exists as a private repository** as of 2026-10-16. The actual AppDeploy source has been uploaded in WORKLINK PR #1 (`feature/worklink-appdeploy-import-20261016`), pending review/merge.
- The GitHub connector connected to ChatGPT can read/write contents, branches and PRs, but does not expose a create-repository action.
- The automation runner's recent scheduled job failed because all configured free coding models exhausted without a validated code batch. Source was not written.

## Activation procedure (must be complete before setting auto_enabled=true)
1. [DONE] GitHub owner created private `worklink` repository. Do not repurpose the public runner or the existing `second-work` product.
2. [PR #1 pending merge and independent CI] Transfer actual sources from the AppDeploy app snapshot (at least `src/**`, `public/**`, `index.html`, `package.json`, `package-lock.json` if generated, `vite.config.ts`, `tsconfig.json`, `tests/tests.json`) into the new private repo's `main` branch. Preserve the actual code and state of the PWA demo; do not mistake demo localStorage for production persistence. Add .gitignore and never commit secrets.
3. [BLOCKED] Private repository GitHub Actions run #38885484025 completed twice with zero job steps / no runner assignment, so independent checks are not validated. Investigate Actions account/repo policies, quota/billing and runner availability before considering success. Check build and tests: `npm ci` (or `npm install` once to generate a lockfile), `npx tsc --noEmit`, `npm run build`; parse `tests/tests.json`. Add proper unit tests and end-to-end workflows.
4. Grant existing runner fine-grained `AUTODEV_REPO_TOKEN` access to this new repository only, with Contents / Pull Requests / Issues read-write and Metadata read; do not grant administration or unrelated accounts.
5. Confirm `main` is the base and runner can create the run-scoped work branch and PR. Check project prompt and per-run source validation.
6. Change `config/projects.json` `worklink` to `auto_enabled=true`, assign proportionate nonzero `auto_weight`, clear `development_status: hold` and `hold_reason`. Trigger a single manual `worklink` run before relying on scheduled rotation.
7. Verify runner returns a real commit + passing checks + linked PR. A scheduled GitHub Actions event alone, without validated code, does not prove progress.

## Production limitations
- No real users, payments, SMS, call translation, matching fees or wage custody should be enabled before legal/compliance and technical integration verification.
- The source-integration check must not alter the existing SECOND, UNKIVE, Cyber Guardian or other product branches.


## 2026-10-16 token and baseline validation
- Fine-grained `AUTODEV_REPO_TOKEN` was updated to include WORKLINK; the publicly hosted central [fixed-head baseline verification](https://github.com/seongjin1908/autodev-runner/actions/runs/38891324159) passed on the second attempt. Its logs show checkout, npm bootstrap, TypeScript, deterministic contracts, production Vite build PASS.
- Private WORKLINK Actions remains blocked by the GitHub account's spending/billing limit and starts zero steps. This is an infrastructure failure, not a source code test failure.
- Import PR #1 remains open (merged=false), so **temporary development base is the validated `feature/worklink-appdeploy-import-20261016` branch**, NOT `main`. Work PRs target that branch until the owner merges PR #1 or GitHub private CI is restored. Do not auto-merge or silently switch base.
- Initial auto-development is enabled with collision gates and strict validation, **not proof that free coding models are available or coding batches are completing**. Confirm by actual Actions commits/PRs.
- Once a safe authorized merge into `main` is possible, change `base_branch` and `source_branch` back to `main` in a separate reviewed PR after confirming the current source SHA, tests, and work PR ownership.
