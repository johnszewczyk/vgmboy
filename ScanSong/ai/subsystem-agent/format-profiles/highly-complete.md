# Format profile: `highly-complete`

Parent playback plugin: `highly-complete`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .gsf and .minigsf — complete GSF container reader

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
