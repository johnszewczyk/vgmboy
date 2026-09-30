# Nintendo NES · NSF / NSFE Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads fixed-header NSF and chunk-based NSFE files.
See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader IDs: `nsf` and `nsfe`; source members: `.nsf` and `.nsfe`.
- Reader: `MetaMan/Sources/MetaManCore/GameMusicMetadataReader.swift`.
- NSF has package-wide `game`, `artist`, and `comment` header values. NSFE
  adds package-wide `copyright`, `ripper`, and `notes`, plus per-song `title`
  and `track-author` values.

## Field Mapping

The platform is stored once as structural `game.console = "Nintendo NES"`.
The file extension is stored in `members[].format`; no version tag is needed.

### NSF

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| game | Album | `game.metadata["Album"]` | Package-wide game/album title. |
| artist | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist; consumers can use it when a song has no track Artist. |
| comment | Comment | `game.metadata["Comment"]` | Package-wide source comment. |

NSF has no authored per-song title or `track-author` field. Keep the source
song index in each subsong playlist entry; do not fabricate song titles.

### NSFE

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| game | Album | `game.metadata["Album"]` | Package-wide game/album title. |
| artist | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist; do not repeat it on every song. |
| copyright | Copyright | `game.metadata["Copyright"]` | Package-wide copyright text. |
| ripper | Dumper | `game.metadata["Dumper"]` | Package-wide ripper credit. |
| notes | Comment | `game.metadata["Comment"]` | Keep notes as Comment; combine with other comments only when meaning is preserved. |
| title | Title | `playlists[].entries[].title` | `tlbl` label for the referenced source index. |
| track-author | Artist | `playlists[].entries[].artist` | `taut` value belongs to this song and overrides the package artist for that song. |
| time-ms | — | `playlists[].entries[].lengthRaw` | Source timing for the corresponding song, in the source field's units. |
| fade-ms | — | `playlists[].entries[].fadeRaw` | Source fade timing for the corresponding song. |

## Format Procedures

- Preserve NSF source indexes and NSFE playlist order and repeats in playlist
  structure. Do not create one UAC member per subsong or duplicate shared
  header metadata on every entry.
- Keep positive authored timing only in the playlist playback fields used by a
  consumer. A reader fallback duration is not source metadata.
- Preserve NSFE non-audio chunks. Surface the sound-effect distinction only
  when a consumer uses it.
- Keep header addresses, speed fields, banks, region, expansion-chip flags,
  counters, and parser diagnostics out of ordinary metadata.

## Required Checks

For NSF, check the 128-byte header, version, declared track count, first-track
index, and index bounds. For NSFE, validate `INFO`, `DATA`, and `NEND`, chunk
bounds, `PLST` references and repeats, and preserved non-audio chunks.
