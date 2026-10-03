# Nintendo Game Boy · GBS Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads GBS
headers and optional NEZplug extended-M3U
sidecars. See `VGMManDocs > MetaMan > format-layouts.md`.

## Scope

- **Reader** — `gbs`; `GameMusicMetadataReader.swift` and
  `GBSM3UMetadataReader.swift`.
- **Source members** — `.gbs`; optional companion `.m3u`.
- **Coverage** — Header fields `game`, `artist`, and `comment`; M3U entry
  titles and recognized comment keys.
- **Status** — Draft; fixture validation pending.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo Game Boy"`. Store package **Format** as **GBS**.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `game` / M3U `TITLE` | Album | `game.metadata["Album"]` | Package-wide title; an M3U title comment overrides the header value. |
| `artist` / M3U `ARTIST` | Album Artist | `game.metadata["Album Artist"]` | Store a shared artist once, even when repeated for every M3U entry. |
| `comment` | Comment | `game.metadata["Comment"]` | Package-wide header comment. |
| M3U `title` | Title | `playlists[].entries[].title` | Title for the referenced source index. |
| M3U `DATE` | Date | `game.metadata["Date"]` | Package-wide date comment. |

## Format Procedures

- **Other M3U comments** — Reader output is not automatic approval; add a
  mapping before projecting a field.
- **Playlist structure** — Preserve order and source indexes in playlist
  entries; do not turn them into metadata tags.
- **Playback timing** — Keep positive authored timing in playback fields only
  when a consumer uses it. Do not promote loop, fade, or reader defaults to
  descriptive tags.
- **Companion bytes** — Preserve the M3U when it contributes titles, identity,
  or playback data.

## Required Checks

- **GBS header** — Check the 112-byte header, signature, version, declared
  track count, and first track index.
- **M3U mapping** — Validate target names, index ranges, order, and timing.
- **Fallback duration** — Do not project the reader's 150-second fallback as
  source metadata.
