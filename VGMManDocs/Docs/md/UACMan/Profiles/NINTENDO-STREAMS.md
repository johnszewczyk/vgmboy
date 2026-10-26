# Nintendo Stream Audio Profiles

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Exact reader coverage and
layout checks are in [MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Readers** — ngc-dtk-adp, txth-ima-adp, nds-strm, nds-strm-ffta2,
  ngc-dsp-standard, rs03, ngc-thp-audio, and agsc.
- **Source members** — .adp, .strm, .bin, .dsp, and .thp files. Preserve native
  bytes. Retain a TXTH sidecar as a source/configuration asset and preserve its
  path relationship.
- **Coverage** — The reader IDs separate DTK/TXTH IMA, standard/FFTA2 STRM,
  standard DSP, RS03, THP, and AGSC layouts; see the linked layout map for
  signature, version, and payload bounds.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| DTK ADP, TXTH IMA, NDS STRM, FFTA2 STRM, standard DSP, RS03, and THP filename stem | Title | `members[].metadata["Title"]` | Display fallback only; do not treat as game identity. |
| AGSC bank/stream name | Title | `playlists[].entries[].title` | Preserve source stream order and index; one physical bank remains one member. |
| DTK ADP, TXTH IMA, NDS STRM, FFTA2 STRM, standard DSP, RS03, and THP play length | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Use reader sample-rate arithmetic. |
| DTK ADP, TXTH IMA, NDS STRM, FFTA2 STRM, standard DSP, RS03, and THP loop start | Intro Length (ms) | `members[].metadata["Intro Length (ms)"]` | Store only when loop bounds are valid. |
| DTK ADP, TXTH IMA, NDS STRM, FFTA2 STRM, standard DSP, RS03, and THP loop body | Loop Length (ms) | `members[].metadata["Loop Length (ms)"]` | Store only when loop bounds are valid. |
| AGSC stream play timing | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Store on the corresponding logical stream. |
| AGSC stream loop start | Intro Length (ms) | `playlists[].entries[].extraFields["Intro Length (ms)"]` | Store only when loop bounds are valid. |
| AGSC stream loop body | Loop Length (ms) | `playlists[].entries[].extraFields["Loop Length (ms)"]` | Store only when loop bounds are valid. |
| TXTH sidecar | Format Sidecar | `game.metadata["Format Sidecar"]` | Use a direct relative member path; retain exact sidecar bytes and source relationship. |
| DSP coefficients, codec, channels, offsets, sample counts, and raw headers | — | — | Keep as technical evidence; do not expose as descriptive tags. |

## Application Behavior

- **Stream model** — AGSC enumerates logical streams from one bank. Other
  readers in this group describe one stream per source file.
- **ADP dispatch** — The .adp suffix is shared. Select DTK or TXTH IMA only
  when the corresponding bounded probe or declared sidecar matches; leave
  unknown aliases on their existing fallback route.
- **DSP aliases** — The .dsp suffix includes unrelated standard DSP, RS03, and
  THP layouts. Require content/layout recognition before assigning a reader.
- **Platform** — Use verified platform identity in structural game.console.
  Nintendo format facts do not alone establish a particular game or region.
- **Hashes** — The UAC wrapper holds member/source hashes. Do not duplicate
  them in Songbase or user-facing tags.

## Format Procedures

- **Timing** — Use positive sample-derived playback fields, not arbitrary
  technical tags. Preserve the reader's loop rules and known decoder-compatible
  play-window calculations.
- **Sidecars** — Keep TXTH as a non-playable support member with provenance.
  Do not flatten the sidecar directives into UAC tags.
- **Source bytes** — Do not decode, resample, or rewrite the source while
  applying UAC metadata.

## Required Checks

- **Recognition** — Verify the format-specific signature/probe, version,
  header bounds, payload extent, channel count, and sample rate.
- **Variant coverage** — Review each materially different layout, including
  both STRM routes, DSP/RS03/THP, and both DTK/TXTH ADP routes.
- **Package** — Verify stream order, sidecar association, timing, original
  bytes, and embedded wrapper hashes.

## Reader References

- [ADPMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/ADPMetadataReader.swift)
- [NDSSTRMMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/NDSSTRMMetadataReader.swift)
- [NintendoDSPMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/NintendoDSPMetadataReader.swift)
- [AGSCMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/AGSCMetadataReader.swift)
