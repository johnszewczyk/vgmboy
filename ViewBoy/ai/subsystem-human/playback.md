# Playback and Transport

Selecting a catalog game loads its indexed tracks through `databaseGameTracks`; no source rescan occurs. A single click selects a track, and double-click or Enter starts it. The transport buttons and macOS Playback menu route Previous, Play/Pause, Next, and Stop to the existing native bridge. Native Swift and VGMBoy continue to own archive materialization, format selection, timing, decoding, and audio output.

The Yoga canvas listens for pushed `nativePlaybackState` and `nativePlaybackEnded` events. It displays transport state and current track without polling the decoder. On natural completion, it calls `playbackCompletionRetire` with the active queue and repeat mode. The shared native policy chooses the next track or stops. Playback generation guards prevent a late end event from advancing a newer track.

The first canvas slice exposes Long Play, End Fade, Repeat, Mono, and Volume in Options. Changes persist through the typed native preferences snapshot. Audio controls call `nativePlaybackAudioConfig`; timing controls call `nativePlaybackReconfigure` for a loaded track. Seek, faded skips, playlists tabs, Favorites, and detailed decoder diagnostics have not yet been ported to the canvas. The underlying shared services remain available for later screens.

Opening a local path through the File menu uses native `choosePath`; a chosen folder is projected to its directly playable tracks through `selectFolder`. The canvas currently shows that selection in the Queue page.
