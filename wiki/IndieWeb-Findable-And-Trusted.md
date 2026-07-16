# Findable *and* Trusted

> ✅ **Guidance, and mostly built.** Ddraig generates the sitemap and feed for you and ships
> `public/` to your site root. The rest is a few files and two free signups.

Being **findable** is search engines knowing you exist. Being **trusted** is browsers, mail
servers, and people believing you're not hostile. They're different jobs, and the second one
is the one that quietly wrecks you if you skip it.

---

## Do these two signups now, before anything is wrong

**This is the highest-value thing on the page and it takes ten minutes.**

- **[Google Search Console](https://search.google.com/search-console)**
- **[Bing Webmaster Tools](https://www.bing.com/webmasters)** — don't skip it; SmartScreen is
  in Edge **and Windows itself**

They're free, and they're how you find out you've been hacked **from them, first** — rather
than from a stranger, three weeks and one blocklisting later. **You cannot receive the alert
if you never signed up.** Enrol while everything is fine; that's the entire point.

While you're there: submit your sitemap, and turn on email alerts.

## `security.txt` — how someone tells you you're broken

**[RFC 9116](https://www.rfc-editor.org/rfc/rfc9116).** A researcher finds a problem with your
site. Right now, how do they reach you? Most people's answer is "they don't, so they post it
publicly or sell it."

Put this at `/.well-known/security.txt`:

```
Contact: mailto:security@example.com
Expires: 2027-01-01T00:00:00.000Z
Preferred-Languages: en
Canonical: https://example.com/.well-known/security.txt
```

**`Contact` and `Expires` are the required fields.** Ddraig users: drop it in `public/` and it
lands at the site root automatically. Put a real, monitored address in it — a contact nobody
reads is worse than none, because it looks like you tried.

## `robots.txt` and sitemaps

```
User-agent: *
Allow: /
Sitemap: https://example.com/sitemap.xml
```

**Ddraig generates `sitemap.xml` and Atom `feed.xml` for you** — provided you pass your base
URL at build time:

```sh
ddraig build my-site _site https://example.com
```

Without it, sitemap `<loc>` URLs come out relative, which makes the sitemap invalid and
useless to a search engine. It's the single most common way to have a sitemap that does
nothing.

> **`robots.txt` is not access control.** It's a polite request. It does not stop anyone, and
> listing your secret paths in it is how people find them. If it must stay private, it must
> not be published.

## The `<head>` that makes you look legitimate

Ddraig's default template emits these; if you're hand-rolling, don't skip them:

| Tag | Why |
|---|---|
| `<link rel="canonical">` | One true URL — stops duplicate-content splits |
| Open Graph (`og:title`, `og:description`, `og:image`) | The card people see in chat/social. Its absence looks abandoned. |
| Twitter Card | Same, for that platform |
| `<meta name="description">` | Often *is* your search snippet — write it for a human |
| `<html lang="en">` | Screen readers need it to pick the right voice. **Accessibility, not SEO.** |

## Feeds — the IndieWeb bit

**Ddraig generates a valid Atom `feed.xml`.** Link it in your `<head>`:

```html
<link rel="alternate" type="application/atom+xml" href="/feed.xml" title="Example">
```

A feed is how people follow you **without an algorithm deciding whether they see you**. It's
the quiet centre of the whole IndieWeb argument: your readers, your relationship, no
intermediary who can change the terms. It costs you one line.

Consider also:
- **`rel="me"` links** to your other profiles — the basis of IndieAuth, and how Mastodon
  verifies your site.
- **[h-card](https://microformats.org/wiki/h-card)** microformats, so machines can read who
  you are.

## Trusted: the security headers

**Your host does most of this.** Cloudflare Pages gives you HTTPS and HSTS free. If you're
setting them yourself, the ones that matter:

| Header | Does |
|---|---|
| `Strict-Transport-Security` | HTTPS only, forever |
| `Content-Security-Policy` | The big one — blocks injected scripts. Start with `default-src 'self'`. |
| `X-Content-Type-Options: nosniff` | Stops MIME-sniffing tricks |
| `Referrer-Policy` | Don't leak your visitors' paths to third parties |
| `Permissions-Policy` | Turn off camera/mic/geo you never use |

Check yours: **[securityheaders.com](https://securityheaders.com/)** and
**[SSL Labs](https://www.ssllabs.com/ssltest/)**.

> **A static site makes CSP easy**, because there's nothing dynamic to allow. If you're
> fighting your CSP, that's usually a sign of third-party scripts you'd be better off
> deleting — each one is a supply chain you don't control and a reputation you inherit.

## Accessibility *is* findability

Not a separate virtue — the same work pays twice:

- **Semantic headings** structure the page for a screen reader *and* a crawler.
- **Alt text** describes an image to a person who can't see it *and* to an indexer.
- **Descriptive link text** helps someone tabbing a link list *and* tells search engines what
  you're linking to.
- **Clear language** is the most accessible thing on any page, and it's what people actually
  search for.

Do it because it's right. It also happens to be the SEO advice.

## Where next

- **[Reputation Hygiene](Reputation-Hygiene)** — the blocklists, and staying off them
- **[Site Hijacked](Site-Hijacked-Recovery)** — the page you'll want if it goes wrong
- **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)** — mail people actually receive
