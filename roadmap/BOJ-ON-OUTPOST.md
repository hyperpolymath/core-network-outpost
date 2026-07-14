<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# BoJ server on the outpost — design, and one measured "no"

Closes the BoJ half of issue #1. The DDNS half is **built** (`host/ddns/`); this
half is **designed but not built**, and this document says exactly why, with the
evidence rather than a vibe.

## TL;DR

| | On the Pi 2B | On the final outpost |
|---|---|---|
| **DDNS** | ✅ **built and shipping** (`host/ddns/`) | ✅ same code, unchanged |
| **BoJ — shipped container** | ❌ **impossible**, measured below | ✅ fine |
| **BoJ — MCP bridge, native node** | ⚠️ **unknown — go and measure it** | ✅ fine |

## First: the issue's own hypothesis is wrong

Issue #1 asks: *"Actual problem in Pi 2B due to NIC?"*

**No.** The NIC is a real limitation of this board, but it is not this
limitation. The 2B's single 100 Mbit interface on the shared USB 2.0 bus is what
kills the **inline-firewall** role (an edge router needs two interfaces) — that
is already documented in README § "Why no inline firewall". BoJ is an MCP
server: it is a request/response control-plane process. It is **not NIC-bound**.
Giving it a 10 Gb NIC would change nothing.

Chasing the NIC here would have burned a day and found nothing. The actual wall
is somewhere else entirely.

## The actual wall: CPU architecture

BoJ's container is built `FROM cgr.dev/chainguard/node:latest`. Chainguard
images are **Wolfi**-based. Query the registry for what that image is actually
published for:

```console
$ # OCI image index for cgr.dev/chainguard/node:latest
linux/amd64
linux/arm64
```

**There is no `linux/arm/v7`.** A Pi 2B is `armv7l`. The image does not exist for
this machine — this is not "slow", not "tight on RAM", it is *absent*. No amount
of tuning produces an image that was never built.

And note **this is the same wall this project already hit once**: the README
rejects Wolfi as the *base OS* for exactly this reason ("no 32-bit ARM target —
x86_64 / aarch64 only"). We rejected Wolfi at the bottom of the stack and then
BoJ dragged it back in at the top, through its container base. Worth remembering
the next time a dependency looks architecture-neutral.

## The part that is genuinely worth testing

Don't stop at the container, because BoJ's own `Containerfile` says this:

> `# Runs only the Node.js MCP bridge (zero npm dependencies).`
> `ENTRYPOINT ["node", "mcp-bridge/main.js"]`

A zero-dependency Node process is **not** architecture-locked. Alpine armv7 ships
`nodejs`. So the bridge could plausibly run on a 2B **natively, without a
container at all** — and that is a claim we can settle by *running it* rather
than by reasoning about it.

### The experiment

On the 2B, once the outpost is up:

```sh
apk add --no-cache nodejs
node --version                       # does Alpine armv7 even give us >= 18?
git clone https://github.com/hyperpolymath/boj-server /tmp/boj
cd /tmp/boj
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  | /usr/bin/time -v node mcp-bridge/main.js
```

Three ways this can end, all of them useful:

1. **It answers, in sane RSS.** BoJ's *bridge* works on floor hardware. Ship it
   as a host service alongside CUPS; the container stays impossible, but nobody
   needs the container.
2. **It answers, but RSS is near the 1 GB ceiling** (AdGuard is already resident,
   plus CUPS). Then it "works" and is still a bad idea here — record the number
   and move it to the final outpost.
3. **`node` on Alpine armv7 is too old, or it OOMs.** Then we have a hard,
   *measured* no for the whole class of box, which is worth publishing: a lot of
   people have a 2B in a drawer and deserve a straight answer.

**Record the actual number in this file when it's run.** An outcome nobody wrote
down is an experiment nobody did.

> Status: **not yet run** — blocked on the 2B being on the network.

## Why BoJ probably shouldn't live here anyway

Even if the bridge fits, there is a second, independent argument, and it is not
about performance:

**BoJ is a credentialed control plane.** It exists to reach GitHub, GitLab and
100+ other capability cartridges, which means it holds real, broadly-scoped,
personal tokens. The outpost is, by design, the **least defended interesting box
on the LAN**: it accepts connections from every device in the house (that is what
a DNS sinkhole *is*), it runs a print server, and it is the box most likely to be
handed a hostile packet by a compromised smart-plug.

Putting the estate's credential store on the box with the widest LAN attack
surface inverts the security gradient. Even where BoJ *fits*, it does not
*belong* here. DDNS is the opposite case and that is why it shipped: its
credential is scoped to updating exactly one DNS record and is revocable in one
click.

## The design, then

```
                internet
                    │
            ┌───────┴────────┐
            │  DDNS (dyndns2)│   <- built, host/ddns/, runs fine on a 2B
            │  stable name   │      names the outpost through a moving ISP IP
            └───────┬────────┘
                    │
   ┌────────────────┴──────────────────────────────────┐
   │  OUTPOST (Pi 2B today)                            │
   │    AdGuard Home  (DNS sinkhole)   container       │
   │    CUPS + Avahi  (print)          host            │
   │    nftables      (host firewall)  host            │
   │    ddns-update   (stable name)    host, crond     │
   │                                                   │
   │    BoJ  ── NOT HERE ─────────────────────────┐    │
   └──────────────────────────────────────────────┼────┘
                                                  │
   ┌──────────────────────────────────────────────▼────┐
   │  CONTROL PLANE (aarch64 / x86 — Pi 4+, mini-PC,   │
   │                 or off-site)                      │
   │    BoJ server (container; amd64/arm64 exist)      │
   │    holds the credentials, away from the LAN's     │
   │    widest attack surface                          │
   └───────────────────────────────────────────────────┘
```

DDNS is what makes this two-box split *work* rather than being an inconvenience:
the outpost has a stable name, so the control plane can find it without either
box needing a static IP.

## Hardware that lifts the arch wall

Anything `aarch64` — Pi 4 / Pi 5 / any x86 mini-PC. At that point
`cgr.dev/chainguard/node` **does** publish an image, BoJ's container runs
unmodified, and (per `PI4-AND-BEYOND.md`) Wolfi becomes available as a base OS
too. The whole problem evaporates with the board, which is the honest summary.

## Open, not yet decided

- **Georedundancy.** Issue #1 says "use Dynu's georedundant structure". Dynu's
  *DNS* is georedundant; the *outpost* is one box in one house. Redundant DNS
  pointing at a single point of failure is still a single point of failure. If
  the goal is a genuinely georedundant service, that is a **second node in a
  second location** with health-checked failover — a real design, out of scope
  here, and worth its own issue.
- Whether the BoJ bridge should be a `cartridge`-subset rather than all 115+.
