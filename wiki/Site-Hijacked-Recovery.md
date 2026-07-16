# Your Site's Been Hijacked — Recover, In Order

> ✅ **Guidance, not software.** Nothing to install. This is the page you want at 2am when
> your site is redirecting strangers to somewhere you'd rather not name.

**This happens to ordinary people.** The case that prompted this page: a friend's website was
quietly redirected to a spam site. No ransom note, no defacement — just visitors silently
sent somewhere else, and the owner among the last to know.

**Do the steps in order.** The order is the point. Restoring a backup before you've worked
out *how* they got in just gets you re-hacked by Tuesday with the same hole.

---

## 0. Before anything: stop the bleeding (minutes)

**Take the site offline or put it behind a holding page.** Every hour it's up, it's:

- sending real people to malware or fraud,
- deepening your Safe Browsing / SmartScreen listing,
- burning your domain's reputation — **which is the part that takes months to undo.**

Downtime is embarrassing. A **blocklisted domain** is a genuine business problem. Take it
down.

> **Don't just delete the redirect and put it back up.** That's the most common mistake. The
> redirect is the *symptom*. They still have their way in, and they'll use it tonight.

## 1. Change credentials — from a clean machine (minutes)

If your own computer is compromised, changing passwords from it just hands over the new ones.
Use a different device if there's any doubt.

In this order:

1. **Hosting / control panel** — including any SFTP/SSH keys.
2. **Domain registrar and DNS** — this is the one people forget, and it's the most dangerous.
   **A hijacked DNS record redirects your site without touching your server at all.** Check
   your nameservers are still yours.
3. **CMS admin accounts** — all of them.
4. **Database user.**
5. **Any API tokens / deploy keys** in CI.

Turn on **two-factor authentication** on the registrar and host now, while you're there.

## 2. Work out how they got in (the step people skip)

You cannot skip this. Restoring a backup without it means you restore *the hole too*.

**Where to look:**

| Look at | For |
|---|---|
| **DNS records** | An A/CNAME pointing somewhere strange. Nameservers changed. **Check this first** — it's the cheapest to fix and the easiest to miss. |
| **Access logs** | POSTs to admin/upload paths; one IP hitting `/wp-login.php` a thousand times; a successful login at an odd hour. |
| **File timestamps** | `find . -mtime -14 -type f` — what changed recently that you didn't change? |
| **`.htaccess` / server config** | Classic redirect hiding place. Look for injected rewrite rules. |
| **CMS plugins/themes** | The usual entry point. Anything outdated, abandoned, or nulled/pirated. |
| **Injected files** | Unknown `.php` in upload directories. Uploads should never execute. |
| **Scheduled tasks** | A cron job that reinstalls the backdoor after you clean it. |
| **Admin users** | An account you don't recognise. |

**The four usual answers**, in rough order of likelihood: an **out-of-date CMS plugin**; a
**reused/weak password**; a **stolen registrar or DNS login** (server never touched); or a
**compromised developer machine**.

## 3. Eradicate — rebuild, don't clean

**Rebuild from a known-good source.** Do not try to pick the malware out of a live install —
you will miss a backdoor, because that's what backdoors are for.

1. Restore from a backup **dated before the compromise** (check your logs for when — it's
   often *far* earlier than you think).
2. **Update everything** before it faces the internet again.
3. Delete every plugin/theme you don't actively use. Unused code is attack surface that gives
   you nothing.
4. Rotate credentials **again** if the backup contained any.

## 4. Get delisted (days to weeks — start early)

Being on a blocklist is much easier to enter than leave. Start this **as soon as the site is
genuinely clean** — filing while still infected resets the queue and hurts your standing.

- **[Google Search Console](https://search.google.com/search-console)** → Security & Manual
  Actions → **Request a review**. Say what happened, what you fixed, and how you're
  preventing recurrence. Vague requests get rejected.
- **[Microsoft Bing Webmaster Tools](https://www.bing.com/webmasters)** — SmartScreen is
  built into Edge *and* Windows, so this one reaches people even outside a browser.
- **Check your standing:** [Google Safe Browsing status](https://transparencyreport.google.com/safe-browsing/search),
  [VirusTotal](https://www.virustotal.com/) (multi-engine, includes many smaller vendors).
- **If you send email from the domain**, check the mail blocklists too (Spamhaus and friends)
  — a hijacked site often gets used to send spam, and that poisons your mail separately.

> **Expect this to take a while, and expect it to be the worst part.** Cleaning takes an
> afternoon. Reputation takes weeks. This asymmetry is exactly why the next section is the
> real lesson.

## 5. Prevent — the structural fix

> **The big one: a static site structurally cannot be hijacked this way.**
>
> There's no CMS, no plugins, no admin login, no database, no API, no PHP — **nothing to
> steal, nothing to inject, nothing to exploit.** You publish HTML. An attacker who wants to
> redirect your visitors has to compromise your *git repo* or your *DNS*, both of which have
> 2FA and neither of which is reachable from your website.
>
> This isn't "a smaller attack surface". It's a **different category of thing**. The
> friend's hack — the one that started this page — simply cannot happen to a static site.
>
> → **[Make Your Page](IndieWeb-Make-Your-Page)** and **[Publish It](IndieWeb-Publish)**,
> free, on Cloudflare Pages.

If you must keep a dynamic CMS:

- **2FA on the registrar, host, and CMS.** The registrar especially — DNS hijack needs no
  server access at all.
- **Automatic updates on**, with backups you have actually tested restoring.
- **Delete unused plugins/themes.** Never install nulled/pirated ones — they are *routinely*
  backdoored; that's the business model.
- **Uploads must not execute.** No PHP in the uploads directory, ever.
- **Put Cloudflare's free tier in front** — WAF, DDoS protection, rate limiting, at zero cost
  and zero attack surface on your side.
- **Monitor**: Search Console alerts on, and check your DNS records periodically.

## What this box does and doesn't do for you

**Honest scope**, because overclaiming here would be its own kind of harm:

- ✅ **AdGuard Home blocks known malware/phishing *domains* network-wide** — so *your*
  devices don't reach the bad host. That's delivery-prevention for your household.
- ❌ **It does not protect your public website.** Your site lives on someone else's server;
  this box is on your LAN. Different place, different problem.
- ✅ **It makes the recommended fix easy** — the static-site path above, published off-box.

**You are never the only layer**, and shouldn't try to be: your router, your devices'
endpoint security, Cloudflare's edge, the browser's own Safe Browsing, and this box each
catch what the others miss.

## Where next

- **[Reputation Hygiene](Reputation-Hygiene)** — the "never get on the list" version of this
  page. Cheaper than everything above.
- **[Make Your Page](IndieWeb-Make-Your-Page)** — the structural fix.
