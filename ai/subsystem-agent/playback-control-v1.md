# Playback Control v1

## Scope

The in-process, versioned control boundary between `VGMBoyKit` and its clients.

## Ownership

VGMBoyKit is statically bundled into every frontend process and owns one decoded audio session,
timing, equalizer, app-volume/mono output state, and transport state. A frontend owns
playlist membership, queue transitions, repeat-one/all/shuffle policy, durable settings, catalog
rows, and macOS Now Playing registration. The CLI is one client of this same boundary.

## Invariants

- Typed control values declare `version: 1`; they are in-process API values, not socket or JSONL
  messages.
- `PlaybackController` executes `load`, `play`, `pause`, `stop`, `seek`, timing/tempo/EQ,
  volume, and mono controls. `PlaybackControlSurface` advertises those embedded capabilities so a
  frontend can bind an Options panel without probing private core objects. The core is not located
  or launched by filesystem path.
  changes, and `status`; `subscribe` is its callback-registration API rather than a command, and
  process shutdown stays with the hosting app. There are deliberately no queue, next, previous,
  repeat, shuffle, catalog-write, or playlist-mutation commands.
- The equalizer is CocoaSpice-compatible: ten parametric `AVAudioUnitEQ` bands at 31, 62, 125,
  250, 500, 1k, 2k, 4k, 8k, and 16k Hz, each constrained to -12...+12 dB. It lives in VGMBoy's
  output graph, so every decoder sees identical EQ behavior. Its availability must be smoke-tested
  on an audio-capable macOS host.
- Decoder header facts stay internal to session setup for subtrack validation and timing. VGMBoy
  never exposes, writes, or looks up frontend playlist or MediaScanner catalog metadata.
- Events distinguish responses, current status, natural end, and errors. A frontend makes the
  next queue decision after an `ended` event.
- A frontend links VGMBoyKit as its sole playback implementation. Its former bridge targets and
  audio engine are removed in the same migration; duplicate bridge objects are unsupported.

## Files

- [PlaybackControlProtocol.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackControlProtocol.swift)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
- [PlaybackController.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackController.swift)
