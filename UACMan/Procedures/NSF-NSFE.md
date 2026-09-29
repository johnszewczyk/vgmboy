# Nintendo NES NSF / NSFE Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). **Draft pending fixture
validation.** The MetaManCore `nsf` and `nsfe` readers handle fixed-header NSF
and chunk-based NSFE files; see
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Field mapping

| Source fact | UAC location | Type and normalization | Omission or review rule |
| --- | --- | --- | --- |
| System | `game.console` | `Nintendo NES` | Set once for either format. |
| NSF version byte | `member.metadata["Format"]` | `NSF v.<integer>` | Use the actual header value. |
| NSFE format | `member.metadata["Format"]` | `NSFE` | NSFE has no global version byte. |
| Game / `auth` game | `member.metadata["Album"]` | Populated source text | Keep separate from package identity. |
| Artist / `auth` artist | `member.metadata["Artist"]` | Populated source text | `taut` may add track-specific artists. |
| Copyright/comment / `auth` copyright and ripper | `member.metadata["Comment"]` / `Dumper` | Populated source text | Omit empty values. |
| NSFE `tlbl` / `taut` | Playlist entry `Title` / `Artist` | Source labels in ordered entries | Preserve unlabeled entries without blank fields. |
| NSF track index / NSFE `PLST` | Playlist entry source index | Zero-based index and authored order | Preserve repeats; do not infer titles. |
| NSFE `time` / `fade` | Playlist entry timing | Positive authored values | Include only when a player or UI consumes them. |
| NSFE `psfx` | Source member / playback behavior | Preserve chunk bytes | Surface only when a consumer uses its sound-effect distinction. |

## NSF/NSFE-specific checks

For NSF, check the 128-byte header, version, declared track count, first-track
index, and index bounds. For NSFE, validate `INFO`, `DATA`, and `NEND`, chunk
bounds, `PLST` references and repeats, and preserved non-audio chunks. The
reader's 150-second fallback is not source metadata. Keep header addresses,
speed fields, banks, region, expansion-chip flags, raw counters, and parser
diagnostics out of ordinary tags.
