# Options ownership

## Scope

The stable division between frontend options and the shared VGMBoy control surface.

## Frontend-owned options

- ScanSong catalog path, read-only catalog reload, scan history, and root selection.
- Local-file browser roots, database/sidebar view, playlist columns, queue order, repeat, and
  queued-skip policy.
- Window layout, appearance, fonts, toolbar/menu behavior, keyboard shortcuts, and persistence.
- Frontend presentation such as title, filename, Now Playing, and per-app status text.

## VGMBoy-owned options

- Decoder-family capabilities and exact tempo multiplier.
- Playback mode, play window, authored timing, and fade window.
- Ten-band EQ, output volume, mono output, and transport gain ramps.
- Decoder/output statistics and transport health returned through `PlaybackStatus`.

## Rule

SPCBoy WK and CocoaSpice may expose these controls in different native or WebKit layouts, but
the controls in the VGMBoy-owned group must translate to the same typed commands. A new frontend
should consume the endpoint surface rather than copy either app's Options view. Queue and catalog
behavior cannot be extracted into VGMBoy until it is independent of each frontend's database and
playlist model.

## Files

- [VGMBoyEndpointCore.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyEndpointCore/VGMBoyEndpointCore.swift)
- [PlaybackControlProtocol.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlaybackControlProtocol.swift)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
