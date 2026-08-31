# Playback and transport

SPCBoy WK obtains transport state, elapsed position, decoder statistics, and reached-end state
from the in-process VGMBoy bridge. The native transport pushes bounded status updates while a
track is playing, and the frontend renders those updates; it does not poll the decoder. Natural
completion is delivered as a native end event. Playback timing remains owned by VGMBoy; SPCBoy
owns queue order and presentation.

Natural completion retires the finished native session and advances to the next
queue target when one exists. The completion path waits for that replacement
start, so a finished track does not leave the frontend stopped between songs.

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

Amiga modules in LHA archives use complete-set materialization because UADE
modules can identify their player through a filename prefix and may require
sibling player or sample files. MDX modules use the same shared archive path
with an adjacent PDX bank as dependency data; PDX is not a playlist track.

Selecting a catalog game fills the playlist directly from indexed catalog rows;
it does not rescan the source folders or wait for a second metadata pass.

Selecting catalog files or folders uses the same shared CatalogReader projections
as CocoaSpice. JSON is only the bridge transport; it does not define a second
playlist query implementation.

Command-Shift-D replaces the current playlist with a snapshot of shared Favorites;
it does not change the sidebar mode or trigger a catalog reload.

Long Play is capability-gated by the VGMBoy format registry. Standard audio,
including FLAC, keeps its decoder-reported natural duration even when Long Play
is enabled; loop-capable formats retain the manual Long Play duration.

The displayed track length and the native playback window use the same effective
timing plan. Changing Long Play or its target updates both together. Long Play's
duration accepts any non-negative whole-second value; `0` means unbounded Long
Play, displayed as `∞`, until the decoder reports a real end. It is not rewritten
to an arbitrary minimum or maximum.

Timing changes reconfigure the already-loaded VGMBoy session through the native
bridge, preserving the current position and paused/playing state. The separate
Options WebView relays the shared playback preference snapshot to the main
WebView before this reconfiguration occurs.

Tracks without decoder-provided timing, including SID music, use the persisted
unknown-duration fallback of 2:30 plus the configured fade unless Long Play is
enabled. That fallback is separate from the explicit Long Play value; a zero
Long Play value is not treated as an unknown-duration fallback.

The root window's sidebar divider is draggable. Its persisted width is also available from the
appearance settings controls, and the divider supports keyboard adjustment when focused.
