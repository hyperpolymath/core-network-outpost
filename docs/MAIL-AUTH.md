<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
# Optional module: mail-domain authentication (the DNS/policy layer — NOT an MTA)

**Status: strong Tier-4 candidate.** A form-driven, set-and-forget helper that makes a
domain's mail authentication *provably correct*. The pain is real and no router does it —
a genuine differentiator, **if** scoped as below.

## Hard scope — what it IS and ISN'T
**IS:** a generator + validator + signer + monitor for a domain's mail-auth **DNS records
and policies**. Set-and-forget (these change rarely) — matches your "neatly separated, don't
mess with the daily computer" instinct exactly.

**IS NOT:**
- **Not an MTA.** No SMTP, no SpamAssassin/Bayes on the box — that's *inbound* mail filtering
  and belongs at your mailbox provider. (You already said no MTA; this respects it.)
- **Not PTR, not home-sending.** PTR (rDNS) is owned by whoever owns the IP block — your **ISP**,
  not you — and **Virgin blocks outbound :25**. So you **cannot** send real mail from home or set
  your own PTR. This module manages the DNS auth for a domain whose mail is *sent via a proper
  provider* (Fastmail / Migadu / a VPS relay). It can *check* PTR and tell you what to ask the
  provider for — it can't set it.

## What it manages
SPF (TXT), DKIM (TXT public key + rotation reminders), DMARC (TXT policy + rua/ruf reporting),
MTA-STS (TXT + the policy file at `mta-sts.<domain>` over HTTPS), TLSA/DANE, all under
**DNSSEC + ZONEMD**.

## Dependability-safe architecture (the crux — two sharp risks)
1. **An authoritative nameserver is inherently PUBLIC** — conflicts with dark-by-default.
   → **Don't serve authoritative DNS from the box.** Either (a) **hidden primary** (box signs,
   AXFRs to public secondaries — stays dark, owns source-of-truth); or **(b, cleaner for you)**
   emit the records as code and **publish via your existing `cloudflare-dns-terraform`** —
   Cloudflare serves them authoritatively **with its own managed DNSSEC**. No public DNS surface
   on the box, no fragile self-run signing. **Prefer (b).**
2. **DNSSEC is unforgiving** — an expired signature or botched key-roll takes the **whole domain
   offline (mail *and* web)**. Autoconfig-for-novices is a footgun unless the automation is
   bulletproof: auto-resign well before expiry, monitor signature validity + DS/DNSKEY match,
   safe rollback. The Cloudflare path (b) sidesteps this by letting Cloudflare own DNSSEC — far
   more dependable than self-signing on an appliance.

## The compelling, LOW-risk half: monitoring
- **Ingest DMARC aggregate (rua) reports → the dashboard.** This is where everyone is blind:
  who's sending as you, what passes/fails *alignment*, and whether it's safe to ramp
  `p=none → quarantine → reject`. Read-only, safe, high value, and it plugs straight into your
  Prometheus/Loki/Phoenix stack.
- Continuous external validation: does live DNS still match intent? are certs/signatures near expiry?

## Placement
Tier-4 **optional module**, isolated, off by default. Positioned right ("finally make
SPF/DKIM/DMARC/DNSSEC human-easy") it's a strong "on offer to the world" differentiator —
so long as it stays the **DNS-auth layer + DMARC dashboard**, never an MTA.
