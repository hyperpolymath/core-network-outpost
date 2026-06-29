<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Installing the outpost on a Raspberry Pi 2B

## 0. Confirm what you've got

```sh
uname -m            # armv7l  -> genuine 2B-class (32-bit). This guide.
                    # aarch64 -> 64-bit Pi; see roadmap/PI4-AND-BEYOND.md
cat /proc/cpuinfo | grep -i model
```

The Pi 2B is **ARMv7, 1 GB RAM, 100 Mbit Ethernet on the USB 2.0 bus, no Wi-Fi.**
That shapes every choice below.

## 1. Flash Alpine

Use **Alpine Linux for armv7** (the "Raspberry Pi" image). Do the standard
`setup-alpine`, then commit changes (`lbu commit` on a diskless install, or use a
sys install to an SD card so Podman has normal persistent storage — **recommended:
`setup-disk` / sys mode**, because containers + CUPS want a real writable rootfs).

> Why Alpine and not Wolfi? Wolfi has **no 32-bit ARM target** — x86_64 and
> aarch64 only. On a 2B it's simply not buildable. Alpine has first-class armv7.
> Debian / Raspberry Pi OS is the fallback if you hit an Alpine driver wall
> (e.g. an awkward USB Wi-Fi dongle).

## 2. Clone the repo and configure

```sh
git clone <this-repo> outpost && cd outpost
cp .env.example .env
$EDITOR .env        # set TZ, LAN_SUBNET, SSH_PORT, and pin AGH_IMAGE to a digest
$EDITOR host/nftables.nft   # set `define LAN` + `define SSHPORT` to match .env
```

## 3. Run the bootstrap

```sh
sudo sh host/setup.sh
```

This installs Podman, CUPS, Avahi, and nftables; loads the firewall; starts the
print server; and (if `.env` exists) starts AdGuard Home.

## 4. AdGuard Home first run

Open `http://<pi-ip>:3000` and complete the wizard (admin user, upstreams,
listen interface). Then **lock in reproducibility**:

```sh
# Copy the generated config into the repo and commit it.
cp adguardhome/conf/AdGuardHome.yaml adguardhome/conf/AdGuardHome.yaml
git add adguardhome/conf/AdGuardHome.yaml
git commit -m "outpost: capture AdGuard config"
```

From now on, the committed `AdGuardHome.yaml` is your source of truth — rebuild
the box from a blank SD card and you get the same DNS sinkhole back.

Point your router's DHCP "DNS server" at the Pi's IP (or set it per-device) and
the whole LAN goes through the sinkhole.

## 5. Add the printer

Plug the USB printer into the Pi. At `http://<pi-ip>:631` → **Administration** →
**Add Printer**, then ensure **"Share printers connected to this system"** is
ticked. Wi-Fi clients discover it via mDNS through your router. Done.

## 6. Harden SSH (instead of a honeypot)

On an internal box a honeypot is net-negative. Do this instead:

```sh
# /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
# optional: Port <non-22>  (then update host/nftables.nft + .env SSH_PORT)
```

`nftables` already rate-limits new SSH connections. If you ever **deliberately
expose** the box to the internet, enable the commented-out `endlessh` tarpit in
`compose/adguardhome.yaml`.

---

## Why no inline "hardware firewall" on a 2B

A true edge firewall sits **between your modem and your LAN**, which needs **two
network interfaces**. The 2B has **one**, and it hangs off the **USB 2.0 bus**.
Bolting on a USB-Ethernet adapter funnels *all* WAN↔LAN traffic through a single
shared USB 2.0 bus → a hard throughput/CPU bottleneck. And the appliance OSes
people mean (OPNsense/pfSense) are **x86-only and don't run on a Pi at all**.

What you get instead, and it's genuinely useful:
- **`nftables`** protecting the box itself (this repo).
- **AdGuard Home** as a network-wide security layer — DNS sinkholing of
  malware/tracker/ad domains is the firewall-ish value a box like this gives you.

If you later want a real inline firewall, that's a **2-NIC x86 mini-PC** (or a
Pi 4/5 with a USB 2.5GbE adapter and modest expectations) — see `roadmap/`.

## Performance expectations on a 2B

- DNS sinkhole: snappy. This is what the box is for.
- Print server: fine for a home printer.
- Don't also try to make it a Plex box / NAS / VPN concentrator. 1 GB RAM and a
  100 Mbit USB-bus NIC are the ceiling. Keep the outpost single-minded.
