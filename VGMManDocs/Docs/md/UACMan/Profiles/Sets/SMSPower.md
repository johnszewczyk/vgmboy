# SMS Power Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[VGM/VGZ profile](../VGM.md). Keep actual source counts, package status,
version distributions, and exceptions in AudioMan's per-set report.

## Scope

- **Collection** — Official SMS Power music packs for Sega 8-bit platforms.
- **Format profiles** — VGM; one UAC package represents one catalog pack.
- **First-pass eligibility** — Process a catalog-listed pack when its No-Intro
  title root is positive, its VGM members all have one container version, and
  the pack's source/catalog platform is resolved. Keep title-root conflicts
  and mixed-version packs in review. Release ambiguity alone does not block a
  known game title from packaging.

## Source Authority

- **Source** — SMS Power's [VGMs catalog](https://www.smspower.org/Music/VGMs)
  and the catalog page for each pack.
- **Package fields** — Use **Set Name** `SMS Power` and the catalog URL
  `https://www.smspower.org/Music/VGMs` as **Set URL** on every package. Keep
  each pack's detail-page URL in `sources[].sourceURL`. Do not add **Set
  Collection**.
- **Original packages** — Preserve source ZIPs in source-state on EXT and link
  the exact package through `sources[]`. Keep source-document attachments found
  in the package with the UAC when they remain useful.
- **Hashes** — Store the four standard Stream Hashes for each complete VGM
  member. Keep source ZIP identity in the source database and `sources[]`; do
  not invent a surfaced source-archive hash tag.
- **Page URLs** — The official pack detail page is
  `https://www.smspower.org/Music/<source ZIP stem>` and belongs in
  `sources[].sourceURL`. The stable catalog page remains the **Set URL**.

## Identity Enrichment

- **Game identity** — Use a positive No-Intro title-root link for structural
  `game.title` and the package filename. Add **Game ID** only when one DAT
  release record is supported. An ambiguous release can still have a known
  game title. Set **Region** only when every remaining DAT candidate agrees;
  use `--` when review confirms it is unknown. Do not put `--` in a filename.
  Add a known region suffix only to resolve a filename collision.
- **Platform** — The exact SMS Power pack page is authoritative for the
  platform represented by that VGM pack. Set `game.console` from that page
  and make the populated English GD3 System value match it in the UAC member.
  Preserve the original ZIP and Japanese System value. Record every corrected
  English value and the catalog page in the per-set report. Keep SMS, Game
  Gear, SG-1000, SC-3000, and Othello Multivision distinct.
- **GD3 field shape** — Use the eleven standard GD3 strings for named tags.
  If a member includes additional serialized strings, retain them in the VGM
  member and report the count; do not invent UAC tag names for them.

## Set Procedures

- **GD3 system aliases** — Apply the VGM profile's explicit Sega mappings.
  Resolve `Sega Master System / Game Gear` only when the containing catalog
  pack identifies one system; otherwise hold the whole package.
- **Version** — Surface each member's exact header version in track **Format**.
  Never freshen a VGM header. A package that mixes versions remains in review.
- **Gzip-wrapped members** — Remove one gzip envelope from `.vgz` members and
  from any `.vgm` member whose bytes begin with gzip magic. If decompression
  leaves another gzip layer or an invalid VGM header, hold the package and
  document the issue.
- **Curated TXT** — Preserve each source TXT unchanged as `meta.txt`,
  `meta-02.txt`, and so on, and reference it with **Text File**. Surface
  explicit, populated `Game developer` and `Game publisher` as package
  **Developer** and **Publisher**. Keep native GD3 **Date**/**Year** values;
  do not overwrite them from TXT. When dates disagree, retain both source
  records and report the conflict. Do not turn tracklists, loop/length tables,
  package version/history, `Complete music dump`, `FM`, or music hardware into
  tags. `Package created by` is not evidence of a tagger credit; leave it in
  the attached TXT unless the source explicitly identifies taggers. Do not
  infer supplementary composer credits when GD3 already assigns track-level
  composers.
- **Attachments and duplicate artwork** — Preserve playlists and every
  distinct source image as package-level **Title Snap**. Keep every playlist
  and resolve its member references per the VGM profile. If the source ZIP
  contains byte-identical artwork members, retain one copy in the UAC and
  document the omitted duplicate; never remove or alter the source ZIP.
- **Content boundaries** — Do not merge SMS and Game Gear packs because their
  names or music overlap. Review conspicuously short or sound-effect-only packs
  individually.

## Required Checks

- **Source linkage** — Confirm each UAC points to the exact catalog pack and
  source ZIP used.
- **Track inventory** — Account for each VGM member and bundled document.
- **Version and platform** — Check every member version; route mixed-version
  packages to review without rewriting the source. Compare English GD3 System
  against the exact pack page before normalizing it in UAC.
- **Identity and text** — Check output filename collisions, Game ID/Region
  evidence, GD3 versus text-title/date conflicts, explicit Developer/Publisher
  values, and every source attachment or intentional omission.
