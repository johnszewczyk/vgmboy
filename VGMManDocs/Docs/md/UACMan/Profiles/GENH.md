# GENH Generic Header Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Reader layout and fallback
behavior are in [MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — genh in MetaManCore.
- **Source members** — One GENH stream and its source payload, kept as one playable
  member.
- **Coverage** — Bounded generic header fields, optional coefficient/sample
  facts, and timing. The reader does not open the declared audio decoder.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| GENH filename stem | Title | `members[].metadata["Title"]` | Reader fallback only; retain the original filename. |
| Supported sample count | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Use reader-derived value after layout validation. |
| Supported loop start sample | Intro Length (ms) | `members[].metadata["Intro Length (ms)"]` | Use only when loop bounds are valid. |
| Supported loop end sample | Loop Length (ms) | `members[].metadata["Loop Length (ms)"]` | Use only when loop bounds are valid. |
| Codec ID, channels, rate, interleave, offsets, DSP coefficients, skip samples | — | — | Technical layout facts are not user metadata. |

## Application Behavior

- **Format identity** — GENH describes a payload layout; it does not identify
  a game, platform, source release, or codec's correctness by itself.
- **Fallback** — The exact legacy zero-header-size case uses the established
  0x800-byte header and payload offset. Preserve the source and record the
  reader route.
- **Hashes** — Use the wrapper's embedded integrity hashes for the source
  member. Do not add separate CRC metadata tags or database copies.

## Format Procedures

- **Bounds** — Validate declared header size, audio offset, data extent,
  channel/rate values, optional sample count, and loop bounds.
- **Decoder** — Keep the existing decoder path for audio interpretation.
  MetaMan facts alone do not authorize transcoding or source cleanup.

## Required Checks

- **Fixture** — Review standard and legacy header layouts and representative
  codec/coefficient variants.
- **Timing** — Compare sample and loop arithmetic with the applicable
  reference layout before approving a conversion.
- **Package** — Confirm source payload bytes remain unchanged and the UAC
  manifest stores wrapper hashes rather than fabricated stream tags.

## Reader Reference

- [GENHMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/GENHMetadataReader.swift)
