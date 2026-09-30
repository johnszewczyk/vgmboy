# SNESMusic.org SPC tag and naming preview

**Status: preview only.** This report proposes a revised tag set and display. No UAC manifest, package filename, SPC member, or database row was changed.

**Hash correction:** the eight-hash Current/Initial proposal below is withdrawn.
Use the corrected four-hash, source-derived preview in
[`SNESMusicOrg-SPC-Source-Hash-Relocation-Preview-2026-09-23.md`](SNESMusicOrg-SPC-Source-Hash-Relocation-Preview-2026-09-23.md).

## Findings from the current set

- The set has 1,519 UAC packages and 34,917 SPC members. Twenty-seven package filenames and matching game titles are entirely lowercase; `super castlevania iv.uac` is one of them. Package filenames should use the unique No-Intro-backed canonical GameID and title. This example currently links to five candidate No-Intro IDs (2611, 2612, 3852, 3861, 3862), so its canonical release is unresolved and it should remain in review until the database identity is disambiguated. Do not rename it to a guessed ID.
- All 34,917 SPC member basenames already match the `NN-Track Name.spc` pattern. Three Sailor Moon packages have multiple numbered subfolders, so their number sequences restart by folder. Super Castlevania IV already has `00-` through `35-` filenames.
- The SPC `Artist` source tag is retained in the current generic `nativeMetadata` block; unanimous values are promoted to package metadata, so they are absent from many track rows. Across the set there are 41,332 native `Artist` occurrences, 3,898 track-level normalized `artist` values, and 1,405 packages with a package-level `artist` value. Proposed projection: show populated source-derived fields on each applicable track, without an opaque **Native Metadata** tag.
- `Publisher` is preserved as a native source tag (34,484 occurrences) but is not currently projected to any SPC track metadata. `Dumper` is preserved as `Dumper` in the source tags, but the normalized track field is named `encodedBy` (12,185 track projections). No `Developer` field is currently projected.
- `trackNumber` is projected from raw hexadecimal `OST Track` values. In this UAC, raw `0100` becomes 256, `0200` becomes 512, and values repeat for different tracks. The Tracks table also emits its own row number plus a fixed `Track #` header and a generated `trackNumber` column with the same `Track #` label. This accounts for the duplicate column and bad values.
- The current package metadata contains the nested `set` object and `containedContainerVersions` object. The latter repeats `formatsScanned`, `schemaVersion`, and header/version counts even though all 36 tracks here are standard SPC v0.30.
- A full manifest audit found all 1,519 packages have four hashes for the source RSN, and all 34,917 SPC members have four `playable-payload` hash records. The corrected preview displays these as package-level **Source .rsn Hashes** and per-track **Stream Hashes**. No SPC member had the optional four-algorithm `raw-member` hash group.
- None of the 1,519 current package manifests has a populated `game.canonicalIDs`. Songbase currently has 1,431 canonical title links. Those links need to be reconciled to a unique No-Intro release ID before ID-based package naming; a title link with multiple regional/reissue IDs is not enough.

### Current lowercase package filename candidates

- `Nintendo SNES/aero the acro bat 2.uac`
- `Nintendo SNES/aero the acro bat.uac`
- `Nintendo SNES/american tail an fievel goes west.uac`
- `Nintendo SNES/bass masters classic pro edition.uac`
- `Nintendo SNES/bass masters classic.uac`
- `Nintendo SNES/bubsy ii.uac`
- `Nintendo SNES/dinocity.uac`
- `Nintendo SNES/gp 1.uac`
- `Nintendo SNES/krusty s super fun house.uac`
- `Nintendo SNES/magic boy.uac`
- `Nintendo SNES/mask the.uac`
- `Nintendo SNES/mickey mania the timeless adventures of mickey mouse.uac`
- `Nintendo SNES/mohawk headphone jack.uac`
- `Nintendo SNES/monopoly.uac`
- `Nintendo SNES/mortal kombat 3.uac`
- `Nintendo SNES/mr do.uac`
- `Nintendo SNES/ren stimpy show the time warp.uac`
- `Nintendo SNES/shanghai ii dragon s eye.uac`
- `Nintendo SNES/simpsons the bart s nightmare.uac`
- `Nintendo SNES/sonic blast man ii.uac`
- `Nintendo SNES/star trek deep space nine crossroads of time.uac`
- `Nintendo SNES/star trek starfleet academy starship bridge simulator.uac`
- `Nintendo SNES/super castlevania iv.uac`
- `Nintendo SNES/tetris dr mario.uac`
- `Nintendo SNES/ultima vii the black gate.uac`
- `Nintendo SNES/wolverine adamantium rage.uac`
- `Nintendo SNES/x kaliber 2097.uac`

