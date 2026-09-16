# ScanSong format accommodations

## Scope and reading rules

This document describes the scanner's current behavior for every registered
intake route. It is intentionally more specific than a list of decoder names:
an extension is admitted only according to the route in
[`BuiltInScannerPlugins.swift`](/Users/john/Downloads/Code/VGMMan/ScanSong/Sources/ScanSongKit/BuiltInScannerPlugins.swift), and a row is published only according to that route's structure and metadata handler.

Scanner admission, metadata availability, and playback compatibility are
separate facts. A format may have a useful scanner row while its playback
decoder still needs a dependency set; conversely, a VGMBoy playback format may
be deliberately absent from ScanSong until a safe scanner adapter exists.
Invalid headers and incomplete timing commands remain failures. MetaMan has
one explicit S98 recovery: a truncated final register write is ignored only
after all preceding commands were parsed, with a diagnostic attached; this
does not turn arbitrary decoder failures into one-track records.

## Dependency-free format data

The complete NSF/GBS/NSFE/HES readers, including ordered track documents, live
in `MetaManCore`; HES companion M3U data is supplied through the metadata
context. AY's signed relative-pointer reader and SAP's
directive-header reader are also in MetaManCore. APE, CRI/Monster ADX, RIFF ATRAC3/ATRAC3+,
Sony MSF, SID PSID/RSID, SPC ID666/xID6, S98, VGM/VGZ, and PSF/PSF2/SSF/USF/2SF
metadata are also read through MetaManCore, which owns the Konami/SNK SVAG header reader.
ScanSong supplies source files and maps neutral metadata into its catalog
schema. These metadata routes do not require a playback decoder. Decoder-backed
enumeration, timing, dependency validation, and rendering remain on their
existing routes.

MetaManCore owns AY, SAP, NSF/GBS/NSFE, HES, SNDH, APE, ADX, ATRAC3, Sony MSF,
SVAG, SID, SPC, S98, VGM/VGZ,
and supported PSF-family metadata parsers plus the neutral metadata document;
ScanSong owns source routing and the schema-23 adapter. The package does not
link a playback decoder.

## Format coverage and eventual playback target

Every playable media format admitted by ScanSong is in the eventual
single-player coverage target: CocoaSpice should be able to play the media it
can catalog. VGMBoy's
[`FormatRegistry.playbackDescriptors`](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift)
describes current playback support, not the metadata-reader extraction
boundary. The matrix below summarizes current playback families; the route
summary lists every ScanSong-recognized media format and its current metadata
method. A scanner-only route is a playback gap to close, not an excluded
extraction target. Dependency files, sidecars, and control data that are not
independent media sources are not playback targets.

| CocoaSpice playback family | Playable extensions or names | ScanSong metadata methodology and current boundary |
| --- | --- | --- |
| `libgme` | `.ay`, `.gbs`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.sap`, `.spc` | Direct format readers handle all eight: native header/chunk/playlist facts are used without starting libgme. |
| `libvgm` | `.vgm`, `.vgz`, `.gym`, `.s98`, `.dro` | `.vgm`/`.vgz` use MetaManCore's direct GD3/header-timing reader and `.s98` uses its direct header/device/tag/event reader. `.gym` remains one structure-known row without metadata and is not an extraction target; `.dro` has no ScanSong route. |
| `psgplay` | `.sndh` | MetaManCore bounded header/tag/ICE! reader; PSGPlay remains the playback engine and is not linked for production scanning. |
| `mdx` | `.mdx` | VGMBoy-built `vgmboy-mdx-inspect` still supplies decoder-derived enumeration and metadata; dependencies are materialized but not published as tracks. |
| `standard-audio` | `.aac`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`, `.mp3`, `.wav`, `.wave` | Core Audio supplies duration/common tags, with FLAC Vorbis comments. `.ogg` is routed through this scanner handler too. `.aac`, `.caf`, and `.wave` do not currently have ScanSong routes. |
| `ffmpeg-audio` | `.ape`, `.mp2`, `.tak` | `.ape` uses MetaManCore's direct header/tag reader. `.mp2` and `.tak` do not currently have ScanSong routes. |
| `highly-complete` | `.gsf`, `.minigsf` | MetaManCore validates PSF v0x22 payloads, GBA segments, and dependency chains without mGBA. |
| `twosf` | `.2sf`, `.mini2sf` | `MetaManCore` PSF-style `[TAG]` reader; it does not start the playback core. |
| `vgmstream` | `.aa3`, `.adp`, `.adx`, `.adpcm`, `.ads`, `.agsc`, `.ahx`, `.aifc`, `.at3`, `.aus`, `.bk2`, `.bik`, `.bika`, `.bnk`, `.dsp`, `.dvi`, `.fsb`, `.genh`, `.h4m`, `.hbd`, `.hd`, `.iecs`, `.int`, `.ldat`, `.logg`, `.mib`, `.msf`, `.mtaf`, `.ogg`, `.ps3`, `.rsf`, `.rws`, `.s14`, `.ss2`, `.stream`, `.strm`, `.svag`, `.swav`, `.thp`, `.txtp`, `.vag`, `.xa`, `.xmd`, `.xvag` | `.adx`, `.at3`, `.aus`, `.msf`, and `.svag` use MetaManCore's content-aware readers, while `.xa` uses ScanSong's direct reader; nonmatching aliases retain vgmstream. `.txtp` and HD-bank inputs use vgmstream with dependency preparation. Other routed streams use `vgmstream-cli -I`. `.ogg` currently uses the Core Audio scanner route. |
| `lazyusf` | `.usf`, `.miniusf` | `MetaManCore` PSF-style `[TAG]` reader; `.usflib` remains dependency data, not a track. |
| `playpsf` | `.psf`, `.minipsf`, `.psf2`, `.minipsf2` | `MetaManCore` PSF-style `[TAG]` reader; libraries remain dependency data. |
| `qsf` | `.qsf`, `.miniqsf` | MetaManCore's complete PSF v0x41/QSound reader validates payload blocks, root tags, and declared dependencies without the QSound core. |
| `sidplayfp` | `.sid` | `MetaManCore` reads PSID/RSID header metadata; the playback decoder remains in VGMBoy. |
| `openmpt` | `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`, `.ptm`, `.s3m`, `.stm`, `.ult`, `.xm` | ScanSong admits one known-structure row, but metadata remains optional/deferred; no playback decoder inspection runs. |
| `amiga-uade` | UADE replayer prefixes such as `mod.*`, `p4x.*`, `med.*`, and TFMX | VGMBoy-built `vgmboy-amiga-inspect` still supplies subsong enumeration and metadata; complete-set dependencies are materialized first. |

