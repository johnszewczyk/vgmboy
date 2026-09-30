# VGM / VGZ Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads `.vgm` and gzip-compressed `.vgz` members. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `vgm`; source members: `.vgm` and `.vgz`.
- Reader: `MetaMan/Sources/MetaManCore/VGMMetadataReader.swift`.
- The reader exposes the GD3 names `title_english`, `title_original`,
  `game_english`, `game_original`, `system_english`, `system_original`,
  `artist_english`, `artist_original`, `date`, `converted_by`, and `notes`.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| system_english / system_original | Platform | `game.console` | Prefer populated English, then original. VGM labels are exempt from the limited aliases in [Platforms](PLATFORMS.md). |
| title_english / title_original | Title | `members[].metadata["Title"]` | Prefer English, then original; do not use a filename fallback. |
| game_english / game_original | Album | `game.metadata["Album"]` | Prefer English, then original; this is the package-wide game/album title. |
| artist_english / artist_original | Album Artist / Artist | `game.metadata["Album Artist"]` or `members[].metadata["Artist"]` | Use Album Artist for a shared package credit; use track Artist only for a track-specific credit. |
| date | Date / Year | `game.metadata["Date"]` or `game.metadata["Year"]` | Use Date for a full date and Year when only a year is present. |
| converted_by | Dumper | `game.metadata["Dumper"]` | Preserve the GD3 credit; do not rename it **Encoded By**. |
| notes | Comment | `game.metadata["Comment"]` | Keep useful source text. |
| Stored member format | — | `members[].format` | Store the actual member extension; do not create a duplicate **Format** tag. |

## Format Procedures

- The UAC packer does not accept `.vgz` as a playable member. Retain the
  original VGZ as source evidence or a scoped attachment, decompress it to a
  VGM member, and record the transformation.
- Hash the complete normalized VGM member, not emulator output or the
  compressed VGZ wrapper.
- Preserve source bytes and the versioned UTF-16LE GD3 block. Do not promote
  sample rate, clocks, chip flags, offsets, sample counts, or diagnostics as
  metadata tags.

## Required Checks

Check header bounds, EOF/data/GD3/loop offsets, truncation, UTF-16 diagnostics,
and contradictory timing. Hold missing, mixed, or ambiguous GD3 platform
labels for review.
