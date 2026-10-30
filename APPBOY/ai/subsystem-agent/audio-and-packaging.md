# Audio Engine and Sideload Packaging

## Scope

Background audio session lifecycle, generation-fenced `AVAudioEngine` processing
(10-band EQ, Mono downmix, seamless Long Play looping, End Fade Out, and
pitch-preserving Playback Speed) with `AVPlayer` remote stream fallback, system
Now Playing / Remote Command integration, and standalone iOS `.app` / `.ipa`
build packaging.

## Ownership

- `AppBoyPlaybackCoordinator.swift` owns `AVAudioSession`, the local/synthesized
  `AVAudioEngine` graph (`AVAudioPlayerNode` → `AVAudioUnitTimePitch` →
  `AVAudioUnitEQ(numberOfBands: 10)` → `mainMixerNode`), the `AVPlayer` fallback
  for remote HTTP(S) streams, periodic progress observation,
  interruption/route-change/configuration recovery, `MPNowPlayingInfoCenter`,
  and `MPRemoteCommandCenter`.
- `AppBoyChiptuneSynth.swift` owns deterministic stereo `44.1 kHz` 16-bit PCM
  WAV loop synthesis for `synth://` starter catalog URIs so all 10 EQ bands up
  to `16 kHz`, Mono downmix, seamless Long Play looping, scrubbing, background
  audio, and lock-screen transport work without external servers or fixtures.
- `Package.swift`, `app-info.plist`, `app-icon.png`, and `build.sh` own SwiftPM
  cross-compilation (`iphoneos` and `iphonesimulator`), bundle assembly, code
  signing, and `.ipa` archive generation.

## Invariants

- Configure `AVAudioSession` with category `.playback`, mode `.default`, and
  policy `.longFormAudio`, paired with `UIBackgroundModes = ["audio"]` in
  `app-info.plist`, before starting `AVAudioEngine` or `AVPlayer` so audio
  continues across screen lock and app switching.
- Apply 10 parametric peaking EQ bands at `31, 62, 125, 250, 500, 1k, 2k, 4k,
  8k, 16k` Hz (`-12` to `+12 dB`, `0.5 dB` steps, `1.0` octave bandwidth) with
  non-clipping headroom attenuation `10^(-maxPositiveBoostDB / 20)` on
  `mainMixerNode` combined with `appVolume`.
- Loop local/synthesized PCM frames modulo `fileLengthFrames` when `Long Play`
  is enabled up to `manualPlayTimeSeconds`, applying transitional end-fade gain
  over `fadeOutSeconds` when `fadeOutEnabled` is active, and re-anchoring active
  buffers live when `Long Play`, `Mono`, or `Fade Out` settings change mid-track.
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
