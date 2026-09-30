# VGM / VGZ Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads `.vgm` and gzip-compressed `.vgz` members.
See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `vgm`; source members: `.vgm` and `.vgz`.
- Reader: `MetaMan/Sources/MetaManCore/VGMMetadataReader.swift`.
- The reader exposes the GD3 names `title_english`, `title_original`,
  `game_english`, `game_original`, `system_english`, `system_original`,
  `artist_english`, `artist_original`, `date`, `converted_by`, and `notes`.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| system_english / system_original | Platform | `game.platform` | Prefer populated English, then original. Preserve the GD3 platform label; VGM/VGZ is exempt from the limited aliases in [Platforms](PLATFORMS.md). |
| — | Format | `track.metadata["Format"]` | Use the header version as `VGM v.<version>`. |
| title_english / title_original | Title | `track.metadata["Title"]` | Prefer English, then original; do not use a filename fallback. |
| game_english / game_original | Game Title | `track.metadata["Game Title"]` | Prefer English, then original; keep distinct from package title and soundtrack **Album**. |
| artist_english / artist_original | Artist | `track.metadata["Artist"]` | Prefer English, then original; omit when empty. |
| date | Date | `track.metadata["Date"]` | Preserve a complete source date. |
| date | Year | `track.metadata["Year"]` | Use only when the source value is a year; do not derive a full date. |
| converted_by | Dumper | `track.metadata["Dumper"]` | Preserve the GD3 credit; do not rename it **Encoded By**. |
| notes | Comment | `track.metadata["Comment"]` | Keep useful nonempty source text. |

## Format Procedures

- The UAC packer does not accept `.vgz` as a playable member. Retain the
  original VGZ as source evidence or a scoped attachment, decompress it to a
  VGM member, and record the transformation.
- Profile hashes cover the complete normalized VGM member, not emulator
  output or the compressed wrapper.
- Preserve source bytes and the versioned UTF-16LE GD3 block. Do not promote
  sample rate, clocks, chip flags, offsets, sample counts, or reader
  diagnostics as music tags.

## Required Checks

Check header bounds, EOF/data/GD3/loop offsets, truncation, UTF-16 diagnostics,
and contradictory timing. Hold missing, mixed, or ambiguous GD3 platform
labels for review.
