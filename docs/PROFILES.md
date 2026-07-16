<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Build profiles — `legacy-sbc` vs `modern`

Two profiles so the estate fits both a 1 GB armv7 relic and a modern box without
either compromising the other. One shared git repo; the profile toggles which
components and bases are used. This is the clean resolution of "not everything fits
the 2B" — and it directly serves maintainability (Tier-3).

## `legacy-sbc`  — Pi 2B / armv7 / ≤1 GB / Alpine
The dependable floor. Single-minded, RAM-frugal.
- AdGuard sinkhole · CUPS print · nftables firewall · Dynu DDNS
- chrony (+ DS3231 RTC) · link-quality monitor (**exporter only — no local TSDB**)
- read-only root (Alpine `lbu`-native) · watchdog (busybox) · OpenSSH bastion behind SPA
- Base: **Alpine armv7**
- **Excluded by hardware:** Wolfi (no armv7), ClamAV (RAM), CAKE (not inline),
  SELinux-enforcing.

## `modern`  — Pi 4/5 aarch64 · x86 N100 · …
Everything in `legacy-sbc`, plus the heavier layers:
- **Chainguard Wolfi** bases on Podman
- **CAKE/SQM** shaping (N100, inline)
- **ClamAV** (scheduled `clamscan`, defined ingest path)
- **SELinux-enforcing** (SELinux host) *or* AppArmor
- **VictoriaMetrics/Prometheus** store can live here (never on the 2B)
- Base: **Wolfi / aarch64** or **x86**

## Design principles that cut across both
- **IPv6-first** where the ISP provides it (see docs/HARDENING.md) — but default-deny must
  treat v6 as first-class, since there's no NAT to hide behind.
- The 2B keeps working forever as the sinkhole even after a `modern` box takes
  routing + shaping — the roadmap's "suggested split".

## Deployment topology — two boxes, split by *criticality + exposure*
The right answer is **don't build one juggernaut.** A monolith is worse on *both* axes you
care about: more likely to be *down* (complex = fragile) and a *crown-jewels target*
(compromise it once and you get DNS + keys + mail + dev access together). Split by **what must
stay up and dark** vs **what's exposed and optional** — not by feature category:

- **Box A — Core (minimal, dark, always-on):** AdGuard sinkhole · nftables · chrony/NTP ·
  SDP/SPA gate · DDNS · link-quality monitor. Holds the keys, exposes almost nothing, must never
  go down. Make *this* one bulletproof (read-only root, watchdog). Fits a `legacy-sbc` 2B.
- **Box B — Frontier (exposed, optional, non-critical):** setup/autoconfig UI · mail-auth +
  DMARC dashboard · IndieWeb/promo · developer bastion · ODoH pool node. Higher attack surface,
  changes often — but its **failure or compromise cannot reach Box A**. Fits a `modern` N100.

What this buys: **blast-radius reduction** (breached frontier ≠ breached core),
**failure-domain isolation** (setup box down ≠ network down), and **separate-the-valuable-from-
the-exposed** (the crown jewels aren't on the attackable box).

Two orthogonal axes: **capability** (`legacy-sbc` / `modern`) × **role** (core / frontier); a
deployment picks both. **Solo-maintainer ceiling: two boxes, maybe three** — more single-minded
boxes keep helping security, but each is another thing to patch; past ~three you lose on
maintainability (Tier 3). Don't split so finely you can't keep them all current.

## Release channels — `main` = Core only, `alpha` = + Frontier
Sharpens the Core/Frontier split into *what people actually install*:
- **`main` / stable = Core only** — sinkhole · firewall · time · DDNS · monitor · (shaping if
  gateway) · **Ddraig SSG generator**. No Frontier. Smallest attack surface, least to footgun,
  what most people run.
- **`alpha` = Core + Frontier** — mail-auth · bastion · ODoH node · the **full Prometheus/Loki/
  Phoenix** stack. Exciting for developers; explicitly opt-in and unstable.

This is the release-level expression of "keep the crown jewels boring; quarantine the exciting stuff."
- **SSG in `main` is fine** — Ddraig is a *build-time generator* (no runtime surface → *not* the
  Bandit dynamic risk). Keep *serving* **off-box** (Cloudflare Pages); `main` just holds the
  generator + content.
- **Observability split:** the heavy TSDB stack is **`alpha`-only**. Regular (`main`) users get
  observability **free from AdGuard Home's own dashboard** (query log, blocked/allowed, top
  domains/clients) — "use what AdGuard already outputs". Optional: a **tiny status TUI/CLI** (reuse
  the setup TUI) reading AdGuard's stats API + the link-quality monitor for a one-glance health
  readout — no TSDB.