`metadataPolicy: .direct` means the route does not need a playback-decoder
process; it does not promise facts the source format never stores. `.decoder`
marks routes whose scanner result still depends on a decoder/inspector, while
`.optionalDeferred` admits structure without a complete metadata method. Every
recognized media route remains in the eventual player-coverage target, even
when the current playback registry does not yet admit it.

### UAC packages

.uac is a metadata-bearing TAR+Zstandard package, not a playable media
extension. ScanSong reads and validates its bounded UAC manifest (and the
seek-table structure when present), then projects supported playable member
records directly into the catalog. It does not expand, hash, or inspect the
TAR+Zstandard payload during scanning; declared member sizes and BLAKE3 values
are trusted rather than recomputed. A playable member is represented from its
manifest record and does not need an inner-format inspector.

The UAC game title and console select the catalog's browser grouping only.
UAC member fields exclusively define the schema-23 track fields CocoaSpice
consumes; missing, null, or invalid values remain blank/default, never falling
back to contained-file tags. Track rows remain independent, so differing values
are not promoted or overwritten by package-level consensus. Rich UAC member
metadata, hash records, playlists, and game-level metadata remain in the
package manifest. During playback CocoaSpice may decode the selected payload
member, but must not read its source-format tags for displayed metadata.
The current schema-23 player catalog projects only its established common
track fields and does not expose those additional manifest fields in CocoaSpice.

## Route summary

