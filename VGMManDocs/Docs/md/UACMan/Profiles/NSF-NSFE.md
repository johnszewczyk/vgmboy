# Nintendo NES · NSF / NSFE Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads
fixed-header NSF and chunk-based NSFE files. See
[`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — `nsf` and `nsfe`; `GameMusicMetadataReader.swift`.
- **Source members** — `.nsf` and `.nsfe`.
- **Coverage** — NSF has package-wide `game`, `artist`, and `comment` fields.
  NSFE adds package-wide `copyright`, `ripper`, and `notes`, plus per-song
  `title` and `track-author` fields.
- **Status** — Draft; fixture validation pending.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo NES"`. Store one package-level **Format** value,
**NSF** or **NSFE**, matching the playable members. Do not mix NSF and NSFE
members in one UAC; their stored extensions remain structural details, not
per-member metadata tags.

### NSF

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `game` | Album | `game.metadata["Album"]` | Package-wide title. |
| `artist` | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist; consumers can use it when a song has no Artist. |
| `comment` | Comment | `game.metadata["Comment"]` | Package-wide source comment. |

NSF has no authored per-song title or `track-author`; retain each source song
index in its playlist entry and do not fabricate song titles.

### NSFE

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `game` | Album | `game.metadata["Album"]` | Package-wide title. |
| `artist` | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist; do not repeat it on every song. |
| `copyright` | Copyright | `game.metadata["Copyright"]` | Package-wide copyright text. |
| `ripper` | Dumper | `game.metadata["Dumper"]` | Package-wide credit. |
| `notes` | Comment | `game.metadata["Comment"]` | Combine with other comments only when meaning is preserved. |
| `title` | Title | `playlists[].entries[].title` | `tlbl` label for the referenced source index. |
| `track-author` | Artist | `playlists[].entries[].artist` | `taut` belongs to this song and overrides package artist for it. |
| `time-ms` | — | `playlists[].entries[].lengthRaw` | Source timing in its original units. |
| `fade-ms` | — | `playlists[].entries[].fadeRaw` | Source fade timing for the corresponding song. |

## Format Procedures

- **Playlist structure** — Preserve NSF source indexes and NSFE order/repeats
  in playlist entries. Do not create one member per subsong or duplicate
  shared header metadata on each entry.
- **Playback timing** — Keep positive authored timing in playback fields only
  when a consumer uses it. A reader fallback duration is not source metadata.
- **NSFE chunks** — Preserve non-audio chunks. Surface a sound-effect
  distinction only when a consumer uses it.
- **Technical data** — Keep header addresses, speed fields, banks, region,
  expansion-chip flags, counters, and parser diagnostics out of ordinary
  metadata.

## Required Checks

- **NSF header** — Check the 128-byte header, version, declared track count,
  first-track index, and index bounds.
- **NSFE chunks** — Validate `INFO`, `DATA`, and `NEND` bounds, `PLST`
  references/repeats, and preservation of non-audio chunks.
