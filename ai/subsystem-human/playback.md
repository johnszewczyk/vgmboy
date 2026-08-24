# Playback and transport

SPCBoy WK obtains transport state, elapsed position, decoder statistics, and reached-end state
from the in-process VGMBoy bridge. While a track is playing, the frontend polls that state so the
elapsed/track/playlist readout stays current and the next playlist item can begin when playback
ends. Playback timing remains owned by VGMBoy; SPCBoy owns queue order and presentation.

PSF music stored inside an archive plays with its required companion library
files, so archive-backed PlayStation tracks use the same playback path as loose
PSF files.

Selecting a catalog game fills the playlist directly from indexed catalog rows;
it does not rescan the source folders or wait for a second metadata pass.

Selecting catalog files or folders uses the same shared CatalogReader projections
as CocoaSpice. JSON is only the bridge transport; it does not define a second
playlist query implementation.

Long Play is capability-gated by the VGMBoy format registry. Standard audio,
including FLAC, keeps its decoder-reported natural duration even when Long Play
is enabled; loop-capable formats retain the manual Long Play duration.

Tracks without decoder-provided timing, including SID music, use the VGMBoy
safety window of 2:30 plus the configured fade unless Long Play is enabled.

The root window's sidebar divider is draggable. Its persisted width is also available from the
appearance settings controls, and the divider supports keyboard adjustment when focused.
