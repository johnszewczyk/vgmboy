# NEC TurboGrafx-16 · HES Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads the HES
header and an optional companion M3U
without emulating the PC Engine. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Scope

- **Reader** — `hes`; `HESMetadataReader.swift`.
- **Source members** — `.hes`; optional companion `.m3u`.
- **Coverage** — One sound module; M3U rows reference song indexes and may
  provide titles and timing. Playlist comments may provide shared identity and
  credits.
- **Status** — Draft; fixture validation pending.

## Field Mapping

Store the canonical platform once as structural
`game.console = "NEC TurboGrafx-16"`; `PC Engine` is a source alias. Store
package **Format** as **HES**.

### HES Header

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `game` | Album | `game.metadata["Album"]` | Package-wide title. |
| `artist` | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist. |
| `copyright` | Copyright | `game.metadata["Copyright"]` | If it contains only a year, use the shared Year rule. |

### Companion M3U Comments

MetaMan currently repeats playlist-wide comments in each logical-track result;
project each shared value once.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `Game` / `TITLE` | Album | `game.metadata["Album"]` | Prefer explicit playlist identity over the HES header. |
| `Artist` / `ARTIST` | Album Artist | `game.metadata["Album Artist"]` | Prefer explicit playlist artist over the HES header. |
| `COMPOSER` / `Composer` | Composer | `game.metadata["Composer"]` | Playlist-wide credit, not a per-song credit. |
| `ENGINEER` / `Engineer` | Engineer | `game.metadata["Engineer"]` | Playlist-wide credit. |
| `RIPPER` / `Ripping` | Dumper | `game.metadata["Dumper"]` | Playlist-wide credit. |
| `TAGGER` / `Tagging` | Tagger | `game.metadata["Tagger"]` | Playlist-wide credit. |
| `COMMENT` / `Comment` | Comment | `game.metadata["Comment"]` | Keep useful text; do not duplicate a bare first-line Album fallback. |

### Companion M3U Entries

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| M3U entry title | Title | `playlists[].entries[].title` | Attach to its ordered HES song index. |
| M3U entry length / loop / fade | — | `playlists[].entries[].lengthRaw`, `loopRaw`, `loopStartRaw`, `fadeRaw` | Preserve authored values in their source units as playback data. |

## Format Procedures

- **Companion bytes** — Preserve the M3U when it supplies titles, order,
  identity, or timing. Keep entries in source order, map each to its HES index,
  and retain original lines/context in the playlist.
- **No M3U** — The reader's 256 compatibility slots do not establish 256 real
  songs. Do not create titles or Track Number values from them.
- **Shared comments** — Store playlist-wide values once; do not copy them to
  each song.
- **Timing** — Keep authored timing only when a playback consumer uses it.
  Omit the reader's 150-second fallback and derived estimates.
- **Technical data** — Keep version, address, bank, data-chunk, raw-header, and
  parser facts out of ordinary metadata; preserve HES source bytes unchanged.

## Required Checks

- **HES header** — Validate signature and header bounds.
- **M3U** — Check paths, address-slot ranges, order, timing, duplicate
  references, and UTF-8/Windows-1252 decoding.
- **Package mapping** — Confirm member-to-playlist mapping and preserve the
  companion M3U when it contributes data.
