#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
#
# Launch AdGuard Home from the committed, digest-pinned base in images.lock.
# Refuses to start on a floating (un-pinned) tag — reproducibility guard.
#
#   sh bin/up.sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

[ -f images.lock ] || { echo "images.lock missing — run from the outpost repo." >&2; exit 1; }

# Local, non-committed overrides first (TZ, LAN_SUBNET, SSH_PORT)...
if [ -f .env ]; then set -a; . ./.env; set +a; fi
# ...then the committed pin, which WINS over anything in .env.
set -a; . ./images.lock; set +a

: "${AGH_IMAGE:?AGH_IMAGE not set in images.lock}"
export TZ="${TZ:-UTC}"

# Reproducibility guard: never boot on a moving tag.
case "$AGH_IMAGE" in
  *@sha256:*) : ;;
  *)
    echo "refusing to launch: AGH_IMAGE is not digest-pinned:" >&2
    echo "  $AGH_IMAGE" >&2
    echo "run 'sh bin/bump.sh --apply' to pin a digest from source." >&2
    exit 1
    ;;
esac

mkdir -p adguardhome/conf adguardhome/work
echo ">> AdGuard Home base (pinned): $AGH_IMAGE"
exec podman-compose -f compose/adguardhome.yaml up -d
