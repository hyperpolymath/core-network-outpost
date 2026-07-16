# Tested Devices — the community catalogue

> ✅ **Live catalogue.** This is the wiki face of
> [`docs/HARDWARE.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/HARDWARE.md).
> **It is short, and that's honest** — one unpaid person can't buy every board. If you run
> it somewhere, adding a row is the single most useful contribution you can make.

**Legend:** ✅ works · ⚠️ works with caveats · ❌ no · ❓ untested (expected, unverified)

## The catalogue

| Device | Arch | RAM | Profile | Status | CAKE ceiling | Notes | Reporter |
|---|---|---|---|---|---|---|---|
| **Raspberry Pi 2B** | armv7 | 1 GB | `legacy-sbc` | ⚠️ | n/a (not inline) | Sinkhole / print / firewall / time / monitor only. No onboard RTC → add a DS3231. | maintainer |
| *dev/CI: WSL2 Debian* | x86-64 | — | — | ✅ authoring | — | Configs authored here; shellcheck / `sh -n` clean. Idle Virgin baseline ~12 ms / <1 ms jitter / 0 % loss (2026-07-15). | maintainer |
| **Raspberry Pi 4 / 5** | aarch64 | 2–8 GB | `modern` | ❓ | ~600–900 Mbit | Expected to work. **Not yet tested.** | — |
| **Intel N100 (2× i226-V)** | x86-64 | 8–16 GB | `modern` | ❓ | ~1–2.5 Gbit | The intended inline shaper. **Not yet tested** — hardware not yet purchased. | — |

> **Read those ❓ rows literally.** The N100 is the box this whole design points at, and it
> has **never been run**. The shaper configs are reviewed and `shellcheck`-clean, but they
> are **not hardware-proven**. If you get there before the maintainer does, your report is
> genuinely valuable.

## What "tested" means here

Deliberately strict, because an optimistic catalogue is worse than a short one:

- **✅ works** — you ran it, it did its job, you'd leave it running.
- **⚠️ works with caveats** — it runs, but something needs saying (a limit, a workaround, a
  gotcha). **This is the most useful status.**
- **❌ no** — you tried; here's the wall you hit. Also useful — it saves the next person.
- **❓ untested** — nobody has run it. An educated guess, clearly labelled.

**A ⚠️ with a real caveat is worth more than an optimistic ✅.** If it only *half* works, say
so — that's the honest thing, and it's what stops someone wasting a weekend.

## Report your device

Open a **[Discussion](https://github.com/hyperpolymath/core-network-outpost/discussions)** or
send a PR against
[`docs/HARDWARE.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/HARDWARE.md)
using this template:

```
- Device / SoC:
- Arch / RAM / storage:
- Profile (legacy-sbc / modern):
- OS + version:
- What worked / what didn't:
- CAKE bufferbloat grade (if inline):  before → after
- Gotchas / notes:
```

**If you ran the shaper inline, the before → after bufferbloat grade is the number this
project most wants.** Grab it from
[waveform.com/bufferbloat](https://www.waveform.com/tools/bufferbloat) on a wired machine.

## Known-good and known-bad components

| Thing | Verdict | Why |
|---|---|---|
| **Intel i226-V 2.5GbE** | ✅ recommended | The reference NIC for the inline path. |
| **Realtek 2.5GbE** | ⚠️ avoid | Driver pain — the classic wasted evening. |
| **DS3231 RTC (I²C, ~£3)** | ✅ recommended on any RTC-less Pi | Without it the 2B forgets the time on every power-off, which quietly breaks TLS and DNSSEC. |
| **Jetson (any)** | ❌ wrong tool | The GPU can't run CAKE and the A57 CPU is weaker than a Pi 4's. |
| **Pi 2B as a gateway** | ❌ no | 100 Mbit NIC on the shared USB 2.0 bus. Superb sidecar though. |

## The profiles, briefly

- **`legacy-sbc`** — Pi 2B / armv7 / ≤1 GB / Alpine. Sinkhole, print, firewall, DDNS, chrony,
  monitor. No Wolfi (no armv7 target), no ClamAV (RAM), no local metrics store, not inline.
- **`modern`** — Pi 4/5 aarch64 or x86 N100. Everything above **plus** Wolfi bases, CAKE
  shaping (N100, inline), SELinux/AppArmor, and a metrics store.

Full detail:
[`docs/PROFILES.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/PROFILES.md).
