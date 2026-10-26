# AY, SAP, NSFE, SNDH, and S98 Profiles

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). This page covers the
registered readers for ZX Spectrum AY, Atari SAP, NES NSFE, Atari ST SNDH, and
S98 music files. Reader layout details are in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Readers** — ay, sap, nsfe, sndh, and s98 in MetaManCore.
- **Source members** — Registered .ay, .sap, .nsfe, .sndh, and .s98 files.
  Retain required companions and preserve ICE-compressed SNDH sources as received.
- **Coverage** — AY, SAP, NSFE, and SNDH expose ordered subtunes; S98 exposes
  one command-stream document. Reader bounds and variant limits are in the
  linked MetaMan layout map.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| AY subtune title | Title | `playlists[].entries[].title` | Preserve source order and source index. |
| AY author | Album Artist | `game.metadata["Album Artist"]` | One shared header credit; store once at package scope. |
| AY comment | Comment | `game.metadata["Comment"]` | One shared header comment; omit blank values. |
| AY frame-derived play length | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Omit the reader's default timing. |
| SAP NAME | Game Title | `game.metadata["Game Title"]` | Shared header value; omit placeholders. |
| SAP AUTHOR | Album Artist | `game.metadata["Album Artist"]` | Shared header credit; omit placeholders. |
| SAP DATE | Copyright | `game.metadata["Copyright"]` | SAP DATE is exposed by this reader as copyright text. |
| SAP TIME non-loop value | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Use only a valid positive authored length. |
| SAP TIME loop-start hint | Intro Length (ms) | `playlists[].entries[].extraFields["Intro Length (ms)"]` | A loop-start hint alone is not a loop body. |
| NSFE auth game | Game Title | `game.metadata["Game Title"]` | Store once at package scope. |
| NSFE auth artist | Album Artist | `game.metadata["Album Artist"]` | Store once at package scope. |
| NSFE auth copyright | Copyright | `game.metadata["Copyright"]` | Keep distinct from DAT identity. |
| NSFE auth ripper | Dumper | `game.metadata["Dumper"]` | Preserve the source role. |
| NSFE tlbl | Title | `playlists[].entries[].title` | Index by source track, then apply PLST order including repeats. |
| NSFE taut | Artist | `playlists[].entries[].artist` | Index by source track, then apply PLST order including repeats. |
| NSFE time | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Preserve positive authored values; omit fallback timing. |
| NSFE fade | Fade Length (ms) | `playlists[].entries[].extraFields["Fade Length (ms)"]` | Preserve positive authored values; omit fallback timing. |
| NSFE text chunk note | Comment | `game.metadata["Comment"]` | Use the reader's notes tag; do not copy its combined comment projection. |
| SNDH !#SN subtune name or TITL fallback | Title | `playlists[].entries[].title` | Preserve the reader's source title; do not promote a filename display fallback. |
| SNDH COMM composer | Album Artist | `game.metadata["Album Artist"]` | Shared source credit; store once at package scope. |
| SNDH YEAR | Year | `game.metadata["Year"]` | Shared source year; store once at package scope. |
| SNDH FRMS/TIME duration | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Store positive source-derived playback timing only. |
| S98 TITLE | Title | `members[].metadata["Title"]` | Preserve populated authored title. |
| S98 GAME | Game Title | `game.metadata["Game Title"]` | Promote only when package scope is supported. |
| S98 ARTIST | Album Artist | `game.metadata["Album Artist"]` | Promote only when package scope is supported. |
| S98 DATE | Date | `game.metadata["Date"]` | Preserve the source date. |
| S98 YEAR | Year | `game.metadata["Year"]` | Keep only when distinct from Date. |
| S98 GENRE | Genre | `game.metadata["Genre"]` | Preserve populated value. |
| S98 COMMENT | Comment | `game.metadata["Comment"]` | Preserve populated value. |
| S98 COPYRIGHT | Copyright | `game.metadata["Copyright"]` | Preserve populated value. |
| S98 S98BY | Encoded By | `game.metadata["Encoded By"]` | Preserve populated value. |
| S98 command play timing | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Store positive parsed value. |
| S98 command loop start | Intro Length (ms) | `members[].metadata["Intro Length (ms)"]` | Store only when the loop offset is valid. |
| S98 command loop body | Loop Length (ms) | `members[].metadata["Loop Length (ms)"]` | Store only when the loop offset is valid. |

## Application Behavior

- **Multi-track readers** — AY, SAP, NSFE, and SNDH expose logical tracks from
  one physical source file. Store the member once and point ordered playlist
  entries at its source indexes.
- **Platform identity** — Store the canonical platform in structural
  game.console. Do not emit reader system labels as duplicate metadata.
- **Reader diagnostics** — Keep malformed pointers, chunk issues, and timing
  uncertainty in the report. Do not turn diagnostics or technical facts into
  user tags.
- **NSFE aggregate comment** — Do not copy the reader’s combined comment field
  when it repeats copyright, ripper, and note values already mapped
  individually.

## Format Procedures

- **NSFE order** — Preserve playlist order and repeated source indexes. Keep
  sound-effect markers as source facts unless a reviewed consumer contract
  defines a direct field.
- **SAP timing** — The reader's default window is not authored TIME data;
  omit it when the source lacks a positive authored length.
- **SNDH ICE** — Preserve the original compressed source as received. MetaMan's
  bounded temporary expansion is not a replacement package member.

## Required Checks

- **Format scope** — Confirm the actual signature/layout, source track count,
  companion files, and playlist references against the reader facts.
- **Metadata mapping** — Compare source tags with package and playlist fields;
  verify no reader diagnostic or fallback value was promoted.
- **Package review** — Inspect a representative multi-track UAC in UACMan and
  its Songbase projection before approving new conversions.

## Reader References

- AY: [AYMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/AYMetadataReader.swift)
- SAP: [SAPMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SAPMetadataReader.swift)
- NSFE: [GameMusicMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/GameMusicMetadataReader.swift)
- SNDH: [SNDHMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SNDHMetadataReader.swift)
- S98: [S98MetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/S98MetadataReader.swift)
