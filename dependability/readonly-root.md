<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Read-only root — the single highest-value dependability change [dep+]

Runtime writes never touch the SD/root, so it **can't be worn out or corrupted by
normal operation** (the #1 Pi failure mode) *and* the base is immutable (a security
win too). Two honest paths, because the two boxes differ:

> ⚠️ **Test on a spare card first.** A wrong writable-path list silently hides real
> config changes ("why didn't my edit stick?"). Dependability-first means proving it.

## Pi 2B (Alpine) — you already have this, natively
Alpine's **diskless / run-from-RAM** mode boots the system into RAM from read-only
media; deliberate changes are committed explicitly:
```sh
lbu commit -d        # persist the current config to the boot media
lbu status           # show what would be committed
```
Nothing else to install. Keep `/var/log` in RAM (default) and ship logs to Loki, or
add `log2ram` if you want them to survive a reboot. This is arguably *cleaner* than
bolting an overlay onto a mutable distro.

## Debian / Raspberry Pi OS / N100 — `overlayroot`
```sh
apt-get install -y overlayroot
```
`/etc/overlayroot.conf`:
```
# Writes go to a tmpfs overlay and vanish on reboot. Persist deliberate changes with
# `overlayroot-chroot` (edit), or set overlayroot="" , change, then re-enable.
overlayroot="tmpfs:swap=1,recurse=0"
```
Volatile paths as size-capped tmpfs — append to `/etc/fstab` (a runaway log then
fills RAM, not the card, and is bounded):
```
tmpfs  /tmp      tmpfs  defaults,noatime,nosuid,nodev,size=128M  0 0
tmpfs  /var/tmp  tmpfs  defaults,noatime,nosuid,nodev,size=64M   0 0
tmpfs  /var/log  tmpfs  defaults,noatime,nosuid,nodev,size=64M   0 0
```
`/var/log` in tmpfs loses logs on reboot — fine when they're shipped to Loki; use
**log2ram** (periodic writeback) if you need them to persist locally.

## The pairing that makes it safe
Read-only root + **bounded logging** + **logs shipped to Loki** together mean the box
can run for years without the card degrading, and a crash loses nothing important.
