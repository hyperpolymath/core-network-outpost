#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
#
# bump.sh — maintainer-gated base-image bump for the outpost.
#
# Refreshes the AdGuard Home image digest FROM SOURCE and repins it in
# images.lock — but only when the maintainer makes the upgrade choice.
# Detection and application are separated on purpose (report-only by default).
#
# Usage:
#   sh bin/bump.sh                 # check only: is a newer version available?
#   sh bin/bump.sh --check         #   (same; exit 0 = up to date, 10 = upgrade available)
#   sh bin/bump.sh --apply         # bump to LATEST, after y/N confirmation
#   sh bin/bump.sh --apply --to vX.Y.Z   # bump to a SPECIFIC version (still gated)
#   sh bin/bump.sh --apply --yes   # non-interactive accept (you already decided)
#   sh bin/bump.sh --verify        # re-resolve the CURRENT pin from source; assert no drift
#
# Dependencies: curl + POSIX sh + sed/awk/grep (no jq/python needed).

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOCK="$ROOT/images.lock"
[ -f "$LOCK" ] || { echo "images.lock missing — run from the outpost repo." >&2; exit 1; }

# Load current pin.
# shellcheck disable=SC1090
. "$LOCK"

MODE=check
TARGET_VERSION=
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE=check ;;
    --apply)   MODE=apply ;;
    --verify)  MODE=verify ;;
    --to)      shift; TARGET_VERSION="${1:?--to needs a version, e.g. v0.107.77}" ;;
    --to=*)    TARGET_VERSION="${1#--to=}" ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) sed -n '3,22p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# --- source resolvers ---------------------------------------------------------

latest_version() {
  curl -fsSL "https://api.github.com/repos/${AGH_GH_REPO}/releases/latest" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

# Resolve the multi-arch manifest-list digest for repo:tag from Docker Hub.
resolve_digest() { # $1 = tag
  _tag="$1"
  _tok=$(curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${AGH_IMAGE_REPO}:pull" \
         | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -n "$_tok" ] || { echo "could not obtain registry token" >&2; return 1; }
  curl -fsSL -o /dev/null -D - \
    -H "Authorization: Bearer ${_tok}" \
    -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
    -H "Accept: application/vnd.oci.image.index.v1+json" \
    "https://registry-1.docker.io/v2/${AGH_IMAGE_REPO}/manifests/${_tag}" \
    | awk 'tolower($1)=="docker-content-digest:"{gsub(/\r/,"",$2); print $2; exit}'
}

# Best-effort: warn (don't fail) if the index lacks an armv7 variant.
assert_armv7() { # $1 = tag
  _tag="$1"
  _tok=$(curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${AGH_IMAGE_REPO}:pull" \
         | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  _body=$(curl -fsSL \
    -H "Authorization: Bearer ${_tok}" \
    -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
    -H "Accept: application/vnd.oci.image.index.v1+json" \
    "https://registry-1.docker.io/v2/${AGH_IMAGE_REPO}/manifests/${_tag}")
  if printf '%s' "$_body" | grep -q '"architecture": *"arm"' \
     && printf '%s' "$_body" | grep -q '"variant": *"v7"'; then
    return 0
  fi
  echo "WARNING: ${AGH_IMAGE_REPO}:${_tag} manifest does not appear to include linux/arm/v7." >&2
  echo "         A Pi 2B (armv7) may not be able to run this image. Proceed with care." >&2
  return 0
}

# --- verify mode: drift check on the CURRENT pin ------------------------------

if [ "$MODE" = verify ]; then
  got=$(resolve_digest "$AGH_VERSION") || exit 1
  if [ "$got" = "$AGH_DIGEST" ]; then
    echo "OK: ${AGH_IMAGE_REPO}:${AGH_VERSION} still resolves to the pinned digest."
    exit 0
  fi
  echo "DRIFT: pinned ${AGH_DIGEST}" >&2
  echo "       source ${got} for ${AGH_VERSION}" >&2
  echo "(tag was re-pushed upstream, or registry changed — investigate before re-pinning.)" >&2
  exit 1
fi

# --- determine target ---------------------------------------------------------

if [ -n "$TARGET_VERSION" ]; then
  NEW_VER="$TARGET_VERSION"
else
  NEW_VER=$(latest_version) || true
fi
[ -n "${NEW_VER:-}" ] || { echo "could not determine target version from source." >&2; exit 1; }

NEW_DIG=$(resolve_digest "$NEW_VER") || exit 1
[ -n "$NEW_DIG" ] || { echo "could not resolve a digest for ${NEW_VER}." >&2; exit 1; }

echo "current:  ${AGH_VERSION}  ${AGH_DIGEST}"
echo "proposed: ${NEW_VER}  ${NEW_DIG}"

if [ "$NEW_VER" = "$AGH_VERSION" ] && [ "$NEW_DIG" = "$AGH_DIGEST" ]; then
  echo "already up to date — nothing to do."
  exit 0
fi

# --- check mode: report only (matches 'detect, do not auto-apply') ------------

if [ "$MODE" = check ]; then
  echo
  echo "An upgrade is available. The maintainer applies it explicitly:"
  echo "  sh bin/bump.sh --apply              # newest, with confirmation"
  echo "  sh bin/bump.sh --apply --to ${NEW_VER}"
  exit 10   # 10 = upgrade available (so a report-only notifier can key off it)
fi

# --- apply mode: the maintainer's upgrade choice ------------------------------

assert_armv7 "$NEW_VER"

if [ "$ASSUME_YES" -ne 1 ]; then
  printf "Repin AdGuard Home %s -> %s ? [y/N] " "$AGH_VERSION" "$NEW_VER"
  read -r ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "aborted; images.lock unchanged."; exit 1 ;;
  esac
fi

NEW_IMAGE="${AGH_IMAGE_REPO}@${NEW_DIG}"
STAMP=$(date -u +%Y-%m-%d)
tmp="${LOCK}.tmp.$$"

sed -e "s|^AGH_VERSION=.*|AGH_VERSION=${NEW_VER}|" \
    -e "s|^AGH_DIGEST=.*|AGH_DIGEST=${NEW_DIG}|" \
    -e "s|^AGH_IMAGE=.*|AGH_IMAGE=${NEW_IMAGE}|" \
    -e "s|^AGH_BUMPED_UTC=.*|AGH_BUMPED_UTC=${STAMP}|" \
    "$LOCK" > "$tmp"
mv "$tmp" "$LOCK"

echo
echo "repinned in images.lock:"
echo "  ${NEW_IMAGE}"
echo
echo "next steps:"
echo "  git --no-pager diff images.lock     # review the repin"
echo "  sh bin/up.sh                        # pull + recreate the container"
echo "  git commit -am 'outpost: bump AdGuard Home to ${NEW_VER}'"
