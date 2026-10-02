# Development Factory Control Plane

This repository is the canonical control plane for autonomous development.

## Goal
Ship product repositories quickly without letting multiple agents, chats, schedules, or deployment systems edit the same work lane at the same time.

## Single source of truth
- Target registry: `config/projects.json`
- Automation workflow: `.github/workflows/autodev.yml`
- Launch acceleration workflow: `.github/workflows/launch-sprint.yml`
- Product-specific instructions: `prompts/*.md`
- Verified progress: commits, CI results, PR state, and deployment evidence only.

## Operating rules
1. One product lane has one canonical work branch.
2. Runner workflows are serialized through the same concurrency group.
3. A recent-change guard prevents a new batch from immediately stepping on a fresh branch update.
4. Never write directly to a production branch from the coding worker.
5. Never auto-merge or auto-enable production payments.
6. Baseline failures are repaired before lower-priority feature work.
7. A batch is progress only when durable source changes exist and the target validation passes.
8. AppDeploy or another production deployment is downstream of repository validation, not the development loop.
9. New AI providers are optional fallbacks. Do not make the control plane depend on a paid provider.
10. New projects enter rotation only after repository, work branch, base branch, validation, prompt, and collision policy are defined.

## Chat operating model
The conversation named "깃허브 자동개발 목록 확인" can be treated as the human control room.

The user may issue plain-language commands such as:
- "Fortune 우선"
- "Fault 계속"
- "Restore 잠깐 멈춰"
- "전체 상태 확인"
- "실패한 것만 고쳐"

The assistant should translate those commands into the existing project registry and GitHub state rather than creating duplicate branches, duplicate runners, or parallel control systems.

## Human-touch policy
Default to no user action when GitHub-side changes can be completed safely through the existing connection.

Ask the user only when an external service requires an account-owned action that cannot be completed through GitHub, for example:
- creating or approving a third-party API credential,
- accepting provider terms,
- authorizing a billing/payment account,
- performing a real-money production payment test.

## Current active lanes
See `config/projects.json`. Product repositories keep their own source and PR history; this runner stores only orchestration logic.
