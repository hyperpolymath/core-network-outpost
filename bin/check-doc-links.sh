#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# check-doc-links.sh — every documentation reference must point at a real file.
#
# Enforces the repo's two-part reference convention:
#   1. CLICKABLE LINKS  — markdown [text](path) / asciidoc link:path[] — are
#      resolved RELATIVE TO THE FILE, because that is what GitHub follows.
#   2. PROSE MENTIONS   — `backticked/path.md` — are resolved RELATIVE TO THE
#      REPO ROOT. Root-relative prose survives the *referring* file being moved,
#      which is the failure this check exists to prevent.
#
# Exit 0 = every reference resolves. Exit 1 = at least one is dead.
# Run before committing any docs move.

# shellcheck disable=SC2016  # backticks in the greps are literal characters, not command substitution
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
repo=$(pwd -P)
fail=0

# Skip this script: its own comments contain illustrative paths (`docs/X.md`,
# link:path.adoc[]) that are examples of the convention, not references to files.
scan=$(git ls-files | grep -E '\.(md|adoc|sh|nft|service|timer|conf|ya?ml|example|in)$' \
       | grep -v '^bin/check-doc-links\.sh$')

for f in $scan; do
  dir=$(dirname "$f")

  # ---- 1. clickable links: file-relative ----------------------------------
  # markdown [x](./path.md)  and asciidoc link:path.adoc[]
  links=$(grep -oE '\]\([^)]+\.(md|adoc)\)|link:[A-Za-z0-9._/-]+\.(md|adoc)\[' "$f" 2>/dev/null \
          | sed -E 's/^\]\(//; s/\)$//; s/^link://; s/\[$//' | sort -u)
  for l in $links; do
    case "$l" in http*|'#'*) continue;; esac
    t=$(realpath -m "$dir/${l%%#*}" 2>/dev/null)
    case "$t" in "$repo"*) ;; *) continue;; esac
    if [ ! -e "$t" ]; then
      echo "  ❌ LINK   $f → $l  (file-relative; missing: ${t#"$repo"/})"
      fail=1
    fi
  done

  # ---- 2. prose mentions: repo-root-relative ------------------------------
  # only paths containing a "/" — a bare `foo.md` is a filename, not a path
  prose=$(grep -oE '`[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+\.(md|adoc)`' "$f" 2>/dev/null \
          | tr -d '`' | sort -u)
  for p in $prose; do
    case "$p" in http*|../*|./*) continue;; esac
    if [ ! -e "$repo/$p" ]; then
      echo "  ❌ PROSE  $f → \`$p\`  (root-relative; missing: $p)"
      fail=1
    fi
  done

  # ---- 3. no ../ in prose mentions (breaks when the referrer moves) -------
  if grep -qE '`\.\./[A-Za-z0-9._/-]+\.(md|adoc)`' "$f" 2>/dev/null; then
    bad=$(grep -oE '`\.\./[A-Za-z0-9._/-]+\.(md|adoc)`' "$f" | tr -d '`' | sort -u | tr '\n' ' ')
    echo "  ⚠️  STYLE  $f uses ../ in a prose mention ($bad) — use a root-relative path"
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  echo "  ✅ every documentation reference resolves to a real file"
fi
exit $fail
