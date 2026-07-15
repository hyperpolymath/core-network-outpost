#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# cake-shaper — inline CAKE SQM for a Virgin Media (DOCSIS) edge on a Pi 4/5.
#
# Egress (upload) is shaped directly on the WAN interface.
# Ingress (download) can't be shaped directly, so it's redirected to an IFB
# device and shaped there — the standard sqm-scripts technique.
#
# Usage: cake-shaper {start|stop|restart|status}
# Config: /etc/edge-shaper/.env  (or ./.env next to this script)

set -euo pipefail

# --- load config ------------------------------------------------------------
ENV_FILE="${ENV_FILE:-/etc/edge-shaper/.env}"
[ -f "$ENV_FILE" ] || ENV_FILE="$(dirname "$(readlink -f "$0")")/.env"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

: "${WAN_IF:?set WAN_IF in .env}"
: "${LAN_IF:?set LAN_IF in .env}"
: "${DOWN_KBIT:?set DOWN_KBIT in .env}"
: "${UP_KBIT:?set UP_KBIT in .env}"
: "${OVERHEAD_PRESET:=docsis}"
: "${EGRESS_DIFFSERV:=besteffort}"

IFB="ifb-${WAN_IF}"

require_root() { [ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }; }

stop() {
  # Tear down quietly; ignore "not found" on a clean box.
  tc qdisc del dev "$WAN_IF" root        2>/dev/null || true
  tc qdisc del dev "$WAN_IF" ingress     2>/dev/null || true
  tc qdisc del dev "$IFB"    root        2>/dev/null || true
  ip link set dev "$IFB" down            2>/dev/null || true
  ip link del "$IFB"                     2>/dev/null || true
}

start() {
  require_root

  # Offloads bundle packets into super-frames that defeat accurate shaping.
  # Disable GRO/GSO/TSO on the WAN path (harmless if the NIC lacks them).
  ethtool -K "$WAN_IF" gro off gso off tso off 2>/dev/null || true

  # --- EGRESS / upload: CAKE straight on the WAN device ---------------------
  # docsis        : cable overhead preset (overhead 18, mpu 64)
  # ack-filter    : thin the upload's ACK stream so a busy download stays snappy
  #                 (this is the "download before upload" behaviour on asymmetric links)
  # dual-srchost  : per-LAN-host fairness on the way out
  # nat           : de-NAT via conntrack so fairness sees real LAN hosts, not the WAN IP
  tc qdisc replace dev "$WAN_IF" root cake \
      bandwidth "${UP_KBIT}kbit" \
      "$OVERHEAD_PRESET" \
      "$EGRESS_DIFFSERV" \
      ack-filter \
      dual-srchost \
      nat

  # --- INGRESS / download: redirect WAN ingress to an IFB, shape it there ----
  ip link add name "$IFB" type ifb 2>/dev/null || true
  ip link set dev "$IFB" up
  tc qdisc replace dev "$WAN_IF" handle ffff: ingress
  tc filter replace dev "$WAN_IF" parent ffff: protocol all matchall \
      action mirred egress redirect dev "$IFB"

  # ingress       : tell CAKE it's policing the receive side (counts drops+delivered)
  # wash          : clear inbound DSCP so upstream marks don't mis-prioritise us
  # dual-dsthost  : per-LAN-host fairness on the way in
  tc qdisc replace dev "$IFB" root cake \
      bandwidth "${DOWN_KBIT}kbit" \
      "$OVERHEAD_PRESET" \
      wash \
      dual-dsthost \
      nat \
      ingress

  echo "cake-shaper: up  (down ${DOWN_KBIT}kbit / up ${UP_KBIT}kbit on ${WAN_IF})"
}

status() {
  echo "### egress (${WAN_IF}) ###"; tc -s qdisc show dev "$WAN_IF"
  echo; echo "### ingress (${IFB}) ###"; tc -s qdisc show dev "$IFB" 2>/dev/null || echo "(ifb not up)"
}

case "${1:-}" in
  start)   start ;;
  stop)    require_root; stop ;;
  restart) require_root; stop; start ;;
  status)  status ;;
  *) echo "usage: $0 {start|stop|restart|status}" >&2; exit 2 ;;
esac