## Proposed tag placement

Use Title Case labels in the user-facing tag grid. Put soundtrack identity and authorship on each track. Keep the package focused on source-set identification and actual attachments. Keep byte-level provenance and checksums in their existing source/hash records rather than presenting them as ordinary tags.

### Package-level tags and attachments

| Proposed tag | Proposed value | Notes |
| --- | --- | --- |
| **Set Name** | `SNESMusic.org` | Plain package-level tag; no nested set object. |
| **Set URL** | `https://snesmusic.org/v2/torrent.php` | Clickable source-set link. |
| **Source RSN** | `scv4.rsn` | Original canonical source archive identity; preserve its bytes outside the derived UAC. |
| **Source .rsn Hashes** | Four hashes | Hash the complete source RSN file: BLAKE3-256, CRC32, SHA-1, and MD5. |
| **Attachments** | Existing source documentation, if selected | Keep actual attachment pointers separate from descriptive metadata. |

Omit **Formats Scanned**, schema-version tags, and `Contained Container Versions`. For homogeneous standard SPC v0.30 sets, omit a Sub-Container tag. Keep the single version/header anomaly in the existing Review path and report it as an exception; do not repeat v0.30 on every track.

For this example, the four source RSN hashes are BLAKE3-256
`bf8d7b06dde398a986c353f0337a9a45a133734b6b7fd3f073766bb2190815c5`, CRC32
`3F05F8E0`, SHA-1 `1f3a8ad5069f2799ba585868529e25beaf8f6d97`, and MD5
`6ff6480ffea8f8e31ed2b54b8bcb418f`.

### Track-level tag proposal for Super Castlevania IV

Every row below proposes **Game Title: Super Castlevania IV**, **Artist: Masanori Adachi, Taro Kudou**, **Publisher: Konami**, **Developer: Konami***, and **Year: 1991**. Use **Album** in place of **Game Title** only when the SPC source actually supplies an `Album` tag; do not synthesize Album from the game title or from `OST Title`. `Artist` and `Dumper` retain their source tag names. The Developer value follows your instruction for this game and is not claimed to come from the SPC.

| Track Number | Proposed SPC member | Title | Dumper | Source OST Track (evidence only) |
| ---: | --- | --- | --- | --- |
| 00 | `00-Konami Logo.spc` | Konami Logo | Slick Mandela | — |
| 01 | `01-Demon Castle Dracula.spc` | Demon Castle Dracula | Datschge | 0100 |
| 02 | `02-Dracula's Theme.spc` | Dracula's Theme | Datschge | 0200 |
| 03 | `03-Password.spc` | Password | Datschge | — |
| 04 | `04-Prologue.spc` | Prologue | Datschge | 0300 |
| 05 | `05-Theme of Simon.spc` | Theme of Simon | Datschge | 0400 |
| 06 | `06-Forest of Monsters.spc` | Forest of Monsters | Datschge | 0500 |
| 07 | `07-The Cave.spc` | The Cave | Datschge | 0600 |
| 08 | `08-The Waterfalls.spc` | The Waterfalls | Datschge | 0600 |
| 09 | `09-The Submerged City.spc` | The Submerged City | Datschge | 0600 |
| 10 | `10-Rotating Room.spc` | Rotating Room | Datschge | 0700 |
| 11 | `11-Spinning Tower.spc` | Spinning Tower | Datschge | 0700 |
| 12 | `12-Boss 1.spc` | Boss 1 | Datschge | 0800 |
| 13 | `13-Stage Clear.spc` | Stage Clear | Datschge | 0900 |
| 14 | `14-Map A.spc` | Map A | Datschge | 0A00 |
| 15 | `15-In the Castle.spc` | In the Castle | Datschge | 0B00 |
| 16 | `16-The Castle's Gate.spc` | The Castle's Gate | Datschge | — |
| 17 | `17-Entrance Hall.spc` | Entrance Hall | Datschge | 0C00 |
| 18 | `18-Chandeliers.spc` | Chandeliers | Datschge | 0C00 |
| 19 | `19-Pillared Corridor.spc` | Pillared Corridor | Datschge | 0D00 |
| 20 | `20-Cellar.spc` | Cellar | Datschge | 0E00 |
| 21 | `21-Map B.spc` | Map B | Datschge | 0F00 |
| 22 | `22-Treasury Room.spc` | Treasury Room | Datschge | 1000 |
| 23 | `23-Boss 2.spc` | Boss 2 | Datschge | 1100 |
| 24 | `24-Map C.spc` | Map C | Datschge | 1200 |
| 25 | `25-Bloody Tears.spc` | Bloody Tears | Datschge | 1300 |
| 26 | `26-Map D.spc` | Map D | Datschge | 1400 |
| 27 | `27-Vampire Killer.spc` | Vampire Killer | Datschge | 1500 |
| 28 | `28-Beginning.spc` | Beginning | Datschge | 1600 |
| 29 | `29-Room of Close Associates.spc` | Room of Close Associates | Datschge | 1700 |
| 30 | `30-Dracula Battle.spc` | Dracula Battle | Datschge | 1800 |
| 31 | `31-Dracula's Death.spc` | Dracula's Death | Datschge | 1900 |
| 32 | `32-Ending.spc` | Ending | Datschge | 1A00 |
| 33 | `33-Secret Room.spc` | Secret Room | Datschge | 1B00 |
| 34 | `34-Death of Simon.spc` | Death of Simon | Datschge | — |
| 35 | `35-Game Over.spc` | Game Over | Datschge | 1C00 |

