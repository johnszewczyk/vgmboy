# VGMRIPS

Set-specific rules for converting the current VGMRIPS VGM collection to UAC.
Apply these rules together with the [VGM format profile](../VGM.md) and the
[Base Set Profile](BASE-SET-PROFILE.md).

## Scope

- **Set identity** — Use **Set Name** `VGMRIPS`. Use the official snapshot or
  pack-catalog URL for **Set URL**; the currently retained 2026-10-05 snapshot
  is documented at <https://vgmrips.net/forum/viewtopic.php?t=496>.
- **Source state** — Keep each downloaded source snapshot on the external
  source-state volume. Process the latest snapshot as its own VGMRIPS set;
  retain earlier hash and identity evidence, but do not carry forward older
  VGMRIPS metadata as if it described the new snapshot.
- **Platform folders** — Keep each platform directly under the set root. Use
  the normalized platform name for Sega folders, including **Sega Genesis**,
  **Sega CD**, **Sega 32X**, **Sega Pico**, and **Sega SG-1000**. Keep arcade
  boards under the set's **Arcade** folder. Use **Nintendo NES** for NES,
  Famicom, and Family Computer aliases, including the English VGM GD3 System
  value; trim accidental surrounding whitespace before alias matching. Keep
  FDS, Vs. System, Dendy, and mixed-platform packages distinct or in review.
- **Conversion scope** — Process and report one console folder at a time. Make
  one UAC per game package for that console; leave every other console folder
  untouched until its own pass. Reuse current source/member identities and
  metadata records rather than refreshing the entire multi-console source set.
- **Separate source identity and master promotion** — Keep VGMRIPS source
  provenance separate from JoshW and Project2612. For an explicitly scoped
  JohnS master-building pass, a positively identified VGMRIPS UAC may be moved
  into its console master without rebuilding it or removing its VGMRIPS source
  record, Set Name/URL, or source-package hash. This is a one-location move,
  not a second copy or a source-set merge. Cross-set overlap alone does not
  authorize promotion; unresolved identity, regional-root conflicts, and
  unattributed variants stay in `VGMRIPS/Review/<Console>`.
- **Master filename after positive identification** — On a scoped No-Intro
  promotion, name the package from the DAT's displayed title root. If several
  packages share that root, keep the plain root on the unqualified package and
  append the shortest source-supported qualifier to the others (such as
  `(Beta)` or `(Prototype)`). Preserve source-supported aliases only when
  needed to distinguish the packages. Do not infer `(JP)`, `(US)`, or another
  region from a title alias; use a known region only under the shared filename
  rules. Keep source Set Name/URL and the package source hash unchanged.
- **Overlap evidence** — Use complete stream-hash comparisons to identify
  exact or partial Project2612 overlaps. Keep both sources' UAC packages,
  metadata, attachments, and provenance distinct; leave unresolved matches for
  review under the Project2612 profile and dated comparison report.
- **Outer filenames** — Replace underscores with spaces in outer package and
  artwork filenames. Remove a redundant console parenthetical when the
  destination folder identifies that platform. Preserve title punctuation,
  region, edition, prototype, beta, and other source-supported distinctions.
  In the **Nintendo NES** folder, remove `(Family Computer)` when it adds no
  release distinction; retain it when needed to prevent a collision between
  distinct releases.
  Do not rename members inside a source ZIP during this layout pass.
- **Review placement** — Keep mixed-platform packages, packages with unresolved
  game identity, package boundaries, or source-ROM attribution, and packages
  with unresolved corruption/container findings in `Review/Sega`, retaining
  the source system label in the filename. A positively identified package with mixed VGM
  versions may move to the console folder with `Status: Mixed Versions` and
  the original per-track **Format** values preserved. Keep artwork with its
  uniquely matched package; retain ambiguous or unmatched artwork in
  `Review/Sega/Artwork` until its package is established.
- **Multi-game packages** — When one source package contains multiple games and
  populated track-level **Game Title** values positively assign tracks to those
  games, make separate per-game UACs only after each title maps to an exact
  No-Intro title root or a separately reviewed non-DAT identity. Preserve each
  stored VGM stream exactly once across the outputs. Keep collection-level or
  otherwise unassigned tracks together in a clearly named Review package; do
  not duplicate tracks into each game. Mark per-game outputs `Status:
  Incomplete` when shared tracks remain outside them.
- **Multi-game playlists and snaps** — Preserve the source UAC's full M3U queue
  once in the shared Review package. Generate each per-game M3U by filtering
  the source queue to assigned tracks while retaining source member names and
  relative order; do not use loop/fade durations to infer game assignment.
  Preserve the source note byte-for-byte with each derived package. Attach the
  matching snap to its per-game package. A shared-track Review package may
  carry the full snap set as collection context; when that duplicates snap
  bytes already present in the per-game UACs, record that intentional
  collection-context duplication in the operation report.
- **Title Snap** — Keep source artwork beside its ZIP while staging. When a
  unique image is bundled into UAC, store it as a `role: asset` PNG member and
  set the package-level **Title Snap** tag to its relative path, such as
  `art/title-snap.png`. Use one string for one image or an array of paths when
  the source package has multiple distinct title snaps. Keep region/release
  alternatives in review rather than choosing the nearest artwork. Do not label
  artwork as a front cover unless the source identifies it that way.
- **Regional source-ROM splits** — Read `meta.txt` and any rip log for the exact
  ROM release and track-to-ROM mapping. Apply the shared **Source ROM** field
  only when the log or a verified ROM hash identifies the input. Title Snap
  and GD3 game-title variants identify names; they do not prove which ROM
  generated a track. Split a combined regional package only when each moved
  track has a source-ROM attribution. Keep common or unassigned tracks in the
  original review package; do not duplicate them into each region. If a
  release-specific output is intentionally partial, mark it **Status:
  Incomplete** and do not describe it as the complete soundtrack for that ROM.
  When `Game ID`, filename, or source notes point to different No-Intro title
  roots, keep the intact UAC in Review unless source-ROM evidence assigns its
  tracks. A shared title alias does not select a region.
- **Package notes** — Preserve each curated source TXT byte-for-byte inside its
  UAC as `meta.txt` and expose it through the direct package tag
  `"Text File": "meta.txt"`. Record its source filename and the member-name
  normalization in provenance. Keep the note as an attachment; do not duplicate
  its track list or package history as tags.
- **Package set tags** — Use **Set Name** `VGMRIPS` and **Set URL** for the
  official snapshot/source page. Do not add **Set Collection**; `sources[]`
  retains the collection identity and package-level source file.

## Reports

Keep observed package counts, artwork matches, naming exceptions, and platform
review outcomes in the dated AudioMan VGMRIPS dashboard and operation report.
This profile records reusable conversion input rules only.
