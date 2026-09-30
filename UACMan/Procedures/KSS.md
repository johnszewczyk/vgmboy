# KSS · Multi-Platform Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). MetaManCore reads KSS and
KSSX headers without interpreting or
emulating the music payload. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Scope

- **Reader** — `kss`; `KSSMetadataReader.swift`.
- **Source members** — `.kss` with either `KSCC` or `KSSX` signature.
- **Coverage** — Device flags classify platform; they do not identify a
  separate tagged format. The reader does not parse embedded or sidecar tags
  or KSS M3U playlists.
- **Status** — Draft; fixture validation pending.

## Field Mapping

Store the canonical platform once in structural `game.console`; normalize the
reader's `Game Gear` label to **Sega Game Gear** using [Platforms](PLATFORMS.md).

### KSCC (`KSCC` Signature)

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| None | — | — | No stock metadata tags. Addresses, banks, and device flags are technical header data. |
| Device flags | Platform | `game.console` | Classify as **MSX**, **Sega Master System**, **Sega Game Gear**, or **Sega Mega Drive**. |

### KSSX (`KSSX` Signature)

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| None | — | — | No stock metadata tags. Extended headers add bounds, song indexes, and volume bytes, not tags. |
| Device flags | Platform | `game.console` | Use the canonical platform names listed above. |

## Format Procedures

- **Member format** — Store `.kss` as `members[].format = "kss"`; do not
  create a Format tag from the `KSCC` or `KSSX` signature.
- **Song count** — KSS has no authored track count. The reader's 256
  compatibility slots are not track evidence; KSSX bounds do not make them a
  playlist. Do not fabricate titles, Track Number, or timing values.
- **Technical data** — Do not project addresses, banks, data sizes, device
  flags, volume bytes, payload facts, or diagnostics as metadata tags.
- **Source bytes** — Preserve KSS/KSSX bytes unchanged.

## Required Checks

- **Header** — Validate signature and base-header size.
- **KSSX extension** — Check declared extension bounds and record unsupported
  extra-header sizes for review.