An example proposed track row is:

| Tag | Value |
| --- | --- |
| **Title** | Dracula's Theme |
| **Game Title** | Super Castlevania IV |
| **Artist** | Masanori Adachi, Taro Kudou |
| **Publisher** | Konami |
| **Developer** | Konami* |
| **Dumper** | Datschge |
| **Track Number** | 02 |
| **Year** | 1991 |

The **Stream Hashes** list for the first member, `00-Konami Logo.spc`,
already exists in its manifest and should be surfaced as:

| Checksum label | Value |
| --- | --- |
| **Stream BLAKE3-256** | `f92e233f82408be32a4500c7b5e3aa63f4c40f5655a931e804c62afb4ebef20a` |
| **Stream CRC32** | `331C2D61` |
| **Stream SHA-1** | `4e9c963451e38ceb5375e506df0ec1d5d73cee06` |
| **Stream MD5** | `2af8b6ca887fabe7aaf3a69b809a4cc1` |

### Fields omitted from the prominent tag grid

- Preserve **Album** as Album when that exact SPC source tag exists. Otherwise use **Game Title** for the canonical game identity; do not map `OST Title` to Album without an explicit rule.
- Do not expose `Encoded By`; use **Dumper**, preserving the SPC source name.
- Do not use decoded hexadecimal `OST Track` as **Track Number**. Keep the exact native `OST Track` value under source evidence, and use the sequential member-name prefix for one visible **Track Number** column.
- Do not surface `Formats Scanned`, schema version, `spcHeaderVersion`, or repetitive v0.30 inventory details as ordinary tags. Keep the version-header mismatch in the review report.
- Do not edit SPC ID666/xID6 source tags in this pass. Do not expose an opaque **Native Metadata** field in the tag grid. Keep the byte-identical SPC as the authoritative source for raw tags and unknown xID6 items; put parser diagnostics in the conversion audit report.
- Show each track's four `playable-payload` hashes as **Stream Hashes**, with BLAKE3-256, CRC32, SHA-1, and MD5. Preserve the existing member hash records and do not create duplicate metadata values.
- Use **Date** and **Year** as the canonical metadata labels. Map a source Copyright Year value to canonical Year without rewriting the SPC source tag. Never derive Year from Date.
- Set package filename from the unique canonical No-Intro ID and title. The current Super Castlevania IV link has five IDs, so its release-specific name is unresolved and the package should be routed for review until the identity is settled.

## Preview decisions for your review

- This proposal retains **Artist** as the SPC source tag name; its values identify the composers. No source-label rename is proposed.
- `Developer: Konami` is marked with an asterisk because it follows your direction and awaits the later company-role cleanup.
- The proposed package fields are flat **Set Name** and **Set URL**, plus source archive identity and separate current/initial hash lists. The current writer contract still documents a nested `game.metadata.set`; the writer and contract need an approved update before applying this preview.
- A package name includes the unique No-Intro-backed canonical GameID and canonical title. Unidentified and ambiguous games belong in a separate review folder; title similarity alone is not a confirmed identity. Twenty-six other lowercase package names also need identity and capitalization review rather than a blind title-case transform.
- The full audit confirms source-archive hash lists and track playable-hash lists already exist in all current packages. The next revision must make them visible and consistently labeled, not recompute or replace them without evidence.
- Recommended additional fields: **Game Region** only after unique No-Intro identity; **Game Version** only from positive build/revision evidence; explicit SPC source Date; and populated technical timing where useful. Do not infer Developer, Album, region, or version from a company name or title resemblance.
- No package metadata or filenames have been changed. This report is the review artifact for the next revision pass.
