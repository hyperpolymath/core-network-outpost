# Your Domain + Mail DNS — done right

> **Mixed status — read carefully.** The DNS records here are ✅ **doable today by hand**, and
> that's how you should do them. The **mail-auth module** that automates this is 📐 **designed,
> not built** — spec at
> [`docs/MAIL-AUTH.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/MAIL-AUTH.md).
> Don't wait for it.

**Your domain is the one piece of your identity nobody can take away** — you can move hosts,
change generators, switch mail providers, and keep it. It's also the thing most likely to be
misconfigured in a way you never notice until your mail silently stops arriving.

---

## First, the two hard truths about mail from home

**Read these before you plan anything.** They're not obstacles to route around; they're the
shape of reality.

1. **You cannot send real mail from a home connection.** Residential IP ranges sit on
   permanent blocklists **by design** (Spamhaus PBL and friends). It's policy, not a bug, and
   there's no appeal. **Virgin Media blocks outbound port 25** anyway.
2. **You don't own your PTR/rDNS record** — whoever owns the IP block does, i.e. your ISP.
   You cannot set it. Every "proper mail server" guide assumes you can. You can't.

**So: no MTA on this box. Ever.** That's a deliberate scope decision, not a missing feature.
Send through a real provider — **Fastmail**, **Migadu**, or a VPS relay — and use this page to
authenticate *your domain* so their mail is provably yours.

## What this page is (and isn't)

| It IS | It IS NOT |
|---|---|
| The **DNS and policy layer** for your domain's mail | An MTA — no SMTP server, ever |
| SPF, DKIM, DMARC, MTA-STS, DANE, under DNSSEC | Inbound spam filtering (SpamAssassin/Bayes) — that's your mailbox provider's job |
| Set-and-forget — these change rarely | PTR, or home-sending. Both impossible; see above. |

## 1. Get a domain and put it on Cloudflare

Any registrar. Then use **Cloudflare for DNS** (free), because:

- **Cloudflare owns DNSSEC for you** — this is the big one, see the warning below
- Free WAF/DDoS/TLS for the site in front
- It's where [Publish It](IndieWeb-Publish) points anyway

> ⚠️ **Do not self-host authoritative DNS for your domain.** Two reasons, both painful:
> an authoritative nameserver is **inherently public**, which fights the dark-by-default
> design of this whole estate; and **DNSSEC is unforgiving** — one expired signature or
> botched key-roll takes your **entire domain offline, mail and web together**. Letting
> Cloudflare own DNSSEC is *more dependable than doing it yourself*, and it costs nothing.
> Dependability first, even when it means not running the thing.

**Turn DNSSEC on** in the Cloudflare dashboard (DNS → Settings → Enable DNSSEC), then add the
DS record it gives you at your **registrar**. That last step is easy to forget and it's the
one that makes it work.

## 2. Point the domain at your site

Cloudflare Pages → *Custom domains* → add your domain. It writes the records for you.

## 3. Authenticate your mail

Three records. **They only work together** — SPF alone is close to worthless.

### SPF — who may send as you

```
Type: TXT   Name: @   Value: v=spf1 include:spf.messagingengine.com -all
```

Use *your provider's* `include:` (that example is Fastmail's). Then:

- **`-all` (hard fail)** — what you want, once you're sure the list is complete.
- **`~all` (soft fail)** — start here if unsure.
- ⚠️ **Max 10 DNS lookups.** Chained `include:`s blow this limit silently and SPF just stops
  working. One or two providers is fine; five is a bug.

### DKIM — cryptographically sign it

Your provider generates the key and gives you the record — usually a `CNAME`:

```
Type: CNAME   Name: fm1._domainkey   Value: fm1.example.com.dkim.fmhosted.com
```

Just paste what they give you. Set a reminder to **rotate the key** yearly.

### DMARC — tie it together and *get reports*

**This is the one that pays for itself**, because it's the only one that tells you what's
happening:

```
Type: TXT   Name: _dmarc   Value: v=DMARC1; p=none; rua=mailto:dmarc@example.com; fo=1
```

> **Start at `p=none`. Read the reports for a few weeks. Then tighten.**
>
> `p=none` means "don't block anything, just tell me". The reports show **who is sending as
> you** and **what fails alignment** — and the answer is almost always something legitimate
> you forgot: a newsletter tool, a booking system, your accountant's invoicing thing. Jumping
> straight to `p=reject` is how people discover those systems *by breaking them*.
>
> Ramp: **`none` → `quarantine` → `reject`**, only as the reports come clean.

### MTA-STS + TLSA/DANE — optional, later

MTA-STS says "always use TLS to reach me". It needs a TXT record **and** a policy file served
over HTTPS at `mta-sts.<domain>` — which your static host can serve. Nice to have; do the
three above first, they're 95 % of the value.

## 4. Verify you got it right

**Check, don't assume.** These are free:

- **[MXToolbox](https://mxtoolbox.com/SuperTool.aspx)** — SPF/DKIM/DMARC/DNSSEC in one go
- **[Mail-Tester](https://www.mail-tester.com/)** — send it a real email, get a scored report
- **[DNSViz](https://dnsviz.net/)** — visualise your DNSSEC chain
- `dig TXT _dmarc.example.com +short`

## The module that will automate this

> 📐 **Designed, not built.** Spec:
> [`docs/MAIL-AUTH.md`](https://github.com/hyperpolymath/core-network-outpost/blob/main/docs/MAIL-AUTH.md).

The plan is a form-driven helper that generates and validates these records, publishes them
via **OpenTofu → Cloudflare** (never self-served DNS), and — the genuinely valuable half —
**ingests your DMARC aggregate reports into a dashboard** so "who is sending as me?" becomes
a page you look at instead of a pile of XML you don't.

> **Why OpenTofu, not Terraform:** HashiCorp relicensed Terraform to **BUSL 1.1** in 2023 —
> source-available and anti-compete, **not** OSI open-source. OpenTofu is the MPL-2.0
> Linux-Foundation fork, drop-in, same HCL.

**It's scoped hard: the DNS-auth layer and a DMARC dashboard. Never an MTA.** If it ever
grows an SMTP server, it's gone wrong.

## Where next

- **[Findable & Trusted](IndieWeb-Findable-And-Trusted)** — `security.txt`, sitemap, Search Console
- **[Reputation Hygiene](Reputation-Hygiene)** — the mail-blocklist survival guide