- **IaC = OpenTofu, not Terraform.** HashiCorp relicensed Terraform to **BUSL 1.1** (source-available,
  anti-compete, *not* OSI open-source) in 2023. Use **OpenTofu** (MPL-2.0, Linux-Foundation fork,
  drop-in — same HCL + Cloudflare provider); `cloudflare-dns-terraform` works with it unchanged.
- **Don't add a third (`beta`) channel — use opt-in *modules* instead.** SPA/SDP and Prometheus are
  unrelated features with different risk (lockout vs weight); a separate release train **triples the
  solo maintenance cost**. Ship them as **modules, off by default**, that *mature in `alpha`* then
  *graduate to `main` (still default-off)* once stable. **Channels = stability; modules = features** —
  keep the axes separate. Most users need neither, so default-off opt-in is the right shape.

## Implementation & packaging
This is **mostly declarative config + small shell glue**, *not* a big application:
chrony, nftables, AdGuard Home, Podman/compose, Prometheus/Loki, systemd/OpenRC units.
Deliberate — least bespoke code = most dependable + maintainable (Tiers 1 & 3).
- **No custom Rust/Go app is needed for the core.** If a bespoke daemon is ever
  genuinely required (a tighter SPA responder, a metrics exporter), write it as a **small
  static Rust or Go binary** in a **Wolfi/distroless** image — memory-safe, single-binary,
  tiny attack surface. **Even better for a *protocol* daemon (SPA responder, ODoH stub, the
  bastion's QUIC transport): build on a `proven-servers` formally-verified Idris 2 core via its
  C/Zig FFI** — machine-checked correctness is dependability-first (Tier 1) taken to its limit,
  and stronger than a hand-rolled Rust daemon. But prefer wiring existing tools over any new code.
- **Native integration (Elixir):** never raw **NIFs** (a fault kills the whole BEAM VM — Tier-1
  risk). For pure numeric/byte-buffer compute (crypto, parsing, compression) use the user's
  **SNIFs** (`hyper-repos/snifs`) — WASM-sandboxed via `wasmtime`/`wasmex`, so a guest fault is a
  catchable `{:error, _}` and the VM survives. For *stateful / protocol / I/O* integration
  (proven-servers connectors) use **Ports / out-of-process**. (User: "snifs not nifs".)
- **HTTP server = Bandit, kept but *hardened*** (pure Elixir, Phoenix's default;
  `network-dashboard` already uses `Bandit.PhoenixAdapter`). Purpose: **mainly IndieWeb** — to
  encourage an independent web. Serve *dynamic* surfaces (LiveView dashboard, setup forms, DMARC
  live view) via Phoenix; serve *static* content via **`Plug.Static`** (file-serving only, no
  dynamic execution).
  - **Enforce the guard rails in config — don't just warn.** HTTPS-only + HSTS, a strict **CSP**
    that blocks plugins/inline scripts + `block-all-mixed-content` / `upgrade-insecure-requests`,
    least-privilege, read-only content dir. *This* is what actually stops the "I'll add Flash +
    mixed content" footgun — an at-your-own-risk note doesn't. Documented as a hardened IndieWeb
    server; other uses **not recommended, at your own risk**.
- **SSG = `ddraig-ssg` as the blessed/showcase default.** Reasons that *override* the usual
  "prefer a mainstream SSG" advice here: (1) **no added language** — it's Idris 2, already
  load-bearing (proven-servers ABIs); (2) **WCAG 2.2 AAA-capable + dependently-typed** — a real
  accessibility/correctness differentiator mainstream SSGs don't lead with; (3) it
  **dogfoods/promotes the ecosystem**. Newcomer barrier is *low*: authoring is just
  Markdown + front-matter + HTML templates — only *extending the generator* needs Idris 2. Keep a
  documented **static-output contract** so anyone who prefers Hugo/Astro isn't locked out. A handful
  of pages → hand-written/markdown still beats any SSG.
- **Don't conflate the web server with the DNS *zone* server.** Bandit serves HTTP (incl. the single
  static MTA-STS policy file). The DNS zone is served by a DNS server or — better — **published via
  `cloudflare-dns-terraform`** (Cloudflare serves it authoritatively + owns DNSSEC), never Bandit.
- Caddy only for a polyglot edge proxy in front of non-Elixir services.
- **Setup = a small TUI / CLI, NOT a web form.** This removes an entire dynamic-web attack surface
  (the earlier "setup UI" worry, and one of the fragile extra interfaces). A **CLI core**
  (scriptable, reproducible) that **emits config-as-code — git-committable, no hidden state** — with
  an optional **TUI front-end** for human-easy one-time setup. Idris 2 (coherent) or Elixir; it has
  **no listening socket**, so zero network surface. The same tool gains an **`export diagnostics`
  command**: a one-shot, **read-only, LLM-ready support bundle** — live state in your `.a2ml`/STATE
  format + this deployment's **topology** + **secret-sanitised** logs + config-as-code + the relevant
  **Bustfile/doc pages** + a suggested prompt — written to a **local file the user chooses to share**
  (no auto-upload, no on-box LLM). It's the runtime instance of your `0-AI-MANIFEST.a2ml` legibility
  work; the reasoning happens on whatever tool the user brings. Core-safe → can ship in `main`.
