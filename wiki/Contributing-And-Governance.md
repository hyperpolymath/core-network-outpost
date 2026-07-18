# Contributing & Governance

> ✅ **Built.** The pin/bump flow, canary, and governance docs all ship today.
> 📐 The **OpenSSF badge** is a goal, **not yet obtained** — see below.

**Contributions are welcome, and the most valuable one probably isn't code.** This is a
one-person, unpaid project shared for free. Telling me something is wrong, or that a doc lies,
or that it broke on your board, is a real contribution.

---

## The most useful things you can do

Roughly in order of how much they help:

1. **Report a device** → [Tested Devices](Tested-Devices). The catalogue is short and honest;
   the ❓ rows include the **N100, which has never been run**. A ⚠️ with a real caveat beats
   an optimistic ✅.
2. **Report the bufferbloat before → after grade** if you run the shaper inline. That's the
   number this project most wants and cannot get alone.
3. **Tell me a doc is wrong.** Docs rot; this repo has already had to fix its own stale
   references. Finding another is a gift.
4. **Improve the wiki** — see the source-of-truth note below.
5. **Code.** Genuinely last. **Prefer wiring existing tools over writing new code** — least
   bespoke code = most dependable and maintainable.

## Who decides

| Doc | Covers |
|---|---|
| [`.github/GOVERNANCE.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/.github/GOVERNANCE.md) | Policy, incl. **Policy 1** (the bump rule below) |
| [`.github/MAINTAINERS.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/.github/MAINTAINERS.md) | Who reviews |
| [`.github/CODEOWNERS`](https://github.com/hyperpolymath/core-network-outpost/blob/main/.github/CODEOWNERS) | What needs whose review |
| [`.github/SECURITY.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/.github/SECURITY.md) | How to report a vulnerability |

## The pin/bump flow — upgrades are never silent

**This is the heart of the reproducibility promise, so it's worth understanding before you
touch it.** Container bases are pinned **by digest** in `images.lock` (committed, multi-arch
including `linux/arm/v7`). `bin/up.sh` **refuses any un-pinned tag** — a `:latest` anywhere
stops the launch.

**Detection and application are separate steps, on purpose:**

```sh
sh bin/bump.sh --check     # report only: is a newer release out? (exit 10 = yes)
sh bin/bump.sh --verify    # assert the current pin still matches source (drift check)
sh bin/bump.sh --apply     # re-resolve the digest from source + repin — AFTER you confirm
git commit -am 'outpost: bump AdGuard Home'   # review the images.lock diff, then commit
```

A weekly **report-only canary** (`bin/canary.sh`, via crond — **no GitHub Actions**) runs
`--check`/`--verify` and tells you if there's something to decide. **It never applies
anything.**

> **Why so strict?** Because "it worked yesterday" must stay true. A silent base-image change
> is an unreviewed change to a security appliance. Blank SD card + this repo = the same box
> back — that guarantee dies the moment something auto-updates itself.

## Wiki contributions — PR, don't edit in place

> **`wiki/` in the main repo is the source of truth.** Edits made in the GitHub wiki web UI
> get **overwritten** on the next sync.

```sh
$EDITOR wiki/Some-Page.md
sh bin/wiki-sync.sh --check    # diff repo vs published wiki, change nothing
sh bin/wiki-sync.sh            # publish (maintainer)
```

**This is a security decision, not bureaucracy.** A GitHub wiki is a *separate git repo*:
outside this repo's review, history, and backups. For a **security appliance**, a wiki page is
exactly where someone would slip in a malicious `curl … | sh` — and it would look completely
normal. Routing wiki edits through PR review means **the install instructions are as
version-controlled as the code**.

Maintainer note: also set **Settings → Features → Wikis → restrict editing to collaborators**.

## Docs conventions

Two rules, both enforced by `bin/check-doc-links.sh`:

| Kind | Resolved from | Example |
|---|---|---|
| **Clickable link** — `[text](<path>)` | **the file it sits in** — that's what GitHub follows | `[.github/GOVERNANCE.md](../../.github/GOVERNANCE.md)` |
| **Prose mention** — `` `docs/<file>.md` `` | **the repo root** | `` `docs/HARDENING.md` `` |

Root-relative prose **survives the referring file being moved**; `../` in prose doesn't —
which is exactly what broke when the docs moved into `docs/`. Run the checkers before you
commit:

```sh
sh bin/check-doc-links.sh                              # exit 1 on a dead reference
asciidoctor -o /dev/null --failure-level=WARN docs/*.adoc   # adoc must parse clean
shellcheck bin/*.sh edge-shaper/*.sh dependability/*.sh
```

**Licensing:** code/config **MPL-2.0**; docs (`.md`/`.adoc`) **CC-BY-SA-4.0**. Every file
carries an SPDX header — please keep that up.

> **MPL-2.0 *is* GPL-compatible.** The incompatibility people remember was MPL **1.1**. Files
> here don't carry the Exhibit-B "Incompatible With Secondary Licenses" notice, and AdGuard
> Home (GPLv3) runs as a **separate container** = mere aggregation, not a derivative work.

## Code contributions

**Before writing code, check whether the design already declined it.**
[`docs/DESIGN-LOG.adoc`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/DESIGN-LOG.adoc)
records ~40 decisions with rationale, and
[Estate Architecture](Estate-Architecture) has the "evaluated and declined" list. Redis,
LMDB, Ecto, SpamAssassin, embedded IPFS, on-device LLMs, and SSH tarpits are all **deliberate
noes with reasons** — if you want to reopen one, argue with the reason.

If it survives that:

- **Validate before apply** — every config change ships with its check command.
- **`shellcheck`-clean.** No exceptions.
- **Never enforcing-by-default** for anything that costs dependability (`[dep-risk]`).
- **Elixir: SNIFs, never raw NIFs** — a NIF fault kills the whole BEAM VM.
- **Keep it boring.** "Least bespoke code" is a feature.

## The priority order — what "better" means here

Every proposal gets judged against this, in this order:

1. **Dependability** — if security isn't dependable it's *dangerous*; if the box isn't
   dependable it gets ditched and the user loses **every** benefit.
2. **Security** — but only the kind that doesn't cost dependability.
3. **Maintainability & accessibility.**
4. Everything else — extra features, performance.

**An N100 removes the *resource* limit, not the *maintenance-time* or *attack-surface* cost.
"Can it run?" is the wrong question. "Is it worth maintaining and exposing — forever, by one
person?" is the right one.**

## OpenSSF

> 📐 **A goal, not a badge yet.** Don't infer a security posture we haven't earned.

Worth pursuing for a security appliance offered to the public:

- **[OpenSSF Best Practices](https://www.bestpractices.dev/)** — a self-certification covering
  reporting, testing, review, release practice. Much of it this repo already does (SECURITY.md,
  digest pinning, gated bumps, governance docs).
- **[OpenSSF Scorecard](https://github.com/ossf/scorecard)** — automated checks. Note it
  favours GitHub Actions, and this project **deliberately uses a crond canary instead** — so
  expect an imperfect score and a *reasoned* deviation rather than chasing the number.

## Reporting a vulnerability

**Don't open a public issue.** Follow
[`.github/SECURITY.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/.github/SECURITY.md).

And a plea for realism about scope: this is **one unpaid person**. Expect a human response,
not an SLA. That's exactly why the design refuses features it can't maintain — and why the
critical path is kept boring enough that there's less to get wrong.
