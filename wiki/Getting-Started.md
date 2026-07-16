# Getting Started — the Core on a spare device

> ✅ **Built.** Everything on this page ships in the repo and runs today. It's been run on a
> Raspberry Pi 2B (armv7, 1 GB). If your device isn't in [Tested Devices](Tested-Devices),
> you're likely fine — but you'd be the first, so please report back.

**What you get in about an hour:** network-wide ad/tracker/malware blocking for *every*
device, a default-deny firewall, a print server that makes any USB printer AirPrint-capable,
and a stable name for your connection. No subscription, no cloud account, no vendor who can
switch it off.

**What this page does *not* cover:** the CAKE traffic shaper. That needs the box to be your
*gateway*, which needs two network ports and a faster CPU — see
[Right-Size Your Box](Right-Size-Your-Box). Everything here works fine without it.

---

## Before you start

| You need | Notes |
|---|---|
| A spare device | A Raspberry Pi 2B or better. Almost anything works — it's a **sidecar**, not a router. |
| A wired Ethernet port | Wi-Fi-only works but is a worse place to put your DNS. |
| An SD card (8 GB+) | Or whatever your board boots from. |
| Your router's admin login | One setting changes at the end. |
| ~1 hour | Most of it is waiting for downloads. |

**This is a sidecar.** It sits *beside* your router, not between your router and the
internet. If it dies, you set your DNS back and carry on — you do **not** lose your
connection. That's the whole point of starting here.

```
  Internet ──▶ your router ──┬──▶ your devices
                             │
                             └──▶ [ this box ]   ← sidecar: DNS + print + time
```

## 1. Flash the OS

Use **Alpine Linux** for your board (the "Raspberry Pi" image for a Pi). Run `setup-alpine`,
and choose a **sys install to the SD card** (`setup-disk`, "sys" mode) — containers and CUPS
want a real writable root filesystem.

> **Why Alpine?** It's tiny and has first-class 32-bit ARM support. The 64-bit boxes in this
> estate use Chainguard Wolfi instead, which has **no 32-bit ARM target** — that's why the
> old-board path is Alpine. If you hit a driver wall (an awkward USB Wi-Fi dongle, say),
> Raspberry Pi OS / Debian is the fallback.

Check what you've got:

```sh
uname -m     # armv7l  -> 32-bit, this guide
             # aarch64 -> 64-bit; same steps, more options later
```

## 2. Get the repo and configure it

```sh
git clone https://github.com/hyperpolymath/core-network-outpost outpost && cd outpost
cp .env.example .env
$EDITOR .env               # set TZ, LAN_SUBNET, SSH_PORT
$EDITOR host/nftables.nft  # set `define LAN` + `define SSHPORT` to match .env
```

> ⚠️ **Don't hand-edit the image digest in `.env`.** The container base is pinned by digest
> in `images.lock` so you get a byte-identical, reproducible box. Upgrades go through
> `bin/bump.sh` (see [Contributing & Governance](Contributing-And-Governance)) — never a
> silent `:latest`.

## 3. Run the bootstrap

```sh
sudo sh host/setup.sh
```

That installs Podman, CUPS, Avahi, and nftables; loads the firewall; starts the print server;
and starts AdGuard Home. Launch always goes through `bin/up.sh`, which **refuses any
un-pinned tag** — if someone slipped a `:latest` in, it stops.

## 4. Set up AdGuard Home

Open `http://<box-ip>:3000` and complete the wizard (admin user, upstream resolvers, listen
interface). Then **lock in reproducibility** — this is the step people skip and regret:

```sh
git add adguardhome/conf/AdGuardHome.yaml
git commit -m "outpost: capture AdGuard config"
```

From now on that committed YAML **is** your source of truth. Blank SD card + this repo = the
same box back. That's the promise the whole design exists to keep.

## 5. Point your network at it

In your **router's DHCP settings**, set the primary DNS server to the box's IP.

> ✅ **Do this too — it's the single most important dependability step on this page.** Set a
> **secondary DNS** to your router's own IP or `1.1.1.1`. Then if the box ever dies, the
> worst that happens is *ads come back* — not *the internet stops*. A DNS box that takes the
> house offline when it crashes is a box your household will (rightly) make you unplug.

Give the box a **static IP** (or a DHCP reservation) first, or this breaks the next time it
reboots.

## 6. Add the printer

Plug the USB printer in. Go to `http://<box-ip>:631` → **Administration** → **Add Printer**,
and tick **"Share printers connected to this system"**. Wi-Fi clients — including iPhones —
discover it over mDNS. An old USB printer becomes an AirPrint printer.

## 7. Harden SSH

```sh
# /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
```

`nftables` already rate-limits new SSH connections. Key-only auth is the control that
matters here.

---

## Recommended next: the dependability layer

> ✅ **Built** — configs are in [`dependability/`](https://github.com/hyperpolymath/core-network-outpost/tree/main/dependability)
> and all of it runs on a 2B today. This is the *highest-value* thing you can add, and it's
> mostly copying files.

Do these in order — each one is independently useful, and the order is deliberate:

1. **`chrony.conf`** → `/etc/chrony/chrony.conf`. Authenticated (NTS) time from multiple
   independent sources, with your router as a low-trust cross-check. Validate with
   `chronyd -p -f /etc/chrony/chrony.conf` **before** enabling.
   *Why first: TLS, DNSSEC, and your logs all fail — silently and confusingly — on bad time.*
   **On a Pi 2B, also add a ~£3 DS3231 RTC**, or at minimum `fake-hwclock`: the 2B has no
   battery-backed clock and forgets the time on every power-off.
2. **`adguard-healthcheck.sh`** → `/usr/local/sbin/`, plus a 1-minute cron line. If AdGuard
   falls over, this restarts it, so a crashed sinkhole self-heals.
3. **The `watchdog` package** — auto-reboots a hung box. Essential for something unattended.
4. **Read-only root — last, and on a spare SD card first.** Kills the #1 Pi failure mode
   (SD-card write death) and gives you an immutable base. Highest value, so do it *after* the
   above are proven, not before.

**The golden rule throughout: validate before you apply.** Every file in `dependability/`
lists its check command (`nft -c -f …`, `chronyd -p -f …`). A bad config must never be able
to take the box down. This isn't theoretical — it caught a broken firewall line during this
project's own development.

**Always keep a break-glass path**: a local console or LAN SSH that doesn't depend on
anything you just hardened.

## Where next

- Something wrong? → **[Troubleshooting](Troubleshooting)**
- Wondering if you need better hardware? → **[Right-Size Your Box](Right-Size-Your-Box)**
- Want the shaper (low ping/jitter under load)? → that's the gateway path;
  **[Estate Architecture](Estate-Architecture)** explains the two-box split.
- Please add your device to **[Tested Devices](Tested-Devices)** — honest ⚠️ entries with a
  real caveat are worth more than optimistic ✅ ones.
