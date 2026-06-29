<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# 🩹 Micropatch server — future sketch (NOT built)

> **Status: sketch / placeholder.** This is a deliberate "here's where it could
> go" note, not a deliverable. It is parked here precisely because the **Pi 2B
> is too small to host it** (1 GB RAM, slow SD, 100 Mbit USB-bus NIC). It wants
> a Pi 4 / 5 or an x86 mini-PC — see `PI4-AND-BEYOND.md`.

## The idea

A small, LAN-local service that turns the outpost from a passive sinkhole into
an **active patch distribution point**: your devices and containers pull
**pinned, vetted, mirrored** updates *from the outpost* rather than reaching out
to the wider internet individually. "Micro" because the ambition is tiny and
sharply scoped — not a full Spacewalk/Foreman, just enough to:

1. **Mirror** a small set of upstreams you actually use (Alpine `apk` repos,
   selected container image digests, maybe firmware blobs).
2. **Pin + sign** what it mirrors, so every LAN device gets a reproducible,
   tamper-evident artifact (ties naturally into the digest-pinning this repo
   already does for AdGuard).
3. **Serve** them on the LAN over plain HTTP(S) + mDNS discovery, the same shape
   as the print server.

## Why it pairs well with a sinkhole

The outpost already sees and shapes the LAN's DNS. A micropatch server is the
logical "supply side" twin: the sinkhole says *what you may reach*; the
micropatch server provides *vetted copies of the things you should reach*. Same
box, same "quiet trusted infrastructure" role, same reproducibility discipline.

## Rough shape (when the hardware exists)

```
[ upstream apk / OCI registries ]
            |  (scheduled, signed pull)
            v
   micropatch-server (Pi 4+ / x86)
   ├── mirror store (content-addressed, digest-pinned)
   ├── signer (your existing GPG/SSH signing identity)
   └── LAN endpoints: apk repo + OCI pull-through cache + mDNS advert
            |
            v
[ LAN devices + the outpost's own containers pull from here ]
```

## Why NOT on the 2B

- A pull-through OCI cache + apk mirror is disk- and RAM-hungry; the 2B has
  neither to spare.
- 100 Mbit on a shared USB 2.0 bus makes it a poor distribution point.
- SD-card wear from a write-heavy mirror is a real failure mode.

## Open questions (for future-you)

- Mirror vs pull-through cache vs both?
- Reuse the estate signing identity, or a box-local key?
- Where does verification live — verify-on-ingest, verify-on-serve, or both?
- Does this subsume / overlap an existing estate component? (Check before building.)
