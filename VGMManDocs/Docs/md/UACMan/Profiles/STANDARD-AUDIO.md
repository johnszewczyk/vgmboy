# Standard Audio and FLAC Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Reader coverage and FLAC
comment layout are described in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — standard-audio in MetaManCore.
- **Extensions** — AIF, AIFF, FLAC, M4A, MP3, OGG, and WAV.
- **Coverage** — Common AVFoundation metadata and duration. FLAC additionally
  preserves ordered Vorbis comments and shared sample-accurate loop fields.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| Common metadata or FLAC TITLE | Title | `members[].metadata["Title"]` | Preserve populated source value. |
| Common metadata or FLAC ALBUM | Album | `members[].metadata["Album"]` | Keep distinct from DAT Game ID. |
| FLAC ARTIST, COMPOSER, or common Artist/Author | Artist | `members[].metadata["Artist"]` | Preserve a populated track credit. The reader's selected convenience value follows ARTIST, ALBUMARTIST, COMPOSER, common Artist, then Author; use the raw tag role when choosing scope. |
| FLAC ALBUMARTIST | Album Artist | `game.metadata["Album Artist"]` | Preserve the explicit package-wide credit once; do not duplicate it as member Artist. |
| FLAC DATE or common Date | Date | `members[].metadata["Date"]` | Preserve the selected direct value. |
| FLAC YEAR | Year | `members[].metadata["Year"]` | Keep only when distinct from Date. |
| FLAC GENRE | Genre | `members[].metadata["Genre"]` | Preserve populated value. |
| FLAC COMMENT | Comment | `members[].metadata["Comment"]` | Preserve populated value. |
| FLAC COPYRIGHT | Copyright | `members[].metadata["Copyright"]` | Preserve populated value. |
| FLAC ENCODED_BY | Encoded By | `members[].metadata["Encoded By"]` | Preserve populated value. |
| File duration | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Use the reader's frame-count or asset-duration result. |
| Supported FLAC loop comments | Loop | `members[].metadata["Loop"]` | Follow the shared sample-accurate loop object contract and preserve source comments. |

## Application Behavior

- **Codec scope** — This is a reader mapping for the listed extensions. It is
  not a blanket approval for every codec alias or an audio transcoding policy.
- **Tag sources** — Preserve FLAC native comment order and bytes. Use the raw
  `ALBUMARTIST` key to distinguish package credit from the reader's selected
  convenience `artist` value. Common metadata remains available through the
  file's native metadata.
- **Identity** — Album and title are matching clues only. DAT identity and
  region are assigned through AudioMan's Museum workflow.

## Format Procedures

- **Loop metadata** — Use only supported positive source-backed loop values.
  A duration field does not define a sample-accurate loop.
- **Source bytes** — Package the original encoded member. Do not decode and
  re-encode while applying metadata.

## Required Checks

- **Reader route** — Confirm the extension and actual detected codec/layout.
- **Projection** — Compare visible metadata, duration, and any loop against
  native source tags and bytes.
- **Package** — Verify the original member and UAC wrapper integrity records.

## Reader Reference

- [StandardAudioMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/StandardAudioMetadataReader.swift)
