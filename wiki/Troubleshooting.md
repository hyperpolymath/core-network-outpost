# Troubleshooting

> **Mixed status — read the badges.** The manual steps here are ✅ **usable today**. The
> one-button **diagnostic bundle** is 📐 **designed, not built** — it's described at the
> bottom so you know what's coming, not so you can run it.

**First, the reassuring bit.** The Core is a **sidecar**: it sits beside your router, not in
the path. If it's misbehaving and you need your evening back:

```sh
# Point your router's DHCP back to your router's own IP (or 1.1.1.1) as primary DNS.
# That's it. You're back to normal. The box can wait until tomorrow.
```

If you set a **secondary DNS** as [Getting Started](Getting-Started) recommends, this mostly
happens by itself.

---

## Start here: is it DNS?

It's usually DNS. Work down this list — each step tells you something the next one needs.

```sh
# 1. Is the box up at all?
ping <box-ip>

# 2. Is AdGuard answering DNS?
dig @<box-ip> example.com +short          # expect an IP
nslookup example.com <box-ip>             # Windows equivalent

# 3. Is the container actually running?
sudo podman ps                            # expect adguardhome, Up
sudo podman logs adguardhome | tail -50

# 4. Is anything listening on :53?
sudo ss -ulnp | grep :53
```

| Symptom | Likely cause | Fix |
|---|---|---|
| `ping <box-ip>` fails | Box is down, or its IP changed | Console in. **Give it a static IP / DHCP reservation** — a moving DNS server breaks everything. |
| Box pings, `dig` times out | AdGuard is down | `sudo podman ps`; restart via `sh bin/up.sh`. Then install the healthcheck so this self-heals. |
| `dig` works, browsing doesn't | Router DHCP isn't handing out the box's IP | Recheck the router's DNS setting; **reconnect the client** (it caches its DHCP lease). |
| Works on one device only | Client DNS cache / DoH | The device may be using **DNS-over-HTTPS**, bypassing you entirely — see below. |
| A site is broken | Over-blocking | AdGuard → **Query log**, find the domain, **Unblock**. |

### The one that catches everyone: browsers bypassing your sinkhole

Firefox and Chrome can send DNS over HTTPS **straight past your box** — your blocklists just
stop applying, with no error message. If blocking works on some devices and not others, this
is why. Turn off "Secure DNS" / "DNS over HTTPS" in the browser, or point it at your box.

## Time problems (the ones that look like something else)

Bad time fails **silently and confusingly**: TLS certificate errors, DNSSEC failures, logs
that don't line up. If you're seeing weird certificate errors, check this *before* you
suspect anything else.

```sh
chronyc tracking     # System time offset should be tiny
chronyc sources -v   # expect several reachable sources, one selected (^*)
timedatectl          # or: date
```

**On a Pi 2B: it has no battery-backed clock.** It forgets the time on every power-off. If it
booted without internet, its clock may be *years* out. Add a **DS3231 RTC (~£3)**, or at
minimum `fake-hwclock` so it never jumps *backwards*.

## Printing

```sh
lpstat -p -d                  # is the printer there and enabled?
sudo systemctl status cups    # or: rc-service cupsd status   (Alpine)
sudo systemctl status avahi-daemon
```

| Symptom | Fix |
|---|---|
| Printer invisible to iPhone/Mac | Avahi (mDNS) isn't running, or the client is on a different subnet/VLAN — **mDNS doesn't cross subnets**. |
| Visible but won't print | CUPS → `http://<box-ip>:631` → check the queue isn't paused. |
| Not shared | CUPS → Administration → tick **"Share printers connected to this system"**. |

## Firewall — you locked yourself out

**Always keep a break-glass path**: a local console (keyboard + monitor, or serial) that
doesn't depend on SSH. That's the answer to this whole category.

```sh
sudo nft -c -f host/nftables.nft   # VALIDATE first — never load blind
sudo nft list ruleset              # what's actually loaded
sudo nft flush ruleset             # PANIC: drop all rules (opens the box up — temporary!)
```

> **`nft -c -f` before every apply.** A bad ruleset must never be able to take the box down.
> This isn't hypothetical — a broken firewall line got caught exactly this way during this
> project's development.

## The link monitor says jitter/ping/loss is bad

**First: separate the two kinds of bad.** They have completely different answers.

| Kind | Looks like | Answer |
|---|---|---|
| **Under-load** (bufferbloat) | Fine when idle, terrible during an upload/download | **The shaper fixes this** → [Right-Size Your Box](Right-Size-Your-Box) |
| **Idle / random** | Bad even when the line is quiet — loss with no traffic | **No software fixes this.** It's physical. |

**Idle packet loss on cable is a physical fault** — signal power, SNR, or T3 timeouts. No
qdisc, no setting, no amount of CAKE tuning touches it. Check your modem's signal page and
**talk to your ISP**. Being clear-eyed about this saves weeks: this project's whole shaping
design is explicitly only aimed at the *under-load* kind.

## Reproducible escape hatch

Because it's all config-as-code and digest-pinned, the nuclear option is cheap:

```sh
git status                    # what did I change?
git checkout -- <file>        # undo it
sh bin/up.sh                  # rebuild containers from the committed pins
```

Blank SD card + this repo = the same box back. If you're deep in a hole, **rebuilding is
often faster than debugging** — that's the design working as intended.

## Getting help

Open a **[Discussion](https://github.com/hyperpolymath/core-network-outpost/discussions)**.
Please include: your device and OS, what you expected, what happened, and the output of the
commands above. Redact your public IP and any tokens.

---

## Coming: the one-button diagnostic bundle

> 📐 **Designed, not built.** No code yet — this describes the plan. Tracked as a project
> task; see [LLM-Legibility](LLM-Legibility) for the reasoning.

The intent is an `export diagnostics` command in the setup TUI/CLI that writes **one local
file you choose whether to share**:

- live state in a structured format, plus this deployment's topology
- **secret-sanitised** logs and config-as-code
- the relevant recovery recipes and doc pages
- a suggested prompt, so **your own LLM** can read it

**Read-only, no auto-upload, no on-box LLM.** The box gets *legible*; the reasoning happens
on whatever tool you bring. That split is deliberate — an LLM with write access to a security
box is prompt-injectable *through the very logs it reads*.
