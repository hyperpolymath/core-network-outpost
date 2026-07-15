<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Hardware compatibility catalogue

No one can buy every board — this is a **community catalogue**. Ran it somewhere?
Add a row by PR, or post in **Discussions** with the template below. This is also how
the honest "Tested on" grows beyond what one maintainer can verify.

Legend: ✅ works · ⚠️ works with caveats · ❌ no · ❓ untested (expected, unverified)

| Device | Arch | RAM | Profile | Status | CAKE ceiling | Notes | Reporter |
|--------|------|-----|---------|--------|--------------|-------|----------|
| Raspberry Pi 2B | armv7 | 1 GB | `legacy-sbc` | ⚠️ | n/a (not inline) | sinkhole/print/fw/time/monitor only; no onboard RTC → add DS3231 | maintainer |
| _dev/CI: WSL2 Debian_ | x86-64 | — | — | ✅ authoring | — | idle Virgin baseline ~12 ms / <1 ms jitter / 0 % loss (2026-07-15); configs authored + shellcheck/`sh -n` clean here | maintainer |
| Raspberry Pi 4 / 5 | aarch64 | 2–8 GB | `modern` | ❓ | ~600–900 Mbit | expected to work; **not yet tested** | — |
| Intel N100 (2× i226-V) | x86-64 | 8–16 GB | `modern` | ❓ | ~1–2.5 Gbit | intended inline shaper; **not yet tested** | — |

## Report template
```
- Device / SoC:
- Arch / RAM / storage:
- Profile (legacy-sbc / modern):
- OS + version:
- What worked / what didn't:
- CAKE bufferbloat grade (if inline):  before → after
- Gotchas / notes:
```
Keep it honest — a ❓ that becomes a ⚠️ with a real caveat is worth more than an
optimistic ✅.

## Right-size to *your* line — 2.5GbE is NOT a requirement
2.5GbE (i226-V) is headroom for **gigabit+ inline shaping**, not a baseline. Match the box to
your actual connection:

| Your connection | Inline shaping | Sidecar (sinkhole/fw/time/monitor) |
|---|---|---|
| **Gigabit+ cable/fibre** | N100 + **2.5GbE** headroom | any capable box, 1 NIC |
| **Sub-gig ≤ ~500 Mbps** | **1GbE** + modest CPU (a Pi 4 copes) | any Pi/mini-PC, 1 NIC |
| **VDSL ~40–80 Mbps** | onboard **1GbE** is plenty | a Pi 2B is fine |
| **5G/4G home box, hotspot** | often **can't do inline** (won't bridge) → **sidecar**; the mobile radio is the bottleneck anyway | 1 NIC, anything |

**Rule:** NIC + CPU scale with **line speed**, not a fixed spec. Most people never need 2.5GbE or
even a second NIC — the **sidecar Core (single NIC)** is the majority path and runs on almost
anything. Inline shaping + 2.5GbE is the *gigabit-enthusiast* tier.
