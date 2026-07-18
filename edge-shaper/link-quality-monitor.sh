#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# link-quality-monitor — continuous jitter/ping/loss to fixed anchors, emitted
# as Prometheus text so node_exporter's textfile collector (and hence
# network-dashboard's future "Link Quality" panel) can scrape it "for all time".
#
# This is the measurement half of the ALARP goal: you cannot hold jitter/ping/loss
# low without watching them, and it also tells you whether packet loss is the
# under-load kind (CAKE fixes it) or the idle/physical kind (a Virgin line job).
#
# Deps: fping. Install: apt-get install -y fping  (Debian) / apk add fping (Alpine)
# Usage: link-quality-monitor.sh            # loops forever, one round every INTERVAL s
#        run via systemd timer or a supervised service on the outpost/edge Pi.

set -euo pipefail

ANCHORS=("1.1.1.1" "9.9.9.9" "8.8.8.8")   # stable, anycast, ICMP-friendly
INTERVAL="${INTERVAL:-30}"                 # seconds between rounds
COUNT="${COUNT:-20}"                       # pings per anchor per round
OUT="${OUT:-/var/lib/node_exporter/textfile_collector/link_quality.prom}"

emit_round() {
  local tmp; tmp="$(mktemp)"
  {
    echo "# HELP link_quality_rtt_ms Round-trip time to an internet anchor (ms)."
    echo "# TYPE link_quality_rtt_ms gauge"
    echo "# HELP link_quality_jitter_ms Std-dev of RTT over the round (ms)."
    echo "# TYPE link_quality_jitter_ms gauge"
    echo "# HELP link_quality_loss_ratio Fraction of pings lost this round (0..1)."
    echo "# TYPE link_quality_loss_ratio gauge"
    for a in "${ANCHORS[@]}"; do
      # fping -q -c N prints per-target stats on stderr:  a : xmt/rcv/%loss = ..., min/avg/max = ...
      # -s/-e give timing; we parse avg RTT, loss%, and derive jitter from mdev-like spread.
      local line
      line="$(fping -q -c "$COUNT" "$a" 2>&1 || true)"
      # loss%
      local loss_pct avg jitter
      loss_pct="$(printf '%s' "$line" | sed -n 's/.*= [0-9]*\/[0-9]*\/\([0-9.]*\)%.*/\1/p')"
      avg="$(printf '%s' "$line" | sed -n 's/.*min\/avg\/max = [0-9.]*\/\([0-9.]*\)\/[0-9.]*/\1/p')"
      # fping doesn't print stddev; approximate jitter as (max-min)/4 as a cheap proxy.
      local mn mx
      mn="$(printf '%s' "$line" | sed -n 's/.*min\/avg\/max = \([0-9.]*\)\/.*/\1/p')"
      mx="$(printf '%s' "$line" | sed -n 's/.*min\/avg\/max = [0-9.]*\/[0-9.]*\/\([0-9.]*\).*/\1/p')"
      loss_pct="${loss_pct:-100}"; avg="${avg:-0}"; mn="${mn:-0}"; mx="${mx:-0}"
      jitter="$(awk -v a="$mx" -v b="$mn" 'BEGIN{printf "%.3f",(a-b)/4}')"
      local loss_ratio; loss_ratio="$(awk -v p="$loss_pct" 'BEGIN{printf "%.4f",p/100}')"
      printf 'link_quality_rtt_ms{anchor="%s"} %s\n'    "$a" "$avg"
      printf 'link_quality_jitter_ms{anchor="%s"} %s\n' "$a" "$jitter"
      printf 'link_quality_loss_ratio{anchor="%s"} %s\n' "$a" "$loss_ratio"
    done
  } > "$tmp"
  mkdir -p "$(dirname "$OUT")"
  mv "$tmp" "$OUT"      # atomic swap so scrapes never see a half-written file
}

command -v fping >/dev/null || { echo "fping not installed" >&2; exit 1; }
while true; do
  emit_round || true
  sleep "$INTERVAL"
done
