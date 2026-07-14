#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
#
# Dynamic DNS updater for the outpost.
#
# PROVIDER-AGNOSTIC. This speaks the de-facto "dyndns2" update protocol, which
# Dynu, DuckDNS, No-IP, DynDNS and others all implement. Dynu is the endpoint in
# .env.example because it is what this outpost was built against — an EXAMPLE,
# not a recommendation. Repoint DDNS_UPDATE_URL at another dyndns2 provider and
# nothing else here changes.
#
# Runs from crond every 15 minutes (installed by host/setup.sh). It contacts the
# provider only when the public IP has ACTUALLY CHANGED. Blindly re-announcing an
# unchanged address every 15 minutes is how you get rate-limited or flagged as
# abuse, so don't.
#
#   sh host/ddns/ddns-update.sh           # normal (cron)
#   sh host/ddns/ddns-update.sh --force   # update even if the IP looks unchanged
#   sh host/ddns/ddns-update.sh --status  # print state; change nothing
#
# CREDENTIALS: never passed in argv. argv is world-readable through `ps`, so a
# "-u user:pass" style invocation would leak the password to every account on the
# box. They are fed to curl on stdin with "--config -" instead, and live only in
# .env (gitignored, chmod 600). Nothing secret is ever printed or committed.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
STATE_DIR="${OUTPOST_STATE_DIR:-/var/lib/outpost}"
STATE_FILE="$STATE_DIR/ddns.last"

MODE="cron"
case "${1:-}" in
  --force)  MODE="force" ;;
  --status) MODE="status" ;;
  "")       : ;;
  *) echo "usage: $0 [--force|--status]" >&2; exit 64 ;;
esac

log() { echo "[ddns] $*"; }
die() { echo "[ddns] error: $*" >&2; exit 1; }

# --- config ---------------------------------------------------------------
[ -f "$ROOT/.env" ] || die "no .env — copy .env.example to .env and set the DDNS_* values."

# The .env holds the provider credential. Warn if anyone but its owner can read it.
PERMS="$(stat -c '%a' "$ROOT/.env" 2>/dev/null || echo '')"
case "$PERMS" in
  600|400|'') : ;;
  *) log "WARNING: .env is mode $PERMS and contains your DDNS password."
     log "WARNING: fix with:  chmod 600 $ROOT/.env" ;;
esac

set -a; . "$ROOT/.env"; set +a

DDNS_ENABLED="${DDNS_ENABLED:-false}"
case "$DDNS_ENABLED" in
  true|yes|1) : ;;
  *) [ "$MODE" = "status" ] && log "DDNS_ENABLED=$DDNS_ENABLED — disabled."
     exit 0 ;;
esac

: "${DDNS_HOSTNAME:?DDNS_HOSTNAME not set in .env}"
: "${DDNS_USERNAME:?DDNS_USERNAME not set in .env}"
: "${DDNS_PASSWORD:?DDNS_PASSWORD not set in .env}"
DDNS_UPDATE_URL="${DDNS_UPDATE_URL:-https://api.dynu.com/nic/update}"
DDNS_IP_LOOKUP="${DDNS_IP_LOOKUP:-https://api.ipify.org}"
# Providers expire records that go unrefreshed (Dynu: ~30 days). Re-announce well
# before that even when the IP has not changed.
DDNS_MAX_AGE_DAYS="${DDNS_MAX_AGE_DAYS:-25}"

LAST_IP=""
LAST_AT=0
if [ -f "$STATE_FILE" ]; then
  LAST_IP="$(sed -n '1p' "$STATE_FILE" 2>/dev/null || true)"
  LAST_AT="$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo 0)"
fi
[ -n "${LAST_AT:-}" ] || LAST_AT=0

# --- what is our public IP? -----------------------------------------------
CUR_IP="$(curl -fsS --max-time 20 "$DDNS_IP_LOOKUP" 2>/dev/null || true)"
# It must really be a dotted quad. A captive portal splash or an error page must
# never be announced to DNS as our address.
case "$CUR_IP" in
  *[!0-9.]*|"")
    die "public IP lookup via $DDNS_IP_LOOKUP did not return an IPv4 address (got: '$(printf '%.40s' "${CUR_IP:-<empty>}")'...). Leaving DNS untouched."
    ;;
esac

NOW="$(date +%s)"
AGE_DAYS=$(( (NOW - LAST_AT) / 86400 ))

if [ "$MODE" = "status" ]; then
  log "hostname      : $DDNS_HOSTNAME"
  log "endpoint      : $DDNS_UPDATE_URL"
  log "public IP     : $CUR_IP"
  if [ -n "$LAST_IP" ]; then
    log "last announced: $LAST_IP (${AGE_DAYS}d ago)"
  else
    log "last announced: <never>"
  fi
  exit 0
fi

if [ "$MODE" != "force" ] && [ "$CUR_IP" = "$LAST_IP" ] && [ "$AGE_DAYS" -lt "$DDNS_MAX_AGE_DAYS" ]; then
  exit 0   # unchanged and not stale: say nothing, do nothing.
fi

if [ -z "$LAST_IP" ]; then
  log "first announce: $DDNS_HOSTNAME -> $CUR_IP"
elif [ "$CUR_IP" = "$LAST_IP" ]; then
  log "IP unchanged ($CUR_IP) but last announce was ${AGE_DAYS}d ago — refreshing before it expires."
else
  log "IP changed: $LAST_IP -> $CUR_IP — announcing."
fi

# --- announce --------------------------------------------------------------
# dyndns2: GET <url>?hostname=H&myip=IP with HTTP Basic auth.
# Credentials go over stdin, NOT argv (see header).
RESP="$(printf 'user = "%s:%s"\n' "$DDNS_USERNAME" "$DDNS_PASSWORD" | \
  curl -fsS --max-time 30 --config - \
       --data-urlencode "hostname=$DDNS_HOSTNAME" \
       --data-urlencode "myip=$CUR_IP" \
       --get "$DDNS_UPDATE_URL" 2>/dev/null || true)"

case "$RESP" in
  good*|nochg*)
    mkdir -p "$STATE_DIR"
    printf '%s\n%s\n' "$CUR_IP" "$NOW" > "$STATE_FILE"
    chmod 600 "$STATE_FILE" 2>/dev/null || true
    log "ok: $DDNS_HOSTNAME -> $CUR_IP ($(echo "$RESP" | cut -d' ' -f1))"
    ;;
  badauth*)
    die "provider says badauth — DDNS_USERNAME / DDNS_PASSWORD in .env are wrong. Not retrying; fix the credential."
    ;;
  nohost*)
    die "provider says nohost — '$DDNS_HOSTNAME' is not a hostname on this account."
    ;;
  abuse*)
    die "provider says abuse — this account/hostname is blocked. Stop and contact the provider."
    ;;
  911*|dnserr*)
    die "provider-side failure ('$RESP'). Transient; cron will retry."
    ;;
  "")
    die "no/failed response from $DDNS_UPDATE_URL. Transient; cron will retry."
    ;;
  *)
    die "unrecognised provider response: '$(printf '%.60s' "$RESP")'"
    ;;
esac
