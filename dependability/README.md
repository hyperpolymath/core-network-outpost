<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Dependability tier — shippable now, works on the 2B today [dep+]

The reliability-first layer from `../HARDENING.md` §0 & §6, as real config. All of it
runs on the current Pi 2B **before any N100 hardware**. Ordered by value.

| File | What it gives you | Runtime |
|------|-------------------|---------|
| `readonly-root.md` | SD-card can't wear out / corrupt; immutable base | Alpine-native (2B) / overlayroot (Debian) |
| `chrony.conf` | authenticated multi-source time, router cross-check, LAN NTP, offline-resilient | portable |
| `adguard-healthcheck.sh` + `.service`/`.timer` | DNS self-heal so a crashed sinkhole ≠ dead internet | script portable; timer = systemd, cron on Alpine |
| `watchdog-systemd.conf` | auto-reboot a hung box | systemd (N100); `watchdog` pkg on Alpine |

## Golden rules (dependability first)
1. **Validate before apply** — every file lists its check command
   (`chronyd -p -f …`, `systemd-analyze verify …`, `nft -c -f …`). A bad config must
   never be able to take the box down. *(This is the discipline that catches typos.)*
2. **Always keep a break-glass path** — a local console / LAN SSH that does **not**
   depend on the SPA layer, so a hardening mistake can't lock you out.
3. **Graceful degradation over hard failure** — the healthcheck self-heals DNS, and
   DHCP should advertise a **secondary resolver (the router)** so clients keep
   resolving during any gap: a dead sinkhole means "ads come back", not "internet down".

## Runtime split (be honest — the boxes differ)
- **Pi 2B = Alpine + OpenRC.** Read-only root is native (`lbu`); watchdog via the
  `watchdog` package; the healthcheck runs from **cron**. `chrony.conf` is identical.
- **N100 = Debian + systemd (likely).** Use the `.service`/`.timer`, the
  `system.conf.d` watchdog drop-in, and `overlayroot`.

## Install order on the 2B (all today, no new hardware)
1. `chrony.conf` → `/etc/chrony/chrony.conf`; `chronyd -p -f` to validate; enable.
2. `adguard-healthcheck.sh` → `/usr/local/sbin/`; add a 1-minute cron line.
3. `watchdog` package + `/dev/watchdog` check; enable via OpenRC.
4. Read-only root **last**, after the above are proven, on a spare card first.
