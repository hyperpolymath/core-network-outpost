<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Governance

`outpost` is a small, single-maintainer homelab project. Governance is
deliberately lightweight, but two things are **policy**, not just habit.

## Roles

- **Maintainer** — sole decision-maker; see [MAINTAINERS.md](MAINTAINERS.md).
- **Contributors** — anyone opening issues/PRs. Welcome, but changes to the
  surfaces below require explicit maintainer sign-off.

## Decision process

Day-to-day: lazy consensus on PRs. The maintainer merges. Linear history;
squash or rebase only (no merge commits).

## Policy 1 — base images are maintainer-gated

The pinned container base lives in [`/images.lock`](../images.lock) as a
**multi-arch manifest-list digest** (the reproducible base the appliance boots
from). It is changed **only** by a deliberate maintainer action:

- Detection is automated and **report-only**: `sh bin/bump.sh --check`
  (exit `10` = an upgrade is available) and `sh bin/bump.sh --verify`
  (assert the current pin still matches source — supply-chain drift check).
- Application is a separate, explicit choice: `sh bin/bump.sh --apply`, which
  re-resolves the digest from source and repins **only after the maintainer
  confirms**. The resulting `images.lock` change is reviewed and committed like
  any other diff.

A weekly **canary** (`bin/canary.sh`, installed as a crond/systemd job on owned
compute — never GitHub Actions) runs exactly those report-only modes and pings
the maintainer when there is something to decide. It cannot apply anything.

Rationale: detection without auto-application. The tool never silently moves the
base; a human makes the upgrade call. Never pin or boot a floating tag —
`bin/up.sh` refuses to launch anything not pinned to a `@sha256:` digest.

## Policy 2 — surface-changing edits need review

Changes to `host/nftables.nft`, `host/cups/`, or anything that alters the box's
exposed network surface get extra scrutiny (this is, after all, a piece of
network infrastructure). Default-deny stays default-deny.

## Security

Report security issues per [SECURITY.md](SECURITY.md) (or the org-level policy
in `hyperpolymath/.github`) — not in public issues.

## Changing this document

Amendments are a maintainer decision, recorded in git history.
