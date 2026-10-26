# Console Stream Audio Profiles

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). This page covers compact
console stream readers that expose a native header or filename-derived title
but do not decode or rewrite audio. Exact layouts are in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Readers** — adx, aus, at3, msf, svag, xmd, sony-sshd, ps-headerless-mib,
  bink-audio, ahx, and dvi.
- **Source members** — .adx, .aus, .at3, .msf, .svag, .xmd, .ads, .ss2, .mib,
  .bika, .ahx, and .dvi files. Preserve encoded bytes. A multi-stream Bink file
  is one physical member with ordered logical tracks.
- **Coverage** — Only AT3 projects authored RIFF/INFO text. Other readers use
  validated headers or filename fallbacks; shared suffixes remain content-routed.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| ADX, AUS, SVAG, XMD, SSHD, MIB, AHX, and DVI filename stem | Title | `members[].metadata["Title"]` | Display fallback only; preserve the original member path. |
| MSF header stream name | Title | `members[].metadata["Title"]` | Prefer a populated source name; otherwise keep the filename display fallback. |
| Bink container filename stem | Title | `members[].metadata["Title"]` | Shared display title; preserve one logical entry per stream and source order. |
| AT3 INAM | Title | `members[].metadata["Title"]` | Direct RIFF/INFO title. |
| AT3 IART | Artist | `members[].metadata["Artist"]` | Direct RIFF/INFO artist. |
| AT3 IPRD | Album | `members[].metadata["Album"]` | Product is Album, not DAT Game ID. |
| AT3 ICRD | Date | `members[].metadata["Date"]` | Preserve the source value. |
| AT3 IGNR | Genre | `members[].metadata["Genre"]` | Preserve populated value. |
| AT3 ICMT | Comment | `members[].metadata["Comment"]` | Preserve populated value. |
| AT3 ICOP | Copyright | `members[].metadata["Copyright"]` | Preserve populated value. |
| AT3 ISFT | Encoded By | `members[].metadata["Encoded By"]` | Preserve populated value. |
| ADX, AUS, AT3, MSF, SVAG, XMD, SSHD, MIB, AHX, DVI play length | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Store source-derived timing, not parser/header descriptions. |
| ADX, AUS, AT3, MSF, SVAG, XMD, SSHD, MIB, AHX, DVI loop start | Intro Length (ms) | `members[].metadata["Intro Length (ms)"]` | Store only when loop is valid. |
| ADX, AUS, AT3, MSF, SVAG, XMD, SSHD, MIB, AHX, DVI loop body | Loop Length (ms) | `members[].metadata["Loop Length (ms)"]` | Store only when loop is valid. |
| Bink packet timing | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Store per-stream timing. |
| Codec, channel, frame, offset, and header facts | — | — | Keep as reader evidence; do not serialize technicalFacts as user tags. |

## Application Behavior

- **Text metadata** — AT3 is the only reader in this group that promotes
  authored RIFF/INFO text fields. Other readers' generated comments such as
  “header” or “metadata source” describe the parser route and are not user
  metadata.
- **Multiple tracks** — Bink returns one ordered result per audio stream.
  Preserve one physical member and point the playlist entries to that member.
- **Format identity** — Use structural game.format for the actual playable
  codec/layout and game.console only when independently established.
- **Hashes** — Let the UAC wrapper retain member and source hashes. Do not add
  duplicate hash tags or hash rows to Songbase.

## Format Procedures

- **Shared suffixes** — ADX, MIB, and other aliases require the reader's
  signature and layout checks; an extension alone is not identification.
- **Fallback titles** — A filename-derived title is not evidence for Game ID,
  game title, territory, or release.
- **Timing** — Reader-compatible loop windows may include a playback projection
  beyond the native loop. Keep them in timing fields and do not relabel them as
  authored fade metadata.

## Required Checks

- **Reader match** — Check the concrete reader ID, variant, bounded header,
  payload extent, and any source fallback.
- **AT3 tags** — Compare every mapped INFO field with the original member and
  omit empty or conflicting values.
- **Bink** — Check stream count, frame-offset walk, and packet-derived sample
  durations.
- **Package** — Verify original member bytes, wrapper hashes, and visible
  titles/timing in the intended consumer.

## Reader References

- [ADXMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/ADXMetadataReader.swift)
- [AtomicPlanetAUSMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/AtomicPlanetAUSMetadataReader.swift)
- [RIFFATRAC3MetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/RIFFATRAC3MetadataReader.swift)
- [SonyMSFMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SonyMSFMetadataReader.swift)
- [SVAGMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SVAGMetadataReader.swift)
- [KonamiXMDMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/KonamiXMDMetadataReader.swift)
- [SonySSHDMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/SonySSHDMetadataReader.swift)
- [MIBMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/MIBMetadataReader.swift)
- [BinkAudioMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/BinkAudioMetadataReader.swift)
- [AHXMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/AHXMetadataReader.swift)
- [DVIMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/DVIMetadataReader.swift)
