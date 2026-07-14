<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Architecture

A map of `outpost` for someone changing it. For *why* the choices were made and
how to install, see [README.md](README.md) and [docs/INSTALL.md](docs/INSTALL.md).

## What this is

A single-board network appliance for a **Raspberry Pi 2B** (ARMv7 / 1 GB RAM /
100 Mbit Ethernet on the USB 2.0 bus / no Wi-Fi). It does three jobs:

1. **DNS sinkhole** — AdGuard Home, in a container.
2. **Print server** — CUPS + Avahi, on the host.
3. **Host firewall** — nftables, protecting the box itself.

It is **not** an inline edge firewall/router — the 2B has one NIC on a shared
USB bus and the appliance router OSes are x86-only. See README § "Why no inline
firewall".

## Component map

```
                         ┌─────────────────────────── Raspberry Pi 2B (Alpine, armv7) ──┐
   LAN clients ──DNS───▶ │  AdGuard Home  (container, Podman, host-net)                  │
   LAN clients ──IPP───▶ │  CUPS + Avahi  (host services)  ── USB ──▶ printer            │
                         │  nftables      (host firewall, default-deny, LAN-scoped)      │
                         └──────────────────────────────────────────────────────────────┘
```

| Concern | Lives in | Runtime |
|---------|----------|---------|
| Sinkhole service | `compose/adguardhome.yaml` | container (Podman, `network_mode: host`) |
| Sinkhole config | `adguardhome/conf/AdGuardHome.yaml` | committed source of truth (captured after first-boot wizard) |
| Pinned base image | `images.lock` | committed; multi-arch `@sha256` digest |
| Launch wrapper | `bin/up.sh` | sources the pin; refuses un-pinned tags |
| Bump tooling | `bin/bump.sh` | maintainer-gated repin from source |
| Canary (report-only) | `bin/canary.sh`, `host/canary/` | weekly check/verify on owned compute; notifies, never applies |
| Host bootstrap | `host/setup.sh` | idempotent Alpine provisioning |
| Firewall | `host/nftables.nft` | host nftables ruleset |
| Print server | `host/cups/cupsd.conf`, `host/avahi/airprint.service` | host CUPS + mDNS |
| Dynamic DNS | `host/ddns/` | host script + crond (15min); announces only on IP change |
| Local overrides | `.env` (from `.env.example`) | TZ, LAN subnet, SSH port; **not** committed |
| Future intent | `roadmap/` | sketches only — not built |

## Why containers for DNS but host for printing

AdGuard Home is a single self-contained service with one YAML state file → a
clean, digest-pinned container is the most reproducible packaging. CUPS needs
USB device passthrough and host mDNS to do AirPrint cleanly; on a 1 GB armv7 box
that is far less fiddly run directly on the host. Pragmatic split, not dogma.

## The pin-and-bump flow (the load-bearing design)

The "stabilised, reproducible environment" property rests here:

```
  source of truth ........ images.lock  (AGH_IMAGE = repo@sha256:...)
        │
        │  sh bin/up.sh        loads pin, guards against floating tags, starts container
        ▼
  running container at an immutable digest

  upgrades (maintainer-gated):
     sh bin/bump.sh --check    report-only; exit 10 if a newer release exists
     sh bin/bump.sh --verify   re-resolve current pin from source; assert no drift
     sh bin/bump.sh --apply    re-resolve digest + repin AFTER explicit confirmation
```

Digests are **manifest-list** digests, so one pin resolves the right per-arch
image automatically (armv7 today, aarch64 on a Pi 4). Governance for this flow:
[.github/GOVERNANCE.md](.github/GOVERNANCE.md) § "Policy 1".

## Base OS constraint (don't relitigate without checking arch)

Base is **Alpine (armv7)**. Wolfi was first choice but has **no 32-bit ARM
target**, so it is impossible on a 2B. On a 64-bit Pi (`uname -m` = `aarch64`)
Wolfi becomes possible — see `roadmap/PI4-AND-BEYOND.md`.

## Boundaries / non-goals

- Not a router or inline firewall (hardware can't do it credibly).
- Not a NAS / media server / VPN concentrator — 1 GB RAM + USB-bus NIC ceiling.
- The micropatch server (`roadmap/MICROPATCH-SERVER.md`) is explicitly **future**
  and needs better hardware; it is not part of the running system.

## Dynamic DNS

`host/ddns/ddns-update.sh` keeps a stable hostname pointed at a domestic,
ISP-rotated IP. It speaks the generic **dyndns2** protocol — Dynu is the
reference endpoint, not a dependency; repoint `DDNS_UPDATE_URL` and nothing else
changes. It runs from crond every 15 minutes and announces **only on actual IP
change** (plus a forced refresh every ~25 days, before providers expire an
unrefreshed record). Its credential is scoped to one DNS record, lives only in
gitignored `.env`, and is passed to curl on stdin — never argv, which `ps` would
expose. No firewall change is needed: the nftables `output` chain is
`policy accept`, and this adds no inbound surface.

Note that DDNS makes the box **nameable**, not **reachable** — reaching it still
requires a port-forward, which this project neither asks for nor wants.

## Why BoJ is not here

The estate's BoJ MCP server cannot run on a 2B: its container base
(`cgr.dev/chainguard/node`, Wolfi) publishes **only** `linux/amd64` and
`linux/arm64` — no `armv7`. This is the *same* 32-bit-ARM wall that already
disqualified Wolfi as the base OS, re-entering through a dependency.

There is also a security-gradient argument that holds even on hardware where BoJ
*does* fit: BoJ holds broadly-scoped credentials, while the outpost is
deliberately the most widely-exposed box on the LAN (every device talks to the
sinkhole). Credentials belong on the control plane, not here. Full reasoning,
including the one experiment that is still worth running on a 2B:
[`roadmap/BOJ-ON-OUTPOST.md`](roadmap/BOJ-ON-OUTPOST.md).
