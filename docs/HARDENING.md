<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Security & observability architecture — core-network-outpost (draft / WIP)

Posture: **default-deny everywhere**, services **dark until authorized**,
openings **ephemeral + transaction-scoped**, base images **minimal**, access
**mandatory-controlled**, everything **observable** so it can be tested.

**Priority order (the project's optimisation function):**
1. **Dependability** — if security isn't dependable it's *dangerous*, and if the box
   isn't dependable it gets ditched and the user loses every benefit.
2. **Security** — but only the kind that doesn't cost dependability.
3. **Maintainability & accessibility.**
4. Everything else — extra functions, performance.

Each item is tagged **[dep+]** (raises reliability), **[dep~]** (neutral), or
**[dep-risk]** (buys security at some reliability cost → opt-in, prove-first, always
keep a break-glass path). Nothing **[dep-risk]** ships enforcing-by-default.

**IPv6-first** where the ISP provides it: global addressability removes NAT
hole-punching for the mesh (Tier-4) and is the future — but it also removes NAT's
*accidental* firewall, so **default-deny must cover v6 as first-class, not an
afterthought** (the shaper's `nftables.nft` currently defers v6 — that gets elevated).
⚠️ Verify Virgin actually hands you **native IPv6 / DHCPv6-PD** first — historically
patchy on their network.

**Can the box add IPv6 when the router can't?** Only if it's the **inline gateway** — then
it does **DHCPv6-PD** to Virgin itself and **dnsmasq/radvd** hands the delegated prefix to
the LAN (RA + DHCPv6), native, independent of the old router. A **sidecar behind a v6-blind
router that holds the WAN cannot** — prefix delegation happens at the WAN terminator it
can't reach around. Fallback there: a **6in4 tunnel** (e.g. HE.net) on the box → dnsmasq to
the LAN. That works, but it's a tunnel — a `[dep-risk]` dependency that must degrade
gracefully and **never break IPv4**.

## Be honest about the tiers — not everything fits the 2B

| Capability | Pi 2B (armv7, 1 GB) | Pi 4/5 (aarch64) | N100 (x86) |
|---|---|---|---|
| Chainguard **Wolfi** base | ❌ no armv7 → Alpine | ✅ | ✅ |
| **SELinux** enforcing | ⚠️ not on Alpine | ✅ (SELinux host) | ✅ |
| **ClamAV** (`clamd`) | ❌ DB needs ~1–2 GB RAM | ✅ | ✅ |
| **SPA / fwknop** dark firewall | ✅ | ✅ | ✅ |
| **CAKE** shaping | ❌ not inline | ⚠️ < 1 Gb | ✅ |
| node_exporter + monitor | ✅ | ✅ | ✅ |

Rule of thumb: the **2B stays single-minded** (sinkhole + print + firewall +
DDNS + monitor). The heavy hardening lands on the **aarch64/N100 tier**. Don't
crush a 1 GB box trying to make it a fortress.

## 0. Time (chrony) — foundational, sits *under* both dependability and security **[dep+]**
Almost everything silently depends on correct time: TLS/cert validation, **DNSSEC in
AdGuard**, log correlation (Prometheus/Loki), **SPA replay windows**, DDNS, cron, the
bump/canary schedule. Bad time breaks security *and* dependability quietly — so yes,
an NTP setup is worthwhile, and it ranks near the **foundation**, not as an extra.

- **Use `chrony`** (not ntpd/timesyncd/**NTPsec**): fast convergence, survives
  intermittent links, no-RTC-friendly — the exact Pi-appliance case. **NTS** is the
  security layer (already on via `nts`), so you get NTPsec's headline benefit without
  its always-on/reference-clock orientation or patchy Alpine-armv7 packaging. [dep+ & maint]
- **Cross-check multiple independent sources** (your instinct, done right): several
  NTS upstreams (`time.cloudflare.com`, Netnod) + the pool + **the router as a
  low-trust sanity source**. chrony's selection algorithm rejects "falsetickers", so
  one lying clock (incl. a flaky Virgin Hub) can't drag you off. Don't *trust* the
  router as primary — consumer routers are mediocre time sources; use it as a
  cross-check and **export the offset (your disciplined clock − router) to
  Prometheus/Loki** so drift is visible.
- **Serve time to the LAN** (`allow <LAN/mgmt subnet>`, bound LAN-only per §5a): the
  outpost becomes the estate's local, low-latency, authenticated NTP server — the
  network keeps a coherent clock even if internet NTP drops. Whole-estate dep win.
- **RTC by tier:** the **Pi 2B has no battery-backed clock** — it forgets time on
  every power-off (a real appliance bug). Add a **£3 DS3231 RTC** (I²C), or at minimum
  `fake-hwclock` so it never jumps *backwards*. The **N100 has an RTC** — fine as-is.
- **Observe it:** chrony offset/stratum/source-reachability → dashboard. Time health
  becomes a first-class signal.

## 1. Ephemeral, transaction-gated firewall + "disappearing" (SDP)
- **Full lockdown:** `nftables` default-drop on input & forward.
- **Dark services via Single Packet Authorization (SPA):** `fwknop` (mature) or
  nftables-native — a valid signed knock inserts a rule into a **timeout set**
  (`nft add element … timeout 30s`) that auto-expires. Port scanners see nothing.
  This *is* your "ephemeral transaction-gated firewall, others on full lockdown."
- **SDP note — you may already have it:** `network-dashboard` shows **Twingate**,
  which is a ZTNA/SDP — services reachable only through an authenticated connector,
  zero inbound ports. Sensible split: **Twingate for service access, fwknop for
  break-glass SSH** to the box itself. (Decision A.)
- **SSH tarpits (`endlessh`) and regular port-rotation — skip both.** A tarpit wastes
  only the dumbest bots and protects nothing; rotating the SSH port is
  security-by-obscurity plus a real lockout risk. **SPA already beats both — a dark
  port has *nothing* to tarpit or scan.** Key-only auth + SPA + fail2ban/CrowdSec are
  the controls that matter; `endlessh` is a Tier-4 novelty, not a pillar.

## 2. Minimal base — Chainguard Wolfi on Podman
- On aarch64/x86, switch container bases to `cgr.dev/chainguard/*`, keep the
  **digest-pin + maintainer-gated bump** flow you already have. Low-CVE, distroless-ish.
- The **2B stays Alpine** (armv7 has no Wolfi). Document the split; the compose/
  config is portable so only `*_IMAGE` digests change.

## 3. Mandatory access control — SELinux (with a real caveat)
- SELinux is a **host** decision, and it does **not** pair with Alpine or a bare
  Wolfi host. It's clean on **Fedora IoT** or **Debian + selinux-basics**.
- **Decision B:** either (a) run a **SELinux-enforcing host** on the N100 (matches
  the permissive SELinux you already set in the WSL kernel) with Podman `:Z` labels
  + confined containers; or (b) use **AppArmor** — lighter, already default on
  Debian — if you don't specifically need SELinux. Pick one; don't run both.

## 4. ClamAV — **`modern` profile only** (never on the 2B)
> **Decision (yours):** include it to protect the estate — but in the `modern` build
> only, as a **scheduled `clamscan`** (not resident `clamd`), ingest path = the **CUPS
> print spool** + any download/share dir. `legacy-sbc` skips it (RAM).

**Lighter, more appliance-appropriate alternatives (reconsider whether you need file-AV at all):**
on a dark appliance you care more about *"has the box been tampered with"* than scanning arbitrary
files —
- **AIDE** (file-integrity monitoring) + **rkhunter/chkrootkit** (rootkit detection): far lighter than
  ClamAV's 1–2 GB resident DB, detect *compromise* rather than scan downloads. **Recommended default.**
- **read-only root + digest-pinned images** (already planned) mean malware can't persist, and
  **AdGuard already blocks malware/phishing *domains*** network-wide (delivery-prevention).
- Only with a *real file ingest path* (share/print-spool/downloads): **YARA** (rules-based, light,
  on-demand) or scheduled `clamscan`. Resident `clamd` stays off by default.
  - **VirusTotal API** is *cloud* multi-engine lookup — distinct from YARA (which is *local* rules
    from the same team). Free tier: **4 req/min · 500/day · ~15.5K/month · non-commercial only**.
    **Opt-in, bring-your-own-key, off by default**: it sends file hashes to a Google-owned third
    party (against the no-phone-home ethos), the non-commercial terms would bite business users, and
    it needs internet + a per-user key. **Prefer local YARA** (private, offline, unlimited). See docs/PROFILES.md.

- `clamd`'s signature DB is ~1–2 GB resident → **infeasible on the 1 GB 2B**.
- **Decision C — what would it even scan?** AV on a pure DNS/router node with no
  ingest path is dead weight. Only worth it if there's a real target: the **CUPS
  print spool**, a file share, or a downloads dir. If yes, prefer scheduled
  `clamscan` (cron) over resident `clamd` to save RAM; run it on aarch64/N100.

## 5. Observability — yes; wire, don't build
Substrate already exists: **network-dashboard** (Phoenix LiveView + Prometheus +
Loki) + `link-quality-monitor.sh`. Add only glue:
- **node_exporter** on each box (host metrics).
- **textfile collector emitting `tc -s qdisc`** drops/backlog/latency → the CAKE
  before/after tuning story (this is the "load of testing" you flagged).
- **link-quality** jitter/ping/loss → the ALARP "for all time" panel (Task #5).
- **Loki** streams: nftables drops, SPA/fwknop auth events, SELinux/AppArmor
  denials, ClamAV hits.

Not a new platform — ~a day of wiring. And since shaping is measure→adjust→measure,
this *is* the test harness, not an extra.

### How heavy? (Prometheus, or lighter)
The weight isn't the exporter — it's *where the time-series DB lives*.
- **Never on the 2B.** Local TSDB = constant SD-card writes (card death) + RAM you
  don't have. The 2B runs a **~20 MB node_exporter** only and keeps nothing.
- **Prometheus server feels heavy?** Swap it for **VictoriaMetrics** — single
  binary, Prometheus-compatible scrape + PromQL, a fraction of the RAM/disk;
  network-dashboard keeps working unchanged.
- **Want zero assembly?** **Netdata** — near-zero config, auto-discovers, streams
  Pi→parent, great default dashboards. Trade-off: its own world, partly duplicating
  the Phoenix dashboard.
- **Pick:** Prometheus/Loki model, exporters-only on boxes, VictoriaMetrics as the
  store once the 2B is the constraint.

## 6. Dependability-first hardening (do these *before* the security-max items) **[dep+]**
> **Shippable configs for this section live in `dependability/`** — `chrony.conf`,
> `adguard-healthcheck.{sh,service,timer}`, `watchdog-systemd.conf`, `readonly-root.md`.
> All run on the current 2B today; each carries a validate-before-apply command.

These raise reliability *and* usually security — the sweet spot, so they come first:
- **Read-only root + tmpfs/overlay for writable paths.** Kills the #1 Pi failure
  (SD-card write death) *and* gives an immutable base. Highest-value single change.
- **Hardware watchdog** (`RuntimeWatchdogSec`) — auto-reboot a hung box. Essential for
  an unattended appliance.
- **Graceful DNS degradation (a real SPOF).** If the AdGuard container dies, does the
  whole house lose DNS? Ship a fallback (router/secondary resolver) so a crashed
  sinkhole means "ads come back", not "internet down". *The* key dep item for a DNS box.
- **Validate config before apply** — `nft -c -f`, `chronyd -p`, compose lint. A bad
  config must never be able to take the box down. (Caught the broken firewall line above.)
- **Healthchecks + bounded auto-restart** (Podman healthcheck, `Restart=on-failure`)
  and **snapshot/rollback on a bad bump** (your flow is pinned+gated; add a revert).
- **Bounded logging** (`log2ram`, journald size caps) so disk-full / SD-wear can't brick it.
- **Clean-shutdown / UPS** — unclean power-off = SD corruption; read-only root mitigates,
  a small monitored UPS finishes the job.

**Security items that cost dependability → opt-in, prove-first, keep break-glass [dep-risk]:**
SELinux-**enforcing** (lockout risk — you already run permissive for exactly this reason;
stay permissive/audit until a clean relabel, or use AppArmor); **SPA/fwknop** (a moving
part between you and SSH — always keep a LAN break-glass path); **ClamAV** (OOM risk on
small boxes; skip unless a real ingest path). None ship enforcing-by-default.

## 7. Encryption at rest — encrypt the *secrets*, not a keyless box naively [dep-risk done right]
What's actually secret is small: DDNS creds, SSH/NTS host keys, SPA keys, tokens, and
**AdGuard query logs** (who-asked-what = privacy). Config lives in a *public* git repo — not secret.
- **Don't full-disk-encrypt a headless SBC naively.** LUKS on a keyboard-less box means
  either a passphrase you can't type at boot (**unattended reboot dies — Tier-1 fail**)
  or a key stored on the device (theatre).
- **Do it dependably:** **N100** → LUKS + **TPM2 auto-unlock** (`systemd-cryptenroll`):
  unattended reboot *and* a stolen disk is useless. **Pi (no TPM)** → **network-bound
  unlock (clevis + tang)**: auto-decrypts *only* when it can reach a tang server on your
  LAN, so a stolen device off-network can't; in a two-box estate each tangs for the other.
- **Shrink the surface** so at-rest matters less: read-only root (already planned) leaves
  little writable; keep query logging **off / anonymised / short-retention**; ship logs to
  the central store, don't hoard them on the SD card.

## 8. Firewall: stateful default + stateless pre-drop + SPA pinholes only [dep+/sec]
- **Stateful is the right default** (your `nftables.nft` already is): `established,related
  accept` + `invalid drop` is how default-deny-inbound and NAT work cleanly.
- **Add a thin *stateless* pre-drop at the WAN** for obvious junk (bogons, bad TCP-flag
  combos, fragments) *before* conntrack — protects the **conntrack table from exhaustion**,
  a real DoS vector on an internet-facing box. Not either/or: stateless-junk → stateful-rest
  is edge-router best practice.
- **Pinholes:** **disable ALG/conntrack helpers** (FTP/SIP ALGs auto-open ports from packet
  contents — a classic exploit surface). The *only* dynamic openings should be your
  **SPA-authenticated `nft` timeout-set pinholes** — controlled, authenticated, auto-expiring.

## 9. Own web/DNS surface hardening [dep~/sec]
Admin UIs are already internal-only (§5a); this is defence-in-depth + good citizenship:
- **Security headers** on every web surface via one small reverse proxy: HSTS, strict CSP
  (`frame-ancestors 'none'`), `X-Content-Type-Options: nosniff`, `Referrer-Policy`,
  `Permissions-Policy`.
- **`/.well-known/security.txt`** (RFC 9116) — how to report a vuln.
- **DNS integrity:** DNSSEC-validate upstream (sign your local zone if you serve one); **CAA**
  if it serves TLS; consider **DANE/TLSA**. ("Absolutely protected" isn't a thing — these are
  layers, not a guarantee.)
- **Local names:** **don't AXFR/IXFR from the router** (it usually can't, and a DHCP-lease
  "zone" isn't worth transferring). **Conditionally forward** the local domain (`home.arpa`,
  RFC 8375) to whatever owns DHCP. AXFR/IXFR is right only **between DNS servers you both
  control** — e.g. a pair of outposts — not router→box.

## 10. Lightweight *preventive* security (the SpywareBlaster model) + the real cost [dep+]
SpywareBlaster "walled things up" *preventively* — static denylists, no resident scanner. That model
fits a dark appliance perfectly and is cheap on every axis:
- **AdGuard domain blocklists** (auto-updated) — DNS-*level* blocking: devices never resolve the
  malware host. **NB it is not DPI** — AdGuard *Home* filters by domain, it doesn't inspect payloads
  (that's the *client apps*). The **nftables IP feeds** above are the complement, catching malware
  that uses **hardcoded IPs** (no DNS lookup). Neither is heavy.
- **You are never the only layer** — defence in depth: AdGuard (names) → nftables feeds (IPs) →
  read-only root (persistence) → AIDE/rkhunter (tamper) → the **router's own firewall** → **Cloudflare's
  edge** (for published surfaces) → **endpoint security on users' devices** → (in the pool) **other
  people's nodes**. Each catches what the others miss; none needs to be heavy. Don't reimplement a
  layer you already get for free.
- **nftables IP denylists from auto-updated threat feeds** (FireHOL, Spamhaus DROP) — block known-bad
  IPs at the firewall; just data + a cron refresh, no resident engine.
- **read-only root + digest-pinned images** — immutable base; nothing persists.
- **AIDE + rkhunter** — detect tampering (§4), not scan downloads.
- **Offload public-facing protection to Cloudflare** (free tier: WAF, DDoS, rate-limiting, DNSSEC, TLS)
  for anything you publish there — protection with **zero cost/surface on your box**.

**On "can we do everything?" — you're overestimating the *resource* cost, and would be
*under*estimating the other cost.** An N100 eats all of the above for breakfast — **resources are NOT
the constraint.** What the N100 does *not* fix: (1) **your maintenance time** (solo — every feature is
yours to patch/document/support forever) and (2) **attack surface** (every service is more to exploit).
So curate by *"worth maintaining + exposing"*, not *"can it run"*. Good news: most of the list is
**preventive/data-driven → cheap on both axes**; it's the heavy *active* engines (an MTA +
SpamAssassin/Bayes, resident ClamAV) that cost time + surface for marginal gain — already cut.
**Bayes/SpamAssassin has no home without a mail pipeline you don't want — leave it out.**

## Sequencing for one person (don't big-bang this)
This doc lists a lot. Solo and unpaid, the real failure mode is **burnout, not
insufficient hardening**. Ship in layers; let the roadmap hold the ambition and
keep `main` shippable — the repo's own "three honest jobs, refuses a fourth" ethos,
applied to security too:
1. **Now, on the 2B:** default-deny nftables + link-quality monitor + node_exporter → dashboard. Proves the goal, costs almost nothing.
2. **When the N100 lands:** CAKE shaping + Wolfi bases + VictoriaMetrics store.
3. **Later, only if warranted:** SPA/fwknop, SELinux-enforcing host, ClamAV (iff a real ingest path exists).

## Tier-4 futures (roadmap — must never couple to the dependable core)
Worth building, but only as **optional, isolated modules/forks** — per the priority order:
- **Pooled Oblivious DNS (ODoH).** A network of community outposts acting as ODoH
  relays/targets for each other splits "who is asking" from "what they ask" — genuinely
  better privacy + resilience than a couple of ISP resolvers (the property you intuited).
  **Conditional on the crypto:** ODoH relay-separation + DNSSEC validation, *not*
  plaintext peer-forwarding (a malicious peer could poison/surveil that). Rides your
  existing **ZeroTier** (trusted pool) or ODoH over the public net (oblivious strangers).
- **Bastion-in-mesh.** Each outpost a *dark* SSH/SFTP/SCP jump node. **Reach it over the
  ZeroTier/Twingate overlay you already run** (that IS ZTNA: dark endpoint + NAT
  traversal + encrypted transport — don't hand-roll it). Note: wrapping SSH doesn't make
  its crypto *stronger* (it's already E2E) — it only changes reachability/blending. So an
  **HTTPS/QUIC-on-443 wrap (`sslh` / MASQUE / SSH3) is an OPTIONAL fallback** for networks
  that block SSH, *not* the default. **Avoid DNS-over-QUIC/DoH as a transport:** that's DNS
  *tunnelling* — kbps, high-latency, and a known exfil signature your own sinkhole flags.
  Always: behind SPA + a LAN break-glass path.
- **Showcase / promo surface (developer option, OFF by default).** A demo HTTP surface to
  get people interested — your "risky for running right" instinct is correct, so keep it
  **isolated + opt-in**: a *separate sandboxed container* serving *static* content (never
  the live admin UI), no access to secrets/core, unable to take the appliance down.
  **Safer still: host the promo off-box** (GitHub Pages / a cheap static host) so the
  appliance carries zero promo attack surface. On-box only if you want a self-contained
  "plug in and watch it work" story — and even then, isolated and disabled by default.

Both are **Tier-4 (extra functions)**: if the pool is down or a peer misbehaves, the
house's DNS/print/firewall/time keep working untouched. That isolation is the price of
admission for anything distributed.

## Open decisions (yours)
- **A:** SDP = Twingate (service access) + fwknop (break-glass SSH)? or self-host all of it?
- **B:** SELinux-enforcing host (Fedora IoT / Debian+selinux) **vs** AppArmor on Debian?
- **C:** ClamAV — is there an actual ingest path to scan, or skip it?
