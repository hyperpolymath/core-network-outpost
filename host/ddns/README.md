<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Dynamic DNS

Gives the outpost a **stable name** on a domestic connection whose IP the ISP
keeps changing.

## What it does, and what it deliberately doesn't

`ddns-update.sh` speaks the de-facto **dyndns2** update protocol. Dynu is the
reference endpoint (it's what this was built against) but the script has no
Dynu-specific code in it — point `DDNS_UPDATE_URL` at DuckDNS, No-IP or any
other dyndns2 provider and nothing else changes. **The provider is an example,
not a recommendation.**

It runs from `crond` every 15 minutes and **only contacts the provider when your
public IP has actually changed**. Re-announcing an unchanged address every 15
minutes is how accounts get rate-limited or flagged for abuse. It *does* force a
refresh every `DDNS_MAX_AGE_DAYS` (default 25) because providers expire records
that are never refreshed — Dynu's window is about 30 days.

If the IP lookup returns something that isn't an address — a captive portal
splash, an error page — it **aborts rather than announcing junk to DNS**.

## Setup

```sh
cp .env.example .env
$EDITOR .env          # set DDNS_ENABLED=true, DDNS_HOSTNAME, DDNS_USERNAME, DDNS_PASSWORD
chmod 600 .env        # it holds a credential
sudo sh host/setup.sh # installs the 15-min cron hook and announces once
```

Check it:

```sh
sh host/ddns/ddns-update.sh --status   # print state, change nothing
sh host/ddns/ddns-update.sh --force    # announce now, even if unchanged
```

## Credentials

- `DDNS_PASSWORD` is a **scoped, single-purpose, revocable** credential that can
  update one DNS record. It is **not** a personal password and must never be a
  reused one.
- It lives **only** in `.env`, which is gitignored. It is never committed and
  never printed.
- It is **never passed in argv** — argv is world-readable through `ps`, so
  `curl -u user:pass` would leak it to every account on the box. It is fed to
  curl on **stdin** via `curl --config -`.
- The script warns if `.env` is not mode `600`.

## Note on exposure

DDNS makes the outpost *nameable* from outside. It does **not**, on its own,
make it *reachable* — that still needs a port-forward on your router, which this
project does not ask for and does not want. The firewall
(`host/nftables.nft`) is LAN-scoped and default-deny inbound. If you ever do
deliberately expose this box, re-read `docs/INSTALL.md` § "Harden SSH" first.
