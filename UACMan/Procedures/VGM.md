# VGM and VGZ to UAC Profile

## Status and scope

Draft pending fixture validation. Covers `.vgm` and gzip-compressed `.vgz` read
by MetaManCore's `vgm` reader. See the native layout summary in
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md), the shared
[`PRE-DISC-NATIVE.md`](PRE-DISC-NATIVE.md) policy, and
[`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md).

## Projection

| Source field | UAC field | Rule |
| --- | --- | --- |
| Header version | `Format` | `VGM v.<version>` from the header's encoded version; retain on every applicable member. |
| GD3 English/original title | `Title` | Prefer English, then original. Do not use a filename fallback as a source tag. |
| GD3 English/original game | `Album` | Prefer English, then original. Keep it distinct from package identity. |
| GD3 English/original system | `game.console` | Prefer English, then original. Normalize a clear match using [`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md); do not add a member `System` or `Platform` tag. Hold missing, mixed, or unrecognized system labels for review. |
| GD3 English/original artist | `Artist` | Prefer English, then original. |
| GD3 release date | `Date` | Keep populated source text. Derive `Year` only when the leading four digits form a valid year. |
| GD3 converted-by | `Dumper` | Preserve the source meaning; do not rename it `Encoded By`. |
| GD3 notes | `Comment` | Include only when nonempty and useful. |
| Total and loop sample counts | Playback fields/report | Keep positive source-backed timing/loop data only if UAC's playback consumer uses it. Header sample counts alone do not authorize synthetic loop objects or negative loop tags. |

GD3 consists of a versioned UTF-16LE block. Preserve the original VGM bytes so
all other header fields, commands, unknown GD3 fields, and original encoding
remain available. Do not project sample rate, offsets, clocks, chip flags, or
reader diagnostics as music tags.

## VGZ handling and hashes

The UAC packer currently rejects `.vgz` as a playable member. For a VGZ source,
retain the exact source VGZ outside the playable member or as a clearly scoped
source attachment, then decompress to a byte-exact `.vgm` member as an explicit
normalization step. Record the source VGZ hash separately only when its bytes
are not otherwise captured in the source record. The four playable hashes are
over the complete normalized VGM member, not decoded emulator audio and not
the compressed VGZ wrapper.

Every physical VGM member gets BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5 under
`uac-playable-payload-v1`. Hash each file once even if it is played as multiple
subsongs. UAC structural `member.format` may say `vgm`; visible `Format` is the
single combined value such as `VGM v.1.71`.

## Review and validation

Report malformed headers, invalid EOF/data/GD3/loop offsets, truncated GD3,
invalid UTF-16 diagnostics, or timing fields that contradict one another.
Preserve valid unusual versions per member; follow a collection's review path
for mixed versions without discarding their `Format` tags. Verify normalization
by inflating VGZ and byte-comparing its output to the packaged VGM member.
