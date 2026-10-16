# WORKLINK repository onboarding checkpoint — 2026-10-16

## Verified state
- Public control plane: `seongjin1908/autodev-runner`, existing scheduled `.github/workflows/autodev.yml`.
- WORKLINK demo: `https://worklink-ifzhuo.v2.appdeploy.ai/`; AppDeploy ID `worklink-ifzhuo`; **frontend-only**. AppDeploy is currently the source of product source files.
- `seongjin1908/worklink` is **not present** in the authenticated GitHub repository listing as of 2026-10-16.
- The GitHub connector connected to ChatGPT can read/write contents, branches and PRs, but does not expose a create-repository action.
- The automation runner's recent scheduled job failed because all configured free coding models exhausted without a validated code batch. Source was not written.

## Activation procedure (must be complete before setting auto_enabled=true)
1. GitHub owner creates a new **private** repository called `worklink`. Do not repurpose the public runner or the existing `second-work` product.
2. Transfer actual sources from the AppDeploy app snapshot (at least `src/**`, `public/**`, `index.html`, `package.json`, `package-lock.json` if generated, `vite.config.ts`, `tsconfig.json`, `tests/tests.json`) into the new private repo's `main` branch. Preserve the actual code and state of the PWA demo; do not mistake demo localStorage for production persistence. Add .gitignore and never commit secrets.
3. Check build and tests: `npm ci` (or `npm install` once to generate a lockfile), `npx tsc --noEmit`, `npm run build`; parse `tests/tests.json`. Add proper unit tests and end-to-end workflows.
4. Grant existing runner fine-grained `AUTODEV_REPO_TOKEN` access to this new repository only, with Contents / Pull Requests / Issues read-write and Metadata read; do not grant administration or unrelated accounts.
5. Confirm `main` is the base and runner can create the run-scoped work branch and PR. Check project prompt and per-run source validation.
6. Change `config/projects.json` `worklink` to `auto_enabled=true`, assign proportionate nonzero `auto_weight`, clear `development_status: hold` and `hold_reason`. Trigger a single manual `worklink` run before relying on scheduled rotation.
7. Verify runner returns a real commit + passing checks + linked PR. A scheduled GitHub Actions event alone, without validated code, does not prove progress.

## Production limitations
- No real users, payments, SMS, call translation, matching fees or wage custody should be enabled before legal/compliance and technical integration verification.
- The source-integration check must not alter the existing SECOND, UNKIVE, Cyber Guardian or other product branches.
