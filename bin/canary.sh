#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
#
# canary.sh — scheduled, REPORT-ONLY watch over the pinned base.
#
# Runs bump.sh in its non-mutating modes and notifies if there is something for
# the maintainer to decide. It NEVER applies an upgrade. This is the scheduled
# embodiment of GOVERNANCE.md "Policy 1": detection is automated, application is
# a separate, deliberate human choice.
#
# Install it via host/canary/ (Alpine crond or systemd timer). Manual run:
#   sh bin/canary.sh
#
# Optional config (sourced if present): /etc/outpost/canary.env
#   OUTPOST_LOG=/var/log/outpost-canary.log
#   OUTPOST_NOTIFY='mail -s "outpost" you@example.com'   # any cmd reading stdin
#                  # e.g. ntfy:  OUTPOST_NOTIFY='curl -s -d @- https://ntfy.sh/your-topic'

set -u

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

[ -f /etc/outpost/canary.env ] && . /etc/outpost/canary.env
LOG="${OUTPOST_LOG:-/var/log/outpost-canary.log}"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

report=""

# 1. Is a newer release available? (exit 10 = yes)
out=$(sh bin/bump.sh --check 2>&1); rc=$?
if [ "$rc" -eq 10 ]; then
  report="${report}
[outpost] An AdGuard Home upgrade is available (review, do not auto-apply):
${out}
"
fi

# 2. Has the pinned digest drifted at source? (non-zero = drift/error)
vout=$(sh bin/bump.sh --verify 2>&1); vrc=$?
if [ "$vrc" -ne 0 ]; then
  report="${report}
[outpost] Pin verification FAILED (possible supply-chain drift):
${vout}
"
fi

# Always leave a heartbeat line in the log.
if [ -n "$report" ]; then
  { echo "$TS  ACTION-NEEDED"; printf '%s\n' "$report"; } >> "$LOG" 2>/dev/null || true
  printf '%s\n' "$report" | logger -t outpost-canary 2>/dev/null || true
  if [ -n "${OUTPOST_NOTIFY:-}" ]; then
    printf '%s\n' "$report" | sh -c "$OUTPOST_NOTIFY" 2>/dev/null || true
  fi
  printf '%s\n' "$report"
else
  echo "$TS  ok: up to date, no drift" >> "$LOG" 2>/dev/null || true
fi

# Report-only: succeed regardless so the scheduler stays quiet.
exit 0
