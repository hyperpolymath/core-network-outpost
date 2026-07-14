<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# roadmap/ — sketch area (NOT built)

Future intent only. Nothing here is implemented; it's a place to park ideas so
the path forward is obvious when better hardware shows up. Treat every file in
this directory as a napkin sketch, not a spec.

Current contents:

- **`MICROPATCH-SERVER.md`** — a future local patch/update mirror + signer, so
  the LAN's devices and containers pull pinned, vetted updates from the outpost
  instead of straight from the internet. Sketch only.
- **`BOJ-ON-OUTPOST.md`** — where the BoJ MCP server can and cannot run, and why
  the Pi 2B answer is a *measured* no (its container base publishes no armv7).
  Also the credential-gradient argument for keeping BoJ off the LAN-facing box.
  The DDNS half of that design is **built** (`host/ddns/`), not a sketch.
- **`PI4-AND-BEYOND.md`** — the hardware upgrade path (Pi 4 / 5 / x86 mini-PC)
  and what each one unlocks: 64-bit (`aarch64`) → **Wolfi base becomes possible**,
  more RAM, USB3 / real second NIC → a *credible* inline firewall, headroom for
  the micropatch server above.

If you pick one of these up, promote it out of `roadmap/` into its own top-level
area with a real design doc and remove the "sketch" caveats.
