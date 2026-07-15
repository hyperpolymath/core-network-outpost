<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# edge-shaper — inline CAKE SQM for the Virgin Media edge

**Status: draft config set**, now in its own private repo `edge-shaper` (renamed from
`pi-edge-shaper` — the shaper runs on the x86 N100, so nothing is Pi-bound). Not yet
deployed inline; awaiting the N100.

This realises **Rung 2** of `pi-core-network-outpost/roadmap/PI4-AND-BEYOND.md`:
an **x86 N100 mini-PC with dual 2.5GbE (Intel i226-V), inline between the Virgin
Hub and the LAN**, doing `nftables` NAT/routing + **CAKE** smart-queue shaping.

> **Why N100, not the Pi (Rung 1):** the line is **~1 Gb**, and CAKE is
> single-threaded. A Pi 4 caps ~350–500 Mbit of shaping, a Pi 5 ~600–900 Mbit —
> both short of a gig. The N100's per-core throughput CAKEs a full gigabit
> comfortably. Base N100 is enough; spend on the dual i226-V NICs, not on cores
> (N305/N150 buy nothing for pure routing). The config below is byte-identical to
> the Pi version — only the interface names change.

## What problem it actually solves

Your **idle** link is already excellent (~11–12 ms, <1 ms jitter, 0 % loss to
Cloudflare — measured 2026-07-15). The thing that wrecks ping/jitter on cable is
**bufferbloat**: when a download or (worse) an upload saturates, the modem's
buffer fills and latency balloons to hundreds of ms. CAKE holds a little
headroom back and keeps the queue short, so latency-under-load stays flat.

| Your goal | How this delivers it |
|-----------|----------------------|
| Lowest **ping/jitter**, for all time | CAKE on both directions keeps queueing delay ~flat under load, permanently, for every device behind the Pi |
| **Packet loss** down | *Only the under-load / tail-drop kind.* Idle/random loss on DOCSIS is physical (power/SNR/T3) — no qdisc fixes it; the monitor tells you which kind you have |
| **Download before upload** | `ack-filter` thins the upload's ACK stream so a busy download stays responsive, and egress is shaped so upload can't bloat the downstream ACK path — the real mechanism behind "downloads feel prioritised" on asymmetric cable |

> **Honesty note on "download before upload":** CAKE runs an *independent* qdisc
> per direction — there is no strict cross-direction priority scheduler. What you
> actually want (downloads stay fast even while uploading) is exactly what
> `ack-filter` + correctly-shaped egress produce. If you later want hard app
> priority, that's DSCP marking + `diffserv`, documented inline in `cake-shaper.sh`.

## Topology

```
  Internet ─ coax ─▶ Virgin Hub 5 (MODEM MODE) ─ eth ─▶ [ N100 edge-shaper ]
                                                          enp1s0 = WAN (i226-V 2.5GbE, DHCP/modem)
                                                          enp2s0 = LAN (i226-V 2.5GbE, static)
                                                             │  nftables NAT + CAKE
                                                             ▼
                                                        LAN switch / AP ─▶ clients
                                                             │
                                              [ Pi 2B: AdGuard sinkhole + print ]  (unchanged)
```

The 2B stays exactly as it is — DNS sinkhole + print server — per the outpost
roadmap's "suggested split once you have two boxes".

## Files

| File | Role |
|------|------|
| `.env.example` | interface names + measured CAKE rates — copy to `.env`, **fill in real speeds** |
| `cake-shaper.sh` | the tc/CAKE setup (egress on WAN, ingress via IFB), DOCSIS-tuned |
| `nftables.nft` | inline-router firewall: default-deny input, LAN→WAN forward, NAT masquerade |
| `sysctl-forwarding.conf` | enable IPv4/IPv6 forwarding |
| `cake-shaper.service` | systemd unit — apply/reapply the qdiscs at boot & on WAN up |
| `link-quality-monitor.sh` | fping-based jitter/ping/loss → Prometheus textfile (feeds `network-dashboard`) |

## Install (on the inline N100, once provisioned)

```sh
cp .env.example .env && $EDITOR .env         # set WAN_IF/LAN_IF + measured rates
sudo cp sysctl-forwarding.conf /etc/sysctl.d/99-edge-forwarding.conf && sudo sysctl --system
sudo nft -f nftables.nft                     # review first!
sudo install -m755 cake-shaper.sh /usr/local/sbin/cake-shaper
sudo cp cake-shaper.service /etc/systemd/system/ && sudo systemctl enable --now cake-shaper
cake-shaper status                           # verify qdiscs are attached
```

## Tuning the rates (the one step that matters)

1. At a **quiet hour**, run a wired speedtest **3×**; take the **lowest** down/up.
2. Set `DOWN_KBIT` ≈ **85 %** of measured download, `UP_KBIT` ≈ **90 %** of upload.
   (Download gets the deeper haircut — the CMTS buffer upstream of you is the part
   you can't control, so you trade a little throughput for a lot of latency.)
3. Run **waveform.com/bufferbloat** while watching `cake-shaper status`. Tighten
   the rates 5 % at a time until the under-load latency line is flat (grade **A/A+**).
4. Leave `link-quality-monitor.sh` running so the setting stays honest for all time.

See the outpost repo's `PI4-AND-BEYOND.md` for the hardware ladder and the
graceful demotion of the 2B.

## Requirements

**Edge shaper (the N100 path):**
- x86-64 mini-PC, **2× NIC** (Intel i226-V 2.5GbE recommended; avoid Realtek 2.5GbE).
- Linux with `sch_cake`, `ifb`, `act_mirred` in-kernel (mainline ≥ 4.19; present in
  Debian 12 / Ubuntu 22.04+ / OpenWrt). `iproute2` (`tc`), `nftables`, `ethtool`. Root.
- An upstream in bridge/modem mode handing a single WAN to the box (e.g. Virgin Hub → Modem Mode).

**Monitor (runs anywhere, incl. the Pi 2B outpost):**
- `fping`, `bash`, and a Prometheus `node_exporter` textfile-collector directory to scrape.

## Tested on

> **Honesty for anyone this is shared with:** the shaper is a **reviewed reference
> config, not yet a hardware-proven appliance.** Rates in `.env` are placeholders.

- **Live link, idle baseline — measured 2026-07-15** on Virgin Media (DOCSIS,
  `cable.virginm.net`) from a WSL2 client: **~12 ms RTT, <1 ms jitter, 0 % loss**
  to `1.1.1.1` and `9.9.9.9`. *Idle only — under-load/bufferbloat not yet measured.*
- **Authoring/review env:** WSL2, Debian, kernel `6.18.x-microsoft-standard`,
  `tc`/CAKE present; scripts shellcheck-clean; `nftables.nft` reviewed, not yet loaded.
- **Not yet deployed** on N100 hardware (pending purchase) or on the Pi outpost.
  When you run it, append your box + OS + measured before/after bufferbloat grade here.
