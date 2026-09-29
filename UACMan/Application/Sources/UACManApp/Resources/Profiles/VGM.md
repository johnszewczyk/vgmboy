# VGM / VGZ Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore's `vgm` reader handles `.vgm` and gzip-compressed
`.vgz`; see [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Field mapping

| Source fact | UAC location | Type and normalization | Omission or review rule |
| --- | --- | --- | --- |
| GD3 system | `game.console` | Canonical name from [`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md) | Prefer English, then original. Hold missing, mixed, or unknown labels for review. |
| VGM header version | `member.metadata["Format"]` | `VGM v.<version>` | Use the encoded header version. |
| GD3 title | `member.metadata["Title"]` | Prefer English, then original | Do not use a filename fallback. |
| GD3 game | `member.metadata["Album"]` | Prefer English, then original | Keep distinct from package identity. |
| GD3 artist | `member.metadata["Artist"]` | Prefer English, then original | Omit when empty. |
| GD3 release date | `member.metadata["Date"]` | Populated source text | Use **Year** only when the value gives a year without a full date. |
| GD3 converted-by | `member.metadata["Dumper"]` | Populated source text | Do not rename to `Encoded By`. |
| GD3 notes | `member.metadata["Comment"]` | Useful nonempty source text | Omit empty values. |
| Total/loop sample counts | Playback fields | Positive source-backed values | Use only when a playback consumer requires them; counts alone do not authorize synthetic loop objects. |

## VGZ normalization and checks

The UAC packer does not accept `.vgz` as a playable member. Retain the exact
VGZ as source evidence or a scoped attachment, decompress it to a VGM member,
and record that transformation. Profile hashes cover the complete normalized
VGM member, not emulator output or the compressed wrapper.

Preserve the source bytes and versioned UTF-16LE GD3 block. Check header bounds,
EOF/data/GD3/loop offsets, truncation, UTF-16 diagnostics, and contradictory
timing. Do not promote sample rate, clocks, chip flags, offsets, or reader
diagnostics as music tags.
