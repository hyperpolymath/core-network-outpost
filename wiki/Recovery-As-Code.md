# Recovery as Code — Bustfiles + `network-ambulance`

> 📐 **Designed, not built — but you own half the tooling already.** The Bustfile recipes
> below are a **plan**, not shipping code. [`network-ambulance`](https://github.com/hyperpolymath/network-ambulance)
> **is real** (v1.0.0, MPL-2.0) and is the intended engine underneath.

**Why this page exists:** the inline router is the one component with genuinely scary
criticality. It's a single point of failure for *all* connectivity. You can't make an in-path
router "inherently safe" — it's *in the path*. So you make it **fail-safe**, and you make
recovery **boring, scripted, and rehearsed**.

---

## The three latches — non-negotiable for anything inline

| Latch | Means |
|---|---|
| **1. Fail-open** | If CAKE/nftables/the box dies, traffic **passes** — unshaped, unfiltered. Never blocked. **A shaper fault degrades to "no shaping", never to "no internet".** |
| **2. Watchdog** | Auto-reboot a hang. Unattended appliances hang. |
| **3. Strippable** | Pull the box, Hub back in, **~60 seconds**. A physical bypass path always exists. |

**Those three — not "it never fails" — are the answer.** If you only take one thing from this
page: *fail-open is the big one*, and it's the one most easily forgotten because it only
matters on the worst day.

## What's already designed for self-healing

Some of this ships today, in [`dependability/`](https://github.com/hyperpolymath/core-network-outpost/tree/main/dependability):

| Mechanism | Status | Does |
|---|---|---|
| **Watchdog** (`RuntimeWatchdogSec`) | ✅ config shipped | Auto-reboots a hung box |
| **AdGuard healthcheck + restart** | ✅ config shipped | Crashed sinkhole self-heals |
| **Validate-before-apply** | ✅ discipline + commands | A bad config **cannot** take the box down |
| **Read-only root** | ✅ documented | SD-card can't wear out; immutable base |
| **Graceful DNS fallback** | ✅ documented | Dead sinkhole = "ads come back", not "internet down" |
| **Fail-open inline router** | 📐 **the big missing one** | *Add this before going inline.* |

> **Validate before apply, always.** `nft -c -f`, `chronyd -p`, compose lint. This isn't
> theoretical: it **caught a broken firewall line during this project's own development** —
> a rule referencing an nftables set that didn't exist, which would have failed to load. The
> discipline works because it's cheap and mechanical.

## The Bustfiles — recovery-as-code

> 📐 **Planned.** `just`-style rescue recipes. The names below are the intended interface.

The idea: when it's 2am and the internet is down, you should not be *reasoning*. You should be
running a recipe you wrote when you were calm.

| Recipe | Does |
|---|---|
| `just bypass-shaper` | Drop the box out of the WAN path; the Hub takes over |
| `just rescue-dns` | Fall back to Cloudflare/router DNS if AdGuard is down |
| `just rebuild-from-pin` | Redeploy every container from its committed digest |
| `just break-glass` | LAN-only SSH that **ignores the SPA layer** |
| `just verify-all` | Validate every config **before** it can take a box down |

**`network-ambulance` is literally the recovery tool** — diagnose plus safe, reversible repair
with evidence trails, already written. **Point the Bustfiles at it.** That's the autofix
layer, and it's half-built already; this is wiring, not invention.

> **Why `just` and not a pile of shell:** recipes are discoverable (`just --list`),
> self-documenting, and hard to fat-finger at 2am. The alternative is a folder of scripts
> nobody remembers the arguments to.

## `network-ambulance` — the engine

> ✅ **Real and released** (v1.0.0, MPL-2.0).

Its own framing fits this page exactly:

> *"It's 2am, your internet is down, and you have a deadline. You don't need a networking
> degree — you need Network Ambulance."*

It exists because the alternative is searching forums and finding fifty answers, half
outdated and some actively dangerous (`sudo rm -rf /etc/NetworkManager`). It gives **safe,
documented, reversible** repairs with **full evidence trails** — which is precisely the
property you want in a recovery layer for a box that must not stay broken.

**Reversible + evidence-trailed is the load-bearing bit.** An autofix tool that can't be
undone, or can't tell you what it did, is a second outage waiting to happen.

## The reproducible escape hatch

Because everything is config-as-code and digest-pinned, the nuclear option is cheap — and
often *faster than debugging*:

```sh
git status                    # what did I change?
git checkout -- <file>        # undo it
sh bin/up.sh                  # rebuild every container from committed pins
```

**Blank SD card + this repo = the same box back, in an afternoon.** That's the promise the
whole design exists to keep, and it's why there's no vendor who can strand you the way
eBlocker and Bitdefender BOX stranded their buyers.

## Rehearse it

**A recovery path you've never run is a hypothesis, not a plan.** Cheap things to actually
try, on a quiet afternoon, before you need them:

- Pull the box out of the path. Time it. **Is it really ~60 seconds?**
- Kill the AdGuard container. **Does DNS survive?** (It should — you set a secondary.)
- Restore onto a spare SD card from a blank flash. **Does it come back?**
- Load a deliberately broken nftables file with `nft -c -f`. **Does it get caught?**

Then write down what actually happened, not what should have.

## Where next

- **[Troubleshooting](Troubleshooting)** — the symptom-first user version
- **[Estate Architecture](Estate-Architecture)** — the fragility read this page answers
- **[LLM Legibility](LLM-Legibility)** — why an LLM may *author* a recipe but never *execute*
  on Core
