# NEC TurboGrafx-16 · HES Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads HES header fields and an optional companion
extended M3U without emulating the PC Engine. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `hes`; source member: `.hes`.
- Reader: `MetaMan/Sources/MetaManCore/HESMetadataReader.swift`.
- HES header labels are exposed as `game`, `artist`, and `copyright`. The
  optional M3U contributes entry `title` values and keeps recognized comment
  tag names in their source spelling.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| game / M3U Game / TITLE | Game Title | `track.metadata["Game Title"]` | Prefer an explicit M3U game value, then the HES header value. Keep separate from package title and soundtrack **Album**. |
| artist / M3U Artist / ARTIST | Artist | `track.metadata["Artist"]` | Prefer explicit M3U artist, then the HES header value. |
| copyright | Copyright | `track.metadata["Copyright"]` | Preserve populated header text; if the entire value is only a year, use **Year**. |
| M3U title | Title | `track.metadata["Title"]` | Use the ordered playlist entry title; omit empty values. |
| M3U Composer / COMPOSER | Composer | `track.metadata["Composer"]` | Preserve populated source text. |
| M3U Engineer / ENGINEER | Engineer | `track.metadata["Engineer"]` | Preserve populated source text. |
| M3U Ripping / RIPPER | Dumper | `track.metadata["Dumper"]` | Preserve the person or tool credited with ripping. |
| M3U Tagging / TAGGER | Tagger | `track.metadata["Tagger"]` | Preserve separately from **Dumper**. |
| M3U Comment / COMMENT | Comment | `track.metadata["Comment"]` | Keep explicit, useful comments only. Omit a bare first-line value already used as the fallback **Game Title**. |

## Format Procedures

- Set `game.platform` to **NEC TurboGrafx-16**. The reader's **PC Engine**
  value is an alias for this canonical platform.
- Read the optional `.m3u` as package context. Preserve its bytes as a package
  asset when it supplies titles, order, or timing. Do not write its identity
  tags once for every playlist entry when one package-level fact is enough.
- HES has no authored track count. Without an M3U, MetaMan exposes 256
  compatibility slots; these are not evidence for 256 real tracks. Do not
  fabricate titles or **Track Number** values from them.
- Other M3U comment names pass through the reader but are not mapped here. Do
  not project them until their exact source names and UAC fields are reviewed.
- Keep positive source timing only when a playback consumer uses it. Omit the
  reader's 150-second fallback and its derived estimates.
- Keep version, address, bank, data-chunk, raw header, and parser facts out of
  ordinary metadata. Keep the HES source bytes unchanged.

## Required Checks

Validate the HES signature and header bounds. Check M3U paths, address-slot
ranges, order, timing, duplicate references, and UTF-8/Windows-1252 decoding.
Confirm the package's member-to-playlist mapping and preserve the companion
M3U when it contributes data.
