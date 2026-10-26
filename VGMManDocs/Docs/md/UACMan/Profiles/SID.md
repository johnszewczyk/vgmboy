# SID, PSID, and RSID Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). Reader facts are in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — sid in MetaManCore.
- **Source members** — One physical PSID or RSID file, stored once.
- **Coverage** — Supported v1 and extended headers, Windows-1252 identity
  fields, raw header retention, and up to 256 declared subtunes. The reader
  does not calculate playback duration.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| SID header Title | Title | `game.metadata["Title"]` | Names the SID work, not each declared subtune. |
| SID header Author | Album Artist | `game.metadata["Album Artist"]` | Shared header credit. |
| SID header Released | Comment | `game.metadata["Comment"]` | Preserve as a release note; do not recast arbitrary text as Copyright or Date. |
| SID song count and start song | Playlist trackIndex and order | `playlists[].entries[].trackIndex` | Preserve native order; do not invent per-song titles. |
| SID has no native duration | — | — | Leave timing absent; do not store zero reader timing as a zero-length tag. |

## Application Behavior

- **Platform identity** — Use the canonical Commodore 64 platform in
  structural game.console. No source title string is a No-Intro Game ID.
- **Header** — Keep the native member byte-exact. The raw header is reader
  evidence, not a UAC metadata object to serialize wholesale.

## Format Procedures

- **Variants** — Validate PSID versus RSID signature, declared header version,
  data offset, and song count before building a playlist.
- **Titles** — If the native title is empty, the reader's filename fallback
  remains a display aid; do not claim that fallback as source-authored text.

## Required Checks

- **Structure** — Check header version, payload offset, declared subtunes, and
  source member integrity.
- **Playlist** — Confirm logical tracks preserve source order and share one
  physical member.
- **Review** — Verify missing metadata remains missing and no timing is
  invented.

## Reader Reference

- [SIDMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SIDMetadataReader.swift)
