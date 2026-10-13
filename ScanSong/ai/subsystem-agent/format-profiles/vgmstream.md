# Format profile: `vgmstream`

Parent playback plugin: `vgmstream`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## Sony CD-XA

Recognized raw Sony XA sectors and RIFF/CDXA-wrapped sectors use MetaManCore's
in-process sector reader. It mirrors vgmstream's audio-sector test, first
three-audio-sector frame-header validation, 128 per-channel state slots,
interleaved file/channel subsong ordering, end-of-file resets, stream labels,
and sample-rate/form/bit-depth timing calculation. It does not decode ADPCM or
start `vgmstream-cli`. For sparse raw files, vgmstream's 32-bit probe offset
can wrap and revisit data after EOF; the direct reader folds those duplicate
probes while retaining the decoder's initial 32-sector search limit. Other
`.xa` signatures, including Maxis XA, XA30, 04SW, and AIFC aliases, remain on
vgmstream. The decoder also accepts a 100-byte raw prefix when its first XA
header/frame is valid: out-of-range frame reads are zero-filled. The direct
reader deliberately preserves this legacy boundary rather than tightening it.

The current read-only root-1 comparison through MetaMan and the production
ScanSong adapter matched all 867 saved rows across 827 files in 18 archives,
including multi-subsong indexes. The prior ScanSong-owned reader matched that
same corpus to both the catalog and vgmstream; this extraction pass did not have
a vgmstream CLI available, so the decoder comparison is the pre-move reference
rather than a fresh post-move oracle. The current scanner route averaged
0.716 ms/file in that Debug corpus pass; treat this as observational, not a
paired before/after performance claim. Sparse one-sector, two-sector,
audio-plus-non-audio, and 100-byte-prefix probes previously matched the
decoder's legacy boundaries. Archive extraction is serialized, with one
archive payload at a time.

## CRI / Monster ADX

CRI ADX files route through MetaManCore's in-process metadata reader rather
than `vgmstream-cli`. It recognizes type-03, type-04 (including encrypted version
markers), and type-05 headers, plus the distinct Monster Games ADX layout. The
reader preserves the existing catalog projection and additionally retains
exact header bytes, sample rate/count, channels, and loop bounds as technical
facts. The live-catalog test compares all saved ADX fields against MetaMan and
`vgmstream-cli`. The read-only root-1 result covers 489 rows in 13 source
containers: all 489 exactly match both the saved catalog and vgmstream.
Optimized Release mean inspection is 0.190 ms/row through MetaMan and
81.375 ms/row through the CLI, including its per-file process startup; these
are local per-file measurements, not whole-scan guarantees. Only recognized
CRI/Monster headers use this reader; other
payloads named `.adx` (including Ogg and RIFF aliases) remain on vgmstream, so
extension alone does not classify content as CRI ADX.

## Atomic Planet AUS

Recognized `AUS ` signatures use MetaManCore's complete in-process header
reader. It retains all 32 header bytes and exposes codec, native signed sample
count, rate, channels, raw and effective loop points, and both loop signals;
codec selection (`0x02` Xbox IMA versus PS-ADPCM fallback) is not needed to
derive metadata. No payload decoding or `vgmstream-cli` startup is required.
Valid loops preserve the CLI's two iterations plus ten-second fade; invalid
loop bounds are cleared using vgmstream's preparation rules while the original
values remain available as technical facts. Titles remain the source filename
without `.aus`, and the metadata source remains `Atomic Planet AUS header`.
Non-`AUS ` files with the same extension retain vgmstream fallback routing.

The read-only live-catalog differential covers all 440 rows in the Mega Man
Anniversary Collection archive. MetaManCore, the ScanSong schema adapter, the
saved catalog, and vgmstream match exactly for all 440 rows. Optimized Release
inspection averaged 0.197 ms/file through MetaMan and 171.546 ms/file through
the vgmstream CLI, including per-file process startup. These are local
per-file measurements, not a whole-scan guarantee.

## Sony MSF

