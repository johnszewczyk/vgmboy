# NEC TurboGrafx-16 · HES Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads the HES header and an optional companion M3U
without emulating the PC Engine. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `hes`; source member: `.hes`.
- Reader: `MetaMan/Sources/MetaManCore/HESMetadataReader.swift`.
- The HES file is one sound module. An optional M3U is a companion playlist:
  each row points to an HES song index and may provide a title and timing.
  Playlist comments can provide shared album identity and credits.

## Field Mapping

Store the canonical platform once as structural
`game.console = "NEC TurboGrafx-16"`. The reader's `PC Engine` label is an
alias. Store the HES member extension in `members[].format`.

### HES header

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| game | Album | `game.metadata["Album"]` | Package-wide game/album title. |
| artist | Album Artist | `game.metadata["Album Artist"]` | Package-wide artist. |
| copyright | Copyright | `game.metadata["Copyright"]` | Package-wide copyright text. If it contains only a year, use the shared Year rule. |

### Companion M3U comments

These comments apply to the playlist as a whole. MetaMan currently repeats
them in each logical-track reader result; project each shared value once.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `Game` / `TITLE` | Album | `game.metadata["Album"]` | Prefer explicit playlist identity over the HES header value. |
| `Artist` / `ARTIST` | Album Artist | `game.metadata["Album Artist"]` | Prefer explicit playlist artist over the HES header value. |
| `COMPOSER` / `Composer` | Composer | `game.metadata["Composer"]` | The supported M3U comment is playlist-wide, not a per-song credit. |
| `ENGINEER` / `Engineer` | Engineer | `game.metadata["Engineer"]` | Playlist-wide credit. |
| `RIPPER` / `Ripping` | Dumper | `game.metadata["Dumper"]` | Playlist-wide credit. |
| `TAGGER` / `Tagging` | Tagger | `game.metadata["Tagger"]` | Playlist-wide credit. |
| `COMMENT` / `Comment` | Comment | `game.metadata["Comment"]` | Keep explicit useful text. A bare first-line value used as fallback Album is not a second Comment. |

### Companion M3U entries

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| M3U entry title | Title | `playlists[].entries[].title` | Use the title for that ordered HES song index. |
| M3U entry length / loop / fade | — | `playlists[].entries[].lengthRaw`, `loopRaw`, `loopStartRaw`, `fadeRaw` | Preserve authored values in the playlist's source units. |

## Format Procedures

- Preserve the companion M3U bytes when it supplies titles, order, identity,
  or timing. Keep its entries in source order and map each entry to the HES
  source index; retain original lines/context in the playlist.
- Without an M3U, the reader exposes 256 compatibility slots. These do not
  establish 256 real songs. Do not create titles or **Track Number** values
  from those slots.
- Do not copy shared playlist comments onto every song. Keep timing only when
  it is authored and a playback consumer uses it; omit the reader's 150-second
  fallback and derived estimates.
- Keep version, address, bank, data-chunk, raw-header, and parser facts out of
  ordinary metadata. Preserve the HES source bytes unchanged.

## Required Checks

Validate the HES signature and header bounds. Check M3U paths, address-slot
ranges, order, timing, duplicate references, and UTF-8/Windows-1252 decoding.
Confirm the package's member-to-playlist mapping and preserve the companion
M3U when it contributes data.
