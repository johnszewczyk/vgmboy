# SBONLINE

SBONLINE is the hosted SPCBOY web player for the private `admin.pre-calc.com`
site. It is a separate product surface from the SB2 macOS application and uses
the VGMMan catalog and playback family.

## Current source layout

- [`prototypes/mobile/index.html`](prototypes/mobile/index.html) is the
  standalone mobile UI concept. It uses sample entries and does not load the
  hosted catalog or play audio.
- The production Django pages, persistent browser player, social and account
  features, stream endpoint, and deployment source currently live in
  [MathBook's private-admin app](../../MathBook/private-admin/). Its current
  behavior is documented in
  [the private-admin human note](../../MathBook/ai/subsystem-human/private-admin.md).
- The production stream adapter currently builds from a deployment copy of
  VGMBoy sources. The authoritative decoder implementation remains in
  [`../VGMBoy/`](../VGMBoy/); provenance is recorded in MathBook's
  [`UPSTREAM.md`](../../MathBook/private-admin/streaming/UPSTREAM.md).

## Ownership boundaries

SBONLINE owns the hosted web-player product route and its standalone interface
work. MathBook currently owns the live Django host integration and deployment.
Catalog publication remains with ScanSong, and playback decoding remains with
VGMBoy. Read `AGENTS.md` and `ai/project-info.md` before making changes.

There is no independent SBONLINE build or deployment command yet. Use the
MathBook deployment route for production changes while the live implementation
remains in that repository.