| ScanSong route | Registered extensions | Structure published | Metadata source | Dependency or archive rule |
| --- | --- | --- | --- | --- |
| `spc-direct` | `.spc` | One track | MetaManCore SPC ID666/xID6 reader | All valid files are handled directly, including tagless info-only defaults; no libgme runtime link. |
| `game-music-direct` | `.gbs`, `.nsf` | One row per header-declared track | `MetaManCore.readResult` fixed-header readers | No emulator is started; the formats do not store authored per-track names or timing. |
| `nsfe-direct` | `.nsfe` | One row per NSFE playlist entry | `MetaManCore.readResult` bounded chunk reader | No emulator is started; labels/authors/times are source-indexed and mapped through the optional playlist, including duplicates. |
| `kss-direct` | `.kss` | 256 compatibility slots | MetaManCore KSCC/KSSX header reader | Header-only; preserves libgme 0.6.5's info-only listing and timing fallback. KSSX track declarations are retained as facts; KSS M3U files are not consumed. |
| `ay-direct` | `.ay` | One row per AY header-declared subtune | `MetaManCore` ZXAYEMUL reader | No decoder; signed relative pointers expose titles, author/comment, raw metadata blocks, and native 50 Hz track lengths. |
| `sap-direct` | `.sap` | One row per `SONGS` header entry (default one) | `MetaManCore` SAP information-header reader | No emulator; retains the bounded raw header and ordered directives; native `TIME` facts map finite durations or loop-start intro times. |
| `hes-direct` | `.hes` | One row per sibling-M3U entry, or 256 compatibility slots without one | `MetaManCore.readResult` HES header/M3U reader | No emulator; MetaMan receives only the same-basename sibling M3U, which remains support data and supplies the authored track map and timings. |
| `sndh-direct` | `.sndh` | One row per declared subtune | `MetaManCore.readResult` with bounded ICE! expansion | PSGPlay remains playback-only; the previous metadata API is a test-only oracle. |
| `openmpt` | `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`, `.ptm`, `.s3m`, `.stm`, `.ult`, `.xm` | One structurally-known row | Optional/deferred; metadata may be empty | No scanner-side module conversion or archive expansion. |
| `standard-audio` | `.aif`, `.aiff`, `.flac`, `.m4a`, `.mp3`, `.ogg`, `.wav` | One track | Core Audio duration and common tags; FLAC Vorbis comments | Exact decoded duration is preferred. |
| `ape-direct` | `.ape` | One validated single row | `MetaManCore` APE descriptor, seek-table, APEv2, and ID3v2 reader | Header-derived duration, ordered tags, and original tag blocks; no decoder startup. |
| `adx-direct` | CRI/Monster ADX in `.adx` | One track | `MetaManCore` CRI/Monster header and loop-timing reader | Preserves native sample/loop bounds and vgmstream's default two-loop/10-second-fade play window; non-ADX signatures (including Ogg and RIFF aliases) use vgmstream. |
| `aus-direct` | Atomic Planet AUS in `.aus` | One track | `MetaManCore` Atomic Planet AUS header reader | Preserves the exact 32-byte header, native codec/sample/channel/loop facts, and vgmstream's default play window without starting PS-ADPCM or Xbox IMA decoding; other `.aus` payloads use vgmstream. |
| `at3-direct` | RIFF/WAVE ATRAC3/ATRAC3+ in `.at3` | One track | `MetaManCore` RIFF chunk, INFO-tag, and loop reader | Preserves ordered `LIST/INFO` tags and non-audio chunks, plus native codec/fact/loop facts and the prior play projection; unrelated aliases use vgmstream. |
| `sony-msf-direct` | Sony MSF in `.msf` | One track | `MetaManCore` Sony MSF header and frame reader | Retains the source header and derives supported codec timing without audio decoding; TamaSoft `MSF ` and other non-Sony aliases use vgmstream. |
| `svag-direct` | Konami/SNK SVAG in `.svag` | One track | MetaManCore Konami/SNK SVAG header reader | Retains header and native PS-ADPCM sample/loop facts; unknown `.svag` signatures use vgmstream. |
| `xa-direct` | Sony CD-XA in `.xa` | One row per XA file/channel subsong | MetaManCore Sony XA sector reader | Preserves interleaved channel enumeration, source facts, and sector-derived timing; RIFF/CDXA wrappers are accepted. Other `.xa` formats use vgmstream. |
| `vgm-direct` | `.vgm`, `.vgz` | One stream row | `MetaManCore` VGM/VGZ header, GD3, and sample timing | VGZ is bounded gzip decompression, not a generic archive; no decoder is started. |
| `s98-direct` | `.s98` | One stream row | `MetaManCore` S98 v0-v3 parser plus ScanSong schema adapter | No playback core is started; full `DATE` and actual intro-to-loop timing intentionally improve on libvgm's projection. |
| `libvgm` | `.gym` | One stream row | Structure-known; metadata remains absent | No scanner-side metadata is invented; `.gym` remains decoder-owned. |
| `sndh-direct` | `.sndh` | One row per declared subtune | `MetaManCore.readResult` with bounded ICE! expansion | PSGPlay is not linked for production metadata inspection. |
| `mdx` | `.mdx` | One logical sequence row | VGMBoy-built `vgmboy-mdx-inspect` | A declared PDX bank is prepared but never published as a track. |
| `amiga-uade` | UADE replayer prefixes (`mod.*`, `p4x.*`, `med.*`, TFMX, and custom players) | One row per UADE subsong | VGMBoy-built `vgmboy-amiga-inspect` | `.lha` and loose sets are materialized as complete sets; companions remain dependency data. |
| `gsf-direct` | `.gsf`, `.minigsf` | One validated row | MetaManCore complete PSF v0x22/GSF reader | CRC, zlib payload, ordered tags, GBA segment chain, and PSFLib dependencies are validated without mGBA. |
| `highly-theoretical` | `.ssf`, `.minissf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | Metadata is available; current VGMBoy/CocoaSpice playback admission remains a gap. |
| `lazyusf` | `.usf`, `.miniusf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.usflib` is playback dependency data, never a row. |
| `twosf` | `.2sf`, `.mini2sf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.2sflib` is dependency data, never a row. |
| `vgmstream` | Remaining raw-stream extensions listed below plus nonmatching `.adx`, `.at3`, `.aus`, `.msf`, `.svag`, and `.xa` aliases | One row per reported subsong | VGMBoy-built `vgmstream-cli` | Native `-I` inspection; subsong count is bounded. Recognized CRI/Monster ADX, RIFF ATRAC3, Atomic Planet AUS, Sony MSF, Konami/SNK SVAG, and Sony XA use MetaManCore. |
| `vgmstream-txtp` | `.txtp` | One row per resolved subsong | `vgmstream-cli` after dependency preparation | Authored TXTP structure is authoritative. |
| `vgmstream-hd-bank` | `.hd`, `.hbd`, `.iecs` | One row per resolved subsong | `vgmstream-cli` after dependency preparation | Bank/control sidecars are support data; IECS remains a known adapter boundary. |
| `play-psf1` | `.psf`, `.minipsf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.psflib` is playback dependency data, never a row. |
| `play-psf2` | `.psf2`, `.minipsf2` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.psflib` is playback dependency data, never a row. |
| `qsf-direct` | `.qsf` | One validated row | MetaManCore complete QSF reader plus ScanSong schema adapter | CRC, bounded zlib output, QSound block ranges, and any referenced `.qsflib` files are validated without a QSound core. |
| `qsf-mini-direct` | `.miniqsf` | One validated row | MetaManCore complete QSF reader plus ScanSong schema adapter | Referenced `_lib` through `_lib9` libraries must be available beside the source and pass container/block validation. |
| `sid` | `.sid` | One structurally-known row | `MetaManCore` PSID/RSID header reader | One file row; no finite duration is invented when the header has none. |

The route table is deliberately not a claim that every registered source is
playable in every frontend. VGMBoy's playback registry and the scanner's
registry are separate contracts; the [VGMBoy format registry](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift) is the playback source of truth.

