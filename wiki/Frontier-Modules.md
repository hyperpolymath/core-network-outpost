# Frontier Modules

> 📐 **Mostly designed, not built. Read this as a plan, not a manual.** Nothing on this page
> except the dashboard has running code in this repo yet. It's here so the direction is
> legible — and so nobody thinks these ship today.

**Frontier is the exposed, optional, non-critical box.** Everything here is **opt-in and off
by default**, and none of it may ever become load-bearing for Core. If the whole Frontier box
catches fire, your DNS, print, firewall, and time keep working — that isolation is the price
of admission for anything on this page.

**Everything here lives in the `alpha` channel.** `main` is Core only.

---

## Status at a glance

| Module | Status | The honest read |
|---|---|---|
| **Observability** (Prometheus/Loki/Phoenix) | 🧪 substrate exists, wiring not done | [`network-dashboard`](https://github.com/hyperpolymath/network-dashboard) is real Phoenix LiveView. Needs exporters + glue — ~a day of wiring, not a build. |
| **Monitoring lock-down** | ✅ **built** | `edge-shaper/monitoring-internal-only.nft` ships **enabled**. |
| **SPA / dark firewall** | 📐 designed | The one genuinely *scary* piece. See below. |
| **SDP / ZTNA** | 📐 decision open | Possibly already solved by Twingate. |
| **Dev bastion** | 📐 designed | Cheap — SSH is low-bandwidth. |
| **Mail-auth + DMARC** | 📐 designed | Spec is written: [`docs/MAIL-AUTH.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/MAIL-AUTH.md) |
| **Pooled ODoH mesh** | 💭 sketch, Tier-4 | Flagship idea; needs a *community*, not just code. |

## Observability — wire, don't build

The substrate already exists. Add glue only:

- **node_exporter** on each box (host metrics)
- **textfile collector emitting `tc -s qdisc`** → drops/backlog/latency, i.e. the CAKE
  before/after story
- **link-quality** jitter/ping/loss → the ALARP "for all time" panel
- **Loki streams**: nftables drops, SPA auth events, SELinux/AppArmor denials

**Since shaping is measure → adjust → measure, this *is* the test harness, not an extra.**
That's why it earns its place despite being the heaviest component here.

**How heavy?** The weight isn't the exporter — it's *where the time-series DB lives*:

- **Never on the 2B.** Local TSDB = constant SD-card writes (card death) + RAM you don't
  have. The 2B runs a ~20 MB node_exporter and keeps nothing.
- **Prometheus feels heavy?** **VictoriaMetrics** — single binary, Prometheus-compatible
  scrape + PromQL, a fraction of the RAM/disk. `network-dashboard` keeps working unchanged.
- **Zero assembly?** **Netdata** — but it's its own world, partly duplicating the dashboard.

### 🔒 No remote access, by construction — this one *is* built

> ✅ **Ships enabled.** `edge-shaper/monitoring-internal-only.nft`.

Observability must **never** be reachable from outside the LAN. Three independent latches,
any one of which suffices:

1. **PRIMARY — bind to the management IP only**, never `0.0.0.0`. *A service that isn't
   listening cannot be reached.*
2. **THIS FILE — a fail-safe pre-chain** that hard-drops monitoring ports from anywhere that
   isn't the management NIC + subnet. Runs at **negative priority, before the main
   firewall**, so a mistake in the main chain **cannot** accidentally expose monitoring.
   `drop` is terminal.
3. **OPTIONAL — an `ether saddr` MAC latch.** Belt and braces.

**A forker who wants remote access must remove it and add their own WireGuard/Twingate
resource — an explicit, deliberate act, never the default.** If someone reaches your
monitoring, they were already inside your network; at that point someone else is responsible
for the breach, and there's still a trusted authority in the zone.

## SPA — the genuinely scary one

> 📐 **Designed, not built.** Opt-in module. Never enforcing by default.

**Single Packet Authorization**: a valid signed knock inserts a rule into an nftables
**timeout set** (`nft add element … timeout 30s`) that auto-expires. Port scanners see
nothing at all.

**Be honest about why this is the scary item:** it's a moving part **between you and SSH**,
and it's the only thing here with a real **lockout** failure mode. It buys security at some
dependability cost — which is exactly backwards from this project's priority order unless
handled carefully.

**So the rules are absolute:**
- **Always keep a LAN break-glass path** that does *not* depend on the SPA layer.
- Opt-in, prove it on a spare box first, never enforcing-by-default.
- Key-only auth + fail2ban/CrowdSec are the controls doing the real work anyway.

> **Skip tarpits and port-rotation.** `endlessh` wastes only the dumbest bots and protects
> nothing; rotating the SSH port is security-by-obscurity plus a lockout risk. **A dark port
> has nothing to tarpit or scan** — SPA already beats both.

## SDP / ZTNA — you may already have it

> 📐 **Decision open (Decision A).**

`network-dashboard` already shows **Twingate** — which *is* a ZTNA/SDP: services reachable
only through an authenticated connector, zero inbound ports.

**The sensible split, and probably the answer:** **Twingate for service access, fwknop for
break-glass SSH** to the box itself. Don't hand-roll what you're already running.

## Dev bastion — a dark jump host

> 📐 **Designed.** The developer hook, and cheap: SSH is low-bandwidth.

Each outpost as a dark SSH/SFTP jump node, reached **over the ZeroTier/Twingate overlay you
already run** — that *is* ZTNA: dark endpoint, NAT traversal, encrypted transport. Don't
rebuild it.

> **Wrapping SSH doesn't make its crypto stronger** — it's already end-to-end. It only
> changes *reachability and blending*. So an HTTPS/QUIC-on-443 wrap (`sslh`/MASQUE/SSH3) is
> an **optional fallback** for networks that block SSH, **not** the default.
>
> ⚠️ **Avoid DNS-over-QUIC/DoH as a transport.** That's DNS *tunnelling*: kbps, high-latency,
> and a known exfiltration signature **your own sinkhole would flag**.

## Pooled ODoH mesh — the flagship, and the hardest

> 💭 **Sketch. Tier-4.** Genuinely novel; genuinely not built.

A network of community outposts acting as **ODoH relays/targets for each other** splits *who
is asking* from *what they ask* — better privacy and resilience than trusting a couple of ISP
resolvers.

- **Conditional on the crypto:** ODoH relay-separation + DNSSEC validation, **not** plaintext
  peer-forwarding — a malicious peer could poison or surveil that.
- **The stub is easy** (`dnscrypt-proxy`). **The relay/pool is the hard part — and it's a
  *community* problem, not a code problem.**

> **The honest caveat, in the maintainer's own words:** this "only really shines with
> knowledgeable people running nodes… I am just one person." Treat it as **opt-in frontier,
> never load-bearing**. If you want to help build it, that's the invitation — it needs people
> more than it needs commits.

## Mail-auth + DMARC

> 📐 **Designed.** [`docs/MAIL-AUTH.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/MAIL-AUTH.md)

**The DNS/policy layer — never an MTA.** The low-risk, high-value half is **ingesting DMARC
aggregate reports into the dashboard**: read-only, safe, and it plugs straight into
Prometheus/Loki/Phoenix. That's where everyone is blind.

Records are published via **OpenTofu → Cloudflare**, never self-served DNS — because an
authoritative nameserver is inherently public, and a botched DNSSEC key-roll takes the
**whole domain** (mail *and* web) offline.

→ User-facing version: **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)**

## Open decisions — yours to make

| | Question |
|---|---|
| **A** | SDP = Twingate (service access) + fwknop (break-glass SSH)? Or self-host all of it? |
| **B** | SELinux-enforcing host (Fedora IoT / Debian+selinux) **or** AppArmor on Debian? Pick one; don't run both. |
| **C** | ClamAV — is there an actual ingest path to scan, or skip it? *(Current lean: skip. **AIDE + rkhunter** detect tampering, which is what actually matters on a dark appliance, at a fraction of ClamAV's 1–2 GB resident DB.)* |

## Sequencing — don't big-bang this

**The real failure mode for a solo unpaid maintainer is burnout, not insufficient hardening.**

1. **Now, on the 2B:** default-deny nftables + link-quality monitor + node_exporter →
   dashboard. Proves the goal, costs almost nothing.
2. **When the N100 lands:** CAKE shaping + Wolfi bases + VictoriaMetrics.
3. **Later, only if warranted:** SPA/fwknop, SELinux-enforcing, ClamAV (only if a real ingest
   path exists).

**An N100 removes the *resource* limit — not the *maintenance-time* or *attack-surface* cost.
Curate by "worth maintaining + exposing", never by "can it run".**
