# Format profile: `libgme`

Parent playback plugin: `libgme`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .spc — direct ID666/xID6 route

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

## .ay — relative-pointer metadata route

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

## .hes — header and M3U route

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

## .kss — info-only header route

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

## .nsfe — chunk route

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

## .nsf and .gbs — fixed-header route

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
