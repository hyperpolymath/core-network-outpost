# core-network-outpost — the wiki

A small, low-power box that quietly makes your home network **faster, safer, and more
private** — and that you can actually understand, rebuild, and repair.

This wiki is the **help**: task-first, organised by who you are. The
[repo](https://github.com/hyperpolymath/core-network-outpost) is the **reference**: what it
is, why it's built this way, and the config that proves it.

> **This wiki is generated from `wiki/` in the main repo.** Edits made here in the web UI
> get overwritten on the next sync — please [open a PR](https://github.com/hyperpolymath/core-network-outpost/pulls)
> against `wiki/` instead. That's deliberate: this is a security appliance, and a wiki page
> is exactly where someone would slip in a malicious `curl … | sh`. Going through review
> means the install instructions are as version-controlled as the code.

---

## 🚦 Read the status banner on every page

This project is **honest about what is and isn't built.** Nothing is worse than following
instructions for software that doesn't exist yet. Every page says where it stands:

| Badge | Means |
|---|---|
| ✅ **Built** | Shipped in the repo. You can run it today. |
| 🧪 **Draft config** | Written and reviewed, **not yet hardware-proven**. Expect to tune it. |
| 📐 **Designed, not built** | Decided and documented. **No code yet.** Read it as a plan. |
| 💭 **Sketch** | A parked idea. Not designed, let alone built. |

Right now: the **Core** (DNS sinkhole, firewall, print, DDNS) is ✅ **built and runs on a
Raspberry Pi 2B today**. The **shaper** is 🧪 **draft config** awaiting an N100. Most
**Frontier** modules are 📐 **designed, not built**. Plan accordingly.

---

## 👤 Users — I just want a better home network

Start here. You need one spare device and no new hardware.

- **[Getting Started](Getting-Started)** — the Core on a spare device, in about an hour ✅
- **[Right-Size Your Box](Right-Size-Your-Box)** — how little hardware you actually need (spoiler: 2.5GbE is *not* a baseline)
- **[Tested Devices](Tested-Devices)** — the community catalogue. Ran it somewhere? Add a row.
- **[Troubleshooting](Troubleshooting)** — symptom-first, when something's wrong
- **[Site Hijacked — Recover, In Order](Site-Hijacked-Recovery)** — incident response for a compromised site
- **[Reputation Hygiene](Reputation-Hygiene)** — staying off blocklists; "never get on" beats "get off"

## 🕸️ IndieWebbers — I want to own my web presence

- **[Make Your Page](IndieWeb-Make-Your-Page)** — accessible by construction, no Node, no npm
- **[Publish It](IndieWeb-Publish)** — Cloudflare Pages: free, fast, likely green-hosted
- **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)** — SPF/DKIM/DMARC without the tears
- **[Findable *and* Trusted](IndieWeb-Findable-And-Trusted)** — `security.txt`, sitemaps, Search Console

## 🛠️ Developers / platform maintainers

- **[Estate Architecture](Estate-Architecture)** — two boxes, split by criticality + exposure; channels vs modules
- **[Frontier Modules](Frontier-Modules)** — SPA/SDP, the ODoH pool, the bastion, full observability
- **[Recovery as Code](Recovery-As-Code)** — Bustfiles + `network-ambulance`
- **[LLM Legibility](LLM-Legibility)** — make the box readable by *your* LLM; never give it the keys
- **[Contributing & Governance](Contributing-And-Governance)** — the pin/bump flow, OpenSSF, who decides

---

## The one-paragraph "why"

Your home network runs on a box your ISP handed you: you don't control it, can't inspect it,
can't fix it. Commercial alternatives (eBlocker, Bitdefender BOX) tried to help, then **shut
down and left their buyers stranded** — a box you can't rebuild is a box that can be taken
away from you. This is the opposite: boring, reproducible, config-as-code in git, pinned and
verifiable, split into two single-minded boxes so it never becomes a juggernaut that's always
down or the focus of every attack.

**Priority order, in this order, on purpose:**

1. **Dependability** — if security isn't dependable it's *dangerous*; if the box isn't
   dependable you'll ditch it and lose every benefit.
2. **Security** — but only the kind that doesn't cost dependability.
3. **Maintainability & accessibility.**
4. Everything else — extra features, performance.

Longer version: [`docs/EXPLAINME.adoc`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/EXPLAINME.adoc).
Every decision and *why*: [`docs/DESIGN-LOG.adoc`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/DESIGN-LOG.adoc).

## A word on who maintains this

One person, unpaid, sharing it for free. That's not an excuse — it's a **design input**. It's
why the estate refuses features it can't maintain, why the exciting parts are quarantined from
the parts that must never break, and why you'll see "declined" as often as "planned". If
something here is wrong or broken, saying so is a contribution.
