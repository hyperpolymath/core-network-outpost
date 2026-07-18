# Make Your Page — accessible by construction, no Node

> ✅ **Built.** [Ddraig](https://github.com/hyperpolymath/ddraig-ssg) exists and builds today
> (needs `idris2 >= 0.8.0`, MPL-2.0). **Using** it needs no Idris — you write Markdown.
> Only *extending the generator* touches Idris.

**Own your web presence.** A page that's yours, that nobody can switch off, that loads
instantly, that's genuinely accessible, and that **structurally cannot be hacked and
redirected** the way a CMS can.

---

## Why static, and why this one

**Static first, for a reason that isn't just "it's lighter":** there's no CMS, no plugins, no
admin login, no database, no PHP. There is *nothing to inject and nothing to steal*. The most
common way ordinary sites get hijacked is simply **not available** against a folder of HTML.
That's a different category of safety, not a smaller quantity of it —
see [Site Hijacked](Site-Hijacked-Recovery).

**Ddraig** is this project's blessed generator. Honest reasons — and honest caveats:

| Why it's the default here | The caveat |
|---|---|
| **No Node, no npm, no Python.** One binary. | You need `idris2` once, to build that binary. |
| **WCAG 2.2 AAA-*capable* default theme** — contrast ≥ 7:1, skip link, landmarks, visible focus, reduced-motion, ≥44px targets | "AAA-capable" means the *engine* holds up its end. You can still write inaccessible content. |
| **Proof-carrying accessibility** — the build **fails** if a page isn't attestable | Only covers *machine-decidable* criteria. No tool can check whether your alt text is *good*. |
| **An image cannot be constructed without alt text** — it's a type invariant, not a lint rule | — |
| **No added language to the estate** — Idris 2 is already load-bearing here | If you don't like Idris, that's a fair objection. |

> **Not sold? That's fine, and it's designed for.** Ddraig keeps a documented
> **static-output contract**, so Hugo, Zola, Astro, or hand-written HTML all work with
> everything else on this track — [Publish It](IndieWeb-Publish) and
> [Findable & Trusted](IndieWeb-Findable-And-Trusted) don't care what generated your HTML.
> **For a handful of pages, hand-written HTML genuinely beats any SSG.** Use what you'll
> actually maintain.

## Build the generator (once)

```sh
git clone https://github.com/hyperpolymath/ddraig-ssg && cd ddraig-ssg
idris2 Ddraig.idr -o ddraig        # produces build/exec/ddraig
```

Try it on the bundled example before touching your own content:

```sh
./build/exec/ddraig build examples _site
```

## Write your site

A directory of Markdown. That's the whole authoring model:

```
my-site/
├── index.md
├── about.md
├── posts/
│   └── hello.md
├── templates/          # optional — there's an accessible built-in fallback
│   ├── default.html
│   └── partials/
└── public/             # copied to the site ROOT (see below)
    ├── .well-known/security.txt
    ├── robots.txt
    └── favicon.svg
```

Each page starts with front-matter:

```markdown
---
title: Hello, world
date: 2026-07-16
description: A short summary — this becomes the meta description and the feed entry.
tags: [indieweb, accessibility]
draft: false
---

## A heading

Ordinary **Markdown** from here on: lists, tables, code fences, images, links.
```

Supported front-matter: `title`, `date`, `description`, `slug`, `site`/`brand`, `tags`,
`layout`/`template`, `draft` (drafts are skipped).

You get headings with anchors, bold/italic/strikethrough, inline code, links, images,
blockquotes, ordered/unordered/nested lists, pipe tables (with proper `<th scope="col">`),
fenced code blocks with language classes, horizontal rules, and raw-HTML passthrough for
hero/card/badge markup.

## Build it

```sh
ddraig build my-site _site https://example.com
```

**Pass your real base URL.** It's optional but you want it: `sitemap.xml` requires *absolute*
`<loc>` URLs to be valid, and the Atom feed embeds absolute IDs. Without it the feed still
validates (falling back to `urn:` ids) but your sitemap URLs will be relative — i.e. not much
use to a search engine.

You get: every `.md` rendered to `.html`, `sitemap.xml`, a valid Atom `feed.xml`, canonical
+ Open Graph + Twitter Card meta, your assets copied, and `public/` unpacked at the site root.

```sh
ddraig clean _site      # remove an output dir
ddraig --help
```

## If the build fails on accessibility — that's the feature

Ddraig runs every page through a **total** decision procedure and **refuses to build** an
un-attestable page. Expect to hit:

- **more than one `<h1>`**, or none — exactly one per page
- **skipped heading levels** — `##` → `####` with no `###`

Fix the content; don't look for a flag to switch it off. There isn't one, on purpose: a
warning you can ignore is a warning everyone ignores. Successful builds emit a per-page
certificate at `/.well-known/accessibility-attestation.json`.

> **Be clear-eyed about what this proves.** It proves the *machine-decidable* criteria:
> exactly one `<h1>`, non-skipping headings, alt text *present*. It cannot prove your alt text
> is *meaningful*, your language is clear, or your colour choices survive your own CSS
> overrides. It's a floor you can't fall through — not a ceiling, and not a substitute for
> testing with real assistive tech. The engine-owned vs author-owned split is written down in
> [`ACCESSIBILITY-CHECKLIST.adoc`](https://github.com/hyperpolymath/ddraig-ssg/blob/main/ACCESSIBILITY-CHECKLIST.adoc).

## Accessibility is the point, not a checkbox

This estate ranks **accessibility in the same tier as maintainability** — above features and
performance. Some of it is on you, and no generator can do it for you:

- **Alt text that says what the image *means***, not "image of a graph". Decorative? `alt=""`.
- **Link text that reads alone.** "Click here" is invisible to someone tabbing a link list.
- **Headings that describe structure**, not styling. Don't pick `###` because it looks right.
- **Plain language.** The most accessible thing on any page is a clear sentence.
- **Then test it**: keyboard-only, and a real screen reader.

## Where next

- **[Publish It](IndieWeb-Publish)** — free, fast, likely green-hosted
- **[Findable & Trusted](IndieWeb-Findable-And-Trusted)** — `security.txt`, sitemap, Search Console
- **[Your Domain + Mail DNS](IndieWeb-Domain-And-Mail-DNS)** — make it *yours*
