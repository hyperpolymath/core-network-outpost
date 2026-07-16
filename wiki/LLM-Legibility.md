# LLM Legibility — make the box readable, never give it the keys

> 📐 **Designed, not built.** The `export diagnostics` command is a plan. The principle
> behind it is decided and load-bearing, which is why it's written down.

**The decision in one line: don't put an LLM *on* the box — make the box *legible* to
whatever LLM the user brings.**

---

## Why no on-device LLM

This gets asked a lot, and "it'd be handy for auto-repair" is a reasonable instinct. Here's
why the answer is still no — four independent reasons, each sufficient on its own:

| Reason | Detail |
|---|---|
| **Resource contention** | A local LLM is *the one thing* an N100 can't do well **while also being the network**. It'd fight the router for RAM and CPU — at exactly the moment things are going wrong. |
| **Small models can't be trusted here** | A model small enough to run is **too weak for config that must be exactly right**. Network config is unforgiving: a plausible-looking nftables rule that's subtly wrong is worse than no rule. |
| **Cloud LLM = privacy leak** | Against the no-phone-home ethos, on a box whose whole job is privacy. |
| **🚨 Prompt injection via its own logs** | **This is the killer.** A write-capable LLM on a security box reads logs — and **an attacker controls what's in those logs.** Craft a hostile hostname or User-Agent, get it logged, and the "log analyser" reads your instructions. You've built a remote-code-execution path out of a helper. |

**And it's non-deterministic**, which is disqualifying on its own for anything in the critical
path. The whole estate is built on "boring, reproducible, verifiable". An LLM is none of
those.

## The split that makes it safe

> **Read-only interpretation: welcome. Execution on Core: never.**

| Allowed | Not allowed |
|---|---|
| An LLM **reads** a diagnostic bundle and explains what's wrong | An LLM **touches** the box |
| An LLM **authors** a Bustfile recipe, which you review | An LLM **executes** on Core unattended |
| An LLM **suggests** a config change, which you apply | An LLM **applies** anything itself |

**Repair and monitoring stay deterministic** — Bustfiles, `network-ambulance`, Prometheus
alert rules. An LLM may *author* a recipe; a human applies it; the machine executes something
reviewed and reproducible.

That's not LLM-pessimism. It's the same rule as everywhere else in this estate: **the
critical path is boring and verifiable, and the exciting thing is quarantined outside it.**

## The diagnostic bundle

> 📐 **Designed, not built.** An `export diagnostics` command in the setup TUI/CLI.

One shot, **read-only**, writes **one local file you choose whether to share**:

| Contains | Why |
|---|---|
| **Live state** in a structured `.a2ml`/STATE format | Machine-readable, not screen-scraped |
| **This deployment's topology** | Sidecar or gateway? Which profile? Context changes the answer |
| **Secret-sanitised logs** | The evidence — with the credentials stripped |
| **Config-as-code** | It's already in git; it's already the truth |
| **Relevant Bustfile recipes + doc pages** | So the advice can point at something real |
| **A suggested prompt** | So a non-expert gets a useful answer first try |

**The properties that matter, and why each is deliberate:**

- **Read-only** — it cannot change anything, so running it is never risky.
- **No auto-upload** — it writes a *file*. **You** decide if it leaves your house.
- **No on-box LLM** — the reasoning happens on whatever tool you bring.
- **Secret-sanitised** — because the realistic failure mode is a user pasting their DDNS
  credentials into a chat window without noticing.

> **"One button on the desktop sends a copy of that, LLM-ready to look at."** That's the goal:
> a person who can't read an nftables ruleset can still get competent help, without handing
> anyone the keys to their network.

## It's the runtime instance of work you already have

This isn't a new idea bolted on — it's the running-system version of the **`0-AI-MANIFEST.a2ml`
/ llm-warmup** legibility work already present across this estate's sibling repos
([`network-ambulance`](https://github.com/hyperpolymath/network-ambulance),
[`network-dashboard`](https://github.com/hyperpolymath/network-dashboard),
[`snifs`](https://github.com/hyperpolymath/snifs) all carry one).

**The repos are already legible to an LLM at rest. This makes the *box* legible at runtime.**
Same principle, same format family, applied to live state instead of source.

> ⚠️ **Note for accuracy:** `core-network-outpost` does **not** have a `0-AI-MANIFEST.a2ml`
> yet — its siblings do. Adding one is a reasonable next step and is not done.

## Why "legible" is the right word

Legibility is a **property of the system**, not a feature you install. A box is legible when:

- its state can be **read** without guessing,
- its config **is** its documentation (config-as-code, in git),
- its recovery paths are **written down as recipes**, not folklore,
- and its logs are **structured** enough to reason about.

**Every one of those is worth doing even if no LLM ever reads them.** They're the same
properties that make a system debuggable by a *human* at 2am — which is the real test. The
LLM is a beneficiary of good design here, not the reason for it.

That's why this page sits in the maintainer track rather than being a feature request: it's a
design stance that pays off regardless of what the AI landscape does next.

## Where next

- **[Recovery as Code](Recovery-As-Code)** — the deterministic repair layer an LLM may author for
- **[Troubleshooting](Troubleshooting)** — where the bundle will surface for users
- **[Estate Architecture](Estate-Architecture)** — the full "evaluated and declined" list
