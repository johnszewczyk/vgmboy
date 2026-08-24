# Playback Control v1

## Scope

The in-process, versioned control boundary between `VGMBoyKit` and its clients.

`VGMBoyEndpointCore` publishes the platform-neutral endpoint names and
operations for clients that cannot link Swift directly. Native clients may use
the typed `PlaybackControlRequest`; WebKit, Electron, and future Windows hosts
should expose the same endpoint map and translate their transport into those
typed commands rather than inventing frontend-specific playback controls.

## Ownership

VGMBoyKit is bundled with every frontend and owns one decoded audio session, timing, equalizer,
app-volume/mono output state, and transport state. A frontend owns
playlist membership, queue transitions, repeat-one/all/shuffle policy, durable settings, catalog
rows, and macOS Now Playing registration. The CLI is one client of this same boundary.

Options follow the same boundary: catalog paths, sidebar/view state, queue policy, window/theme
state, and frontend preferences belong to the host; decoder-family tempo enablement, playback
mode, play/fade windows, EQ, output volume, mono, and transport diagnostics belong to VGMBoy.
Hosts may arrange those core controls differently in their Options windows, but they must send the
same typed endpoint operations.

## Invariants

- Typed control values declare `version: 1`; they are the primary in-process API values, not
  socket or JSONL messages. The Electron trial adapter is a packaged local child helper because
  Electron cannot link Swift directly; it maps only this same control surface and is neither a
  discoverable service nor a user-selected executable path.
- `PlaybackController` executes `load`, `play`, `pause`, `stop`, `seek`, timing/tempo/EQ,
  volume, mono, output-ramp, and finite AAC export controls. `PlaybackControlSurface` advertises those embedded capabilities so a
  frontend can bind an Options panel without probing private core objects. The core is not located
  or launched by filesystem path.
  changes, and `status`; `subscribe` is its callback-registration API rather than a command, and
  process shutdown stays with the hosting app. There are deliberately no queue, next, previous,
  repeat, shuffle, catalog-write, or playlist-mutation commands.
- `PlaybackStatus.statistics` is the shared diagnostic payload for decoder family, decoder/output
  rates, decoded frames, audible position frames, and tempo. It deliberately excludes title,
  filename, and other frontend “now playing” presentation fields. Device counters remain in
  `PlaybackStatus.diagnostics`.
- `PlaybackTempo` is the shared fraction representation for frontend settings. UI parsing accepts
  decimal or fractional input and snaps it to musical 1/32 increments before the host sends the
  typed `set_tempo` multiplier; decoder-family capability remains owned by `FormatRegistry` and
  currently enables native tempo for libgme and libvgm.
- The equalizer is CocoaSpice-compatible: ten parametric bands at 31, 62, 125, 250, 500, 1k,
  2k, 4k, 8k, and 16k Hz, each constrained to -12...+12 dB. It is applied before the direct
  AudioUnit ring so every decoder sees identical EQ behavior; the transport callback applies only
  the final de-click envelope.
- Decoder header facts stay internal to session setup for subtrack validation and timing. VGMBoy
  never exposes, writes, or looks up frontend playlist or ScanSong catalog metadata.
- `AACExporter` is a separate offline decoder session. It takes a frontend-provided naked playable
  path, subtrack, finite playback window, output folder, and display filename; it writes ADTS AAC
  (`.aac`) without touching the live transport/device or any catalog. VGMBoy sanitizes the stem and
  chooses a non-overwriting collision suffix. A frontend owns its persisted destination preference
  and archive materialization before making this call.
- `PlaybackStructureReader` is the narrow exception for raw disk browsing: it returns only
  subtrack count, index, natural timing, and fade facts. It returns no decoder tags and never
  opens a catalog. The Electron bridge maps it as `player-structure`.
- Events distinguish responses, current status, natural end, and errors. A frontend makes the
  next queue decision after an `ended` event.
- A native frontend links VGMBoyKit as its sole playback implementation. Electron uses the same
  packaged adapter as its required playback engine for every admitted family, including MP2, TAK,
  and legacy Nintendo DS WAV payloads; there is no automatic fallback to a retired SPCBoy player,
  renderer PCM graph, or external decoder process. Catalog and structural inspection remain
  separate read-only services, not alternate playback engines.

## Files

- [PlaybackControlProtocol.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlaybackControlProtocol.swift)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
- [PlaybackController.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlaybackController.swift)
- [VGMBoyEndpointCore.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyEndpointCore/VGMBoyEndpointCore.swift)
