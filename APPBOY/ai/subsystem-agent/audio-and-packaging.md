# Audio Engine and Sideload Packaging

## Scope

Background audio session lifecycle, generation-fenced `AVAudioEngine` playback
bridging `VGMBoyEmbeddedCore` (`EmbeddedGMEDecoder`, `UACEmbeddedArchiveReader`,
`EmbeddedEqualizerConfiguration`, `EmbeddedPlaybackTempo`) alongside local
`AVAudioFile` and remote `AVPlayer` fallback, system Now Playing / Remote
Command integration, and standalone iOS `.app` / `.ipa` build packaging.

## Ownership

- `AppBoyPlaybackCoordinator.swift` owns `AVAudioSession`, the `AVAudioEngine`
  graph (`AVAudioPlayerNode` → `AVAudioUnitTimePitch` →
  `AVAudioUnitEQ(numberOfBands: 10)` → `mainMixerNode`), real-time multi-buffer
  streaming from `VGMBoyEmbeddedCore.EmbeddedGMEDecoder` (for `.uac` members and
  loose `.spc`/`.nsf`/`.nsfe`/`.gbs`/`.hes`/`.kss`/`.ay`/`.sap`/`.gym` files),
  local PCM file playback, `AVPlayer` fallback for remote HTTP(S) streams, live
  `diagnosticsSnapshot()` telemetry, `MPNowPlayingInfoCenter`, and
  `MPRemoteCommandCenter`.
- `AppBoyChiptuneSynth.swift` owns deterministic stereo `44.1 kHz` 16-bit PCM
  WAV loop synthesis for `synth://` starter catalog URIs so all 10 EQ bands,
  Mono downmix, Long Play looping, `1/32` Playback Speed, background audio, and
  lock-screen transport work out-of-the-box without bundled data packs.
- `Package.swift`, `app-info.plist`, `app-icon.png`, and `build.sh` own SwiftPM
  cross-compilation (`iphoneos` and `iphonesimulator`), bundle assembly, code
  signing, and `.ipa` archive generation.

## Invariants

- Configure `AVAudioSession` with category `.playback`, mode `.default`, and
  policy `.longFormAudio`, paired with `UIBackgroundModes = ["audio"]` in
  `app-info.plist`, before starting `AVAudioEngine` or `AVPlayer` so audio
  continues across screen lock and app switching.
- Share `EmbeddedEqualizerConfiguration` (`31, 62, 125, 250, 500, 1k, 2k, 4k,
  8k, 16k` Hz, `-12` to `+12 dB`, `0.5 dB` steps, non-clipping headroom
  compensation) and `EmbeddedPlaybackTempo` (`1/32` rational steps from `1/2` to
  `2/1`) from `VGMBoyEmbeddedCore`.
- Stamp every `playbackStart` with a monotonically increasing native
  `generation`. Reject `pause`, `resume`, `stop`, `seek`, and completion
  callbacks from superseded generations.
- Pause playback immediately on `.oldDeviceUnavailable` route changes and handle
  `AVAudioSession` interruptions cleanly.
- Keep `app-icon.png` opaque (no alpha channel) and place all build outputs
  under `APPBOY/.build/` so repository working trees stay clean.

## Concurrency

- Isolate `AppBoyPlaybackCoordinator`, `AVPlayer` observers, and
  `MPNowPlayingInfoCenter` mutations to `@MainActor`, running `EmbeddedGMEDecoder`
  chunk rendering on a dedicated serial decode queue fenced by `generation`.

## Failure Boundaries

- Invalid stream URLs, corrupt archives, or unsupported formats publish a
  structured `nativePlaybackState` error snapshot matching the active
  `generation` and reset `MPNowPlayingInfoCenter` playback rate to `0.0`.
- When no Apple Development signing identity is present in Keychain, `build.sh`
  falls back to ad-hoc signing (`codesign --force --sign -`).

## Files

- `Package.swift`
- `app-info.plist`
- `app-icon.png`
- `build.sh`
- `Sources/APPBOY/AppBoyPlaybackCoordinator.swift`
- `Sources/APPBOY/AppBoyChiptuneSynth.swift`
