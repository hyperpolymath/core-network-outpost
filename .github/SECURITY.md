<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Security Policy

`outpost` is a piece of home-network infrastructure (DNS, firewall, print
server), so security reports are taken seriously despite the small scope.

## Reporting

- **Preferred:** GitHub private vulnerability reporting (Security ▸ Report a
  vulnerability) on this repo, if enabled.
- **Email:** jonathan.jewell@gmail.com — subject prefixed `[outpost security]`.
- Please do **not** open a public issue for a vulnerability.

Org-wide policy (if stricter) lives in `hyperpolymath/.github` and takes
precedence where it applies.

## Scope notes

- The base image is digest-pinned in `images.lock`; `bin/bump.sh --verify`
  detects upstream tag/digest drift. Report unexpected drift.
- The firewall (`host/nftables.nft`) is default-deny and LAN-scoped. Report any
  config here that widens the box's exposed surface unintentionally.
- This box is **not** intended to face the public internet. Findings that assume
  internet exposure should say so.

## Supported

Only the current `main`. There are no maintained release branches.
