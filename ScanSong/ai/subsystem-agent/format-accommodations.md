# ScanSong format accommodations

## Scope and reading rules

This document describes the scanner's current behavior for every registered
intake route. It is intentionally more specific than a list of decoder names:
an extension is admitted only according to the route in
[`BuiltInScannerPlugins.swift`](../../Sources/ScanSongKit/BuiltInScannerPlugins.swift), and a row is published only according to that route's structure and metadata handler.

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
Sony MSF, Sony SSHD (`.ads`/`.ss2`), headerless PlayStation MIB, Bink audio containers,
Nintendo DTK and TXTH-described IMA ADP, CRI AHX, Konami Saturn DVI, generic
vgmstream GENH headers, SID PSID/RSID, SPC ID666/xID6, S98, VGM/VGZ, and PSF/PSF2/SSF/USF/2SF
metadata are also read through MetaManCore, which owns the Konami/SNK SVAG header reader.
ScanSong supplies source files and maps neutral metadata into its catalog
schema. These metadata routes do not require a playback decoder. Decoder-backed
enumeration, timing, dependency validation, and rendering remain on their
existing routes.

MetaManCore owns AY, SAP, NSF/GBS/NSFE, HES, SNDH, APE, ADX, ATRAC3, Sony MSF,
Sony SSHD (`.ads`/`.ss2`), headerless PlayStation MIB, Bink audio containers, Nintendo DTK and
TXTH-described IMA ADP, CRI AHX, Konami Saturn DVI, SVAG, SID, SPC, S98, VGM/VGZ,
and supported PSF-family metadata parsers plus the neutral metadata document;
ScanSong owns source routing, common-field projection, and ordered tag persistence
in schema 25. The package does not
link a playback decoder.

## Format coverage and eventual playback target

Every playable media format admitted by ScanSong is in the eventual
single-player coverage target: CocoaSpice should be able to play the media it
can catalog. VGMBoy's
[`FormatRegistry.playbackDescriptors`](../../../VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift)
describes current playback support, not the metadata-reader extraction
boundary. The matrix below summarizes current playback families; the route
summary lists every ScanSong-recognized media format and its current metadata
method. A scanner-only route is a playback gap to close, not an excluded
extraction target. Dependency files, sidecars, and control data that are not
independent media sources are not playback targets.

