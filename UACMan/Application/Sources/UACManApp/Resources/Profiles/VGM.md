# VGM / VGZ · Multi-Platform Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads `.vgm` and
gzip-compressed `.vgz` members. See
`VGMManDocs > MetaMan > format-layouts.md`.

## Scope

- **Reader** — `vgm`; `VGMMetadataReader.swift`.
- **Source members** — `.vgm` and `.vgz`.
- **Coverage** — GD3 fields `title_english`, `title_original`,
  `game_english`, `game_original`, `system_english`, `system_original`,
  `artist_english`, `artist_original`, `date`, `converted_by`, and `notes`.
- **Status** — Draft; fixture validation pending.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `system_english` / `system_original` | Platform | `game.console` | Prefer English, then original. VGM labels are exempt from the limited aliases in [Platforms](PLATFORMS.md). |
| `title_english` / `title_original` | Title | `members[].metadata["Title"]` | Prefer English, then original; no filename fallback. |
| `game_english` / `game_original` | Album | `game.metadata["Album"]` | Prefer English, then original; package-wide title. |
| `artist_english` / `artist_original` | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Use Album Artist for a shared credit and track Artist only for a track-specific credit. |
| `date` | Date / Year | `game.metadata["Date"]` or `game.metadata["Year"]` | Use Date for a full date and Year when only a year is present. |
| `converted_by` | Dumper | `game.metadata["Dumper"]` | Preserve the GD3 credit; do not rename it Encoded By. |
| `notes` | Comment | `game.metadata["Comment"]` | Keep useful source text. |
| `.vgm` or `.vgz` source | Format | `game.metadata["Format"]` | Store one package-level **VGM** value; `.vgz` is a compressed VGM source, not a second playable format. |

## Format Procedures

- **VGZ packaging** — The UAC packer does not accept `.vgz` as playable.
  Retain the original as source evidence or a scoped attachment, decompress
  to a VGM member, and record the transformation.
- **Hash scope** — Hash the complete normalized VGM member, not emulator
  output or the compressed VGZ wrapper.
- **Source preservation** — Preserve original bytes and the versioned
  UTF-16LE GD3 block.
- **Technical data** — Do not promote sample rate, clocks, chip flags, offsets,
  sample counts, or diagnostics to metadata tags.

## Required Checks

- **Header and offsets** — Check header bounds, EOF/data/GD3/loop offsets, and
  truncation.
- **GD3 decoding** — Check UTF-16 diagnostics and contradictory timing.
- **Platform** — Hold missing, mixed, or ambiguous GD3 labels for review.