Recognized Sony MSF signatures use MetaManCore's in-process reader. It preserves
the exact 64-byte header and exposes stream name, codec, channels, sample rate,
flags, raw loop markers, decoded sample bounds, and diagnostics. It derives
sample/timing facts for PCM16, PSX ADPCM, ATRAC3 variants, and MPEG frame headers
(including VBR), without decoding audio or starting `vgmstream-cli`. ATRAC
encoder delay and vgmstream's invalid-loop cleanup are preserved; play length
retains the CLI default of two loop iterations plus a ten-second fade. Content
routing leaves TamaSoft's `MSF ` signature and other non-Sony `.msf` aliases on
vgmstream. Playback remains owned by VGMBoy.

The read-only live-catalog differential matched all 799 rows through MetaMan
and ScanSong's adapter against both the saved catalog and vgmstream, across 799
files in four archives. The corpus covered codecs 0, 4, 5, and 7; focused
fixtures also cover codecs 1, 3, and 6, MPEG CBR/VBR, TamaSoft fallback, and
invalid loops. Optimized Release inspection averaged 1.241 ms/file through
MetaMan and the adapter versus 238.849 ms/file through the vgmstream CLI,
including per-file process startup. This is a local per-file comparison, not a
whole-scan guarantee.

## Konami and SNK SVAG

Known `.svag` variants use MetaManCore's complete direct header reader: `Svag`
selects the Konami layout with interleaved PS-ADPCM data, sample-byte loop
start, and optional `Svag`/`Desi` padding marker; `VAGm` selects SNK's
block-count loop layout. The neutral document retains the structural header
bytes and raw/effective channel, rate, sample, interleave, block, and loop facts.
Invalid loop bounds remain visible as raw facts and diagnostics but are omitted
from timing. The ScanSong adapter preserves the filename title, format comment,
and default two-loop plus ten-second-fade play projection. No ADPCM data is
decoded. Other `.svag` signatures retain the vgmstream fallback; playback stays
with VGMBoy.

The read-only live-catalog differential covers all 284 rows across eight
archives; every live row uses the Konami header. MetaMan plus the ScanSong
adapter, saved catalog, and vgmstream match all rows exactly. Focused MetaMan
fixtures cover the SNK variant, both loop conventions, invalid-loop diagnostics,
both accepted Konami padding markers, malformed headers, and alias probing.
The same-run Release comparison averaged 0.155 ms/file through MetaMan plus
the adapter, 0.056 ms/file through the former in-process reader, and 236.895
ms/file through the vgmstream CLI. The richer neutral document adds about
0.099 ms/file over the former parser while retaining raw header facts; the CLI
figure includes per-file process startup. These local per-file measurements
are not a whole-scan guarantee.

## RIFF ATRAC3/ATRAC3+: complete MetaMan reader

Recognized `.at3` RIFF/WAVE sources route through MetaManCore's bounds-checked
reader. It accepts WAVE ATRAC3 (`0x0270`) and the ATRAC3+ extensible GUID, reads
`fmt `, `fact` sample count/encoder skip, forward `smpl` or `wsmp` loops, and
ordered `LIST/INFO` tags (including duplicate and unknown keys). The native
loop-end conventions and vgmstream's skip adjustment/two-loop/ten-second-fade
play window are preserved. All non-audio RIFF chunks are exposed as named raw
blocks up to a 16 MiB aggregate limit; overflow is diagnosed and audio payload
bytes are not copied. Nonmatching `.at3` aliases retain the vgmstream route.
ScanSong now only performs content-based routing and adapts the neutral
document to schema 25; VGMBoy still owns playback.

The read-only root-1 live-catalog comparison covers all 177 rows in the
Castlevania: The Dracula X Chronicles and Silent Hill: Origins archives.
MetaMan, the ScanSong adapter, saved catalog, and vgmstream match exactly for
all 177 rows, including metadata, timing, and track shape. Release per-file
inspection averaged 0.216 ms through MetaMan versus 411.622 ms through the
vgmstream CLI, including per-file process startup. This is a local corpus
measurement, not a whole-scan guarantee; other formats and `.at3` aliases
still require vgmstream.

## Nintendo DS STRM

