# Nintendo Game Boy GBS Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** The MetaManCore `gbs` reader handles `.gbs` files and optional
NEZplug extended-M3U sidecars; see
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Field mapping

| Source fact | UAC location | Type and normalization | Omission or review rule |
| --- | --- | --- | --- |
| System | `game.console` | `Nintendo Game Boy` | Set once per package. |
| GBS version byte | `member.metadata["Format"]` | `GBS v.<integer>` | Use the actual header value. |
| Game | `member.metadata["Album"]` | Populated source text | Omit empty values. |
| Artist | `member.metadata["Artist"]` | Populated source text | M3U track artist may add track-specific detail without replacing the shared value. |
| Copyright/comment | `member.metadata["Comment"]` | Useful source text | Omit empty or non-informative values. |
| M3U title/artist | Playlist entry `Title` / `Artist` | Referenced GBS and zero-based source index | Preserve variation; do not fabricate titles. |
| M3U order/time/loop/fade | Playlist entry | Authored order and positive values | Apply only to valid target indexes and when supported by the player. Decimal and `$hex` indexes follow the reader's zero-based convention. |

## GBS-specific checks

The header is 112 bytes. Check its signature and bounds, version, declared
track count, and first-track index. Validate M3U target names, index ranges,
ordering, and timing/loop fields. Preserve the M3U bytes when it contributes
playback data. The reader's 150-second fallback is not source metadata.
