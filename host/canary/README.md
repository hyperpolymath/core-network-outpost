<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Canary — scheduled, report-only base watch

Runs `bin/canary.sh` on a schedule. It only **reports** (a new AdGuard Home
release exists, or the pinned digest drifted at source) — it **never applies** an
upgrade. Applying stays a deliberate maintainer action (`bin/bump.sh --apply`).
See [`../../.github/GOVERNANCE.md`](../../.github/GOVERNANCE.md) § "Policy 1".

Runs on **owned compute** (the Pi itself, or your host) — deliberately **not**
GitHub Actions, per the estate's $0-Actions / run-local posture.

## Alpine (the Pi 2B) — busybox crond

`host/setup.sh` already installs this: it writes
`/etc/periodic/weekly/outpost-canary` (from `weekly-outpost-canary.in`, with the
repo path substituted) and enables `crond`. Manual equivalent:

```sh
sed "s|__OUTPOST_DIR__|$(pwd)|" host/canary/weekly-outpost-canary.in \
  > /etc/periodic/weekly/outpost-canary
chmod +x /etc/periodic/weekly/outpost-canary
rc-update add crond && rc-service crond start
```

## systemd (64-bit Pi OS / Debian, or the WSL host)

```sh
sudo cp host/canary/outpost-canary.service host/canary/outpost-canary.timer /etc/systemd/system/
# edit WorkingDirectory/ExecStart paths in the .service first
sudo systemctl enable --now outpost-canary.timer
```

## Notifications (optional)

By default the canary logs to `/var/log/outpost-canary.log` and `logger`/syslog.
To get pushed a message, create `/etc/outpost/canary.env`:

```sh
# any command that reads the report on stdin
OUTPOST_NOTIFY='curl -s -d @- https://ntfy.sh/your-private-topic'
# or: OUTPOST_NOTIFY='mail -s "[outpost]" you@example.com'
OUTPOST_LOG=/var/log/outpost-canary.log
```

## Test it now

```sh
sh bin/canary.sh        # prints a report if action is needed; silent-ish otherwise
```