## Game Music Emu family

### SPC: complete direct ID666/xID6 route

`.spc` is registered as `spc-direct` with `knownSingle` structure.
`MetaManCore` owns SPC metadata parsing; VGMBoy retains SPC's libgme playback
integration. The reader handles text and binary ID666 layouts, optional xID6
items, dump dates, dumper/emulator facts, soundtrack fields, and authored
timing. It validates chunk/item bounds, diagnoses a malformed xID6 chunk
without dropping valid ID666 fields, and retains the original ID666 and xID6
regions as named raw blocks so unsupported values remain recoverable. Every
valid SPC produces direct metadata: when neither tag format is present, the
ScanSong projection keeps empty authored fields, `Super Nintendo`, unknown
intro/loop (`-1`), the 150-second info-only play default, and zero fade.

MetaMan keeps authored xID6 intro, loop, end, and fade facts. These can be
richer than libgme's info-only projection: upstream leaves xID6 intro mapping
disabled and does not consume the extended timing items. A read-only comparison
against CocoaSpice catalog roots 1 and 8 covered all 77,326 SPC rows in 3,389
source containers. MetaMan matched 76,664 saved rows exactly; the other 662
row differences were field-checked and each either matched libgme or had a
source-backed MetaMan value whose decoder difference was independently
explained. There were zero unexplained MetaMan/libgme differences. The catalog
was not modified. Release per-file medians/p95 were 0.055/0.071 ms (root 1)
and 0.056/0.077 ms (root 8) for MetaMan, versus 0.038/0.052 ms and
0.040/0.052 ms for libgme info-only. This parser-only timing excludes archive
extraction and is not a whole-scan performance guarantee. SPC playback remains
VGMBoy/libgme's responsibility. Malformed SPCs remain archive-member failures.

### AY: complete relative-pointer metadata route

