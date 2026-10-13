# Format profile: `openmpt`

Parent playback plugin: `openmpt`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## OpenMPT module subformats

The registered tracker extensions use one structurally-known row. Recognized
31-sample ProTracker-family MOD headers obtain title/sample metadata from
MetaManCore; other OpenMPT modules and unrecognized MOD dialects remain
metadata-free. ScanSong does not render or convert modules during intake.
Playback compatibility and module-specific duration remain the
libopenmpt/VGMBoy boundary.

## .mod — ProTracker-family admission

`.mod` is recognized through the `openmpt` route, alongside other tracker
modules. For recognized 31-sample ProTracker-family signatures, ScanSong calls
MetaManCore, which validates the bounded order/pattern/sample extents and
returns the module title, ordered named samples, header bytes, and layout
facts. It does not start libopenmpt or enumerate/play patterns. MOD dialects
whose header signatures are not recognized remain one structure-only row with
no metadata; malformed recognized headers fail instead of silently falling
back. Other OpenMPT formats remain structure-only pending their own complete
MetaMan readers. PDX is support data for MDX, not a standalone track format.
