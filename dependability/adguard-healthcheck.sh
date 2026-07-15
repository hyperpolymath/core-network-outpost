#!/usr/bin/env sh
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# adguard-healthcheck — graceful DNS self-heal [dep+].
#
# Tests that the local resolver DAEMON is ALIVE (responds at all — even NXDOMAIN),
# NOT that the internet is up. So it won't needlessly bounce AdGuard during a WAN
# outage. If the daemon is dead, restart the container so DNS recovers fast.
#
# Pair with a DHCP-advertised SECONDARY resolver (the router) so clients keep
# resolving during the restart gap — see dependability/README.md. That pairing is
# the actual "ads come back, internet stays up" graceful degradation.
#
# POSIX sh (works with busybox on Alpine). Wire via systemd timer (Debian/N100)
# or cron/OpenRC (Alpine/2B) — see the .timer file and the README.
set -eu

RESOLVER="${RESOLVER:-127.0.0.1}"
CONTAINER="${CONTAINER:-adguardhome}"
PROBE="${PROBE:-liveness-probe.invalid}"   # .invalid → NXDOMAIN locally, no upstream needed
TAG="adguard-healthcheck"

# "Alive" = the server sent ANY reply. dig exits 9 only on no-reply/timeout;
# nslookup (busybox) exits non-zero when it can't reach the server.
if command -v dig >/dev/null 2>&1; then
  alive() { dig +time=2 +tries=1 "@$RESOLVER" "$PROBE" >/dev/null 2>&1; }
else
  alive() { nslookup "$PROBE" "$RESOLVER" >/dev/null 2>&1; }
fi

alive && exit 0

# One retry after a short pause, so a transient blip never triggers a restart.
sleep 3
alive && exit 0

logger -t "$TAG" "resolver $RESOLVER unresponsive — restarting container $CONTAINER"
if podman restart "$CONTAINER" >/dev/null 2>&1; then
  logger -t "$TAG" "restarted $CONTAINER"
else
  logger -t "$TAG" "FAILED to restart $CONTAINER — clients should be failing over to the secondary resolver"
  exit 1
fi
