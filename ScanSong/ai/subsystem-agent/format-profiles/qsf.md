# Format profile: `qsf`

Parent playback plugin: `qsf`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .qsf and .miniqsf — complete QSF container reader

`qsf-direct` and `qsf-mini-direct` route to MetaManCore's complete QSF reader
and adapt its neutral document to schema 25. It verifies PSF v0x41 (root),
compressed-payload CRCs and bounded zlib streams, validates each QSound data
block against the legacy ROM bounds, and resolves `_lib` through `_lib9`
declared sibling dependencies without starting the Z80/QSound playback core.
Root tags provide title, game, artist, comment, length, and fade; ordered
duplicate/unknown tags and raw header/tag blocks remain available in MetaMan.
Length/fade retain the playback bridge's parsing semantics. Libraries are
validated directly but are not recursively traversed; their tags do not
override the root's metadata. The scanner publishes one QSound track per
source. VGMBoy retains its QSF core for playback.
