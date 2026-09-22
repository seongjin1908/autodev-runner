# AutoDev Runner

Central zero-budget development runner for private projects.

## Security model
- This repository contains runner code only. Private project source is never committed here.
- It does not run on pull requests or external issue events.
- Cross-repository access uses one fine-grained token stored as the repository secret `AUTODEV_REPO_TOKEN`.
- The coding worker is blocked from editing target `.github/` workflows, secrets, or environment files.
- Paid AI fallback, production deployment, live payment activation, and auto-merge are disabled.
- Each scheduled run selects one target project, validates it, attempts one coherent batch, validates again, and updates the existing work branch/PR.

## Required setup
1. Make this repository **Public** so standard GitHub-hosted Actions can use the public-repository allowance.
2. Create a fine-grained personal access token limited to the selected private development repositories.
3. Give the token only these repository permissions:
   - Contents: Read and write
   - Pull requests: Read and write
   - Issues: Read and write
   - Metadata: Read
4. Add the token as this repository secret:
   - `AUTODEV_REPO_TOKEN`
5. Keep all product repositories private.

## Targets
The runner rotates through the currently active development branches for Fortune, Daangn Saju, PriceCam, FACE LAB, and Restore AI. Target source code stays in those private repositories.

## Operating policy
- Failure recovery before new features.
- Batch development instead of one-line hourly commits.
- One target per scheduled run to reduce branch collisions.
- Skip a target when its work branch changed very recently.
- Free OpenCode model fallback only.
- No paid fallback.
- No automatic production deploy.
- No automatic merge.
- Verified commit/test/PR evidence only.
