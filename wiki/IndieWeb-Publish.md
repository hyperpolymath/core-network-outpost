# Publish It — free, fast, and off your box

> ✅ **Guidance, not software.** Works with any static site — Ddraig, Hugo, Zola, Astro, or
> hand-written HTML.

**The most important architectural decision on this page: don't serve your site from your
box.** Publish it somewhere else, for free.

---

## Why off-box, when the box could obviously serve it?

Because it's the best call in the whole design, and it costs nothing:

| Serving from your box | Publishing to Cloudflare Pages |
|---|---|
| A public inbound port on your **home** network | **No inbound anything.** Your box stays dark. |
| Your home IP is public and attributable | Your home IP appears nowhere |
| Your uplink is the bottleneck (~100 Mbit up on cable) | A global CDN |
| A power cut / reboot / ISP blip = downtime | Someone else's uptime problem |
| DDoS lands on *your* line | Absorbed upstream, free |
| You maintain the TLS, the server, the patching | You maintain nothing |
| **You are the attack surface** | **You have no attack surface** |

> **"Near-zero fragility. Someone else runs it. Best call in the design."** — this estate's
> own architecture notes rate the off-box path 🟢, the only component that gets a clean
> green. That's not laziness. Refusing to run something you don't need to run *is* the
> engineering.

**You are never the only layer.** Cloudflare's free tier hands you a WAF, DDoS protection,
rate limiting, DNSSEC, and TLS — for nothing, on their hardware. Reimplementing that on a
Pi would be worse in every direction.

## Publish to Cloudflare Pages

**Free tier, no card, unlimited bandwidth.** Roughly ten minutes:

1. Push your site's source to a GitHub repo.
2. **[Cloudflare Pages](https://pages.cloudflare.com/)** → *Create a project* → *Connect to
   Git* → pick the repo.
3. **Build settings** — if you commit the built HTML, there's nothing to build:
   - *Framework preset:* **None**
   - *Build command:* leave **empty**
   - *Build output directory:* `_site` (or wherever your generator writes)
4. Deploy. You get `your-project.pages.dev` immediately, on HTTPS, worldwide.
5. Add your own domain: *Custom domains* → your domain → follow the DNS prompt.
   → **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)**

> **Ddraig users:** Cloudflare's build image has no Idris compiler, so **build locally and
> commit `_site/`**. That's not a workaround — it's better. Your published output is exactly
> what you tested, reviewable in git, and the deploy can't break because someone else's
> toolchain moved. Reproducibility over convenience, same as the rest of this estate.

```sh
ddraig build my-site _site https://example.com
git add _site && git commit -m "site: rebuild" && git push   # Pages deploys on push
```

### Alternatives, honestly

Cloudflare Pages isn't special here — **the pattern is what matters**, and any of these keep
your box dark:

| Host | Notes |
|---|---|
| **Cloudflare Pages** | Free, unlimited bandwidth, WAF/DDoS included, good green story |
| **GitHub Pages** | Free, dead simple, already where your repo is. Fewer edge features. |
| **Codeberg Pages** | Free, non-profit, no US megacorp |
| **Netlify / Vercel** | Fine. Free tiers have bandwidth caps. |

**Any of them beats serving from home.** Pick one and move on.

## The green question — claimed honestly

This matters to this project, so here's the version without the greenwash:

- ✅ **True and worth saying:** your box draws **~10 W**, and the greenest hardware is the
  hardware **you already own** — *embodied carbon from manufacturing often outweighs years of
  operational energy*. Reusing a Pi 2B you already have genuinely beats buying an efficient
  new thing.
- ✅ **True:** Cloudflare is a [Green Web Foundation](https://www.thegreenwebfoundation.org/)
  -recognised host, so a site on Pages is **likely** green-hosted. Check yours with the
  [Green Web Check](https://www.thegreenwebfoundation.org/green-web-check/).
- ⚠️ **Not the same thing:** "my box sips 10 W" is **not** certified green hosting. GWF
  certification is about **renewable energy supply**, and your home electricity is whatever
  your supplier sells you. Efficiency ≠ renewable.
- ❌ **Don't claim** your self-hosted box is "green-hosted" because it's low-power. It isn't.
  Say the true thing instead — it's a better story anyway: *reuse, frugality, and ~10 W*.

## After you publish

- **[Findable & Trusted](IndieWeb-Findable-And-Trusted)** — `security.txt`, sitemap, Search
  Console. **Enrol in Search Console now**, while nothing is wrong — it's how you learn about
  trouble from Google rather than from a stranger.
- **[Reputation Hygiene](Reputation-Hygiene)** — "never get on a blocklist" beats "get off
  one".
- Keep the source in git. Rebuild, commit, push. That's the whole workflow, forever, with no
  vendor who can shut it down.
