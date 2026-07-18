# Right-Size Your Box

> ✅ **Guidance, not software** — this page is just advice, so nothing here is waiting on a
> build. The hardware catalogue it summarises is
> [`docs/HARDWARE.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/HARDWARE.md).

**The short version: you almost certainly need less than you think.** 2.5GbE is headroom for
gigabit inline shaping — it is **not** a baseline. Most people need **one network port on
almost anything**.

---

## First, answer one question: sidecar or gateway?

This decides everything else. It is *the* fork in the road.

| | **Sidecar** (the majority path) | **Gateway** (the enthusiast path) |
|---|---|---|
| **Sits** | Beside your router | *Between* your modem and your LAN |
| **Does** | DNS sinkhole, print, time, firewall-for-itself, monitoring | All of that **+ CAKE traffic shaping** |
| **Needs** | **1 network port**, almost any CPU | **2 network ports**, a fast single core |
| **If it dies** | Ads come back. Internet keeps working. | Everything routes through it — so it **must** fail-open |
| **Runs on** | A Pi 2B. Genuinely. | An x86 N100 for gigabit |

**Start as a sidecar.** It's the low-risk, high-value 90 %. Only go gateway if you have a
specific problem shaping solves — see below.

## Do you actually need the shaper?

Only if you have **bufferbloat**: the thing where a video call breaks up *while someone
uploads*, or your ping triples during a download. Your *idle* ping is probably already fine
and shaping won't improve it.

**Test it in 30 seconds, before buying anything:** run
[waveform.com/bufferbloat](https://www.waveform.com/tools/bufferbloat) on a **wired**
machine. It grades your latency **under load**.

| Grade | What to do |
|---|---|
| **A / A+** | **You don't need the shaper.** Stay a sidecar. Spend the money on nothing. |
| **B / C** | Shaping will give you a real, noticeable win. |
| **D / F** | Shaping will feel transformative. |

> **On this project's own line** (Virgin Media, ~1 Gb cable): idle was already excellent —
> ~12 ms, <1 ms jitter, 0 % loss. Under upload saturation it went to **24 ms average /
> 56 ms max, jitter 1.5 → 9.4 ms** — a solid B/C. That's the gap the shaper closes, and it's
> the *only* reason the N100 is in this design.

## Match the box to your line

The rule: **NIC and CPU scale with line speed, not with a fixed spec sheet.**

| Your connection | For inline shaping | For a sidecar |
|---|---|---|
| **Gigabit+ cable/fibre** | N100 + 2× 2.5GbE (Intel i226-V) | Anything, 1 port |
| **Sub-gig, ≤ ~500 Mbps** | 1GbE + modest CPU — **a Pi 4 copes** | Any Pi / mini-PC, 1 port |
| **VDSL, ~40–80 Mbps** | Onboard 1GbE is plenty — **a Pi 2B is fine** | A Pi 2B is fine |
| **5G / 4G home box, hotspot** | Usually **impossible** — they won't bridge → sidecar. The radio is your bottleneck anyway. | 1 port, anything |

## Why an N100 and not a Pi 5?

**Because CAKE is essentially single-threaded.** This is the single most useful fact on this
page, and it's counter-intuitive:

- **Cores don't help.** Shaping runs on one.
- **RAM doesn't help.** It's not the constraint.
- **A GPU doesn't help at all** — which is why a **Jetson is the wrong tool** here despite
  sounding powerful. Its A57 CPU is *weaker* than a Pi 4's.

Practical ceilings, roughly:

| Box | Shaping ceiling |
|---|---|
| Pi 2B | **Not a gateway at all** — 100 Mbit NIC on the shared USB 2.0 bus |
| Pi 3 / Jetson | Well under a gigabit |
| Pi 4 | ~350–500 Mbit |
| Pi 5 | ~600–900 Mbit |
| **Intel N100** | **~1–2.5 Gbit** ✅ |

**So for a gigabit line, the N100 is the first box that actually clears it.**

### If you buy an N100, spend the money in the right place

- ✅ **Base N100 is enough.** An N305/N150 buys you **nothing** for pure routing — more cores
  don't shape faster.
- ✅ **Spend on the NICs: 2× Intel i226-V.** **Avoid Realtek 2.5GbE** — the driver situation
  is the thing that'll actually waste your evening.
- ✅ Fanless is nice. ~10 W is normal.

## The Pi 2B is not a failure case

It's a genuinely excellent **DNS sinkhole, print server, firewall, DDNS client, and link
monitor** — the dependable, boring, always-on Core. Its honest ceiling is in
[`docs/LEGACY-DEVICES.adoc`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/LEGACY-DEVICES.adoc):

- **armv7 / 32-bit** → no Wolfi, so Alpine.
- **1 GB RAM** → no ClamAV (1–2 GB signature DB), no local metrics database.
- **100 Mbit NIC on the USB 2.0 bus** → **never** a credible router.
- **No onboard RTC** → add a DS3231 (~£3).
- **SD storage** → read-only root and bounded logging, or the card wears out.

> **The greenest box is the one you already own.** Reuse beats buying: embodied carbon
> (manufacturing) often outweighs years of the ~10 W this thing draws. If a spare 2B does the
> job, that *is* the better answer — not a consolation prize.

## Where next

- **[Getting Started](Getting-Started)** — the sidecar path, today, on what you have
- **[Tested Devices](Tested-Devices)** — what people have actually run
- **[Estate Architecture](Estate-Architecture)** — why it's two boxes, not one
