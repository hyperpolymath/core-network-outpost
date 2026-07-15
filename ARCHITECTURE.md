<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Architecture + an honest fragility read

```
                          INTERNET
                             │
                    ┌────────┴────────┐
                    │  Virgin Hub     │   Modem Mode (dumb bridge)
                    └────────┬────────┘
                             │ WAN
        ╔════════════════════╪════════════════════════════╗
        ║  🔴 CORE — inline, CRITICAL PATH, dark           ║
        ║     (N100 gateway; MUST fail-open + watchdog)    ║
        ║   nftables(default-deny) · CAKE(SQM)             ║
        ║   AdGuard(DNS+graceful fallback) · chrony(NTP)   ║
        ║   SPA/SDP gate · DDNS · node_exporter            ║
        ╚════════════════════╪════════════════════════════╝
                             │ LAN
                    ┌────────┴────────┐
                    │   LAN switch    │────────► clients
                    └───┬─────────┬───┘
        🟡 FRONTIER ....│         │.... 🟢 Pi 2B
   ┌────────────────────┴───┐  ┌──┴───────────────┐
   │ isolated box (N100/VM) │  │ retired → backup │
   │  setup UI · mail-auth  │  │ DNS sinkhole     │
   │  DMARC · dev bastion   │  └──────────────────┘
   │  ODoH · hardened Bandit│
   │  Prometheus·Loki·Phoenix│   (scrapes Core's exporter)
   └────────────────────────┘
        │ compromise/failure here CANNOT reach Core │

        🟢 OFF-BOX — someone else runs it, free, ~zero fragility
   ┌──────────────────────────────────────────────────────┐
   │ Cloudflare DNS zone + DNSSEC  │ Pages: IndieWeb +     │
   │ (mail-auth records published) │ .well-known (static)  │
   └──────────────────────────────────────────────────────┘
```

## Fragility scorecard (honest, not reassuring)
- 🟢 **Off-box (Cloudflare/Pages):** near-zero. Someone else runs it. Best call in the design.
- 🟢 **Core as a *sidecar* (2B: sinkhole/firewall/time/monitor):** low — boring, mature,
  single-purpose daemons + read-only-root + watchdog. Genuinely safe.
- 🔴 **Core as the *inline router+shaper* (in the WAN path):** THIS is the real fragility, and
  the worry is correct. It's a single point of failure for *all connectivity* — hang or misconfig
  and the whole house loses internet, not just ads. You can't make an in-path router "inherently
  safe" (it's in the path). You make it **fail-safe**, three ways:
    1. **Fail-open** — if CAKE/nftables/the box dies, traffic *passes* (unshaped/unfiltered), never blocked.
    2. **Watchdog** — auto-reboot a hang.
    3. **Strippable** — pull it, put the Hub back in ~60s. A physical bypass path always exists.
  Those three — not "never fails" — are the answer.
- 🟡 **Frontier (mail/bastion/ODoH/dashboard):** medium complexity, but *isolated* → its failure is
  a feature-outage, never a network-outage. The real cost is **maintenance burden** (solo), not
  fragility. Keep it optional, off by default.
- 🟡 **Extra interfaces:** each NIC/overlay (WAN/LAN/mgmt, ZeroTier, bastion, ODoH) = added surface +
  a failure mode. Instinct correct. Discipline: **minimise interfaces on Core; concentrate them on
  Frontier**, where failure is contained.

## Is it crazy? No — *if* you hold the layering
The two-box + off-box split is precisely what stops it being a juggernaut. It only turns crazy if
(a) you collapse it back into one box, or (b) you let the inline router fail-*closed*. The craziness
is bounded by isolation. The **one thing that genuinely deserves your worry is the inline-router
criticality** — everything else the architecture already tames.

## Self-healing + recovery ("Bustfiles") — the right instinct; you own half the tooling
Already designed: watchdog · AdGuard healthcheck+restart · config-validate-before-apply ·
read-only-root revert · graceful DNS fallback. **Add the big one: fail-open on the inline router.**

Recovery-as-code (Bustfiles = Just-style rescue recipes):
- `just bypass-shaper`   — drop the box out of the WAN path, Hub takes over
- `just rescue-dns`      — fall back to Cloudflare/router DNS if AdGuard is down
- `just rebuild-from-pin`— redeploy every container from its committed digest
- `just break-glass`     — LAN-only SSH that ignores the SPA layer
- `just verify-all`      — validate every config before it can take a box down

**`network-ambulance` is literally your recovery tool** (diagnose + safe, reversible repair, already
in your repos). Point the Bustfiles at it — that's your autofix layer, already started.
