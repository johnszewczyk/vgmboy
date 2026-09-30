# Nintendo NES · NSF / NSFE Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads fixed-header NSF and chunk-based NSFE files.
See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader IDs: `nsf` and `nsfe`; source members: `.nsf` and `.nsfe`.
- Reader: `MetaMan/Sources/MetaManCore/GameMusicMetadataReader.swift`.
- NSF exposes `game`, `artist`, and `comment`; NSFE exposes those plus
  `copyright`, `ripper`, `notes`, `title`, and `track-author`.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Platform | `game.platform` | Set once per package to **Nintendo NES**. |
| — | Format | `track.metadata["Format"]` | NSF header version as `NSF v.<integer>`; use `NSFE` for NSFE. |
| game | Game Title | `track.metadata["Game Title"]` | Preserve populated source text; keep distinct from package title and soundtrack **Album**. |
| artist | Artist | `track.metadata["Artist"]` | Preserve populated source text. |
| comment | Comment | `track.metadata["Comment"]` | NSF comment; omit empty values. |
| copyright | Copyright | `track.metadata["Copyright"]` | NSFE copyright; omit empty values. |
| ripper | Dumper | `track.metadata["Dumper"]` | NSFE ripper credit; omit empty values. |
| notes | Comment | `track.metadata["Comment"]` | NSFE notes; combine with an existing comment only when meaning is preserved. |
| title | Title | `track.metadata["Title"]` | NSFE `tlbl` label at the referenced source index; omit empty labels. |
| track-author | Artist | `track.metadata["Artist"]` | NSFE `taut` label; preserve track-specific attribution. |

## Format Procedures

- Preserve NSF source indexes and NSFE playlist order and repeats in playlist
  structure. Do not fabricate titles for unlabeled entries.
- Keep positive authored NSFE timing only in playback fields when a consumer
  uses it. Do not emit `time-ms` or `fade-ms` as ordinary metadata tags.
- Preserve NSFE non-audio chunks. Surface the sound-effect distinction only
  when a consumer uses it.
- The reader's 150-second fallback is not source metadata. Keep header
  addresses, speed fields, banks, region, expansion-chip flags, counters, and
  parser diagnostics out of ordinary tags.

## Required Checks

For NSF, check the 128-byte header, version, declared track count, first-track
index, and index bounds. For NSFE, validate `INFO`, `DATA`, and `NEND`, chunk
bounds, `PLST` references and repeats, and preserved non-audio chunks.
