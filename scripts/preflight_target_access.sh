#!/usr/bin/env bash
# Explicit fail-closed credential and repository preflight for a private AutoDev target.
# This script NEVER prints credentials or private repository content.
set -euo pipefail

if [[ "${ALIAS:-}" != "cyber-guardian" ]]; then
  echo "Preflight not required for alias: ${ALIAS:-unset}"
  exit 0
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "::error title=CYBER GUARDIAN token missing::Add AUTODEV_REPO_TOKEN to autodev-runner Actions secrets with permission to cyber-guardian-ai. No coding was started."
  exit 11
fi
if [[ "${REPOSITORY:-}" != "seongjin1908/cyber-guardian-ai" ]]; then
  echo "::error title=CYBER GUARDIAN target mismatch::Repository selection did not match the allowlisted private target. No coding was started."
  exit 12
fi
if [[ "${CHECKOUT_BRANCH:-}" != "main" ]]; then
  echo "::error title=CYBER GUARDIAN ref mismatch::Only the authorized main source branch can be checked out."
  exit 13
fi

# GitHub may return a 404 for repositories not included in fine-grained PAT scope.
if ! gh api "repos/$REPOSITORY/contents/guard-policy.js?ref=$CHECKOUT_BRANCH" --jq .sha >/dev/null 2>&1; then
  echo "::error title=CYBER GUARDIAN private checkout blocked::AUTODEV_REPO_TOKEN cannot read cyber-guardian-ai. Grant this token selected-repository access, Contents read/write, Pull requests write and Issues write. Never paste token values in logs or chat."
  exit 14
fi

# Read/write repository permission is needed to push a guarded code branch.
push_allowed="$(gh api "repos/$REPOSITORY" --jq '.permissions.push // false' 2>/dev/null || echo unavailable)"
if [[ "$push_allowed" != "true" ]]; then
  echo "::error title=CYBER GUARDIAN push permission blocked::Target is readable, but this credential does not confirm Contents write permission. No coding was started."
  exit 15
fi

echo "CYBER GUARDIAN access preflight passed: source readable and push permission verified; credentials hidden."
