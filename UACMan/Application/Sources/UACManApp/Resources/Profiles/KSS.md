# Multi-Platform · KSS Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads KSCC and
KSSX headers without interpreting or emulating their music payloads. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `kss`; source member extension: `.kss` (with `KSCC` or
  `KSSX` signature).
- Reader: `MetaMan/Sources/MetaManCore/KSSMetadataReader.swift`.
- KSS is a multi-platform format, commonly encountered on Sega platforms. The
  reader derives a platform label from device flags; classify each file from
  its actual header. No authored title, artist, album, or game-ID tags exist.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Platform | `game.platform` | Derive from the reader's hardware classification; map to **MSX**, **Sega Master System**, **Sega Game Gear**, or **Sega Mega Drive** in [Platforms](PLATFORMS.md). |

## Format Procedures

- Store `kss` as the contained track format. Do not create a direct **Format**
  tag from the `KSCC` or `KSSX` signature.
- Do not turn addresses, banks, data sizes, device flags, volume bytes, payload
  facts, or parser diagnostics into tags.
- KSS has no authored track count. The reader's 256 compatibility slots are
  not real track evidence. KSSX-declared track bounds are source facts and do
  not replace that compatibility listing. Do not fabricate titles, **Track
  Number**, or timing metadata from either count.
- The reader does not consume KSS sidecar M3U files. Do not infer playlist
  order or names from them.
- Preserve KSS/KSSX bytes unchanged.

## Required Checks

Validate the signature, base-header size, and any declared KSSX extension
bounds. Record unsupported extra-header sizes and ensure technical header
facts remain outside ordinary metadata.
