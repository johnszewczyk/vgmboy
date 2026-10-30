# Audio Engine and Sideload Packaging

## Scope

Background audio session lifecycle, generation-fenced `AVPlayer` transport,
system Now Playing / Remote Command integration, and standalone iOS `.app` /
`.ipa` build packaging.

## Ownership

- `AppBoyPlaybackCoordinator.swift` owns `AVAudioSession`, `AVPlayer`, periodic
  progress observation, interruption/route-change recovery,
  `MPNowPlayingInfoCenter`, and `MPRemoteCommandCenter`.
- `AppBoyChiptuneSynth.swift` owns deterministic in-memory PCM WAV synthesis for
  `synth://` starter catalog preview URIs so playback, scrubbing, background
  audio, and lock-screen transport work without external servers or fixtures.
- `Package.swift`, `app-info.plist`, `app-icon.png`, and `build.sh` own SwiftPM
  cross-compilation (`iphoneos` and `iphonesimulator`), bundle assembly, code
  signing, and `.ipa` archive generation.

## Invariants

- Configure `AVAudioSession` with category `.playback`, mode `.default`, and
  policy `.longFormAudio`, paired with `UIBackgroundModes = ["audio"]` in
  `app-info.plist`, before starting `AVPlayer` so audio continues across screen
  lock and app switching.
- Stamp every `playbackStart` with a monotonically increasing native
  `generation`. Reject `pause`, `resume`, `stop`, `seek`, and end-of-item
  notifications from superseded generations so rapid track switching cannot
  corrupt active transport state.
- Pause playback immediately on `.oldDeviceUnavailable` route changes
  (headphone/AirPods disconnect) and handle `AVAudioSession` interruptions,
  resuming only when interruption end carries `.shouldResume` and playback was
  active when interrupted.
- Keep `app-icon.png` and bundled iOS icon PNGs opaque (no alpha channel) to
  satisfy SpringBoard and sideload utilities (AltStore, Sideloadly, TrollStore).
- Place generated SwiftPM caches, `.app` bundles, and `.ipa` archives inside
  `APPBOY/.build/` (or caller-supplied override paths) so repository working
  trees stay clean.

## Concurrency

- Isolate `AppBoyPlaybackCoordinator`, `AVPlayer` observers, and
  `MPNowPlayingInfoCenter` mutations to `@MainActor`. Synthesize `synth://` WAV
  files off blocking UI paths into temporary cache URLs keyed by track ID.

## Failure Boundaries

- Invalid stream URLs or failed `AVPlayerItem` loads publish a structured
  `nativePlaybackState` error snapshot matching the active `generation` and
  reset `MPNowPlayingInfoCenter` playback rate to `0.0` rather than silently
  stalling.
- When no Apple Development signing identity is present in Keychain, `build.sh`
  falls back to ad-hoc signing (`codesign --force --sign -`), which TrollStore
  accepts directly and AltStore/Sideloadly re-sign with the user's Apple ID.

## Files

- `Package.swift`
- `app-info.plist`
- `app-icon.png`
- `build.sh`
- `Sources/APPBOY/AppBoyPlaybackCoordinator.swift`
- `Sources/APPBOY/AppBoyChiptuneSynth.swift`
