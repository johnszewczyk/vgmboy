# Playback and transport

SPCBoy WK obtains transport state, elapsed position, decoder statistics, and reached-end state
from the in-process VGMBoy bridge. While a track is playing, the frontend polls that state so the
elapsed/track/playlist readout stays current and the next playlist item can begin when playback
ends. Playback timing remains owned by VGMBoy; SPCBoy owns queue order and presentation.

Starting a track sends one native playback intent. The native bridge materializes archive members,
applies shared timing, loads and seeks VGMBoy, and starts playback before returning the first
status snapshot. The WebKit layer does not run a second archive, decoder, or metadata-hydration
task.

Pause/resume and seek operate on the already-loaded VGMBoy session through the shared `play` and
`seek` control commands. They do not reload the file, rematerialize an archive, or recompute the
track's timing window. The frontend generation guard still discards a late status response from
an older UI transition.

Queued adjacent-track fade eligibility and duration come from the shared
`FrontendCore.PlaybackTransportCore.PlaybackFadePolicy`; the native bridge projects that result
to WebKit. VGMBoy still performs the actual output-gain ramp.

Playlist replacement, seek, and other interrupting transport actions cancel a pending queued fade
and restore the shared output envelope before continuing. Delayed SPCBoy WK fade callbacks also
compare the VGMBoy session generation before advancing, so an old fade cannot select a track from
a newer playlist.

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

The displayed track length and the native playback window use the same effective
timing plan. Changing Long Play or its target updates both together.

Tracks without decoder-provided timing, including SID music, use the VGMBoy
safety window of 2:30 plus the configured fade unless Long Play is enabled.

The root window's sidebar divider is draggable. Its persisted width is also available from the
appearance settings controls, and the divider supports keyboard adjustment when focused.
