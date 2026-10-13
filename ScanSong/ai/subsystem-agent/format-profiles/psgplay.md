# Format profile: `psgplay`

Parent playback plugin: `psgplay`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .sndh — direct MetaManCore route

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
