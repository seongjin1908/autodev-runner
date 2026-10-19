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

# After repeated *consecutive* timeouts, keep trying other verified free models
# but reduce their individual wait instead of spending ~10 minutes per batch.
# This is per-job only; the preferred model gets its full chance again next run.
model_timeout_after_stalls() {
  local requested="${1:?requested timeout required}"
  local consecutive="${2:?timeout count required}"
  local stall_threshold="${3:-2}"
  local reduced_cap="${4:-25}"
  local n
  for n in "$requested" "$stall_threshold" "$reduced_cap"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( 10#$n < 1 )); then
      echo 'model_timeout_after_stalls requires positive integer timeout/caps' >&2
      return 2
    fi
  done
  if ! [[ "$consecutive" =~ ^[0-9]+$ ]]; then
    echo 'model_timeout_after_stalls requires a nonnegative timeout count' >&2
    return 2
  fi
  if (( 10#$consecutive >= 10#$stall_threshold && 10#$requested > 10#$reduced_cap )); then
    printf '%s\n' "$(( 10#$reduced_cap ))"
  else
    printf '%s\n' "$(( 10#$requested ))"
  fi
}