| CocoaSpice playback family | Playable extensions or names | ScanSong metadata methodology and current boundary |
| --- | --- | --- |
| `libgme` | `.ay`, `.gbs`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.spc` | Direct format readers cover all seven corresponding scanner routes; native header/chunk/playlist facts are used without starting libgme. |
| `asap` | `.sap` | MetaManCore reads the bounded SAP header and ordered TIME facts; VGMBoy routes all SAP player types B/C/D/S through ASAP for playback. |
| `libvgm` | `.vgm`, `.vgz`, `.s98`, `.dro` | `.vgm`/`.vgz` use MetaManCore's direct GD3/header-timing reader and `.s98` uses its direct header/device/tag/event reader. `.dro` has no ScanSong route. |
| `psgplay` | `.sndh` | MetaManCore bounded header/tag/ICE! reader; PSGPlay remains the playback engine and is not linked for production scanning. |
| `mdx` | `.mdx` | MetaManCore reads the clear Shift-JIS title, PDX reference, and bounded MML timing for uncompressed bodies; the VGMBoy-built helper validates player/dependency acceptance only. LZX-compressed bodies retain tags but have no MetaMan timing. Dependencies are not published as tracks. |
| `standard-audio` | `.aac`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`, `.mp3`, `.wav`, `.wave` | MetaManCore's file-URL reader uses AVFoundation for duration/common tags and directly retains FLAC Vorbis comments. `.ogg` is routed through this scanner handler too. `.aac`, `.caf`, and `.wave` do not currently have ScanSong routes. |
| `ffmpeg-audio` | `.ape`, `.mp2`, `.tak` | `.ape` uses MetaManCore's direct header/tag reader. `.mp2` and `.tak` do not currently have ScanSong routes. |
| `highly-complete` | `.gsf`, `.minigsf` | MetaManCore validates PSF v0x22 payloads, GBA segments, and dependency chains without mGBA. |
| `twosf` | `.2sf`, `.mini2sf` | `MetaManCore` PSF-style `[TAG]` reader; it does not start the playback core. |
| `vgmstream` | `.aa3`, `.adp`, `.adx`, `.adpcm`, `.ads`, `.agsc`, `.ahx`, `.aifc`, `.at3`, `.aus`, `.bk2`, `.bika`, `.bik`, `.bnk`, `.dsp`, `.dvi`, `.fsb`, `.genh`, `.h4m`, `.hbd`, `.hd`, `.iecs`, `.int`, `.ldat`, `.logg`, `.mib`, `.msf`, `.mtaf`, `.ogg`, `.ps3`, `.rsf`, `.rws`, `.s14`, `.ss2`, `.stream`, `.strm`, `.svag`, `.swav`, `.thp`, `.txtp`, `.vag`, `.xa`, `.xmd`, `.xvag` | Validated `.adp` DTK/TXTH layouts, `.ads`/`.ss2`, `.adx`, `.ahx`, `.at3`, `.aus`, `.dsp`/`.thp`, `.msf`, `.svag`, and `.xmd` use content-aware MetaManCore readers with vgmstream fallback for unrecognized aliases; validated headerless `.mib` uses the MIB reader with vgmstream fallback for failed probes; `.bika` uses MetaMan's complete Bink container walk; `.xa` uses ScanSong's direct reader, and validated Nintendo DS standard/FFTA2 `.strm` layouts use MetaManCore. `.txtp` and HD-bank inputs use vgmstream with dependency preparation. Other routed streams use `vgmstream-cli -I`. `.ogg` is routed to MetaManCore's standard-audio reader in ScanSong. |
| `lazyusf` | `.usf`, `.miniusf` | `MetaManCore` PSF-style `[TAG]` reader; `.usflib` remains dependency data, not a track. |
| `playpsf` | `.psf`, `.minipsf`, `.psf2`, `.minipsf2` | `MetaManCore` PSF-style `[TAG]` reader; libraries remain dependency data. |
| `qsf` | `.qsf`, `.miniqsf` | MetaManCore's complete PSF v0x41/QSound reader validates payload blocks, root tags, and declared dependencies without the QSound core. |
| `sidplayfp` | `.sid` | `MetaManCore` reads PSID/RSID header metadata; the playback decoder remains in VGMBoy. |
| `openmpt` | `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`, `.ptm`, `.s3m`, `.stm`, `.ult`, `.xm` | Recognized 31-sample ProTracker-family `.mod` headers use MetaMan; all other registered module formats and unrecognized MOD dialects remain one known-structure row without metadata. No playback decoder inspection runs. |
| `amiga-uade` | UADE replayer prefixes such as `mod.*`, `p4x.*`, `med.*`, and TFMX | VGMBoy-built `vgmboy-amiga-inspect` still supplies subsong enumeration and metadata; complete-set dependencies are materialized first. |

`metadataPolicy: .direct` means the route does not need a playback-decoder
process; it does not promise facts the source format never stores. `.decoder`
marks routes whose scanner result still depends on a decoder/inspector, while
`.optionalDeferred` admits structure without a complete metadata method. Every
recognized media route remains in the eventual player-coverage target, even
when the current playback registry does not yet admit it.

### UAC packages

.uac is a metadata-bearing TAR+Zstandard package, not a playable media
extension. ScanSong passes the `.uac` file URL to `MetaManCore.readResult`,
which uses the shared `UACWrapperCore` parser to validate its bounded manifest
and seek-table structure, then returns package and playable-member documents.
ScanSong projects those documents into the catalog. Neither MetaMan nor
ScanSong expands, hashes, or inspects the TAR/audio payload during scanning;
declared member sizes and BLAKE3 values are trusted rather than recomputed. A
playable member is represented from its manifest record and does not need an
inner-format inspector. If the manifest has explicit `subsong` entries, each
unique member/decoder-index pair becomes a catalog row in playlist order; the
entry's per-track metadata and decoder index are retained while all rows point
to the same unchanged member. Ordinary file entries do not expand or duplicate
member rows.