- The existing estate is polyglot: `network-dashboard` is **Elixir/Phoenix**, the outpost
  is **shell + Podman/Alpine**. Nothing here is Rust today.
- **Packaging:** Chainguard **Wolfi** on Podman for **aarch64/x86** (`modern`); **Alpine
  armv7** for the Pi 2B (`legacy-sbc`) — Wolfi has no 32-bit ARM target.

## Feature scope — appealing *without* diluting it
Press/developer appeal comes from being **focused and novel**, not feature-maximal — the
"three honest jobs, refuses a fourth" ethos *is* the story (a reproducible, dark-by-default
network estate that **can't be shut down** like eBlocker / Bitdefender BOX).
- **Flagship differentiators — build these well:** the **pooled oblivious-DNS (ODoH) mesh**
  (novel, privacy-forward, genuinely press-worthy) and the **dark SSH bastion + SDP** (the
  developer hook — and cheap, since SSH is low-bandwidth). These two *are* "the couple of bits".
- **Optional, isolated modules (opt-in, off by default, never touch the core):** the promo
  surface; an **IndieWeb site** if wanted — but that's a *different product category* (personal
  web host; you already run **Bandit**, so serve it via Phoenix/Bandit + `site_encrypt` for ACME, not Caddy), so keep it a **separate container/project**,
  not core.
- **Out of scope for the dependable core:** an **embedded full IPFS node** (heavy, chatty,
  attack-surface — Brave itself *retreated* from bundling one). For integrity / "assurance of
  connection" you already have **content-addressing via digest-pinning**; extend it with
  **signed releases (cosign/sigstore)** — same assurance, far lighter. IPFS only as an optional
  Tier-4 *gateway-fetch*, never an always-on daemon. Also out: an IoT hub.

### Evaluated & declined (deliberate minimalism — dependability + proportionality)
- **External cache (Redis / DragonflyDB):** no workload for it — AdGuard caches DNS
  *in-process*, the Phoenix dashboard uses BEAM **ETS**. A Redis-class datastore adds RAM
  + a moving part for zero gain (and is a non-starter on the 1 GB 2B). The real speed levers
  are **AdGuard's built-in cache tuning** + **CAKE** for latency — not a datastore. (CNCF
  Dragonfly *image-distribution* only matters if a pool P2P-distributes images — Tier-4 at most.)
- **SpamAssassin / any mail filter:** email-only, needs an MTA you explicitly don't want. It
  does **not** share AdGuard's blocklist (email IP/URI RBLs ≠ DNS domain sinkhole), and its
  DNSBL lookups often break through public resolvers. AdGuard already blocks malware/phishing
  *domains* network-wide — the right layer for this box.
- **Extra datastores (LMDB / Postgres / Redis-class):** no relational or KV workload today —
  metrics live in Prometheus/Loki, live state in ETS; `network-dashboard` uses **no database**
  (hence **no Ecto** — by design, not oversight). LMDB is *proportionate* (embedded, no daemon)
  unlike Dragonfly — but in Elixir it needs a **NIF**, reintroducing the crash-the-VM risk. If
  persistence is ever needed, use **BEAM-native (CubDB/DETS/Mnesia)** or **Ecto + SQLite**
  (`ecto_sqlite3`), not LMDB-via-NIF or a Postgres server. LMDB only for a *non-BEAM* component
  (a proven-servers Zig/C connector), out-of-process.
- **On-device LLM (autoconfig / auto-repair):** don't **embed** one. Local LLM = the one thing an N100
  *can't* do well while also being the network (RAM/CPU contention), and a model small enough to run is
  too weak to trust for config that must be exactly right; cloud LLM = privacy leak. A **write-capable**
  LLM on a security box is **prompt-injectable via the logs it reads** and non-deterministic — against
  the whole dependability-first design. **Instead: make the box *legible* to whatever LLM the user
  brings** (structured status/logs, the config-as-code repo, Bustfile recipes, the existing
  `0-AI-MANIFEST.a2ml` / `llm-warmup` files). **Read-only interpretation/advice = welcome** (human
  applies); **repair/monitoring execution stays deterministic** (Bustfiles/network-ambulance +
  Prometheus alert rules) — an LLM may *author* a recipe, never *execute* on Core unattended.
- See also HARDENING: `endlessh` tarpit, port-rotation, embedded IPFS node — all declined.
