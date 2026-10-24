# Playback

## Formats

- Supported formats: [supported-formats.md](supported-formats.md) lists every supported extension, archive container, and notable compatibility rule.
- Playback is provided by the bundled VGMBoy audio core.

## Playback Controls

- Controls: play, pause, stop, previous, and next.
- Controls: media keys and standard transport commands.
- Controls: Play and Pause are explicit desired states. Repeated Play after an output-device reconnect cannot toggle a resumed track back to Paused.
- Repeat: the toolbar cycles Off, Repeat Playlist, and Repeat Song.
- Controls: rapid previous or next commands use the newest requested track.
- Faded Skip applies to direct playlist activation and Enter as well as Previous and Next. It fades the playing track before starting the selected target; when the setting is off or playback is paused, track activation starts immediately.
- Playback: starts through VGMBoy's shared audio session.
- Track changes: starting or skipping to another track makes a short clean output transition before
  the new track begins. The bundled audio endpoint stays ready between tracks, so CocoaSpice does
  not reopen the macOS device for each selection or pause.
- Archives: supported game-music files can play from ZIP, 7z, LHA, RSN, and UAC (`.uac`) containers. CocoaSpice sends the original archive and member to VGMBoy, whose archive core validates the entry and prepares either that member or its required dependency set. Seekable UAC reads decompress only the frames needed for the selected member; decoder-ready temporary files are separate from the frontend's durable browsing/artwork cache. LHA Amiga entries retain the complete set so UADE can access prefix-led modules and sibling data files.
- Natural completion: the shared transport retires the finished VGMBoy session before starting the resolved target; VGMBoy releases that session's temporary archive source during retirement.
- Database playlists: choosing an item in the sidebar immediately publishes its stored source, archive-member, subtrack, and cached metadata rows. The shared CatalogReader performs the exact Games, source, folder, and path SQLite projections; CocoaSpice does not rescan, inspect, extract, or write the catalog while hydrating that playlist.
- Format-specific decoding, dependency handling, subtrack behavior, and timing are owned by VGMBoy. CocoaSpice passes a direct path or the original archive/member identity, plus the catalog subtrack index; it does not inspect decoder headers or tags.
- Before playback, the transport duration readout uses the selected catalog row's cached timing when available, including PSF `length` and `fade`; it uses the unknown-duration default only when the selected track has no catalog timing.
- PlayStation PSF playback waits for the Play! decoder's sound stream to be ready before it reports playable PCM. Archive-backed sets retain their sibling `.psflib` files, including Resident Evil 2's root and `UNKNOWN/` library layouts.
- AAC conversion remains responsive while it renders. The status bar shows bounded native progress and provides Abort; an incomplete conversion is removed rather than presented as an AAC file.
- Seeking: supports forward and backward movement.
- Audio output: resumes at the current position after an output-device change when playback was active.
- Changing Long Play or its target while a supported track is active reapplies the native loop policy at the current playback position instead of restarting the track.
- Random playback has three toolbar states: off, random selection from the indexed library, and random selection from the current playlist. All three toolbar glyphs are native SF Symbols.
- Random Library queues the requested playback action while a small track-count-weighted library pool loads, so Next and end-of-track advance cannot race an empty asynchronous pool or require hydrating the entire indexed library.
- App Volume and Mono are applied by the bundled VGMBoy core. App Volume attenuates only CocoaSpice playback; Mono averages the rendered left and right channels and outputs that signal to both speakers.
- Main-toolbar Volume opens a slider with twenty 5% detents; the toolbar icon and its popover report the current playback volume.

## Timing

- Long Play: one shared setting for loop-capable game-music decoders, available in Playback Options and from the infinity button beside the main transport controls. Finite audio such as WAV, AIFF, FLAC, MP3, and M4A retains its native duration even when Long Play is on.
- Changing Play Speed for an active libgme or libvgm track updates its tempo-scaled timing window at the current position and preserves its paused or playing state.
- Timing: supports manual duration and fade behavior.
- Tracks without decoder-provided timing, including SID music, use the configurable unknown-length default in the Long Play options area plus the configured end fade unless Long Play is enabled.
- End Fade: the shared six-second end fade is enabled by default and can be disabled in Playback Options.

## Files

- [VGMBoyPlaybackEngine.swift](../../Sources/CocoaSpice/App/VGMBoyPlaybackEngine.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)
