#!/usr/bin/env bash
# Run only after the primary coding worker has returned without a validated batch.
# This is an ephemeral GitHub Actions checkout, not a developer's working copy.
set -euo pipefail
: "${START_SHA:?START_SHA required}"
if [[ ! "${START_SHA}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::Invalid protected worker starting commit."
  exit 2
fi
original="$(git rev-parse HEAD)"
if [[ "$original" != "$START_SHA" ]]; then
  echo "::error::Source HEAD changed; Gemini handoff cannot clean another commit."
  exit 2
fi
# Never delete credential, workspace policy, or extension configuration as
# ordinary throwaway provider output. Refuse handoff instead.
if [[ -e .env || -e .gemini || -e .mcp.json || -e .opencode || -e .env.local ]]; then
  echo "::warning::Potential unreviewed runtime configuration detected; no fallback model call."
  exit 3
fi
# Keep the already installed baseline dependencies while excluding them only
# in this ephemeral checkout's local Git metadata. Tracked paths remain visible
# to git diff and all existing commit/source-code gates.
exclude="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude")"
{
  echo "/node_modules/"
  echo "/dist/"
  echo "/coverage/"
  echo "/.astro/"
  echo "/.next/"
  echo "**/__pycache__/"
} >> "$exclude"
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "Discarding unvalidated OpenCode edits from isolated run before independent fallback."
  git reset --hard "$START_SHA" >/dev/null
  git clean -fd -e node_modules/ >/dev/null
fi
if [[ "$(git rev-parse HEAD)" != "$START_SHA" || -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "::error::Gemini handoff remains dirty after rollback; no model request."
  exit 2
fi
echo "Gemini handoff checkout is clean at the protected starting commit."
