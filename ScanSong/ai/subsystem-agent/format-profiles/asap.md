# Format profile: `asap`

Parent playback plugin: `asap`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .sap — header, track, and timing facts

`.sap` uses `sap-direct` and `SAPMetadataReader` in MetaManCore; ScanSong does
not invoke a playback core. Starting after the five-byte `SAP\r\n` signature,
the reader walks CR/LF directive lines to the first `FF FF` binary-data marker,
validates ASAP-supported player types B/C/D/S, up to 32 declared songs and
TIME hints, and bounded numeric fields, and retains the exact header and
ordered directives—including unknown keys. `SONGS` defaults to one. `NAME`
and `AUTHOR` become game and author; the system is `Atari XL`. SAP `DATE`
remains available as a source fact and is not mapped into the catalog comment.
VGMBoy routes `.sap` playback through ASAP because the installed libgme 0.6.5
does not play TYPE D or TYPE S. Detailed parser offsets/layouts are in MetaMan's
[format layout map](../../../../VGMManDocs/Docs/md/MetaMan/format-layouts.md).

The reader retains one `TIME` hint per corresponding subsong. The [SAP format
specification](https://asap.sourceforge.net/sap-format.html) defines a plain
`TIME` as finite duration and `TIME … LOOP` as the point where looping begins.
ScanSong therefore maps plain time to `play_length_ms`, loop-start time to
`intro_length_ms`, leaves unknown loop length and fade at -1, and keeps the
150-second playback fallback for loop-marked or missing timing. This adds
header-authored timing that the previous libgme info-only route did not expose;
it does not infer loop length or a finite end for an indefinitely looping song.

The local ASMA tests cover all 6,335 SAP sources. ScanSong produced metadata
for all 6,335, and its projection matches libgme on the 5,577 files that
libgme accepts. The full catalog projection discovered and scanned 6,336
sources: all 6,335 SAP files produced 8,347 SAP track rows (8,347 tracks
total), with zero source failures and one skipped archive member. The remaining
758 SAP files are TYPE D/S; the separate
VGMBoy fixture test confirms non-silent PCM for B, C, D, and S samples through
ASAP, and verifies track selection plus final-track rendering for a 32-song SAP.

The opt-in cross-format catalog fixture verifies persisted track indexes/counts
for a SID archive member (2), GBS archive member (19), AY file (3), compressed
SNDH (12), and NSFE source (14). This covers per-source row projection and two
archive-member paths; it does not claim a full scan of the 31 MiB AY collection.
These checks verify catalog projection and decoder PCM, not audio-device output
or subjective musical quality.