Two distinct Nintendo DS layouts are recognized under `.strm`: standard
`STRM`/`HEAD`/`DATA`, and Final Fantasy Tactics A2's `RIFF`/`IMA ` variant.
MetaMan reads codec, channel, rate, sample, loop, and interleave facts from
their fixed headers; neither path decodes audio. Only these validated layouts
leave vgmstream. Other `.strm` aliases retain the existing fallback.

The read-only root-1 catalog has 304 `.strm` files in 27 archives: 288 standard
STRM and 16 FFTA2 RIFF/IMA files. Direct signature routing selected all 304,
and every row matched the saved catalog exactly, including track shape,
metadata, and timing. This is saved-catalog parity; a fresh vgmstream CLI
comparison and paired performance measurement have not yet been run. Archive
extraction in the test is serialized and temporary.

## Nintendo DSP, RS03, and THP audio

The `.dsp` suffix covers standard Nintendo DSPADPCM's big-endian `0x60`-byte
header, Retro Studios' `RS03` header (magic `0x52530003`), and THP movie audio.
The `.thp` suffix now selects the same THP component/audio-header reader.
MetaMan retains the native header blocks and derives sample/loop timing without
decoding audio or video. Content signatures select the direct method;
unrecognized `.dsp` and `.thp` payloads continue through vgmstream.

The `.dsp` live comparison covers 211 files in two archives: 118 standard DSP,
84 RS03, and 9 THP-audio streams. The separate root-1 `.thp` catalog contains
one movie in one archive; its saved row, direct MetaMan result, and fresh
vgmstream result match exactly. One file is not a representative performance
sample; the existing `.dsp` corpus remains saved-catalog parity only. Live
tests extract one archive at a time and remove scratch data.

## Konami XMD

