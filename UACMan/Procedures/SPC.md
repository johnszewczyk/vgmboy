# Nintendo SNES · SPC Format Procedure

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

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Platform | `game.platform` | Set once per package to **Nintendo SNES**. |
| — | Game ID | `pack.metadata["Game ID"]` | Four-digit No-Intro ID; add only for a unique, high-confidence release match. |
| Game | Game Title | `track.metadata["Game Title"]` | Keep separate from package title and **Album**. Preserve lists and variation. |
| Song | Title | `track.metadata["Title"]` | Omit empty values. |
| OST Title | OST Title | `track.metadata["OST Title"]` | Keep as soundtrack title; do not relabel it as **Album**. |
| OST Disc | Disc Number | `track.metadata["Disc Number"]` | Preserve the source value; do not infer an OST disc. |
| OST Track | OST Track | `track.metadata["OST Track"]` | This is not display order or **Track Number**. |
| Artist | Artist | `track.metadata["Artist"]` | Preserve populated source text. |
| Dumper | Dumper | `track.metadata["Dumper"]` | Preserve populated source text. |
| Publisher | Publisher | `track.metadata["Publisher"]` | Preserve populated source text. |
| Comment | Comment | `track.metadata["Comment"]` | Preserve populated source text. |
| Date | Date | `track.metadata["Date"]` | Keep an explicit source date; do not use capture time. |
| Year | Year | `track.metadata["Year"]` | Preserve the source year; do not derive it from **Date**. |
| — | Format | `track.metadata["Format"]` | Use the SPC header revision as `SPC v.<revision>`; report disagreement with the text header. |

## Format Procedures

- ID666 and xID6 can both supply a field. Keep both source blocks byte-for-byte
  and record parser diagnostics or contradictory headers in the dated report.
- The reader may supply a 150-second duration fallback. Do not write it as
  **Play Length (ms)** without positive source timing.
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
