#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
#
# Idempotent Alpine Linux bootstrap for the outpost.
# Run as root on the Pi 2B:   sudo sh host/setup.sh
#
# Assumes a fresh Alpine (armv7). Re-running is safe.

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$REPO_DIR"

echo ">> outpost bootstrap  (repo: $REPO_DIR)"

# ---------------------------------------------------------------------------
# 0. Sanity: warn loudly if this isn't 32-bit ARM (then this stack's base-OS
#    choice may be wrong — you might want the Wolfi/aarch64 path in roadmap/).
# ---------------------------------------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
  armv7l|armhf) : ;;
  aarch64) echo "!! uname -m = aarch64 — this is a 64-bit Pi. Alpine is fine, but"
           echo "!! you could also use Wolfi here. See roadmap/PI4-AND-BEYOND.md." ;;
  *) echo "!! Unexpected arch '$ARCH'. Proceeding, but review docs/INSTALL.md." ;;
esac

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
echo ">> installing packages"
apk update
apk add --no-cache \
  podman podman-compose \
  cups cups-filters cups-pdf \
  avahi avahi-tools dbus \
  nftables \
  curl tzdata

# ---------------------------------------------------------------------------
# 2. Container runtime prerequisites (cgroups + tun)
# ---------------------------------------------------------------------------
echo ">> enabling cgroups + tun for podman"
rc-update add cgroups boot 2>/dev/null || true
grep -qxF tun /etc/modules 2>/dev/null || echo tun >> /etc/modules
modprobe tun 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Firewall
# ---------------------------------------------------------------------------
echo ">> installing nftables ruleset"
install -m 0644 host/nftables.nft /etc/nftables.nft
rc-update add nftables 2>/dev/null || true
rc-service nftables restart || rc-service nftables start

# ---------------------------------------------------------------------------
# 4. Print server (CUPS + Avahi/mDNS) — on the HOST, not containerised
# ---------------------------------------------------------------------------
echo ">> configuring CUPS + Avahi"
install -m 0644 host/cups/cupsd.conf /etc/cups/cupsd.conf
install -m 0644 host/avahi/airprint.service /etc/avahi/services/airprint.service 2>/dev/null || true

for svc in dbus avahi-daemon cupsd; do
  rc-update add "$svc" 2>/dev/null || true
done
rc-service dbus restart || rc-service dbus start
rc-service avahi-daemon restart || rc-service avahi-daemon start
rc-service cupsd restart || rc-service cupsd start

echo "   add your printer at: http://<pi-ip>:631  (Administration tab)"
echo "   then 'Share printers connected to this system' must be ticked."

# ---------------------------------------------------------------------------
# 5. AdGuard Home container
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
  echo "!! No .env found — copy .env.example to .env and edit it, then re-run."
  echo "!! (skipping container start for now)"
  exit 0
fi

echo ">> starting AdGuard Home"
mkdir -p adguardhome/conf adguardhome/work
rc-update add podman 2>/dev/null || true
rc-service podman start 2>/dev/null || true
# Launch via the wrapper so the digest-pinned base from images.lock is used
# (and the un-pinned-tag guard runs).
sh bin/up.sh

# ---------------------------------------------------------------------------
# 6. Report-only canary (weekly base-upgrade / drift check) — owned compute
# ---------------------------------------------------------------------------
echo ">> installing weekly canary (report-only; never auto-applies)"
sed "s|__OUTPOST_DIR__|$REPO_DIR|" host/canary/weekly-outpost-canary.in \
  > /etc/periodic/weekly/outpost-canary
chmod +x /etc/periodic/weekly/outpost-canary
rc-update add crond 2>/dev/null || true
rc-service crond start 2>/dev/null || rc-service crond restart || true
echo "   (optional) create /etc/outpost/canary.env to enable push notifications —"
echo "   see host/canary/README.md"


# ---------------------------------------------------------------------------
# 7. Dynamic DNS (optional; only if DDNS_ENABLED=true in .env)
# ---------------------------------------------------------------------------
if [ -f .env ] && grep -qE '^DDNS_ENABLED=(true|yes|1)' .env; then
  echo ">> installing DDNS updater (every 15 min; announces only on IP change)"
  sed "s|__OUTPOST_DIR__|$REPO_DIR|" host/ddns/outpost-ddns.in \
    > /etc/periodic/15min/outpost-ddns
  chmod +x /etc/periodic/15min/outpost-ddns
  rc-update add crond 2>/dev/null || true
  rc-service crond start 2>/dev/null || rc-service crond restart || true
  # Announce once now so the record is correct immediately, rather than waiting
  # up to 15 minutes for the first cron tick.
  sh host/ddns/ddns-update.sh --force || echo "!! first DDNS announce failed — check 'sh host/ddns/ddns-update.sh --status'"
else
  echo ">> DDNS not enabled (set DDNS_ENABLED=true in .env to turn it on) — skipping"
fi

echo
echo ">> done."
echo "   AdGuard first-run wizard: http://<pi-ip>:3000"
echo "   After the wizard, copy adguardhome/conf/AdGuardHome.yaml into git (see INSTALL.md)."
echo "   Check for base upgrades any time:  sh bin/bump.sh --check"
