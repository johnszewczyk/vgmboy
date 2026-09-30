# Sony PlayStation · Disc Audio Format Procedure

Apply the shared [UAC Base Profile](BASE-UAC-PROFILE.md). This profile covers
Redump PlayStation disc audio represented as XA streams, Red Book CD-DA tracks,
or both. Extraction and game-specific loop evidence are defined in the
[PSX preservation protocol](../protocols/PSX-CDXA.protocol.md).

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Platform | `game.platform` | Set once per package to `Sony PlayStation`; do not add a repeated track tag. |
| — | Game ID | `pack.metadata["Game ID"]` | Add an external release ID only when a matching source record verifies it. |
| — | Region | `pack.metadata["Region"]` | Two-letter code, such as `US`; use the same code in the package name. |
| — | Set Name | `pack.metadata["Set Name"]` | Use the exact source collection name. |
| — | Set URL | `pack.metadata["Set URL"]` | Use a stable collection URL; keep member URLs and checksums in `sources[]`. |
| — | Album | `track.metadata["Album"]` | Use an established soundtrack title without region suffix; do not infer it from a filename. |
| TITLE | Title | `track.metadata["Title"]` | CUE track title; use populated source-backed values and omit placeholders. |
| PERFORMER | Artist | `track.metadata["Artist"]` | Use a per-track CUE performer; do not copy a game-level credit onto tracks. |
| — | Composer | `track.metadata["Composer"]` | Use a per-track credit from an authoritative source; omit when absent. |
| — | Publisher | `track.metadata["Publisher"]` | Keep source-backed; do not infer Developer. |
| — | Developer | `track.metadata["Developer"]` | Keep only when separately established by an authoritative source. |
| — | Date | `track.metadata["Date"]` | Use a full source-backed date; keep capture time in provenance. |
| — | Year | `track.metadata["Year"]` | Use when only the year is known; do not duplicate the same fact as Date. |
| — | Format | `track.metadata["Format"]` | Use `CD-ROM XA` or `Red Book CD-DA`; distinct from structural `track.format`. |
| — | Track Number | `track.metadata["Track Number"]` | Give the number a documented meaning. Do not mix physical CUE track numbers with logical soundtrack order. |
| — | Disc Number | `track.metadata["Disc Number"]` | Source-backed only; omit a repeated `1` for a single-disc set. |
| — | Play Length (ms) | `track.metadata["Play Length (ms)"]` | Positive, source-backed operational readout only; omit estimates, defaults, and values with no consumer. |
| — | — | `track.metadata.loop` | Wrapper loop object with sample boundaries; keep positive, source-backed loops used by playback. |

## Format Procedures

- Keep the source CUE byte-for-byte as a package asset. It is the authority for
  physical disc tracks, indexes, and pregaps; do not repeat those facts as
  member tags. Keep source BIN checksums in the verification attachment and
  source record.
- Keep full BIN images and downloaded archives in source study storage, outside
  the UAC payload by default. A UAC is optional when tagged audio plus the CUE
  is sufficient.
- The packer writes its standard scoped raw-member and playable-payload hashes.
  Retain those wrapper records; do not create another tag-based checksum list
  or decoded-PCM hash catalog.
- XA reader facts and sector mappings are evidence, not music tags. Retain only
  the positive loop object needed by playback; keep source-sector research in
  the report or protocol.

## Required Checks

- Verify the source release, CUE, and member mapping before packaging.
- Review actual source tags; distinguish retained, projected, and authored
  values. Keep missing titles and credits absent.
- Run `uacman inspect --verify`; check member roles, paths, sizes, field
  coverage, CUE identity, playlist order, and positive loop objects.
- Record collection-specific counts and unresolved mappings in a dated report
  under `Reports/`.
