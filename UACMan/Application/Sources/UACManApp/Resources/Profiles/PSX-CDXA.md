# Sony PlayStation Disc Audio Format Procedure

Apply the shared [UAC Base Profile](BASE-UAC-PROFILE.md). This profile covers
Redump PlayStation disc audio represented as XA streams, Red Book CD-DA tracks,
or both. Extraction and game-specific loop evidence are defined in the
[PSX preservation protocol](../protocols/PSX-CDXA.protocol.md).

## Field Mapping

Store the canonical platform once as structural
`game.console = "Sony PlayStation"`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Game ID | `game.metadata["Game ID"]` | Add an external release ID only when a matching source record verifies it. |
| — | Region | `game.metadata["Region"]` | Two-letter code, such as `US`; use the same code in the package name. |
| — | Set Name | `game.metadata["Set Name"]` | Use the exact source collection name. |
| — | Set URL | `game.metadata["Set URL"]` | Use a stable collection URL; keep source URLs and checksums in `sources[]`. |
| — | Album | `game.metadata["Album"]` | Use an established soundtrack title without a region suffix; do not infer it from a filename. |
| — | Album Artist | `game.metadata["Album Artist"]` | Store a shared release-level artist once. |
| CUE global `PERFORMER` | Album Artist | `game.metadata["Album Artist"]` | Use only when the CUE credit is global to the release. |
| CUE track `TITLE` | Title | `members[].metadata["Title"]` | Keep the title attached to its audio member; do not use a filename fallback. |
| CUE track `PERFORMER` | Artist | `members[].metadata["Artist"]` | Use the track-specific performer; it takes precedence over Album Artist for that track. |
| Per-track Composer | Artist | `members[].metadata["Artist"]` | Use a per-track composer from an authoritative source, as directed by the shared artist rule. |
| — | Publisher | `game.metadata["Publisher"]` | Keep source-backed; do not infer Developer. |
| — | Developer | `game.metadata["Developer"]` | Keep only when separately established by an authoritative source. |
| — | Date | `game.metadata["Date"]` | Use a full source-backed release date; keep capture time in provenance. |
| — | Year | `game.metadata["Year"]` | Use only when the source gives a year without a full date. |
| CUE track number | Track Number | `members[].metadata["Track Number"]` | Store logical soundtrack order. Keep physical CUE indexes in the CUE attachment. |
| — | Disc Number | `game.metadata["Disc Number"]` | Use for a disc in a multi-disc release. |
| Measured member duration | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Current-schema timing field; it feeds playback timing policy and duration readouts. |
| Verified XA loop map | — | `members[].metadata.loop` | Current-schema sample-accurate loop object; keep it only when source-backed and used by playback. |
| Stored member format | — | `members[].format` | Store the actual member format/extension, such as `xa`, `ape`, or `flac`; do not create a duplicate Format tag. |

## Format Procedures

- `.xa` members are XA source streams. Red Book CD-DA is a disc-audio source
  type, not a filename extension; when encoded losslessly as APE or FLAC, the
  stored member format is `ape` or `flac`. Keep the Red Book source identity in
  the source/transformation record rather than a duplicate Format tag.
- `.psf`, `.psf2`, `.minipsf`, and related PSF-family files are separate
  MetaMan source formats, not PlayStation disc-audio variants. They need their
  own format profile. The PlayStation console name does not make every source
  format a CD-XA format.
- Keep the source CUE byte-for-byte as a package asset. It is authoritative for
  physical disc tracks, indexes, and pregaps; do not repeat those facts as
  member tags. Keep source BIN checksums in the source record.
- Keep full BIN images and downloaded archives in source study storage,
  outside the UAC payload by default. A UAC is optional when tagged audio plus
  the CUE is sufficient.
- Retain wrapper integrity hashes; do not create another tag-based checksum
  list or decoded-PCM hash catalog. XA reader facts and sector mappings are
  source evidence, not music tags.

## Required Checks

- Verify the source release, CUE, and member mapping before packaging.
- Review actual source tags; distinguish retained, projected, and authored
  values. Keep missing titles and credits absent.
- Run `uacman inspect --verify`; check member roles, paths, sizes, field
  coverage, CUE identity, playlist order, and positive loop objects.
- Record collection-specific counts and unresolved mappings in a dated report
  under `Reports/`.
