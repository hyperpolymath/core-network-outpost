<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# core-network-outpost — a reproducible, dependability-first home-network estate

> **Tested devices:** a community-led list of tested versions lives on the
> **[wiki → Tested devices](https://github.com/hyperpolymath/core-network-outpost/wiki/Tested-Devices)**.
> Please contribute your experience with other devices and I'll look at where things can be remediated.

A self-hosted network estate that scales from a **single-NIC sidecar on a Raspberry Pi 2B** up to
an **inline gateway on an x86 N100** — split into **two single-minded boxes by *criticality +
exposure***, so it never becomes a juggernaut that's always-down or the focus of every attack.

> **Right-size it to your line.** 2.5GbE is only for gigabit+ inline shaping — most people need
> one NIC on almost anything. Running a Pi 2B or other old board? Its real limits live in
> **[`docs/LEGACY-DEVICES.adoc`](./docs/LEGACY-DEVICES.adoc)**. Hardware guidance: `docs/HARDWARE.md`.

## Core — the dark, always-on box (single-minded per its ethos)

Three honest jobs (four with time), and it refuses to pretend to a fifth:

| Role | What it is |
|------|-----------|
| 🕳️ **DNS sinkhole** | AdGuard Home, containerised |
| 🧱 **Firewall** | `nftables`, default-deny |
| ⏱️ **Time** | chrony — NTS-authenticated, multi-source, LAN-served |
| 🖨️ **Print server** | CUPS + Avahi (host) |
| 🏷️ **Stable name** | Dynamic DNS (dyndns2; Dynu as the example) |

Add inline **CAKE shaping** only when the box *is* the gateway (an N100, not a 2B) — **fail-open +
watchdog** so a shaper fault degrades to pass-through, never to "no internet". See `docs/ARCHITECTURE.md`.

## Frontier — the exposed, optional, non-critical box

Setup (**TUI/CLI, no web surface**), mail-auth + DMARC, a developer bastion, an ODoH pool node,
the Prometheus/Loki/Phoenix dashboard, and a **Ddraig** static site published **off-box**
(Cloudflare Pages + DNS). By design its **failure or compromise cannot reach Core**.

> **Honest caveat:** the Tier-4 / community parts — the ODoH pool especially — only really shine
> with knowledgeable people running nodes. Treat them as **opt-in frontier, never load-bearing**.

SPECIALIST DEVELOPMENT EXTENSION PROJECTS
| software defined perimeter (SDP) | "invisibility" behind SDP cloak |
| ssh jump server | ...to use with software defined perimeter and dns-over-quic/https/tls (DoQ/DoH - not DoT - bit of a give away!) for better protection for developer work |
| Oblibivious DNS (oDNS) stub resolver | requires a community of users maintaining a distributed network, and a few with dedicated servers to operate the authoritative oDNS servers (obviously, not just one of those!). I am and I am just one sad, lonely guy. BUT if you are interested in developing this with me and can recruit people, would love to do it - and I have started the process here to build that further |

## Why this stack

- **Base OS: Alpine (armv7) on the 2B; Chainguard Wolfi on aarch64/x86.** Wolfi has no 32-bit ARM
  target, so the legacy tier stays Alpine; 64-bit boxes get the hardened, minimal Wolfi bases.
- **AdGuard Home, not Pi-hole.** GPLv3, no mandatory phone-home, entire state in one committed
  YAML → the cleanest "reproducible in git" story.
- **Containerised with Podman**, digest-pinned (`.env` / `images.lock`) for a reproducible,
  stabilised environment.
- **CUPS runs on the host** — mDNS/AirPrint + USB passthrough are far less fiddly that way.

## Quick start (Core, on the 2B — no extra hardware)

```sh
cp .env.example .env        # edit TZ, LAN_SUBNET, SSH_PORT (NOT the image digest — see below)
sudo sh host/setup.sh       # Alpine: installs podman, cups, avahi, nftables; runs bin/up.sh
# open http://<pi-ip>:3000  → AdGuard first-run wizard, then commit the config
```

The container base is **digest-pinned** in `images.lock` (committed, multi-arch incl. `linux/arm/v7`),
so it runs on a 2B as-is. Launch is always via `bin/up.sh`, which refuses any un-pinned tag.
Full walkthrough and caveats: **`docs/INSTALL.md`**.

## Updating the base (maintainer-gated)

Upgrades are never silent — detection and application are separate steps:

```sh
sh bin/bump.sh --check      # report only: is a newer release out? (exit 10 = yes)
sh bin/bump.sh --verify     # assert the current pin still matches source (drift check)
sh bin/bump.sh --apply      # re-resolve digest from source + repin AFTER you confirm
git commit -am 'outpost: bump AdGuard Home'   # review the images.lock diff, then commit
```

A weekly **report-only canary** (`bin/canary.sh`, via crond — no GitHub Actions) runs
`--check`/`--verify` and notifies if there's something to decide. It never applies anything.
Policy: **`.github/GOVERNANCE.md`** § "Policy 1".

## Project docs

**Step-by-step help lives on the [wiki](https://github.com/hyperpolymath/core-network-outpost/wiki)**,
organised by audience (users · IndieWebbers · maintainers). The repo holds the reference material:

- **[`docs/EXPLAINME.adoc`](./docs/EXPLAINME.adoc)** — what this is, in plain terms. Start here.
- **[`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)** — component map, the two-box topology, and the honest fragility read.
- **[`docs/HARDWARE.md`](./docs/HARDWARE.md)** — right-size to your line (device compatibility catalogue).
- **[`docs/LEGACY-DEVICES.adoc`](./docs/LEGACY-DEVICES.adoc)** — Pi 2B / old-board limits, honestly.
- **[`docs/PROFILES.md`](./docs/PROFILES.md)** — `legacy-sbc` vs `modern`, release channels, feature scope.
- **[`docs/HARDENING.md`](./docs/HARDENING.md)** — security + observability architecture (§0–10).
- **[`docs/DESIGN-LOG.adoc`](./docs/DESIGN-LOG.adoc)** — every decision and *why*, plus what we learned.
- **[`docs/MAIL-AUTH.md`](./docs/MAIL-AUTH.md)** — the optional mail-DNS module (not an MTA).
- **[`docs/INSTALL.md`](./docs/INSTALL.md)** — install + caveats. **[`docs/DOCS-MAP.adoc`](./docs/DOCS-MAP.adoc)** — where everything lives.
- **`roadmap/`** — future sketches (not built).
- **`.github/GOVERNANCE.md`**, **`.github/MAINTAINERS.md`**, **`.github/CODEOWNERS`** — who decides, who reviews.

## Licensing

Code/config: **MPL-2.0**. Docs (`.md`/`.adoc`): **CC-BY-SA-4.0**. (Estate convention.)
