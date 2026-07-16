#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# wiki-sync.sh — publish wiki/ (source of truth, in this repo) to the GitHub wiki.
#
# WHY THIS EXISTS
#   A GitHub wiki is a SEPARATE git repo: outside this repo's review, history and
#   backups, and editable out-of-band. For a security appliance that is the wrong
#   default — a wiki page is exactly where someone would slip in a malicious
#   `curl … | sh`, and it would look entirely normal. Keeping the source in this
#   repo means wiki edits go through PR review, like the code.
#
#   Also set: Settings -> Features -> Wikis -> restrict editing to collaborators.
#
# USAGE
#   sh bin/wiki-sync.sh --check   # show what would change; touch nothing (exit 1 if drift)
#   sh bin/wiki-sync.sh           # publish wiki/ to the GitHub wiki
#
# SAFETY
#   --check is read-only and is the default thing to run first. A publish will
#   report any page that was edited in the web UI (i.e. that this would clobber)
#   and require --force to proceed, so out-of-band edits are never silently lost.

set -euo pipefail

cd "$(dirname "$0")/.."
repo_root=$(pwd -P)
src="$repo_root/wiki"

remote=$(git config --get remote.origin.url)
wiki_remote="${remote%.git}.wiki.git"

check_only=0
force=0
for a in "$@"; do
  case "$a" in
    --check) check_only=1 ;;
    --force) force=1 ;;
    -h|--help) sed -n '4,26p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

[ -d "$src" ] || { echo "no wiki/ directory at $src" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "→ cloning $wiki_remote"
if ! git clone --quiet "$wiki_remote" "$tmp/wiki" 2>/dev/null; then
  cat >&2 <<EOF
Could not clone the wiki repo.

If this is the first ever sync, the wiki must be initialised once by hand:
  GitHub -> the repo -> Wiki tab -> "Create the first page" -> Save.
Then re-run this script.
EOF
  exit 1
fi

# --- detect out-of-band edits (pages that differ AND weren't changed by us) ---
drift=""
for published in "$tmp"/wiki/*.md; do
  [ -e "$published" ] || continue
  name=$(basename "$published")
  if [ ! -e "$src/$name" ]; then
    drift="$drift  ! $name — exists in the wiki but not in wiki/ (would be DELETED)\n"
  fi
done

changed=""
for f in "$src"/*.md; do
  name=$(basename "$f")
  if [ ! -e "$tmp/wiki/$name" ]; then
    changed="$changed  + $name (new)\n"
  elif ! diff -q "$f" "$tmp/wiki/$name" >/dev/null 2>&1; then
    changed="$changed  ~ $name (updated)\n"
  fi
done

if [ -z "$changed" ] && [ -z "$drift" ]; then
  echo "✅ wiki is already in sync with wiki/ — nothing to do"
  exit 0
fi

[ -n "$changed" ] && { echo; echo "Pages to publish:"; printf "%b" "$changed"; }
[ -n "$drift" ] && { echo; echo "⚠️  Pages only in the published wiki (edited in the web UI?):"; printf "%b" "$drift"; }

if [ "$check_only" -eq 1 ]; then
  echo
  echo "(--check: nothing was changed)"
  exit 1
fi

if [ -n "$drift" ] && [ "$force" -eq 0 ]; then
  echo
  echo "Refusing to publish: the wiki contains pages that wiki/ does not." >&2
  echo "Either copy them into wiki/ and commit, or re-run with --force to delete them." >&2
  exit 1
fi

# --- publish ---
find "$tmp/wiki" -maxdepth 1 -name '*.md' -delete
cp "$src"/*.md "$tmp/wiki/"

cd "$tmp/wiki"
git add -A
if git diff --cached --quiet; then
  echo "✅ nothing to commit — wiki already current"
  exit 0
fi

rev=$(git -C "$repo_root" rev-parse --short HEAD)
git -c user.name="$(git -C "$repo_root" config user.name)" \
    -c user.email="$(git -C "$repo_root" config user.email)" \
    commit --quiet -m "wiki: sync from core-network-outpost@${rev}

Source of truth is wiki/ in the main repo. Do not edit here — edits are
overwritten by the next sync. Send a PR against wiki/ instead."

git push --quiet origin HEAD
echo
echo "✅ published to ${wiki_remote%.git}"
echo "   https://github.com/hyperpolymath/core-network-outpost/wiki"
