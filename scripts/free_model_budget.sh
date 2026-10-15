#!/usr/bin/env bash
# Pure scheduling helper. Limits unresponsive free provider stalls without
# changing GitHub Actions schedule, model list, or billing policies.
model_attempt_timeout() {
  local configured="${1:?configured timeout required}"
  local attempt="${2:?attempt number required}"
  local primary_cap="${3-180}"
  local fallback_cap="${4-90}"
  local n
  for n in "$configured" "$attempt" "$primary_cap" "$fallback_cap"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( 10#$n < 1 )); then
      echo 'model_attempt_timeout requires positive integer arguments' >&2
      return 2
    fi
  done
  local cap="$fallback_cap"
  if (( 10#$attempt == 1 )); then cap="$primary_cap"; fi
  if (( 10#$configured < 10#$cap )); then cap="$configured"; fi
  printf '%s\n' "$cap"
}
