# Nintendo SNES SPC Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md),
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md), and, for set conversions,
the applicable [Base Set Profile](Sets/BASE-SET-PROFILE.md). MetaManCore reads
SPC ID666 and xID6 metadata without starting an emulator. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `spc`; source member: `.spc`.
- Reader: `MetaMan/Sources/MetaManCore/SPCMetadataReader.swift`.
- The reader exposes populated ID666 and xID6 labels as `MetadataTag` names;
  xID6 takes precedence where both blocks provide the same field.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo SNES"`. The stored member format is `spc`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| ID666/xID6: Game | Album | `game.metadata["Album"]` | Package-wide game/album title; keep package identity in structural `game.title`. |
| ID666/xID6: Song | Title | `members[].metadata["Title"]` | Song title for this SPC member. |
| xID6 `0x10`: Official Soundtrack Title | OST Title | `members[].metadata["OST Title"]` | Distinct soundtrack-title field. |
| xID6 `0x11`: OST Disc | Disc Number | `members[].metadata["Disc Number"]` | Track's soundtrack disc index. |
| xID6 `0x12`: OST Track | Track Number | `members[].metadata["Track Number"]` | Store the source OST sequence number; do not use it to reorder package members. |
| ID666/xID6: Artist | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Use Album Artist for a package-wide credit and track Artist only for a track-specific credit. |
| ID666/xID6: Dumper | Dumper | `game.metadata["Dumper"]` or `members[].metadata["Dumper"]` | Store a shared credit once; retain a differing per-track value on that member. |
| xID6: Publisher | Publisher | `game.metadata["Publisher"]` or `members[].metadata["Publisher"]` | Store a shared fact once; retain a genuinely differing member value. |
| ID666/xID6: Comment | Comment | `game.metadata["Comment"]` or `members[].metadata["Comment"]` | Store a shared comment once; retain a genuinely track-specific comment. |
| ID666/xID6: Date | Date | `game.metadata["Date"]` or `members[].metadata["Date"]` | Explicit source date. |
| xID6 `0x14`: Copyright Year | Year | `game.metadata["Year"]` or `members[].metadata["Year"]` | Source copyright year. |

## Format Procedures

- OST Title, OST Disc, and OST Track are defined xID6 items (`0x10`, `0x11`,
  and `0x12`); they are SPC-format fields, not arbitrary user-defined tags.
- ID666 and xID6 can both supply a field. Keep both source blocks byte-for-byte
  and record contradictory headers or parser diagnostics in the dated report.
- Keep source playback timing only when the timing policy and consumer use it.
  A parser's 150-second fallback is not source timing. Store timing in the
  wrapper's playback fields, not as descriptive metadata tags.

## Required Checks

Validate the SPC signature, minimum size, revision byte, ID666 layout, xID6
bounds, duplicate tags, and reader diagnostics. Confirm every source archive
and extracted member is accounted for, run `uacman inspect --verify`, then
unpack and compare member paths, sizes, and source-byte identity. Keep
collection counts and exceptions in dated reports under `Reports/`.
