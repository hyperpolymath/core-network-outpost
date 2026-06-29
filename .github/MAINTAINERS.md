<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Maintainers

| Name | GitHub | Role | Scope |
|------|--------|------|-------|
| Jonathan Jewell | [@hyperpolymath](https://github.com/hyperpolymath) | Maintainer / owner | All of `outpost` |

This is a single-maintainer homelab project. See [GOVERNANCE.md](GOVERNANCE.md)
for how decisions are made, and [CODEOWNERS](CODEOWNERS) for review routing.

## Areas

| Area | Path | Notes |
|------|------|-------|
| DNS sinkhole | `compose/`, `adguardhome/` | AdGuard Home, digest-pinned |
| Pinned base + bumps | `images.lock`, `bin/` | maintainer-gated (see GOVERNANCE) |
| Host firewall | `host/nftables.nft` | default-deny, LAN-scoped |
| Print server | `host/cups/`, `host/avahi/` | CUPS + mDNS on the host |
| Future sketches | `roadmap/` | not built; intent only |

## Contact

Open an issue, or email the address in `SECURITY.md` for security matters.
