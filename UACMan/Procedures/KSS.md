# KSS Format Procedure

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** MetaManCore reads KSS and KSSX headers without interpreting or
emulating the music payload. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Reader Scope

- Reader ID: `kss`; source member extension: `.kss`.
- Reader: `MetaMan/Sources/MetaManCore/KSSMetadataReader.swift`.
- One `.kss` extension can contain either the `KSCC` or `KSSX` signature.
  Device flags classify the hardware platform; they do not indicate separate
  tagged formats.
- The reader does not parse embedded or sidecar metadata tags. It does not read
  KSS M3U playlists.

## Field Mapping

Store the platform once in structural `game.console`. Normalize the reader's
`Game Gear` label to **Sega Game Gear** using [Platforms](PLATFORMS.md).

### KSCC (`KSCC` signature)

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| None | — | — | KSCC contains no stock metadata tags. Header addresses, banks, and device flags are technical fields, not tags. |
| Device flags | Platform | `game.console` | Classify from the reader's hardware flags: **MSX**, **Sega Master System**, **Sega Game Gear**, or **Sega Mega Drive**. |

### KSSX (`KSSX` signature)

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| None | — | — | KSSX contains no stock metadata tags. The extended header adds payload bounds, song indexes, and volume bytes, not tags. |
| Device flags | Platform | `game.console` | Classify from the reader's hardware flags using the canonical names above. |

## Format Procedures

- Store the source extension as `members[].format = "kss"`. Do not create a
  **Format** tag from the `KSCC` or `KSSX` signature.
- KSS has no authored track count. The reader's 256 compatibility slots are
  not real track evidence. KSSX-declared bounds are header facts and do not
  turn those slots into a playlist. Do not fabricate titles, **Track Number**,
  or timing values from either count.
- Do not turn addresses, banks, data sizes, device flags, volume bytes,
  payload facts, or diagnostics into metadata tags.
- Preserve KSS/KSSX bytes unchanged.

## Required Checks

Validate the signature, base-header size, and any declared KSSX extension
bounds. Record unsupported extra-header sizes and keep technical header facts
outside ordinary metadata.
