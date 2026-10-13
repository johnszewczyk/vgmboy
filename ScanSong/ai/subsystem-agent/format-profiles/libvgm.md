# Format profile: `libvgm`

Parent playback plugin: `libvgm`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

`.vgm`, `.vgz`, and `.s98` use direct MetaMan routes. The libVGM playback family
also admits `.dro`, which ScanSong does not scan. The VGM/VGZ/S98 routes each
publish at most one stream row per source; they are not multi-track archives.

For VGM and VGZ, `MetaManCore` validates the VGM header and reads all 11
standard GD3 strings (both language variants, date, converter, and notes),
retains future extra strings and original GD3 bytes, and reads total/loop
samples. VGZ gzip expansion is bounded to 256 MiB; a declared-but-invalid GD3
block is a malformed-file failure rather than a partial metadata row. The
ScanSong adapter preserves the existing English-first fields and notes-only
comment projection. `.dro` is admitted by this playback plugin but has no ScanSong route.

## .vgm and .vgz — direct GD3 and timing reader

`.vgm` and `.vgz` delegate to the sibling `MetaManCore` package. It parses the
fixed VGM header and GD3 1.00 sequence without linking or invoking libvgm, and
converts total/loop sample counts to milliseconds at 44.1 kHz. Raw GD3 bytes
and all standard fields remain available through `MetadataDocument`; the
scanner keeps the existing common-field and notes-only comment projection.
Release date and converter are available to other clients but are not folded
into the existing VGM catalog comment. Gzip expansion accepts concatenated
members and is capped at 256 MiB. A read-only comparison against all 42,147
root-1 VGM catalog rows found 42,099 exact matches and 48 system-label-only
deltas: MetaMan preserves the literal English GD3 value `Sega Genesis`, while
the saved rows contain older alternate labels. No other metadata, timing, or
track-structure differences were found. This catalog snapshot is a comparison
baseline, not a current libvgm oracle. No VGM playback dependency was removed
by this extraction because the prior ScanSong path was already direct; the
gain is one shared full metadata interface and less ScanSong code.

## .s98 — direct header, tag, and event reader

`s98-direct` delegates to `MetaManCore`, which validates S98 versions 0–3,
parses device tables and the register-command stream, and reads legacy title
text or the v3 `[S98]` tag block without creating a libvgm player or sound
device. It retains ordered duplicate and user-defined tags plus the original
tag-block bytes. BOM-marked tags decode as UTF-8; unmarked v3 tags and legacy
titles use Shift_JIS decoding. `DATE` is retained as a full
string and takes normalized-date precedence over `YEAR`, while `YEAR` remains
independently available.

MetaMan fixes two observed libvgm inspection quirks: the intro duration comes
from the S98 loop offset (the old bridge placed loop duration in both intro and
loop fields), and stale loop pointers after the `FD` end command are ignored
instead of becoming fabricated full-song loops. A truncated final register
write is ignored with a diagnostic while timing from complete preceding events
is retained. The ScanSong schema adapter places full date text in the existing
comment projection; the catalog has no dedicated date column. Unit tests
cover the library and the ScanSong projection.

The read-only CocoaSpice comparison covers all 5,081 current S98 rows across
245 source containers: 1,178 match libvgm exactly and 3,903 differences are
classified as specific improvements (timing, full `DATE`, Shift_JIS decoding,
or edge-space cleanup); there are no unexplained differences or rejected rows.
Five stale loop pointers are among the timing corrections. In optimized
Release measurements, direct median/p95 are 0.136/0.511 ms versus libvgm's
0.142/0.508 ms. These local-corpus timings are not a cross-machine guarantee.
