# Nintendo Game Boy GBS Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads GBS headers and optional NEZplug extended-M3U
sidecars. See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `gbs`; source member: `.gbs`.
- Readers: `MetaMan/Sources/MetaManCore/GameMusicMetadataReader.swift` and
  `GBSM3UMetadataReader.swift`.
- Header fields are `game`, `artist`, and `comment`. M3U entry titles are
  `title`; recognized M3U comment keys keep their source spelling.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo Game Boy"`. Store the member format as `gbs`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| game / M3U `TITLE` | Album | `game.metadata["Album"]` | Package-wide game/album title; an M3U title comment overrides the header value. |
| artist / M3U `ARTIST` | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist; keep it once even when the reader repeats it for every M3U entry. |
| comment | Comment | `game.metadata["Comment"]` | Package-wide header comment. |
| M3U `title` | Title | `playlists[].entries[].title` | Entry title for its referenced source index. |
| M3U `DATE` | Date | `game.metadata["Date"]` | Package-wide date comment. |

## Format Procedures

- Other M3U comment names are reader output, not approved UAC fields. Add a
  mapping before projecting them.
- Keep playlist order and source indexes in ordered playlist entries. Preserve
  positive authored timing in the playlist's playback fields when a consumer
  uses it; do not turn order, loop, fade, or reader defaults into tags.
- Preserve the companion M3U bytes when it contributes titles, identity, or
  playback data.

## Required Checks

Check the 112-byte header, signature, version, declared track count, and first
track index. Validate M3U target names, index ranges, ordering, and timing
fields. The reader's 150-second fallback is not source metadata.