MetaMan reads Konami's two XMD layouts without opening the audio payload:
Silent Hill 4 v1 has a 12-byte header, while Castlevania: Curse of Darkness
v2 has a 17-byte header beginning with `xmd`. The reader validates the
declared data extent, retains unknown v2 header bytes, and derives per-channel
sample and loop facts using the same integer frame arithmetic as vgmstream.
For catalog compatibility, looped files use the CLI's default two loop passes
plus its ten-second fade; this duration is a playback projection, not an
authored file tag. Invalid signatures/ranges remain on the vgmstream fallback.
The exact byte fields and formulas are in MetaMan's
[XMD layout](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#konami-xmd-v1v2).

The read-only root-1 catalog comparison covered all 237 Silent Hill 4 XMD
files from one archive. Every row matched both the saved decoder-produced
catalog and a fresh vgmstream `-I` inspection, including track structure,
metadata, and timing. In the optimized local test run, the direct reader's
per-file median/p95 were 0.077/0.121 ms; vgmstream process inspection measured
59.642/136.783 ms, including per-file process startup. This is a local
parser-versus-process comparison, not a whole-archive scan guarantee. The live
corpus covers v1; synthetic tests cover v2.

## Sony SSHD / ADS / SS2

Validated `.ads` and `.ss2` files route through MetaManCore's direct Sony SSHD
reader. `.ss2` is not a separate layout: both suffixes use the native
`SShd`/`SSbd` stream, with ADSC (`0x08`) and Cavia (`0x7D8`) wrappers also
accepted. The reader reads codec/rate/channel/interleave/body fields and
derives sample timing from PCM16LE, PS-ADPCM, or the special DVI-IMA video
variant without decoding audio. Decoder-compatible loop-address branches and
trailing padding-frame removal are retained. Nonmatching aliases remain on
vgmstream, and playback remains owned by VGMBoy.

The read-only root-1 comparison covered all 196 ADS/SS2 rows/files across 15
archives (52 `.ads`, 144 `.ss2`). Direct MetaMan, the ScanSong schema adapter,
the saved catalog, and fresh vgmstream matched exactly. In Debug, direct
inspection averaged 4.217 ms/file versus 104.329 ms/file through the CLI,
including process startup. This is local corpus evidence, not a whole-scan or
cross-machine performance guarantee. See the [SSHD/ADS/SS2 layout](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#sony-sshd--ads).

## Headerless PlayStation MIB

The live `.mib` sources are raw PlayStation PS-ADPCM streams with no fixed
container header, text tags, or stored sample-rate field. `mib-direct` uses
MetaManCore's `0x2000`-byte PS-frame probe, extension-defined 44.1 kHz, and a
full frame walk to infer channel count, interleave, loop markers, sample count,
and scanner timing. The implementation preserves the reference's legacy loop
arithmetic, including the mono loop-start multiplier, and retains the first
frame as a raw probe block. The filename stem is the only title source because
these live streams contain no text metadata.

The read-only root-1 comparison covered all 327 MIB rows/files across eight
archives. Direct MetaMan, the ScanSong schema adapter, the saved catalog, and
fresh vgmstream inspection matched exactly for all 327 rows. In the optimized
Release run, direct inspection averaged 6.833 ms/file versus 72.767 ms/file
through the vgmstream CLI, including per-file process startup. Invalid probes
retain the vgmstream fallback. The separate `.mib` + `.mih` bank handler is a
different layout and is not claimed by this extraction. See the [MIB layout](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#headerless-playstation-mib)
and [MIB parity test](../../../Tests/ScanSongKitTests/MIBMetadataReaderTests.swift).

## Bink audio containers

The live `.bika` members are self-contained RAD Game Tools Bink containers
with a demuxed-audio suffix. `bink-audio-direct` reads the Bink signature and
revision, variable header blocks, per-stream sample rate and audio flags, the
absolute frame-offset table, and each frame's audio-packet decoded-byte count.
That last walk is required because Bink does not store the decoded sample count
in its main header. MetaMan divides the accumulated decoded bytes by
`2 * channels` and maps the result to finite duration; no Bink transform or
video decoder is started. Multiple Bink audio streams remain ordered
`MetadataTrack` entries rather than being flattened.

The read-only root-1 comparison covered the complete one-archive corpus: all
68 BIKA rows/files matched the saved catalog, the ScanSong adapter, and fresh
vgmstream inspection. Release direct inspection averaged 3.118 ms/file versus
91.143 ms/file through the vgmstream CLI, including per-file process startup.
`.bik`/`.bk2` movie inputs remain on the vgmstream playback/inspection boundary;
this extraction only claims the `.bika` route. See the [Bink layout](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#bink-audio-containers-bika)
and [Bink parity test](../../../Tests/ScanSongKitTests/BinkAudioMetadataReaderTests.swift).

## Mixed `.adp` layouts

`.adp` is a collision extension. `adp-direct` is selected only after a
content probe proves one of two complete layouts: headerless GameCube DTK, or
raw IMA with the exact hidden `.ADP.txth` companion used by the live Contra
archive. The first layout validates ten `0x20`-byte frames at offsets
`0x00..0x13F` using the decoder's repeated header bytes and nibble bounds, then
derives `floor(fileBytes / 0x20) * 28` stereo samples at 48 kHz. The second
accepts only `codec = IMA`, positive `sample_rate`, `channels` 1 or 2, and
`num_samples = data_size`; it derives `fileBytes * 2 / channels` samples and
retains the UTF-8 sidecar bytes and ordered directives.

The live catalog contains 184 `.adp` rows: 175 DTK members and nine TXTH IMA
members. No title, artist, game, loop, or fade tags exist in either layout, so
the filename supplies the title and timing is finite. An incomplete DTK probe,
an absent/malformed sidecar, or any unsupported TXTH directive is routed to
vgmstream instead of producing a partial direct row. The byte map is in
[FORMAT-LAYOUTS.md](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#mixed-adp-layouts), and
the route behavior is covered by
[ADPMetadataReaderTests.swift](../../../Tests/ScanSongKitTests/ADPMetadataReaderTests.swift).
The read-only live comparison covers all 184 rows/files with exact
direct/catalog/decoder parity; Release inspection averaged 0.129 ms/file
direct versus 96.569 ms/file through the CLI, including per-file process
startup. These are local corpus measurements.

## CRI AHX

`.ahx` is content-routed because the suffix belongs to CRI's AHX payload family
but the direct route must not claim arbitrary aliases. `ahx-direct` validates
the `0x8000` signature, the header-relative `(c)CRI` marker, fixed first-frame
word `FF F5 E0 C0`, mono channel, positive rate, and version `0x06`. It reads
only the bounded header and optional footer. Duration is computed from
`fileBytes - dataOffset` at the fixed 160,000-bit/s payload rate, preserving the
declared header sample count separately. The ScanSong projection keeps the
filename stem and `FFmpeg format (CRI ADX)` source label used by the existing
catalog. No AHX/MPEG audio decoding is started; unknown `.ahx` files retain
the vgmstream fallback.

The root-1 live comparison covers all 11 AHX rows/files with exact
direct/catalog/decoder parity. Release inspection averaged 0.160 ms/file
direct versus 35.398 ms/file through the CLI, including process startup. See
the [AHX offset map](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#cri-ahx) and
[AHX parity test](../../../Tests/ScanSongKitTests/AHXMetadataReaderTests.swift).

## Konami Saturn DVI

`.dvi` is content-routed because it is shared by Konami Saturn `DVI.` and
unrelated Capcom `IDVI` streams. `dvi-direct` accepts only the complete
big-endian header: payload offset at `0x04`, sample count at `0x08`, and loop
start at `0x0C` (`-1` means no loop). It retains the complete pre-payload
header, requires `fileBytes - dataOffset == sampleCount`, and derives stereo
Intel DVI/IMA timing at 44.1 kHz with 4-byte interleave. Looping duration uses
the decoder-compatible `loopStart + 2 * loopLength + 44100 * 10` projection.
No IMA decoder is started; `IDVI`, incomplete, and otherwise unknown `.dvi`
payloads retain vgmstream fallback.

The root-1 live comparison covers all 45 DVI rows/files with exact
direct/catalog/decoder parity. Release inspection averaged 0.291 ms/file
direct versus 330.900 ms/file through the CLI, including process startup. See
the [DVI offset map](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#konami-saturn-dvi) and
[DVI parity test](../../../Tests/ScanSongKitTests/DVIMetadataReaderTests.swift).

## Raw stream suffixes

The vgmstream extension set is owned by VGMBoy's
[`VGMStreamFormatManifest.swift`](../../../../VGMBoy/Sources/VGMBoyFormatCore/VGMStreamFormatManifest.swift):

```text
.aa3 .ads .ahx .aifc .at3 .aus .bik .bnk .dvi .fsb .genh .int
.mib .msf .mtaf .rws .ss2 .stream .strm .svag .vag .xmd
```

Although `.adx`, `.ads`, `.ss2`, `.ahx`, `.agsc`, `.at3`, `.aus`, `.dsp`, `.genh`, `.msf`, `.strm`, `.svag`, `.xmd`, and `.xa` remain in VGMBoy's
upstream manifest, ScanSong removes them from generic extension-only routing.
Recognized GENH, CRI/Monster ADX, Sony SSHD (`.ads`/`.ss2`), headerless PlayStation MIB, RIFF ATRAC3, Atomic Planet AUS, Sony MSF,
Konami/SNK SVAG and XMD, standard Nintendo DSPADPCM, Retro Studios RS03, Nintendo THP
audio, complete Retro Studios AGSC v1/v2 banks, CRI AHX, Nintendo DS standard STRM (`STRM`/`HEAD`/`DATA`) and FFTA2 (`RIFF`/`IMA `),
and Sony XA signatures use direct readers; `.bika` uses the complete Bink
container reader described above. Other aliases
retain the vgmstream fallback. For the
remaining raw-stream formats, the scanner invokes the bundled
`vgmstream-cli -I`. It reads sample rate,
total/play sample counts, loop bounds, source name, and decoder metadata. A
reported subsong count is capped at 1,000; each subsong is inspected with its
one-based `-s` selector and becomes a separate catalog row. A file that the
decoder cannot open remains a visible failure, even when its extension is in
the manifest.

`.fsb` remains entirely on vgmstream. The family includes FSB1–FSB5 layouts;
FSB1–4 have versioned sample headers (including variable-sized/basic and
duplicate entries), while FSB5 uses packed sample modes and chained extra
records. Both readers can also use a sibling `.fev` file to replace a bank's
embedded or filename-derived stream name. Do not route only FSB5 to MetaMan: a
direct cutover must cover the full FSB family and preserve applicable FEV name
resolution as well as decoder-derived timing/acceptance behavior.

## GameCube primary streams

The GameCube primary set is:

```text
.adp .agsc .dsp .h4m .ldat .logg .rsf .thp .txtp
```

These members use direct MetaMan inspection for complete recognized
DSP/RS03/THP and AGSC layouts; remaining GameCube primary members use the
bundled vgmstream inspector. The archive materializer normalizes
underscore-prefixed aliases such as
`_.ldat.txth` to `.ldat.txth` inside scratch storage. `.txth`, `.bd`, `.sbb`,
and other bank/control files are dependencies, not duplicate playlist rows.
The RE2 GameCube archive is the regression fixture for this boundary: primary
`.ldat` members must resolve their TXTH aliases and produce real metadata.

## Retro Studios AGSC

MetaMan reads both AGSC bank organizations, preserving the internal stream
name and one row per DSP record. It follows the vgmstream coefficient-pointer
base, including valid records whose 40-byte coefficient read extends eight
bytes beyond the declared header chunk. Sample and loop fields reproduce the
scanner's two-loop/10-second-fade duration projection; no audio decoding runs.
Unsupported or malformed `.agsc` content remains on the decoder route.

The root-1 live catalog has two Metroid Prime 2 AGSC files. The direct MetaMan
rows, saved decoder-produced rows, and fresh vgmstream `-I` rows match exactly
(2/2 each, including names and play/loop timing). The paired run averaged
0.099 ms per direct inspection versus 215.132 ms per vgmstream CLI inspection;
with only two files, this is a startup-sensitive measurement, not a general
performance claim. The executable parity test is
[`AGSCMetadataReaderTests.swift`](../../../Tests/ScanSongKitTests/AGSCMetadataReaderTests.swift).

## vgmstream GENH headers

Valid `.genh` files route through `MetaManCore`'s generic-header reader. The
fixed little-endian header declares channel count, interleave, sample rate,
loop bounds, codec ID, audio offset, and header size. Larger headers can add
DSP coefficient layout, sample count, encoder skip/mode, payload byte count,
and final interleave. A zero header-size field triggers vgmstream's legacy
compatibility rule: both effective header size and audio offset become
`0x800`. The reader retains the complete effective header, uses the filename
stem as title and `GENH generic header` as source label, and computes timing
from header samples—no payload codec is opened. Signature/header failures and
codec IDs outside vgmstream's defined GENH table retain vgmstream fallback.

The read-only root-1 comparison covered both source archives: all 94 saved
rows/files matched direct MetaMan, the ScanSong projection, and a fresh
vgmstream `-I` run (94/94/94 exact, with no mismatches). Mean inspection was
0.185 ms/file through MetaMan versus 195.186 ms/file through the CLI,
including per-file process startup; this is a local, startup-sensitive
measurement rather than a cross-machine guarantee. Byte offsets are listed in MetaMan's
[GENH format layout](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md#vgmstream-genh-generic-headers),
and the parity harness is
[`GENHMetadataReaderTests.swift`](../../../Tests/ScanSongKitTests/GENHMetadataReaderTests.swift).

## TXTP and HD-bank structures

`.txtp` is authored mixing/subsong structure, so its resolved dependencies are
prepared before `vgmstream-cli` is invoked. The TXTP row is authoritative;
its underlying stream is retained for decoder access but suppressed as a
separate source row when it is only a dependency.

`.hd`, `.hbd`, and `.iecs` use the required bank-structure adapter. Existing
IECS layouts with `.td` control data and `.msf` payloads may still fail when
they do not match vgmstream's standard `hd_bd` expectation. Those failures are
kept visible until an IECS-specific adapter exists; the scanner does not hide
them or flatten the `.hd` index into a false track.

vgmstream's playback-only extension set is `.adpcm`, `.bk2`, `.ogg`, `.ps3`,
`.s14`, `.swav`, and `.xvag`. ScanSong already admits `.ogg` through its
standard-audio route; the other six have no scanner route and need a fixture
before they should become catalog sources.
