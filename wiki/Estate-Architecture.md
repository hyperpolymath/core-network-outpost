# Estate Architecture

> ✅ **Documented and decided.** The Core is built; the shaper is 🧪 draft config; most
> Frontier modules are 📐 designed. Full reference:
> [`docs/ARCHITECTURE.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/ARCHITECTURE.md)
> · [`docs/PROFILES.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/PROFILES.md)
> · [`docs/DESIGN-LOG.adoc`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/DESIGN-LOG.adoc)

**The central idea: don't build one juggernaut.** A monolith is worse on *both* axes that
matter — more likely to be **down** (complex = fragile), and a **crown-jewels target**
(compromise it once, you get DNS + keys + mail + dev access together).

---

## The split: criticality + exposure

**Split by what must stay up and dark vs what's exposed and optional** — *not* by feature
category. That distinction is the whole design.

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
   │  setup TUI · mail-auth │  │ DNS sinkhole     │
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

| | **Core** | **Frontier** |
|---|---|---|
| **Ethos** | Boring, dark, always-on | Exciting, exposed, optional |
| **Holds** | The keys | Nothing precious |
| **Exposes** | Almost nothing | The interesting surface |
| **If it fails** | The house notices | A *feature* is down, not the network |
| **Changes** | Rarely, deliberately | Often |
| **Fits** | A `legacy-sbc` Pi 2B | A `modern` N100 |

**What the split buys, precisely:** blast-radius reduction (breached frontier ≠ breached
core), failure-domain isolation (setup box down ≠ network down), and
separate-the-valuable-from-the-exposed (the crown jewels aren't on the attackable box).

> **The complexity becomes *elective*.** That's the move. The "juggernaut / always-down /
> attack-magnet" fear dissolves not because the system got simpler, but because the scary
> parts are now optional and quarantined. You can run *only* Core forever and lose nothing
> that matters.

## The honest fragility read

Not reassuring, on purpose:

| Component | Risk | Why |
|---|---|---|
| 🟢 **Off-box** (Cloudflare/Pages) | Near-zero | Someone else runs it. **Best call in the design.** |
| 🟢 **Core as a *sidecar*** | Low | Boring, mature, single-purpose daemons + read-only root + watchdog. Genuinely safe. |
| 🔴 **Core as the *inline router*** | **This is the real fragility** | It's a single point of failure for **all connectivity**. Hang or misconfigure it and the whole house loses internet — not just ads. |
| 🟡 **Frontier** | Medium complexity, *isolated* | Its failure is a feature-outage, never a network-outage. Real cost is **maintenance time**, not fragility. |
| 🟡 **Extra interfaces** | Each NIC/overlay = surface + a failure mode | Minimise on Core; concentrate on Frontier where failure is contained. |

### You cannot make an in-path router "inherently safe"

It's *in the path*. That's not a solvable problem — it's the definition. You make it
**fail-safe** instead, three ways, and all three are non-negotiable:

1. **Fail-open** — if CAKE/nftables/the box dies, traffic **passes** (unshaped, unfiltered).
   Never blocked. A shaper fault must degrade to "no shaping", never to "no internet".
2. **Watchdog** — auto-reboot a hang. Unattended appliances hang.
3. **Strippable** — pull it out, Hub back in, ~60 seconds. **A physical bypass path always
   exists.**

**Those three — not "it never fails" — are the answer.** Anything that promises the latter is
lying.

## Two orthogonal axes

Don't conflate these. A deployment picks one from each column:

| **Capability** | **Role** |
|---|---|
| `legacy-sbc` — Pi 2B / armv7 / ≤1 GB / Alpine | **Core** — dark, critical |
| `modern` — Pi 4/5 aarch64 · x86 N100 / Wolfi | **Frontier** — exposed, optional |

> **The solo-maintainer ceiling is two boxes, maybe three.** More single-minded boxes keep
> helping security — but each is another thing to patch, document, and support **forever**.
> Past ~three you lose on maintainability, which is Tier 3 and outranks the security you
> gained. Don't split so finely you can't keep them all current.

## Channels vs modules — keep the axes separate

**Release channels = stability. Modules = features.** Conflating them is how projects end up
with a maintenance matrix they can't staff.

| Channel | Contains |
|---|---|
| **`main` / stable** | **Core only** — sinkhole · firewall · time · DDNS · monitor · shaping (if gateway) · the Ddraig generator. Smallest surface, least to footgun. **What most people should run.** |
| **`alpha`** | Core **+ Frontier** — mail-auth · bastion · ODoH node · the full Prometheus/Loki/Phoenix stack. Explicitly opt-in and unstable. |

> **There is deliberately no `beta` channel.** SPA/SDP and Prometheus are unrelated features
> with different risks (lockout vs weight) — a separate release train would **triple the solo
> maintenance cost** for no benefit. Ship them as **modules, off by default**, that mature in
> `alpha` and graduate to `main` (still default-off). A channel triples the work; a feature
> flag doesn't.

**Why the SSG is in `main` and that's fine:** Ddraig is a *build-time generator* — no runtime
surface, so it isn't the dynamic-server risk. `main` holds the generator and your content;
*serving* stays **off-box**.

**Observability split:** the heavy TSDB stack is **`alpha`-only**. `main` users get
observability **free from AdGuard Home's own dashboard** (query log, blocked/allowed, top
domains) — use what it already outputs. Never a time-series DB on a 2B: constant SD writes
kill the card.

