# VGM / VGZ · Multi-Platform Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads `.vgm` and
gzip-compressed `.vgz` members. See
[`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — `vgm`; `VGMMetadataReader.swift`.
- **Source members** — `.vgm` and `.vgz`.
- **GD3 coverage** — The standard eleven GD3 v1.00 fields, including both
  English and original-language fields. These are fixed ordered fields, not
  arbitrary named tags. Preserve populated language-specific values directly
  in Title Case UAC metadata.
- **Source bytes** — Keep the original VGZ or VGM package in source state. UAC
  members use raw VGM after removing one VGZ gzip layer.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `title_english` | Title | `members[].metadata["Title"]` | Preserve the English track title on its VGM member. |
| `title_original` | Title (JP) | `members[].metadata["Title (JP)"]` | Preserve a populated Japanese title separately; omit it when absent. |
| `game_english` | Game Title | `game.metadata["Game Title"]` | Use package scope when the value is consistent across tracks; otherwise preserve it on each affected member. Also use it for required structural `game.title` when it gives the package's known title. Do not substitute it for Album. |
| `game_original` | Game Title (JP) | `game.metadata["Game Title (JP)"]` | Use package scope when consistent; otherwise keep the source value on its member. Omit absent values. |
| `system_english` | Structural platform | `game.console` | Prefer the populated English system label. Normalize only approved, unambiguous aliases; do not add a duplicate System or Platform tag. |
| `system_original` | Platform (JP) | `game.metadata["Platform (JP)"]` | Preserve the populated Japanese platform label at package scope when consistent. |
| `artist_english` | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Put one shared value at package scope only when every track has that same populated value; otherwise preserve each populated value on its member. |
| `artist_original` | Album Artist (JP) / Artist (JP) | `game.metadata["Album Artist (JP)"]` or `members[].metadata["Artist (JP)"]` | Apply the same all-tracks uniformity rule while keeping the Japanese value distinct. |
| `date` | Date / Year | `game.metadata["Date"]` or `game.metadata["Year"]` | Use Date for a complete date and Year only for a year. Use package scope when shared; preserve varying populated values per member. |
| `converted_by` | Dumper | `game.metadata["Dumper"]` or `members[].metadata["Dumper"]` | Preserve the GD3 VGM Creator value. Use package scope only when every track has the same populated value; do not rename it Encoded By. |
| `notes` | Comment | `members[].metadata["Comment"]` | Preserve each populated track note; omit blanks. |
| VGM header version | Format | `members[].metadata["Format"]` | Record the version on every VGM member as `VGM v.1.51`, for example. Do not store a redundant package-level version summary. |

## Format Procedures

- **Sega System normalization** — Use `Sega Genesis`, `Sega CD`, `Sega 32X`,
  `Sega Master System`, `Sega Game Gear`, `Sega SG-1000`, and `Sega SC-3000`
  consistently. Map unambiguous GD3 spellings such as `Sega Mega Drive / Genesis`
  and `Sega Mega Drive / Genesis Mini` to `Sega Genesis`, `Sega MegaCD / SegaCD` to `Sega CD`,
  `Sega 32X / Mega 32X` to `Sega 32X`, and `Sega Game 1000` to
  `Sega SG-1000`. Resolve `Sega Master System / Game Gear` only when the
  containing pack establishes one platform; otherwise hold it for review.
  When a GD3 English System value is normalized, write the same canonical
  value into the UAC VGM member and `game.console`. Record the original and
  output stream hashes and the field change in the UAC transformation. Leave
  the source ZIP byte-identical and preserve the Japanese System value unless
  a per-set report documents a proven correction.
  Also normalize the approved device aliases `NeoGeo Pocket Color` to `Neo Geo
  Pocket Color` and `Bandai WonderSwan` to `WonderSwan`. Keep distinct
  compatible systems, such as Othello Multivision, distinct.
- **GD3 field preservation** — GD3 v1.00 defines eleven ordered strings. When
  changing a known standard field, preserve any additional serialized strings
  and report the member's nonstandard string count. Do not promote unnamed
  trailing strings into UAC tags.
- **Shared fields** — Promote a source field to package scope only when it is
  populated and uniform for every track. If values vary or some tracks omit
  the field, preserve populated values at member scope so package metadata does
  not imply a value on tracks that lack it.
- **VGZ packaging** — The UAC payload stores raw `.vgm`. Detect gzip by magic,
  not the suffix: remove exactly one gzip layer without changing the VGM header
  version or command stream, then update playlist references to `.vgm`. If a
  `.vgz` member already begins with a valid `Vgm ` header, pass its bytes through
  unchanged, rename that UAC member to `.vgm`, and report the source suffix
  mismatch. Record these transformations and keep the original source archive
  unchanged. Hold a second gzip layer or invalid VGM header for review.
- **M3U playlists** — Preserve every source playlist as its own UAC playlist and
  member. A playlist may be a partial queue; keep exactly its listed entries and
  retain every unqueued VGM track in the package. Preserve playlist order,
  comments, byte-order mark, and line endings while changing `.vgz` references
  to `.vgm`. Resolve a mismatched entry only when one source member is an
  unambiguous exact, case-insensitive, or same-number match; record that repair
  in the set report. Hold a package for review when an entry cannot be resolved.
- **Hashes** — Use the UAC Stream Hashes for each complete raw VGM member:
  BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5. These are wrapper hash records,
  not extra metadata tags.
- **VGMRIPS text and artwork** — The curated per-game TXT is a readable package
  note, not a second tag catalog. Include its unchanged bytes as `meta.txt` and
  reference it through package `documents`; preserve its source filename in
  provenance. Do not duplicate its track list, package history, or reader
  diagnostics as tags. The native GD3 fields remain the tag source. VGMRIPS
  artwork is a pack-level **Title Snap** attachment, with one reference for
  each in-archive image. Report loose image sidecars separately; do not silently
  substitute them for the source ZIP artwork or add duplicate copies.
- **No invented fields** — Do not add blank tags, `nativeMetadata`, parser
  dumps, technical statistics, a versionless `Format` tag, or duplicate
  `Game`, `Album`, and `Game Title` values when the source does not contain
  those distinct facts. Set identity uses **Set Name** and **Set URL** only;
  keep detailed provenance in `sources[]`.

## Required Checks

- **Headers and offsets** — Check signature, header bounds, EOF/data/GD3/loop
  offsets, and truncation. Record parse errors in the AudioMan set report.
- **Container versions** — Read every member's VGM version and expose it in
  that member's **Format** tag. Report packages that mix versions and hold them
  for review; never rewrite VGM versions.
- **VGZ expansion** — Confirm the uncompressed payload begins with `Vgm `,
  preserves the source version, and matches the indexed decompressed-stream
  identity when that evidence exists. Confirm every rewritten playlist
  reference resolves to one packaged member.
- **GD3 decoding** — Review UTF-16 diagnostics, conflicting values, and any
  extra serialized strings. Do not silently discard a populated standard GD3
  field or promote unknown trailing fields without reviewing their meaning.
- **Package accounting** — Compare source and UAC member paths, identify every
  intentional extension or playlist rewrite, and report missing/extra files,
  corruption, version mixtures, and UAC verification results in the affected
  set's AudioMan dashboard. Preserve additional source members when their role
  is understood; otherwise hold the package for review instead of dropping
  them.
- **Platform** — Hold missing, mixed, or ambiguous system identities for
  review. For an approved alias, verify that each affected embedded VGM English
  System value exactly matches `game.console`; keep original source tags in the
  unchanged source ZIP and Songbase record.
