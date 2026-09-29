# Nintendo NES NSF and NSFE to UAC Profile

## Status and scope

Draft pending fixture validation. Covers NSF/NESM fixed-header files and NSFE
chunk files read by MetaManCore's `nsf` and `nsfe` readers. See
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md), the shared
[`PRE-DISC-NATIVE.md`](PRE-DISC-NATIVE.md) policy, and
[`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md).

## NSF projection

NSF has a 128-byte header. The version, declared track count, and first-track
index are at offsets `0x05`, `0x06`, and `0x07`. One ordered result entry is
created per declared source track; the source itself is stored once.

| Source field | UAC field | Rule |
| --- | --- | --- |
| NSF / NSFE system identity | `game.console` | Set once at package scope to `Nintendo NES` for either format; do not repeat it as a member `System` or `Platform` tag. |
| NSF version byte | `Format` | `NSF v.<integer>` on the member. |
| Game | `Album` | Keep a nonempty source value. |
| Artist | `Artist` | Keep a nonempty source value. |
| Copyright/comment | `Comment` | Keep only useful, nonempty source text. |
| Track identity | Playlist source index | Preserve zero-based source index and the header's first-track offset; do not fabricate per-track titles. |

The reader's 150-second fallback is not source-authored duration and must not
be surfaced. Header addresses, speed fields, banks, and playback flags remain
in the source bytes/report unless a specific playback consumer requires them.

## NSFE projection

NSFE has no global version byte. Use `Format: NSFE`; do not invent a version.
Preserve the full source member. The reader validates `INFO`, `DATA`, and
`NEND`, applies `PLST` order (including repeated source indexes), and retains
the non-audio chunk bytes.

| NSFE chunk | UAC field or use | Rule |
| --- | --- | --- |
| `auth` | `Album`, `Artist`, `Comment`, `Dumper` | Map the populated game, artist, copyright, and ripper values respectively. |
| `tlbl` | `Title` per ordered playlist entry | Use populated source-track labels; preserve unlabeled entries without blank tags. |
| `taut` | `Artist` per playlist entry | Use populated per-track authors; do not replace shared artist. |
| `PLST` | Playlist order | Preserve exact ordered source indexes and repeats. Hash the NSFE file once. |
| `time`, `fade` | Playback timing | Preserve positive authored values only where a player/UI consumes them; omit nonpositive values and reader-generated 150-second fallback. |
| `psfx` | Report or playback behavior | Preserve the source chunk; surface only if an actual consumer uses its sound-effect distinction. |

Do not promote region/speed, expansion-chip flags, raw data byte counts, chunk
inventory, or reader diagnostics as ordinary music tags. Keep malformed
required chunks and invalid playlist references in review.

## Hashes and validation

For both formats, hash the complete physical NSF/NSFE file with BLAKE3-256,
CRC32/ISO-HDLC, SHA-1, and MD5 under `uac-playable-payload-v1`. A playlist
containing many source tracks does not create additional copies or hashes.
Check version/header bounds for NSF, chunk boundaries and required chunk order
for NSFE, and playlist indexes/repeats for both. Confirm UACMan presents one
Format tag and keeps ordered playlist entries associated with the single
physical file.
