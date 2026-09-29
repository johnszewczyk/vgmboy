# Sony PlayStation Disc Audio Profile

Apply the shared [UAC Base Profile](BASE-UAC-PROFILE.md). This profile covers
Redump PlayStation disc audio represented as XA streams, Red Book CD-DA tracks,
or both. Extraction and game-specific loop evidence are defined in the
[PSX preservation protocol](../protocols/PSX-CDXA.protocol.md).

## Field mapping

| Source fact | UAC location | Type and normalization | Omission or review rule |
| --- | --- | --- | --- |
| PlayStation system | `game.console` | `Sony PlayStation` | Do not add a per-track `Platform`, `System`, or `Console` tag. |
| Verified release identity | `game.metadata["Game ID"]` | Canonical release name with agreed region suffix | Add an external release ID only when a matching source record verifies it. |
| Region | `game.metadata["Region"]` | Two-letter code, such as `US` | Use the same region code in the package name. |
| Source collection | `game.metadata["Set Name"]`, `game.metadata["Set URL"]` | Exact collection name and stable collection URL | Keep archive-member URLs and checksums in `sources[]`. Do not add `Set Collection` when it only repeats the same collection identity. |
| Game or soundtrack title | `member.metadata["Album"]` | Established title without region suffix | Omit when unsupported; do not infer it from a filename. |
| Track title and credits | `member.metadata["Title"]`, `Artist`, `Composer`, `Publisher`, `Developer` | Populated source-backed values | Do not synthesize placeholders or copy game-level credits onto tracks. |
| Release date | `member.metadata["Date"]` or `Year` | Full date when known; otherwise year | Do not store both for one release date. Keep both only for distinct facts such as release date and copyright year. Keep capture time in provenance. |
| Contained format | `member.metadata["Format"]` | `CD-ROM XA` or `Red Book CD-DA` | One source-format value; distinct from `member.format` such as `xa` or `ape`. |
| Track sequence | `member.metadata["Track Number"]` | Number with a documented meaning | File-per-track CD-DA uses physical CUE track numbers. An explicitly OST-ordered mixed-mode set may use logical sequence numbers. Do not mix the two meanings. |
| Disc number | `member.metadata["Disc Number"]` | Source-backed disc number | Omit a repeated `1` for a single-disc set. |
| Duration used by consumers | `member.metadata["Play Length (ms)"]` | Positive, source-backed milliseconds | Optional operational readout. Omit estimates, defaults, and values with no consumer. |
| Verified loop | `member.metadata.loop` | Wrapper loop object with sample boundaries | Store only positive, source-backed loops used by playback; see the protocol. |

## PSX-specific handling

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

## Required checks

- Verify the source release, CUE, and member mapping before packaging.
- Review actual source tags; distinguish retained, projected, and authored
  values. Keep missing titles and credits absent.
- Run `uacman inspect --verify`; check member roles, paths, sizes, field
  coverage, CUE identity, playlist order, and positive loop objects.
- Record collection-specific counts and unresolved mappings in a dated report
  under `Reports/`.