The UAC game title and console select the catalog's browser grouping only.
UAC member fields and explicit subsong projections define the common track
fields CocoaSpice consumes; missing, null, or invalid values remain
blank/default, never falling back to contained-file tags. Track rows remain
independent, so differing values are not promoted or overwritten by
package-level consensus. Rich UAC member
metadata, hash records, playlists, and game-level metadata remain in the
package manifest. During playback CocoaSpice may decode the selected payload
member, but must not read its source-format tags for displayed metadata.
Schema 25 also retains each ordered source tag in `track_metadata_tags` for
ScanSong's Metadata Tags inventory. CocoaSpice still consumes only the common
track fields; it does not expose the additional UAC manifest fields.

For gallery artwork, ScanSong reads the package-level `game.metadata["Title
Snap"]` attachment tag as a direct member path or an array of paths. It checks
that a PNG path is safe and resolves to a declared package member, then stores
an `archive-member:<path>` locator as the catalog's `Title Snap` tag. It does
not extract the image during scanning. The former `cover_front` descriptor
shape remains readable for existing packages.

## Route summary

| ScanSong route | Registered extensions | Structure published | Metadata source | Dependency or archive rule |
| --- | --- | --- | --- | --- |
| `spc-direct` | `.spc` | One track | MetaManCore SPC ID666/xID6 reader | All valid files are handled directly, including tagless info-only defaults; no libgme runtime link. |
| `game-music-direct` | `.gbs`, `.nsf` | One row per header-declared track | `MetaManCore.readResult` fixed-header readers; optional NEZplug M3U for GBS | No emulator is started. NSF headers and GBS headers do not store authored per-track names or timing; a GBS M3U can supply them. MetaMan currently discovers directory M3Us only when exactly one GBS file is present in that directory. |
| `nsfe-direct` | `.nsfe` | One row per NSFE playlist entry | `MetaManCore.readResult` bounded chunk reader | No emulator is started; labels/authors/times are source-indexed and mapped through the optional playlist, including duplicates. |
| `kss-direct` | `.kss` | 256 compatibility slots | MetaManCore KSCC/KSSX header reader | Header-only; preserves libgme 0.6.5's info-only listing and timing fallback. KSSX track declarations are retained as facts; KSS M3U files are not consumed. |
| `ay-direct` | `.ay` | One row per AY header-declared subtune | `MetaManCore` ZXAYEMUL reader | No decoder; signed relative pointers expose titles, author/comment, raw metadata blocks, and native 50 Hz track lengths. |
| `sap-direct` | `.sap` | One row per `SONGS` header entry (default one) | `MetaManCore` SAP information-header reader | No emulator; retains the bounded raw header and ordered directives; native `TIME` facts map finite durations or loop-start intro times. |
| `hes-direct` | `.hes` | One row per sibling-M3U entry, or 256 compatibility slots without one | `MetaManCore.readResult` HES header/M3U reader | No emulator; MetaMan receives only the same-basename sibling M3U, which remains support data and supplies the authored track map and timings. |
| `sndh-direct` | `.sndh` | One row per declared subtune | `MetaManCore.readResult` with bounded ICE! expansion | PSGPlay is not linked for production metadata inspection; the previous metadata API is a test-only oracle. |
| `openmpt` | `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`, `.ptm`, `.s3m`, `.stm`, `.ult`, `.xm` | One structurally-known row | MetaMan reads the bounded title/sample-name header for recognized 31-sample ProTracker-family MOD signatures; unrecognized MOD and the remaining formats have no current MetaMan projection | No scanner-side module conversion or archive expansion. |
| `standard-audio` | `.aif`, `.aiff`, `.flac`, `.m4a`, `.mp3`, `.ogg`, `.wav` | One track | MetaManCore file-URL reader: AVFoundation duration/common tags; ordered FLAC Vorbis comments | Exact decoded duration is preferred; ScanSong only routes and projects the document. |
| `ape-direct` | `.ape` | One validated single row | `MetaManCore` APE descriptor, seek-table, APEv2, and ID3v2 reader | Header-derived duration, ordered tags, and original tag blocks; no decoder startup. |
| `adx-direct` | CRI/Monster ADX in `.adx` | One track | `MetaManCore` CRI/Monster header and loop-timing reader | Preserves native sample/loop bounds and vgmstream's default two-loop/10-second-fade play window; non-ADX signatures (including Ogg and RIFF aliases) use vgmstream. |
| `aus-direct` | Atomic Planet AUS in `.aus` | One track | `MetaManCore` Atomic Planet AUS header reader | Preserves the exact 32-byte header, native codec/sample/channel/loop facts, and vgmstream's default play window without starting PS-ADPCM or Xbox IMA decoding; other `.aus` payloads use vgmstream. |
| `at3-direct` | RIFF/WAVE ATRAC3/ATRAC3+ in `.at3` | One track | `MetaManCore` RIFF chunk, INFO-tag, and loop reader | Preserves ordered `LIST/INFO` tags and non-audio chunks, plus native codec/fact/loop facts and the prior play projection; unrelated aliases use vgmstream. |
| `sony-msf-direct` | Sony MSF in `.msf` | One track | `MetaManCore` Sony MSF header and frame reader | Retains the source header and derives supported codec timing without audio decoding; TamaSoft `MSF ` and other non-Sony aliases use vgmstream. |
| `svag-direct` | Konami/SNK SVAG in `.svag` | One track | MetaManCore Konami/SNK SVAG header reader | Retains header and native PS-ADPCM sample/loop facts; unknown `.svag` signatures use vgmstream. |
| `xmd-direct` | Validated Konami XMD v1/v2 in `.xmd` | One track | MetaManCore bounded XMD header reader | Retains versioned header, native frame/sample/loop facts, and scanner-compatible play time; unknown payloads use vgmstream. |
| `sshd-direct` | Validated Sony SSHD in `.ads` or `.ss2` | One track | MetaManCore Sony SSHD header and encoded-frame reader | Handles native `SShd` plus ADSC/Cavia wrappers, loop-address variants, and padding-frame timing without decoding; nonmatching `.ads`/`.ss2` uses vgmstream. |
| `mib-direct` | Validated headerless PlayStation PS-ADPCM in `.mib` | One track | MetaManCore bounded PS-frame probe and channel/interleave/loop/timing reader | The live eight-archive corpus contains 327 files and matches the saved catalog, ScanSong adapter, and fresh vgmstream exactly. Invalid `.mib` probes retain vgmstream fallback; the separate `.mib`/`.mih` bank layout is not conflated with this route. |
| `bink-audio-direct` | Self-contained RAD Game Tools Bink audio containers in `.bika` | One row per Bink audio stream | MetaManCore Bink header, frame-offset, and packet-sample walk | The live one-archive corpus contains 68 files and matches the saved catalog, ScanSong adapter, and fresh vgmstream exactly. `.bik`/`.bk2` movies remain on the vgmstream playback/inspection boundary. |
| `adp-direct` | Headerless Nintendo DTK or exact `.adp.txth` IMA layout in `.adp` | One track | MetaManCore content probe and complete layout reader | 175 live DTK members and nine TXTH-described Contra members are direct; unknown `.adp` aliases remain on vgmstream and the hidden sidecar is dependency context. |
| `ahx-direct` | Validated CRI AHX in `.ahx` | One track | MetaManCore bounded AHX header and fixed-bitrate payload reader | The live root-1 corpus contains 11 files with exact saved-catalog and fresh-vgmstream parity; invalid `.ahx` aliases remain on vgmstream. |
| `dvi-direct` | Validated Konami Saturn `DVI.` in `.dvi` | One track | MetaManCore bounded DVI header and stereo IMA timing reader | The live root-1 corpus contains 45 files with exact saved-catalog and fresh-vgmstream parity; Capcom `IDVI` aliases and incomplete payloads remain on vgmstream. |
| `dsp-direct` | Standard Nintendo DSPADPCM and Retro Studios `RS03` in `.dsp`; Nintendo THP audio in `.dsp` or `.thp` | One track | MetaManCore's three signature-dispatched header readers | Preserves raw header/layout and native sample/loop facts; unrecognized `.dsp`/`.thp` payloads use vgmstream. |
| `agsc-direct` | Retro Studios AGSC bank versions 1 and 2 in `.agsc` | One row per bank stream | MetaManCore's bounded chunk and DSP-table reader | Reads the internal stream name, sample/rate/loop values, and coefficient-table references without DSP decoding; unrecognized `.agsc` payloads use vgmstream. |
| `genh-direct` | Validated vgmstream GENH headers in `.genh` | One stream row | MetaManCore generic-header reader | The root-1 corpus has 94 rows/files with exact saved-catalog, ScanSong, and fresh-vgmstream parity; the latest run averaged 0.185 ms/file direct versus 195.186 ms/file through the CLI. Unknown codecs and malformed headers use fallback. |
| `nds-strm-direct` | Nintendo DS standard `STRM`/`HEAD`/`DATA` or FFTA2 `RIFF`/`IMA ` in `.strm` | One track | `MetaManCore` standard STRM and FFTA2 readers | Preserves codec, channel, sample, loop, and interleave facts plus scanner-compatible duration; unrelated `.strm` aliases use vgmstream. |
| `xa-direct` | Sony CD-XA in `.xa` | One row per XA file/channel subsong | MetaManCore Sony XA sector reader | Preserves interleaved channel enumeration, source facts, and sector-derived timing; RIFF/CDXA wrappers are accepted. Other `.xa` formats use vgmstream. |
| `vgm-direct` | `.vgm`, `.vgz` | One stream row | `MetaManCore` VGM/VGZ header, GD3, and sample timing | VGZ is bounded gzip decompression, not a generic archive; no decoder is started. |
| `s98-direct` | `.s98` | One stream row | `MetaManCore` S98 v0-v3 parser plus ScanSong schema adapter | No playback core is started; full `DATE` and actual intro-to-loop timing intentionally improve on libvgm's projection. |
| `mdx` | `.mdx` | One logical sequence row | VGMBoy-built `vgmboy-mdx-inspect` | A declared PDX bank is prepared but never published as a track. |
| `amiga-uade` | UADE replayer prefixes (`mod.*`, `p4x.*`, `med.*`, TFMX, and custom players) | One row per UADE subsong | VGMBoy-built `vgmboy-amiga-inspect` | `.lha` and loose sets are materialized as complete sets; companions remain dependency data. |
| `gsf-direct` | `.gsf`, `.minigsf` | One validated row | MetaManCore complete PSF v0x22/GSF reader | CRC, zlib payload, ordered tags, GBA segment chain, and PSFLib dependencies are validated without mGBA. |
| `highly-theoretical` | `.ssf`, `.minissf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | Metadata is available; active VGMBoy playback admission does not include SSF. |
| `lazyusf` | `.usf`, `.miniusf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.usflib` is playback dependency data, never a row. |
| `twosf` | `.2sf`, `.mini2sf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.2sflib` is dependency data, never a row. |
| `vgmstream` | Remaining raw-stream extensions listed below plus nonmatching `.adp`, `.adx`, `.agsc`, `.ads`/`.ss2`, `.at3`, `.aus`, `.dsp`/`.thp`, `.genh`, `.msf`, `.strm`, `.svag`, `.xmd`, and `.xa` aliases | One row per reported subsong | VGMBoy-built `vgmstream-cli` | Native `-I` inspection; subsong count is bounded. Recognized GENH headers, ADP DTK/TXTH, CRI/Monster ADX, Retro Studios AGSC, RIFF ATRAC3, Atomic Planet AUS, standard DSPADPCM, Retro Studios RS03, THP audio, Sony MSF, Sony SSHD, Konami/SNK SVAG and XMD, both Nintendo DS STRM layouts, Sony XA, and Bink `.bika` use direct readers. |
| `vgmstream-txtp` | `.txtp` | One row per resolved subsong | `vgmstream-cli` after dependency preparation | Authored TXTP structure is authoritative. |
| `vgmstream-hd-bank` | `.hd`, `.hbd`, `.iecs` | One row per resolved subsong | `vgmstream-cli` after dependency preparation | Bank/control sidecars are support data; IECS remains a known adapter boundary. |
| `play-psf1` | `.psf`, `.minipsf` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.psflib` is playback dependency data, never a row. |
| `play-psf2` | `.psf2`, `.minipsf2` | One structurally-known row | `MetaManCore` PSF-style `[TAG]` footer reader | `.psflib` is playback dependency data, never a row. |
| `qsf-direct` | `.qsf` | One validated row | MetaManCore complete QSF reader plus ScanSong schema adapter | CRC, bounded zlib output, QSound block ranges, and any referenced `.qsflib` files are validated without a QSound core. |
| `qsf-mini-direct` | `.miniqsf` | One validated row | MetaManCore complete QSF reader plus ScanSong schema adapter | Referenced `_lib` through `_lib9` libraries must be available beside the source and pass container/block validation. |
| `sid` | `.sid` | One row per declared SID song | `MetaManCore` PSID/RSID header reader | No finite duration is invented when the header has none. |