`.ay` uses `ay-direct` and the decoder-independent `MetaManCore`
reader; ScanSong does not open libgme or execute the embedded Z80 player. The
reader validates the `ZXAYEMUL` header and complete track-pointer table,
follows bounded signed big-endian relative pointers, and extracts each
subtune title plus file-level author/comment. It retains the header's version,
player id, first-track byte, native source index, and raw header/table/text/info
blocks while publishing the same zero-based `0..<max_track+1` order used by
[libgme's AY info reader](https://github.com/libgme/game-music-emu/blob/master/gme/Ay_Emu.cpp).

Per-track duration is stored in 50 Hz frames. The reader maps a positive frame
count to milliseconds (`frames * 20`); absent or zero length retains libgme's
150-second play-length fallback. Intro, loop, and fade remain unknown, matching
the info-only contract. The test-only Project AY corpus comparison checks
acceptance, subtune count/order, and all scanner fields against libgme when
`SCANSONG_AY_FIXTURE_DIR` is supplied. The fixture is not available in the
current workspace, so post-cutover corpus parity and performance remain
unverified here. A synthetic test compares every projected AY field against
the former ScanSong reader.

### SAP: direct header, track, and timing facts

`.sap` uses `sap-direct` and `SAPMetadataReader` in MetaManCore; ScanSong does
not open libgme or start the Atari CPU and POKEY playback core. Starting after
the five-byte `SAP\r\n` signature, the reader walks CR/LF directive lines to
the first `FF FF` binary-data marker, validates the player type (B/C only),
optional `SONGS` count, and bounded numeric fields, and retains the exact
header and ordered directives—including unknown keys. `SONGS` defaults to one
as it does in libgme's information-only reader. `NAME` and `AUTHOR` become game
and author; the system is `Atari XL`. SAP `DATE` remains available as a source
fact, matching the old scanner projection that did not map copyright into the
catalog comment. Detailed parser offsets/layouts are in MetaMan's
[format layout map](../../MetaMan/FORMAT-LAYOUTS.md).

The reader retains one `TIME` hint per corresponding subsong. The [SAP format
specification](https://asap.sourceforge.net/sap-format.html) defines a plain
`TIME` as finite duration and `TIME … LOOP` as the point where looping begins.
ScanSong therefore maps plain time to `play_length_ms`, loop-start time to
`intro_length_ms`, leaves unknown loop length and fade at -1, and keeps the
150-second playback fallback for loop-marked or missing timing. This adds
header-authored timing that the previous libgme info-only route did not expose;
it does not infer loop length or a finite end for an indefinitely looping song.

The earlier corpus parity comparison covered all 6,335 SAP sources under the
local ASMA fixture tree: 5,577 were accepted and 758 rejected by both the
former SAP reader and libgme. That run predates the MetaMan cutover. The current
test compares MetaMan-backed ScanSong results with libgme when
`SCANSONG_SAP_FIXTURE_DIR` is set; rerun it before claiming post-cutover corpus
parity. No SAP rows exist in the inspected CocoaSpice catalog for live-row
comparison.

### HES: complete header and M3U route

`.hes` uses `hes-direct` and `MetaManCore`'s complete ordered HES reader; no
libgme or PC Engine emulator is linked or started. The reader validates the
fixed information header, exposes native header facts and all three identity
fields, and reads a bounded same-basename M3U. Playlist order, repeated source
slots, decoded comments/tags, names, and authored timing remain in ordered
`MetadataDocument` results; raw HES header and M3U bytes are retained. MetaMan's
file-URL convenience loads only the matching sibling. ScanSong passes the
materialized member URL, so an archive's sibling M3U is seen without a second
parser or arbitrary dependency lookup. With no playlist, MetaMan exposes 256
compatibility address slots and unknown timing; ScanSong intentionally keeps
the prior zero-time catalog projection. Synthetic reader/adapter tests cover
both paths. The existing libgme fixture and live CocoaSpice catalog comparisons
remain the post-cutover parity gates.

### KSS: complete info-only header route

`.kss` is registered independently as `kss-direct`; header interpretation now
lives in MetaManCore. It validates the 16-byte `KSCC`/`KSSX` base header and
the optional bounded 16-byte KSSX extension, retaining addresses, bank/device
flags, declared payload length, track range, volume bytes, and raw header data.
It does not decode the payload or start a Z80/emulation core. The source has no
title, author, comment, or authored timing in this inspection contract.

The ordered result retains the established 256-slot compatibility range and
150-second play-length fallback. A synthetic KSSX file declaring three tracks
was checked against the installed libgme 0.6.5 info-only API, which still
reported 256; MetaMan keeps `declaredFirstTrack`, `declaredLastTrack`, and
`declaredTrackCount` as facts rather than changing catalog structure. The
vendored newer libgme source has a different KSSX count path, so that divergence
is documented rather than treated as evidence for a catalog migration.
MetaMan preserves ScanSong's established system-name spelling in its normalized
field, so the scanner no longer reinterprets device flags. The vendored
`MSX_Fan.kss` sample and synthetic KSSX case are parity-tested against the
installed info-only oracle. ScanSong does not load KSS M3U playlists, so that
behavior remains unchanged.

### NSFE: complete chunk route

NSFE uses MetaManCore's decoder-independent `GameMusicMetadataReader`. The
reader validates the mandatory INFO, DATA, and
NEND chunks, then harvests AUTH, TLBL, TAUT, TIME, FADE, PLST, PSFX, TEXT,
RATE, BANK, NSF2, VRC7, and region facts without executing the embedded NSF
payload.
Unknown optional chunks are retained as raw facts; unknown mandatory chunks
fail instead of being silently ignored.

The NSFE `time` and `fade` arrays are in source-track order, while `PLST`
defines the visible order and may omit or duplicate source tracks. ScanSong
publishes one row per visible playlist entry and keeps each row's source facts
in the shared reader. A positive authored TIME becomes the row length; zero or
negative/default TIME retains libgme's documented 150-second play-length
fallback, while the raw signed value remains available to callers. Explicit
FADE values are retained, including zero. This preserves both the old scanner
contract and the authored NSFE timing data.

### NSF and GBS: complete header route

NSF and GBS use `game-music-direct`, MetaManCore's dependency-free fixed-header
readers. The headers contain the complete file identity fields,
format facts, and track count, so ScanSong enumerates one row for every
header-declared track without opening libgme. The reader also preserves the
format-specific addresses, playback flags/timer fields, banking, and version
for future catalog projections.

Neither format stores authored per-track names or finite timing. The direct
scanner therefore publishes the header game/author/comment and leaves song
empty. It preserves libgme's unknown intro/loop/fade values and its documented
150-second play-length fallback without running timed emulation. Playback
remains a separate libgme concern.

## SNDH / MetaManCore

`.sndh` is a multi-track executable Atari ST music format and receives the
strongest scanner-specific treatment. The `sndh-direct` route uses MetaManCore
to bound the header by executable-vector branch targets, parse its tag block,
decode Atari ST text, and handle bounded `ICE!` compression. ScanSong neither
links nor starts PSGPlay for metadata. Each declared subtune becomes one row,
with:

- a contiguous zero-based `track_index`;
- the same declared `track_count` on every row;
- the subtune name when present, otherwise the file title;
- the file composer/year fields;
- the subtune's authored duration in `play_length_ms`.

This accommodates SNDH's common complications: default versus selected
subtunes, embedded sound-effect banks, loader/demo files, and files that open
but do not produce conventional music. Scanner publication proves structure
and timing only. The direct reader matches all 5,897 live CocoaSpice sources
and 11,758 catalog rows with zero mismatches. VGMBoy separately validates
playback by selecting and rendering subtunes; a file that is valid SNDH but
silent or hardware-specific is not silently converted into a false music
claim.

## MDX dependencies

`.mdx` is a one-track logical X68000 sequence. ScanSong invokes the
VGMBoy-built `vgmboy-mdx-inspect` executable, so metadata and duration come
from the same mdxmini implementation used by playback. MDX dependency names
are decoded using the legacy Shift-JIS convention, with UTF-8 fallback for
hand-authored files.

PDX is native X68000 sample-bank data, not an archive and not an alternate MDX
encoding. SMP and PCM companions, plus an explicitly referenced MDX sidecar,
are dependency data in this path rather than automatically being new scan
sources. When an MDX declares a dependency, ScanSong looks for a
case-insensitive local sibling first, including compressed `.zst`/`.zstd`
forms, then optionally uses a deterministic root-scoped index for `.pdx`,
`.smp`, `.pcm`, and `.mdx`: nearest shared folder, uncompressed before
compressed, and lexical path order. It never searches outside the supplied
scan root.

The dependency reader infers `.pdx` only when the MDX reference is
extensionless. Explicit alternate references such as `NOS.SMP`, `THRICE.PCM`,
or `KONAMI.MDX` are preserved verbatim (apart from case-insensitive filesystem
matching), so they are not turned into false names such as `NOS.SMP.PDX`.

For `name.MDX.zst`, the decompressed MDX is placed in disposable scratch and
the matching dependency is materialized beside it before the inspector starts.
Standalone compressed PDX, SMP, and PCM companions are suppressed from
discovery. For TAR.ZST, the complete archive is extracted into disposable
scratch, the MDX header is read, and its declared dependency remains data for
that MDX rather than an independent track. A declared but missing dependency
is an explicit MDX failure. The inspector checks the materialized scratch
directory before launching mdxmini and includes the declared name in the
failure (`Required MDX dependency is missing: name.`); it is not a successful
metadata row with an unknown dependency. Failures are recorded per declaring
module, so issue reports must deduplicate dependency names before treating their
counts as a bank inventory; several modules may legitimately share one bank.

The VGMBoy/mdxmini boundary also handles the inner X68000 LZX 0.32/0.42 form.
For MDX, the clear title and dependency header are preserved while only the
compressed sequence body is decoded. For PDX, a whole-file LZX stream is
decoded before the native sample-bank table is parsed. This is a lossless
scratch-layer accommodation: the outer `.zst` and original MDX/PDX payloads
are never rewritten. A legacy leading backslash in a PDX basename is treated
as a same-directory reference; absolute and traversal spellings remain unsafe.

## PSF-family routes

PSF-style footer tags are useful for catalog presentation but do not by
themselves prove that an emulation core can open the source. ScanSong therefore
keeps the following distinctions visible:

### GSF / miniGSF

`gsf-direct` delegates to MetaManCore's complete PSF v0x22 reader; it does not
start mGBA. The reader checks each compressed-payload CRC and zlib stream,
validates every GSF executable segment, and resolves `_lib`, then contiguous
`_lib2`, `_lib3`, etc. references to the PSFLib depth limit. It checks the
assembled GBA header bytes in load order against mGBA's ROM signature/fallback
and BIOS-rejection rules, without constructing or executing a GBA core. Missing
dependencies, unsafe paths, malformed segments, CRC failures, broken zlib
streams, and unrecognized ROM images remain explicit failures. Ordered tags,
including duplicates and unknown keys, exact per-source PSF headers/tag blocks,
and dependency/segment facts now live in MetaMan. Outer-file tags win for
authored metadata and `play_length_ms`; dependency tags fill missing values,
while legacy `intro_length_ms` follows the old inspector's final nested
`length` callback. Both time interpretations retain the old numeric-prefix
behavior. File reads confine dependencies to the source directory and cap a
container at 128 MiB, aggregate dependency bytes at 512 MiB, the chain at 256
files/depth 10, and inflated/assembled data at 64 MiB. Fallback song names use
the source filename, and each valid GSF/miniGSF file contributes one track.
VGMBoy continues to use Highly Complete/mGBA for playback. ScanSong no longer
owns GSF parsing, bundles or invokes a Highly Complete inspector, or links mGBA
for the GSF route. Scanner-plugin preparation also does not call VGMBoy's broad
playback dependency builder.

### QSF / miniQSF

`qsf-direct` and `qsf-mini-direct` route to MetaManCore's complete QSF reader
and adapt its neutral document to schema 23. It verifies PSF v0x41 (root),
compressed-payload CRCs and bounded zlib streams, validates each QSound data
block against the legacy ROM bounds, and resolves `_lib` through `_lib9`
declared sibling dependencies without starting the Z80/QSound playback core.
Root tags provide title, game, artist, comment, length, and fade; ordered
duplicate/unknown tags and raw header/tag blocks remain available in MetaMan.
Length/fade retain the playback bridge's parsing semantics. Libraries are
validated directly but are not recursively traversed; their tags do not
override the root's metadata. The scanner publishes one QSound track per
source. VGMBoy retains its QSF core for playback.

### PSF, PSF2, SSF, USF, and 2SF

`play-psf1`, `play-psf2`, `highly-theoretical`, `lazyusf`, and `twosf` currently use the
MetaMan PSF-style metadata reader for one structurally-known row. The reader
preserves ordered `[TAG]` fields, duplicates, unknown keys, and original footer
bytes; common identity fields and authored `length`/`fade` are projected
without emulation. Tag parsing is bounded to 1 MiB, while the raw footer is
retained. When no footer exists, the title falls back to the filename and the
extension supplies the system name. The parser does not validate the compressed
program payload or resolve playback libraries; those remain playback concerns.
Against the read-only live root-1 catalog, all 14,994 rows across 308 source
containers matched the saved catalog's metadata, timing, and track structure
exactly. Optimized Release inspection measured 0.071 ms median and 0.090 ms p95
per member; this is a local-corpus result, not a cross-machine guarantee.

GSF/miniGSF and QSF/miniQSF now both have complete MetaMan readers. Their
format-specific container, payload, and dependency validation is not duplicated
by ScanSong; generic PSF-family readers remain footer-only by design.

Their sidecars are never independent scanner sources. The recognized support
names are `.psflib`, `.2sflib`, `.gsflib`, `.qsflib`, `.ssflib`, and `.usflib`;
they are omitted from archive `unrecognized` diagnostics and from standalone
`.zst` discovery. The actual playback materializer must still stage the
complete dependency set for formats whose core requires it. ScanSong does not
claim successful playback solely because a PSF footer was readable.

## libVGM

`.vgm` and `.vgz` use `vgm-direct`, `.s98` uses `s98-direct`, and `.gym` stays
on the `libvgm` route. These formats publish at most one stream row per
source; they are not treated as multi-track archives.

For VGM and VGZ, `MetaManCore` validates the VGM header and reads all 11
standard GD3 strings (both language variants, date, converter, and notes),
retains future extra strings and original GD3 bytes, and reads total/loop
samples. VGZ gzip expansion is bounded to 256 MiB; a declared-but-invalid GD3
block is a malformed-file failure rather than a partial metadata row. The
ScanSong adapter preserves the existing English-first fields and notes-only
comment projection. GYM remains admitted through the libVGM route as a
structure-known row without invented metadata and is not a MetaMan target.

### VGM/VGZ: complete MetaMan metadata reader

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

### S98: first complete MetaMan reader

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
comment projection; catalog schema 23 has no dedicated date column. Unit tests
cover the library and the ScanSong projection.

The read-only CocoaSpice comparison covers all 5,081 current S98 rows across
245 source containers: 1,178 match libvgm exactly and 3,903 differences are
classified as specific improvements (timing, full `DATE`, Shift_JIS decoding,
or edge-space cleanup); there are no unexplained differences or rejected rows.
Five stale loop pointers are among the timing corrections. In optimized
Release measurements, direct median/p95 are 0.136/0.511 ms versus libvgm's
0.142/0.508 ms. These local-corpus timings are not a cross-machine guarantee.

## vgmstream and direct raw streams, TXTP, and banks

### Sony CD-XA

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

### CRI / Monster ADX

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

### Atomic Planet AUS

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

### Sony MSF

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

### Konami and SNK SVAG

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

### RIFF ATRAC3/ATRAC3+: complete MetaMan reader

Recognized `.at3` RIFF/WAVE sources route through MetaManCore's bounds-checked
reader. It accepts WAVE ATRAC3 (`0x0270`) and the ATRAC3+ extensible GUID, reads
`fmt `, `fact` sample count/encoder skip, forward `smpl` or `wsmp` loops, and
ordered `LIST/INFO` tags (including duplicate and unknown keys). The native
loop-end conventions and vgmstream's skip adjustment/two-loop/ten-second-fade
play window are preserved. All non-audio RIFF chunks are exposed as named raw
blocks up to a 16 MiB aggregate limit; overflow is diagnosed and audio payload
bytes are not copied. Nonmatching `.at3` aliases retain the vgmstream route.
ScanSong now only performs content-based routing and adapts the neutral
document to schema 23; VGMBoy still owns playback.

The read-only root-1 live-catalog comparison covers all 177 rows in the
Castlevania: The Dracula X Chronicles and Silent Hill: Origins archives.
MetaMan, the ScanSong adapter, saved catalog, and vgmstream match exactly for
all 177 rows, including metadata, timing, and track shape. Release per-file
inspection averaged 0.216 ms through MetaMan versus 411.622 ms through the
vgmstream CLI, including per-file process startup. This is a local corpus
measurement, not a whole-scan guarantee; other formats and `.at3` aliases
still require vgmstream.

### Raw stream suffixes

The vgmstream extension set is owned by VGMBoy's
[`VGMStreamFormatManifest.swift`](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyFormatCore/VGMStreamFormatManifest.swift):

```text
.aa3 .ads .ahx .aifc .at3 .aus .bik .bika .bnk .dvi .fsb .genh .int
.mib .msf .mtaf .rws .ss2 .stream .strm .svag .vag .xmd
```

Although `.adx`, `.at3`, `.aus`, `.msf`, `.svag`, and `.xa` remain in VGMBoy's
upstream manifest, ScanSong removes them from generic extension-only routing.
Recognized CRI/Monster ADX, RIFF ATRAC3, Atomic Planet AUS, Sony MSF,
Konami/SNK SVAG, and Sony XA signatures use MetaManCore readers. Other aliases
retain the vgmstream fallback. For the
remaining raw-stream formats, the scanner invokes the bundled
`vgmstream-cli -I`. It reads sample rate,
total/play sample counts, loop bounds, source name, and decoder metadata. A
reported subsong count is capped at 1,000; each subsong is inspected with its
one-based `-s` selector and becomes a separate catalog row. A file that the
decoder cannot open remains a visible failure, even when its extension is in
the manifest.

### GameCube primary streams

The GameCube primary set is:

```text
.adp .agsc .dsp .h4m .ldat .logg .rsf .thp .txtp
```

These members are admitted only through the bundled vgmstream inspector. The
archive materializer normalizes underscore-prefixed aliases such as
`_.ldat.txth` to `.ldat.txth` inside scratch storage. `.txth`, `.bd`, `.sbb`,
and other bank/control files are dependencies, not duplicate playlist rows.
The RE2 GameCube archive is the regression fixture for this boundary: primary
`.ldat` members must resolve their TXTH aliases and produce real metadata.

### TXTP and HD-bank structures

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

## Standard audio and modules

### Core Audio

`.aif`, `.aiff`, `.flac`, `.m4a`, `.mp3`, `.ogg`, and `.wav` are one-track
standard audio. ScanSong prefers `AVAudioFile`'s exact decoded frame count and
sample rate for duration, then falls back to `AVURLAsset`. Common tags are
mapped to the catalog; FLAC Vorbis comments are read directly for album,
title, artist, album artist, composer, and comment. No game-music timing model
is invented for ordinary audio.

### OpenMPT modules

The registered tracker extensions use one structurally-known row and optional
metadata. ScanSong does not render or convert a module during intake; an empty
metadata object means the module was admitted as a known single source, not
that a title was fabricated. Playback compatibility and module-specific
duration remain the libopenmpt/VGMBoy boundary.

### Amiga modules through UADE

Amiga music is a special route because many historical files identify the
EaglePlayer from a leading filename token rather than a conventional suffix.
ScanSong admits known UADE prefixes such as `mod.*`, `p4x.*`, `med.*`,
`mdat.*`, `smpl.*`, TFMX, and custom-player names through the shared
`AmigaFormatManifest`; an ordinary `music.mod` remains an OpenMPT module.
Loose files and members inside `.lha` archives use the same path-aware route.

The scanner extracts `.lha` with the existing bounded 7zz archive boundary,
then materializes the complete extracted Amiga set before invoking the
VGMBoy-built `vgmboy-amiga-inspect` adapter. This is required because an
Amiga set may contain a module, player companion, or sample bank in the same
archive. Companion data is available to UADE but is not published as a second
track source. UADE reports the actual subsong range, so ScanSong publishes one
row per declared subsong with the same zero-based contiguous track indexes used
by VGMBoy playback. The original module and companion bytes are preserved;
ScanSong does not convert them to WAV or flatten them into a new container.

The current shareable runtime is Homebrew UADE 3.05. UADE is GPL-2.0-only (not
GPL-2.0-or-later), so distribution must keep its license obligations and the
runtime data directory in view. A valid UADE open establishes format support;
native duration may remain zero for EaglePlayers that do not expose a finite
length, in which case VGMBoy's normal natural-end or bounded playback policy
applies. Decode/open failures remain visible `archive-error` records and are
never replaced with a fabricated one-track success.

### APE / Monkey's Audio

`.ape` is a native lossless audio container, not an archive and not a
multi-track module. `MetaManCore` validates the APE descriptor, stream
parameters, seek-table extent, frame offsets, and payload bounds. It derives
duration from the container's sample-block count and rate, retains ordered
APEv2 text tags and leading ID3v2 common tags, and exposes both original tag
blocks for unknown or binary values. An absent title falls back to the source
stem. ScanSong only adapts the resulting `MetadataDocument` to schema 23; it
never starts FFmpeg or an audio decoder. VGMBoy keeps its independent
`CFFmpeg` bridge for APE playback; ScanSong no longer builds or bundles an
FFmpeg inspection helper. The original APE bytes remain the catalog source;
no transcode is performed.

## SID

`.sid` metadata is read by MetaManCore; libsidplayfp remains VGMBoy's playback
dependency. It validates the complete v1 (`0x76`-byte) or v2+ (`0x7C`-byte)
header before reading the PSID/RSID fixed fields: title at `0x16`,
author at `0x36`, and released text at `0x56`, preserving the raw header and
technical identity/address/song-count facts. The source field called
`released` is retained as copyright/release text, not misrepresented as a full
date. ScanSong keeps its established one-row schema projection, with release
text in the comment field.

SID files do not carry a standard finite play duration. The reader therefore
does not infer seconds from the v2 extension bytes: `0x76` begins flags and
other technical fields, not PAL/NTSC lengths. The former direct reader treated
those bytes as durations and used overlapping title offsets for author and
released text; MetaMan fixes both parsing errors. The raw header remains
available through `MetadataDocument` even where schema 23 does not retain the
additional technical facts. See the [PSID/RSID format description](https://github.com/TheCodeTherapy/sid-player/blob/master/SIDspec.md).

## Deliberately not admitted

The following are visible file-type policy entries, not failed attempts at
scanner support:

- `.sgc` and `.m3u` for the current SGC/playlist boundary;
- `.ncsf`, `.minincsf`, and `.ncsflib` for the unimplemented NCSF dependency
  family;
- `.mus` for Doom MUS, which the current vgmstream path does not open.

Changing the ignore policy does not create a decoder. If a format has a route,
it is inspected and malformed data produces a failure. If it has no route,
archive members use compact `unrecognized` diagnostics unless they are known
support files. Sidecars and dependency files are silent support data, never
fake playable records.

## Archive and progress guarantees shared by every route

- A loose file or physical archive is one source-level progress item. Archive
  members update detail/current path but never advance the source denominator.
- Archive extraction is bounded and disposable. TAR.ZST streams `zstd -dc`
  into `tar`; it does not create a second full temporary TAR.
- Required external inspectors run through one bounded process runner with
  cancellation, concurrent stdout/stderr draining, a 30-second deadline, and
  output limits.
- ScanSong's native UI samples the latest aggregate progress; worker callbacks
  cannot pace the scan. CLI JSONL is rate-limited independently.
- A failed member is retained for diagnosis and retry while valid siblings are
  published. A completed source summary counts physical sources; the result
  log separately reports member failures.
- Diagnostic paths are relative to the supplied scanner root. Archive errors
  use `archive#member`, and redundant member names or disposable scratch paths
  are removed from the detail column.

## Maintenance rule

When a plugin or route changes, update this document and the corresponding
route/fixture tests in the same change. A new extension is not complete until
its structure policy, metadata source, dependency behavior, archive behavior,
and failure boundary are stated here and exercised by at least one fixture or
an explicit skipped test hook.
