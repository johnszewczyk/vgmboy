# Nintendo SNES SPC Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads SPC ID666
and xID6 metadata without starting an emulator. See
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
| — | Game ID | `game.metadata["Game ID"]` | Four-digit No-Intro ID; add only for a unique, high-confidence release match. |
| Game | Album | `game.metadata["Album"]` | Use the package-wide game/album title. Keep package identity in structural `game.title`. |
| Song | Title | `members[].metadata["Title"]` | Song title for this SPC member. |
| OST Title | OST Title | `members[].metadata["OST Title"]` | Keep the source's distinct soundtrack-title fact; do not overwrite Album when the values differ. |
| OST Disc | Disc Number | `game.metadata["Disc Number"]` | Use only when the source establishes a disc in a multi-disc release. |
| OST Track | OST Track | `members[].metadata["OST Track"]` | OST source index, not logical package order or **Track Number**. |
| Artist | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Use Album Artist when the credit is shared across the package; use track Artist only for a track-specific credit. |
| Dumper | Dumper | `game.metadata["Dumper"]` or `members[].metadata["Dumper"]` | Store a shared credit once; retain a differing per-track value on that member. |
| Publisher | Publisher | `game.metadata["Publisher"]` or `members[].metadata["Publisher"]` | Store a shared fact once; retain a genuinely differing member value. |
| Comment | Comment | `game.metadata["Comment"]` or `members[].metadata["Comment"]` | Store a shared comment once; retain a genuinely track-specific comment on that member. |
| Date | Date | `game.metadata["Date"]` or `members[].metadata["Date"]` | Keep an explicit source date; do not use capture time. |
| Year | Year | `game.metadata["Year"]` or `members[].metadata["Year"]` | Keep a distinct source year; do not derive it from Date. |

## Format Procedures

- ID666 and xID6 can both supply a field. Keep both source blocks byte-for-byte
  and record contradictory headers or parser diagnostics in the dated report.
- The reader may supply a 150-second duration fallback. Do not project it as
  source playback timing. Keep positive source timing only when the playback
  policy uses it.
- Keep source tags and unknown xID6 items in the unchanged SPC bytes. Do not
  copy the reader document, bulk native tags, raw tag blocks, diagnostics, or
  header facts into ordinary metadata.
- Keep per-member integrity hashes in the UAC hash model. Do not turn hashes,
  revision inventories, or parser facts into ordinary tag fields.

## Required Checks

Validate the SPC signature, minimum size, revision byte, ID666 layout, xID6
bounds, duplicate tags, and reader diagnostics. Confirm every source archive
and extracted member is accounted for, run `uacman inspect --verify`, then
unpack and compare member paths, sizes, and source-byte identity. Keep
collection counts and exceptions in dated reports under `Reports/`.
