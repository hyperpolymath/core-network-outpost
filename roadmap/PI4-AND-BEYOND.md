<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# 🛰️ Upgrade path — Pi 4 and beyond (future sketch)

> **Status: sketch.** The outpost is designed to run happily on a 2B forever for
> its three core jobs. This file is just "when you outgrow it, here's the ladder."

## Why the 2B is the floor

| Constraint on the 2B | Consequence |
|----------------------|-------------|
| ARMv7 / 32-bit | **No Wolfi** (x86_64 + aarch64 only); Alpine armv7 it is |
| 1 GB RAM | sinkhole + print server only; no micropatch mirror, no NAS |
| 100 Mbit NIC on USB 2.0 | poor distribution point; can't be a credible router |
| No Wi-Fi radio | "wireless" = clients reach the wired Pi via the router |
| SD-card storage | write-heavy workloads chew through cards |

## The ladder

### Rung 1 — Raspberry Pi 4 (or 5), 64-bit
- `uname -m` → **`aarch64`** → **Wolfi becomes possible** as the base image.
  Your original first-choice base is back: rebuild the same compose stack on a
  Wolfi/aarch64 host for a hardened, minimal, reproducible appliance.
- 2–8 GB RAM → headroom for the **micropatch server** (`MICROPATCH-SERVER.md`).
- Gigabit Ethernet + USB3 → a USB3 2.5GbE adapter gives a real second interface,
  so a **modest inline firewall** becomes *defensible* (still not OPNsense — that's
  x86 — but `nftables` routing/NAT on a 2-NIC Pi 4 is workable for home WAN speeds).
- Onboard Wi-Fi → could genuinely be wireless if you ever wanted.

**Migration is cheap by design:** the compose file, AdGuard config, nftables
ruleset, and CUPS config in this repo are all portable. On aarch64 you mostly
just swap `AGH_IMAGE` for an aarch64 (or Wolfi-based) digest and re-run
`host/setup.sh` (Alpine aarch64) — or port `setup.sh` to a Wolfi/apk-style base.

### Rung 2 — x86 mini-PC (e.g. fanless N100, 2× NIC)
- The point where a **true inline firewall** stops being a compromise:
  **OPNsense / pfSense run here** (x86), or a Linux + nftables router.
- Full Wolfi/Chainguard container story, lots of RAM, NVMe → the micropatch
  server and a small NAS become realistic.
- The 2B then demotes gracefully to a **dedicated DNS sinkhole** (its best role),
  while the mini-PC takes routing + patching.

## Suggested split once you have two boxes

```
 Internet ── [ x86 mini-PC: inline firewall + micropatch server ] ── LAN switch
                                                                        │
                                          [ Pi 2B: AdGuard sinkhole + print server ]
```

Single-minded boxes, each doing what its hardware is actually good at.