The route table is deliberately not a claim that every registered source is
playable in every frontend. VGMBoy's playback registry and the scanner's
registry are separate contracts; the [VGMBoy format registry](../../../VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift) is the playback source of truth.

## Parent plugin profiles

Each profile follows a VGMBoy playback parent and breaks out its admitted
subformats, ScanSong route, metadata source, and format-specific boundaries.
The playback matrix above remains the compact extension inventory; detailed
subformat behavior lives in these independently maintained profiles.

| Parent playback plugin | Format profile |
| --- | --- |
| `libgme` | [Game Music Emu subformats](format-profiles/libgme.md) |
| `asap` | [SAP](format-profiles/asap.md) |
| `libvgm` | [VGM, VGZ, S98, and playback-only DRO](format-profiles/libvgm.md) |
| `psgplay` | [SNDH](format-profiles/psgplay.md) |
| `mdx` | [MDX and dependencies](format-profiles/mdx.md) |
| `standard-audio` | [AVFoundation-backed audio](format-profiles/standard-audio.md) |
| `ffmpeg-audio` | [APE and related playback extensions](format-profiles/ffmpeg-audio.md) |
| `highly-complete` | [GSF and miniGSF](format-profiles/highly-complete.md) |
| `twosf` | [2SF and mini2SF](format-profiles/twosf.md) |
| `vgmstream` | [Raw streams, TXTP, and banks](format-profiles/vgmstream.md) |
| `lazyusf` | [USF and miniUSF](format-profiles/lazyusf.md) |
| `playpsf` | [PSF and PSF2](format-profiles/playpsf.md) |
| `qsf` | [QSF and miniQSF](format-profiles/qsf.md) |
| `sidplayfp` | [SID](format-profiles/sidplayfp.md) |
| `openmpt` | [Tracker modules](format-profiles/openmpt.md) |
| `amiga-uade` | [Amiga replayer prefixes](format-profiles/amiga-uade.md) |

SSF and miniSSF are ScanSong metadata-only routes without an active playback parent. Their scanner route profile is [highly-theoretical](format-profiles/highly-theoretical.md).

Scanner-only routes and cross-plugin aliases remain in the route inventory;
profiles describe playback-parent groupings without merging the separate
scanner and playback registries.

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
- Supported archive extraction is bounded and disposable. Standalone `.zst`
  files are decoded as one implicit member. UAC payloads use the UAC reader.
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

Run `python3 ScanSong/scripts/check-format-doc-consistency.py` from the VGMMan
repository root to compare playback extension families and scanner route IDs
with their source registries.

When a plugin or route changes, update this registry index, the matching
parent-plugin profile, and the corresponding route/fixture tests in the same
change. A new extension is not complete until its profile identifies its
parent playback plugin (or states that it is scanner-only) and records the
structure policy, metadata source, dependency behavior, archive behavior, and
failure boundary. Exercise it with at least one fixture or an explicit skipped
test hook.