## Implementation stance

**This is mostly declarative config plus small shell glue — not a big application.** chrony,
nftables, AdGuard Home, Podman/compose, systemd/OpenRC units. That's deliberate: **least
bespoke code = most dependable + maintainable.**

- **No custom Rust/Go app is needed for the core.** If a bespoke daemon ever *is* required,
  write a small static binary in a Wolfi/distroless image. But **prefer wiring existing tools
  over writing any new code.**
- **Setup = a TUI/CLI, not a web form** — no listening socket, therefore zero network
  surface, and it emits config-as-code with no hidden state.
- **Elixir: SNIFs, never raw NIFs.** A NIF fault kills the whole BEAM VM — a Tier-1 risk.
  [SNIFs](https://github.com/hyperpolymath/snifs) are WASM-sandboxed via `wasmtime`/`wasmex`,
  so a guest fault is a catchable `{:error, _}` and the VM survives.
- **HTTP = Bandit** (pure Elixir, Phoenix's default, already in `network-dashboard`) — kept
  and *hardened*, with guard rails **enforced in config** (HTTPS-only, HSTS, strict CSP), not
  documented as a warning. Config walls off the footgun; an "at your own risk" note doesn't.

### Evaluated and declined (deliberate minimalism)

Saying no is most of the design work:

| Declined | Why |
|---|---|
| **Redis / DragonflyDB** | No workload. AdGuard caches DNS in-process; the dashboard uses ETS. Adds RAM + a moving part for zero gain. |
| **LMDB / Postgres / any datastore** | No relational or KV workload. **No Ecto by design, not oversight.** LMDB in Elixir needs a NIF → crash-the-VM risk. |
| **SpamAssassin / any mail filter** | Needs an MTA we explicitly don't want. Doesn't share AdGuard's blocklists (mail RBLs ≠ DNS sinkhole). |
| **Embedded full IPFS node** | Heavy, chatty, attack surface — Brave *retreated* from bundling one. Digest-pinning already gives content-addressed integrity. |
| **On-device LLM** | RAM/CPU contention; small models too weak to trust for exact config; a write-capable LLM on a security box is prompt-injectable **via the logs it reads**. → [LLM Legibility](LLM-Legibility) |
| **SSH tarpits (`endlessh`), port-rotation** | SPA already beats both — **a dark port has nothing to tarpit or scan.** |
| **Terraform** | Relicensed to BUSL 1.1 (source-available, anti-compete, not OSI). Use **OpenTofu**. |

## Where next

- **[Frontier Modules](Frontier-Modules)** — what's out there and what's real
- **[Recovery as Code](Recovery-As-Code)** — the antidote to inline-router fragility
- **[Contributing & Governance](Contributing-And-Governance)** — the pin/bump flow
