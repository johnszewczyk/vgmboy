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
`game.console = "Nintendo SNES"`. Store package **Format** as **SPC**.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| ID666/xID6 `Game` | Album | `game.metadata["Album"]` | Package-wide title; package identity remains in structural `game.title`. |
| ID666/xID6 `Song` | Title | `members[].metadata["Title"]` | Title for this SPC member. |
| xID6 `0x10` `Official Soundtrack Title` | OST Title | `members[].metadata["OST Title"]` | Distinct soundtrack title. |
| xID6 `0x11` `OST Disc` | Disc Number | `members[].metadata["Disc Number"]` | Soundtrack disc index. |
| xID6 `0x12` `OST Track` | Track Number | `members[].metadata["Track Number"]` | Source soundtrack order; do not reorder package members. |
| ID666/xID6 `Artist` | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Use Album Artist for a shared credit and Artist only for a track-specific credit. |
| ID666/xID6 `Dumper` | Dumper | `game.metadata["Dumper"]` or `members[].metadata["Dumper"]` | Store a shared credit once; keep a differing member value on that member. |
| xID6 `Publisher` | Publisher | `game.metadata["Publisher"]` or `members[].metadata["Publisher"]` | Store a shared fact once; keep a genuinely differing member value. |
| ID666/xID6 `Comment` | Comment | `game.metadata["Comment"]` or `members[].metadata["Comment"]` | Store shared comments once; keep genuinely track-specific comments. |
| ID666/xID6 `Date` | Date | `game.metadata["Date"]` or `members[].metadata["Date"]` | Explicit source date. |
| xID6 `0x14` `Copyright Year` | Year | `game.metadata["Year"]` or `members[].metadata["Year"]` | Source copyright year. |

## Format Procedures

- **OST fields** — `OST Title`, `OST Disc`, and `OST Track` are defined xID6
  fields (`0x10`, `0x11`, and `0x12`), not arbitrary user-defined tags.
- **Dual tag blocks** — Preserve ID666 and xID6 source bytes; record
  contradictory fields or parser diagnostics in the dated report.
- **Playback timing** — Keep source timing only when policy and a consumer use
  it. A parser's 150-second fallback is not source timing; store playback data
  in wrapper playback fields, not descriptive tags.

## Required Checks

- **SPC structure** — Validate signature, minimum size, revision byte, ID666
  layout, xID6 bounds, duplicates, and reader diagnostics.
- **Source accounting** — Account for every source archive and extracted
  member.
- **Package integrity** — Run `uacman inspect --verify`, then unpack and
  compare member paths, sizes, and source-byte identity.
- **Collection findings** — Keep counts and exceptions in dated reports under
  `Reports/`.
