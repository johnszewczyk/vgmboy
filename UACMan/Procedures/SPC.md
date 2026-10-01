# Nintendo SNES · SPC Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md),
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md), and, for set conversions, the
applicable [Base Set Profile](Sets/BASE-SET-PROFILE.md). MetaManCore reads SPC
ID666 and xID6 metadata without starting an emulator. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Scope

- **Reader** — `spc`; `SPCMetadataReader.swift`.
- **Source members** — `.spc`.
- **Coverage** — Populated ID666 and xID6 fields; xID6 takes precedence when
  both blocks provide the same field.
- **Status** — Approved against collection fixtures; set-specific findings
  remain in dated reports.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo SNES"`. On each track, use **Format** for the
sub-container and version together, such as `SPC v.30` or `SPC v.10`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| ID666/xID6 `Game` | Album | `members[].metadata["Album"]` or `playlists[].entries[].extraFields["Album"]` | Preserve the source game name on each corresponding track. Do not substitute package identity or a database title. |
| ID666/xID6 `Song` | Title | `members[].metadata["Title"]` | Title for this SPC member. |
| xID6 `0x10` `Official Soundtrack Title` | OST Title | `members[].metadata["OST Title"]` | Distinct soundtrack title. |
| xID6 `0x11` `OST Disc` | Disc Number | `members[].metadata["Disc Number"]` | Soundtrack disc index. |
| xID6 `0x12` `OST Track` | — | — | Do not expose this encoded source code as Track Number; use the established member/file order for visible Track Number. |
| ID666/xID6 `Artist` | Artist | `members[].metadata["Artist"]` or `playlists[].entries[].extraFields["Artist"]` | Preserve the populated source value on its track, even when repeated across tracks. |
| ID666/xID6 `Dumper` | Dumper | `members[].metadata["Dumper"]` or `playlists[].entries[].extraFields["Dumper"]` | Preserve the populated source value on its track; prefer the full xID6 value over a shortened duplicate ID666 value. |
| xID6 `Publisher` | Publisher | `members[].metadata["Publisher"]` or `playlists[].entries[].extraFields["Publisher"]` | Preserve the populated source value on its track. |
| SPC source `Developer` | Developer | `members[].metadata["Developer"]` or `playlists[].entries[].extraFields["Developer"]` | Preserve only when present in source metadata; do not infer it from Publisher. |
| ID666/xID6 `Comment` | Comment | `members[].metadata["Comment"]` or `playlists[].entries[].extraFields["Comment"]` | Preserve a populated source comment on its track; omit blanks. |
| ID666/xID6 `Date` | Date | `members[].metadata["Date"]` or `playlists[].entries[].extraFields["Date"]` | Preserve the explicit source date on its track. |
| xID6 `0x14` `Copyright Year` | Year | `members[].metadata["Year"]` or `playlists[].entries[].extraFields["Year"]` | Preserve the source copyright year on its track. |
| SPC revision byte | Format | `members[].metadata["Format"]` or `playlists[].entries[].extraFields["Format"]` | Store the actual version per track, including repeated `SPC v.30` and any valid `SPC v.10`; do not summarize it or treat a different version as a bad tag. |

## Format Procedures

- **OST fields** — `OST Title`, `OST Disc`, and `OST Track` are defined xID6
  fields (`0x10`, `0x11`, and `0x12`), not arbitrary user-defined tags.
- **Dual tag blocks** — Preserve ID666 and xID6 source bytes; record
  contradictory fields or parser diagnostics in the dated report.
- **Source hashes** — Keep the four **Stream Hashes** for each SPC track. For
  SNESMusic.org, also repeat that track's parent-archive **Source .rsn Hashes**
  list on the track as a positive source-identity tag, as specified by the set
  profile. Keep the four RSN digests in the permanent source-state database;
  embedding them in UAC does not replace that record.
- **Playback timing** — Keep source timing only when policy and a consumer use
  it. A parser's 150-second fallback is not source timing; store playback data
  in wrapper playback fields, not descriptive tags.
- **Tag cleanup** — Keep source-backed fields in Title Case; omit blank tags,
  parser-only encoding labels, and the encoded xID6 OST Track code. Keep source
  **Disc Number** and the filename/order-based **Track Number** distinct.

## Required Checks

- **SPC structure** — Validate signature, minimum size, revision byte, ID666
  layout, xID6 bounds, duplicates, and reader diagnostics.
- **Source accounting** — Account for every source archive and extracted
  member.
- **Package integrity** — Run `uacman inspect --verify`, then unpack and
  compare member paths, sizes, and source-byte identity.
- **Report ownership** — Keep reusable SPC reader/fixture findings in UACMan
  procedures. Record live set counts, applied tags, and exceptions in
  AudioMan's per-set UAC dashboard, separate from ROM/set completeness.
