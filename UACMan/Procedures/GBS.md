# Nintendo Game Boy · GBS Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads GBS headers and optional NEZplug extended-M3U
sidecars. See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `gbs`; source member: `.gbs`.
- Readers: `MetaMan/Sources/MetaManCore/GameMusicMetadataReader.swift` and
  `GBSM3UMetadataReader.swift`.
- Fixed-header fields are exposed as lowercase `game`, `artist`, and
  `comment`. M3U entry titles are exposed as lowercase `title`; recognized M3U
  comment keys retain their source spelling.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Platform | `game.platform` | Set once per package to **Nintendo Game Boy**. |
| — | Format | `track.metadata["Format"]` | Use the header version as `GBS v.<integer>`. |
| game | Game Title | `track.metadata["Game Title"]` | Preserve populated source text; omit empty values. |
| artist | Artist | `track.metadata["Artist"]` | Preserve populated source text. |
| comment | Comment | `track.metadata["Comment"]` | Preserve populated source text. |
| title | Title | `track.metadata["Title"]` | M3U entry title for its referenced source index; omit when empty. |
| TITLE | Game Title | `track.metadata["Game Title"]` | M3U `@TITLE`; use common game identity, not a filename. |
| ARTIST | Artist | `track.metadata["Artist"]` | M3U `@ARTIST`; use only when it supplies useful artist metadata. |
| DATE | Date | `track.metadata["Date"]` | M3U `@DATE`; keep only a populated date. |

## Format Procedures

- Other M3U comment names are reader output, not automatically approved UAC
  tags. Add a mapping before projecting them.
- Keep playlist order, source indexes, and positive authored timing in their
  playback fields when a consumer uses them. Do not turn order, loop, fade, or
  the reader's default duration into ordinary metadata.
- Preserve the companion M3U bytes when it contributes titles, identity, or
  playback data.

## Required Checks

Check the 112-byte header, signature, version, declared track count, and first
track index. Validate M3U target names, index ranges, ordering, and timing
fields. The reader's 150-second fallback is not source metadata.
