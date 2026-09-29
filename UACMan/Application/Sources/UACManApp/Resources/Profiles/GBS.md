# GBS to UAC Profile

## Status and scope

Draft pending fixture validation. Covers Game Boy Sound System (`.gbs`) files
and authored NEZplug extended-M3U sidecars used by the MetaManCore `gbs`
reader. See [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md) and
the shared [`PRE-DISC-NATIVE.md`](PRE-DISC-NATIVE.md) policy.

## Projection

GBS has a 112-byte header. The version, declared track count, and first-track
index are at offsets `0x03`, `0x04`, and `0x05`. Store each physical GBS once;
represent each declared track as a playlist entry with its zero-based source
index.

| Source field | UAC field | Rule |
| --- | --- | --- |
| GBS version byte | `Format` | `GBS v.<integer>` on the physical member. |
| Game | `Album` | Use populated source value. |
| Artist | `Artist` | Use populated source value. |
| Copyright/comment | `Comment` | Keep useful nonempty source text. |
| NEZplug M3U `# @TITLE` / `# @ARTIST` | `Title` / `Artist` on matching playlist entries | Apply only to the referenced GBS and zero-based track index. Preserve track-level variation without overwriting the header's common artist. |
| NEZplug `filename::GBS,index,title,time,loop,fade,loopcount` row | Ordered playlist entry | Preserve authored title/order and positive timing/loop data when the player consumes it. Decimal and `$hex` indexes follow the documented zero-based convention. |

Preserve the exact M3U bytes as a companion member when it supplies track
names, order, timing, or loop information. Do not invent per-track titles or
timings when no M3U provides them. The reader's 150-second fallback is not
source data. Do not surface header addresses, timer registers, or reader facts
as tags.

## Hashes and validation

Hash each complete physical GBS file once with BLAKE3-256,
CRC32/ISO-HDLC, SHA-1, and MD5 under `uac-playable-payload-v1`. Do not create
separate hash lists for its playlist entries. Preserve and separately hash an
M3U companion as an ordinary UAC member under wrapper integrity if included.
Validate the header signature and bounds, version and track count, M3U target
filename, source index range, playlist ordering, and each timing/loop field.
Do not translate authored loop counts into exact sample loop points without a
player-specific verified mapping.
