<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# outpost — a network community outpost on a Raspberry Pi

A small, reproducible home-network appliance built for a **Raspberry Pi 2B**
(ARMv7 / 32-bit / 1 GB RAM / 100 Mbit Ethernet / no Wi-Fi).

It does three honest jobs and refuses to pretend to do a fourth:

| Role | What it is | Status on a Pi 2B |
|------|-----------|-------------------|
| 🕳️ **DNS sinkhole** | AdGuard Home, containerised | ✅ ideal fit |
| 🖨️ **Print server** | CUPS + Avahi on the host (wired Pi, serves Wi-Fi clients via the router) | ✅ realistic |
| 🧱 **Host firewall** | `nftables` protecting the box itself | ✅ realistic |
| 🏷️ **Stable name** | Dynamic DNS (dyndns2; Dynu as the example) | ✅ realistic |
| ~~🤖 BoJ MCP server~~ | the estate control plane | ❌ **not on a 2B** — its container base publishes no armv7. See `roadmap/BOJ-ON-OUTPOST.md`. |
| ~~🚧 Inline "hardware firewall"~~ | true edge router between WAN and LAN | ❌ **not on a 2B** — one NIC, on the USB 2.0 bus. See `docs/INSTALL.md` § "Why no inline firewall". |

## Why this stack

- **Base OS: Alpine Linux (armv7).** Wolfi was the first choice but it has **no
  32-bit ARM target** (x86_64 / aarch64 only), so it's impossible on a 2B.
  Alpine has first-class armv7 support; Debian / Raspberry Pi OS is the fallback.
  *If this is actually a Pi 3/4/5 in 64-bit (`uname -m` → `aarch64`), Wolfi is
  back on the table — see `roadmap/`.*
- **AdGuard Home, not Pi-hole.** GPLv3, no mandatory phone-home, and its entire
  state is one committed YAML file → the cleanest "reproducible in git" story.
- **Containerised with Podman**, lighter than Docker on 1 GB RAM. Images are
  **digest-pinned** (`.env`) for a stabilised, reproducible environment.
- **CUPS runs on the host, not in a container** — mDNS/AirPrint + USB passthrough
  are far less fiddly that way on a 2B. Pragmatic split.

## Layout

```
outpost/
├── .env.example              # pin image digests, set TZ + LAN subnet here
├── compose/adguardhome.yaml  # Podman/Docker compose for AdGuard Home (host net)
├── adguardhome/conf/         # committed AdGuard Home config (source of truth)
├── host/
│   ├── setup.sh              # idempotent Alpine bootstrap
│   ├── nftables.nft          # host firewall ruleset
│   ├── cups/cupsd.conf       # network-shared CUPS
│   └── avahi/                # mDNS / AirPrint advertisement
├── docs/INSTALL.md           # step-by-step + the honest caveats
└── roadmap/                  # 🛰️ future sketches (micropatch server, Pi 4 path)
```

## Quick start

```sh
cp .env.example .env        # edit TZ, LAN_SUBNET, SSH_PORT (NOT the image — see below)
sudo sh host/setup.sh       # Alpine: installs podman, cups, avahi, nftables; runs bin/up.sh
# open http://<pi-ip>:3000  → AdGuard first-run wizard, then commit the config
```

The container base is **digest-pinned** in `images.lock` (committed). It already
points at a real multi-arch digest that includes `linux/arm/v7`, so it runs on a
2B as-is. Launch is always via `bin/up.sh`, which refuses any un-pinned tag.

Full walkthrough and caveats: **`docs/INSTALL.md`**.

## Updating the base (maintainer-gated)

Upgrades are never silent — detection and application are separate steps:

```sh
sh bin/bump.sh --check      # report only: is a newer release out? (exit 10 = yes)
sh bin/bump.sh --verify     # assert the current pin still matches source (drift check)
sh bin/bump.sh --apply      # re-resolve digest from source + repin AFTER you confirm
git commit -am 'outpost: bump AdGuard Home'   # review the images.lock diff, then commit
```

A weekly **report-only canary** (`bin/canary.sh`, installed on the Pi via crond —
no GitHub Actions) runs `--check`/`--verify` for you and notifies if there's
something to decide. It never applies anything. See `host/canary/README.md`.

Policy and rationale: **`.github/GOVERNANCE.md`** § "Policy 1".

## Project docs

- **`ARCHITECTURE.md`** — component map + the pin/bump design (read this to change things).
- **`.github/GOVERNANCE.md`**, **`.github/MAINTAINERS.md`**, **`.github/CODEOWNERS`** — who decides, who reviews.
- **`docs/INSTALL.md`** — install + the honest caveats.
- **`roadmap/`** — future sketches (micropatch server, Pi 4 path); not built.

## Licensing

Code/config: **MPL-2.0**. Docs (`.md`): **CC-BY-SA-4.0**. (Estate convention.)
