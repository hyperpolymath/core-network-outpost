# Reputation Hygiene — staying off the blocklists

> ✅ **Guidance, not software.** Nothing to install. This is the cheap version of
> [Site Hijacked — Recover, In Order](Site-Hijacked-Recovery).

**The whole page in one line: "never get on" beats "get off".**

Getting blocklisted takes a day. Getting *un*-blocklisted takes weeks of review queues,
appeals, and waiting — while your visitors see a full-page red interstitial and your mail
silently vanishes. The asymmetry is brutal and it is the entire reason this page exists.

---

## Who actually decides your reputation

Not all of these matter equally. People routinely over-invest in the small ones because
they're visible, and under-invest in the two that reach almost everyone.

### Tier 1 — these reach nearly everybody

| Service | Reach | Why it matters |
|---|---|---|
| **[Google Safe Browsing](https://safebrowsing.google.com/)** | Chrome, Firefox, Safari, Android | The big one. A listing here is a full-page red warning in front of most of the web's users. |
| **[Microsoft SmartScreen](https://www.microsoft.com/en-us/edge/features/microsoft-defender-smartscreen)** | Edge **and Windows itself** | Easy to forget because it isn't just a browser — it's baked into the OS, so it catches downloads too. |

**These two are the ones to care about.** Both are free, both are checkable, and both are
where a listing genuinely hurts.

### Tier 2 — real, but opt-in

- **Norton Safe Web / Gen Digital** (Norton, Avast, AVG — one company now). The installed
  base is genuinely large, but it only affects users who've *installed* their software. Worth
  submitting to; not worth losing sleep over.
- **[VirusTotal](https://www.virustotal.com/)** — aggregates ~70 engines. Best used as a
  **diagnostic**: it tells you which vendor flagged you, so you know whose form to fill in.
  It isn't itself a blocker.

> **Watch out for the sales funnel.** Several "check your reputation" services exist mainly
> to sell you monitoring. Check with the free first-party tools above; treat everything else
> as a lead-gen page.

## Check where you stand right now

Takes two minutes, costs nothing, and most people have never done it:

- **[Google Safe Browsing status](https://transparencyreport.google.com/safe-browsing/search)** — paste your domain
- **[VirusTotal](https://www.virustotal.com/gui/home/url)** — paste your URL, see all engines
- **[Google Search Console](https://search.google.com/search-console)** → Security & Manual Actions
- **[Bing Webmaster Tools](https://www.bing.com/webmasters)** → Security

**Enrol in Search Console and Bing Webmaster Tools *now*, before anything is wrong.** That's
the actual advice. They're free, they take ten minutes, and they're how you find out you've
been hacked from *them* rather than from an angry customer three weeks later. You cannot
receive the warning if you never signed up for it.

## The web side — how people get listed

| Cause | Prevention |
|---|---|
| **Hacked CMS** (the #1 cause by a mile) | Updates on, unused plugins deleted, 2FA everywhere. Or go static — see below. |
| **Nulled/pirated themes & plugins** | Never. They are *routinely* backdoored; that's the entire business model. |
| **User-generated content** | Spam links in comments get you listed for *linking* to bad neighbourhoods. Moderate or disable. |
| **Ad networks / third-party scripts** | You inherit their reputation. Low-quality ad networks serve malware and it lands on *your* domain. |
| **Shared hosting neighbours** | If reputation is IP-based, someone else's mess can splash on you. |
| **Abandoned subdomains** | `old-blog.example.com` still pointing at a dead service someone else can claim → subdomain takeover. **Audit your DNS.** |

> **The structural answer: a static site can't be hijacked-and-redirected.** No CMS, no
> plugins, no admin login, no database, nothing to inject. The most common route onto a
> blocklist simply isn't available to an attacker. → **[Make Your Page](IndieWeb-Make-Your-Page)**

## The mail side — a different, harsher world

**Mail reputation is separate from web reputation, and it's less forgiving.** A "spam" verdict
usually isn't an error message — your mail just silently doesn't arrive.

**The one rule that matters most: never send mail from a residential IP.** Ever.

- Residential ranges are on permanent blocklists (Spamhaus PBL and friends) **by design**.
  It's not a mistake to appeal — it's policy.
- **You don't own your PTR/rDNS record** — your ISP does. You cannot set it.
- **Virgin Media blocks outbound port 25** anyway, so the question is usually moot.

**Send through a real provider** (Fastmail, Migadu, a VPS relay). Then authenticate the
domain properly:

| Record | Does |
|---|---|
| **SPF** | Says which servers may send as you |
| **DKIM** | Cryptographically signs your mail |
| **DMARC** | Ties them together, tells receivers what to do on failure, and **reports back** |

**Start at `p=none` and read the DMARC reports before you tighten.** Going straight to
`p=reject` is how people discover — by breaking it — that their newsletter tool was sending
as them all along. Ramp `none → quarantine → reject` once the reports are clean.

→ Full walkthrough: **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)**

## If you do get listed

1. **Fix it properly first** — see [Site Hijacked](Site-Hijacked-Recovery). Filing a review
   while still compromised resets the queue and damages your standing with the reviewer.
2. **Then request review** in Search Console / Bing Webmaster Tools. Be specific: what
   happened, what you fixed, how you're preventing recurrence. Vague requests get rejected
   and cost you another cycle.
3. **Wait.** Days to weeks. There is no fast lane. This is the part you cannot buy your way
   out of, and it's why everything above is worth doing in advance.

## What this box contributes

Honestly scoped:

- ✅ **AdGuard Home blocks malware/phishing domains network-wide** — protects *your household*
  from other people's compromised sites.
- ❌ **It does nothing for your public website's reputation.** That's on someone else's
  server.
- ✅ It makes the good path easy: static site, published off-box, on infrastructure with a
  reputation team of its own.

**Put Cloudflare's free tier in front of anything you publish.** WAF, DDoS protection, rate
limiting, DNSSEC, TLS — protection with *zero* cost and *zero* attack surface on your box.
Don't reimplement a layer you get for free.
