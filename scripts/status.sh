#!/usr/bin/env bash
# status.sh — progress emitter for RepoRecon protocol steps.
#
# Contract:
#   status.sh start <step>           -> "[ts] [reporecon] start <step>" to stderr; records epoch-ms.
#   status.sh tick  <step> <c>/<t>   -> "[ts] [reporecon] <step> <c>/<t>" to stderr.
#   status.sh done  <step>           -> "[ts] [reporecon] done <step> (elapsed Xms)" to stderr.
#   status.sh error <step> <msg...>  -> "[ts] [reporecon] ERROR <step>: <msg>" to stderr.
#
# All output goes to stderr only. stdout stays clean so JSON-emitting peer
# scripts can be piped without contamination. State for elapsed-ms timing
# lives at ~/.cache/reporecon/.status.start.<step>.
set -euo pipefail

CACHE_DIR="${HOME}/.cache/reporecon"

ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

epoch_ms() {
  # GNU date supports %N; fall back to seconds*1000 if unavailable.
  local ns
  ns="$(date +%s%N 2>/dev/null || true)"
  if [[ "$ns" =~ ^[0-9]+$ ]] && (( ${#ns} > 10 )); then
    echo "$(( ns / 1000000 ))"
  else
    echo "$(( $(date +%s) * 1000 ))"
  fi
}

emit() {
  printf '[%s] [reporecon] %s\n' "$(ts)" "$*" >&2
}

if (( $# < 1 )); then
  emit "ERROR status: usage: status.sh <start|tick|done|error> <step> [...]"
  exit 2
fi

event="$1"; shift || true

case "$event" in
  start)
    (( $# >= 1 )) || { emit "ERROR status: start requires <step>"; exit 2; }
    step="$1"
    mkdir -p "$CACHE_DIR"
    epoch_ms > "$CACHE_DIR/.status.start.${step}"
    emit "start ${step}"
    ;;
  tick)
    (( $# >= 2 )) || { emit "ERROR status: tick requires <step> <c>/<t>"; exit 2; }
    step="$1"; prog="$2"
    emit "${step} ${prog}"
    ;;
  done)
    (( $# >= 1 )) || { emit "ERROR status: done requires <step>"; exit 2; }
    step="$1"
    marker="$CACHE_DIR/.status.start.${step}"
    if [[ -f "$marker" ]]; then
      start_ms="$(cat "$marker" 2>/dev/null || echo "")"
      rm -f "$marker"
      if [[ "$start_ms" =~ ^[0-9]+$ ]]; then
        now_ms="$(epoch_ms)"
        elapsed=$(( now_ms - start_ms ))
        emit "done ${step} (elapsed ${elapsed}ms)"
      else
        emit "done ${step}"
      fi
    else
      emit "done ${step}"
    fi
    ;;
  error)
    (( $# >= 1 )) || { emit "ERROR status: error requires <step> [msg]"; exit 2; }
    step="$1"; shift
    msg="${*:-unspecified}"
    emit "ERROR ${step}: ${msg}"
    ;;
  *)
    emit "ERROR status: unknown event '${event}' (expected start|tick|done|error)"
    exit 2
    ;;
esac
