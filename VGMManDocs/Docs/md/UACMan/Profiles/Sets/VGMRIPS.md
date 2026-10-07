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
  boards under the set's **Arcade** folder.
- **Conversion scope** — Process and report one console folder at a time. Make
  one UAC per game package for that console; leave every other console folder
  untouched until its own pass. Reuse current source/member identities and
  metadata records rather than refreshing the entire multi-console source set.
- **Outer filenames** — Replace underscores with spaces in outer package and
  artwork filenames. Remove a redundant console parenthetical when the
  destination folder identifies that platform. Preserve title punctuation,
  region, edition, prototype, beta, and other source-supported distinctions.
  Do not rename members inside a source ZIP during this layout pass.
- **Review placement** — Keep combined, mixed, or unrecognized platform
  packages and packages with documented container-review findings in
  `Review/Sega`, retaining the source system label in the filename. Keep artwork
  with its uniquely matched package; retain ambiguous or unmatched artwork in
  `Review/Sega/Artwork` until its package is established.
- **Title Snap** — Keep source artwork beside its ZIP while staging. When the
  image is bundled into UAC, keep it as a normal package member and expose it
  through pack-level **Title Snap** metadata using a member reference shaped as
  `{"memberPath":"artwork/file.png","mediaType":"image/png"}`. Use an array
  of references when a package has multiple title images. Do not label artwork
  as a front cover unless the source identifies it that way.
- **Package set tags** — Use **Set Name** `VGMRIPS` and **Set URL** for the
  official snapshot/source page. Do not add **Set Collection**; `sources[]`
  retains the collection identity and package-level source file.

## Reports

Keep observed package counts, artwork matches, naming exceptions, and platform
review outcomes in the dated AudioMan VGMRIPS dashboard and operation report.
This profile records reusable conversion input rules only.
