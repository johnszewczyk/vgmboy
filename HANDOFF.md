# VGMBoy — WIP Handoff

Status: **active shared core** — the playback/decoder and scanner-plugin build
boundary for the CocoaSpice/SPCBoy/ScanSong family.
This note hands off current state and next steps. Live verification happened against fixtures
extracted to `/tmp/vgmboy-test/` (not committed); see each section for the file used.

## What works (verified)

- Core owns the macOS audio device (AVAudioEngine + AVAudioSourceNode) and transport
  (`PlaybackSession`), with decoder-authoritative position, seek, long play, tempo, and fade.
- Command line `vgmboy-cli play` and a minimal SwiftUI GUI (`VGMBoy`) are two thin skins.
- Five decoder families, all end-to-end verified:
  - `libgme` — NSF (Deathbots, 22 tracks)
  - `libvgm` — VGZ (Pit Fighter)
  - `vgmstream` — XA (Bloody Roar loop study)
  - `lazyusf` — N64 miniusf (Blast Corps; needs its companion `.usflib` beside it)
  - `playpsf` — PS1 PSF (Resident Evil 3 MAIN00)
- Session fade DSP now real for real-PCM cores (vgmstream/lazyusf/playpsf) via
  `AudioDecoder.appliesFadeInternally` + `PlaybackSession.applyFadeIfNeeded`. This fixed a latent
  bug where "fade" was just extra playtime for non-internal-fade cores.
- USF family is `hasNaturalEnding == false`, so it always gets a capped window and can't run forever.
- Play! PSF uses SPCBoy's computed long play (loop past tagged length only when the window exceeds
  it) plus driver-halt detection.
- 17 tests pass: `swift test --package-path . --disable-sandbox`.

## Known constraints / gotchas

- **Case-insensitive filesystem collision:** the CLI product is `vgmboy-cli`, not `vgmboy`. A
  `vgmboy` (CLI) vs `VGMBoy` (app) name collision silently overwrote one binary (the command-line
  hang). Don't rename back.
- **VGMBoy owns compiled dependency staging.** `scripts/build-dependencies.sh`
  prepares `.build/dependencies` for the Swift package, and
  `scripts/build-scanner-plugins.sh` prepares ScanSong's external inspection
  binaries. The shared upstream source checkout is VGMBoy's `vendor/` garden;
  no CocoaSpice app, source tree, or launcher is a runtime dependency.
- **miniusf and minipsf resolve `_lib` dependency chains** — companion `.usflib`/`.psflib` must be
  beside the file (matches CocoaSpice's complete-archive-set materialization).
- Driver-halt PSF rips end at the halt (no audio) rather than looping silence — intended.

## Next steps

- Scanner-facing vgmstream and Highly Complete inspection products are now
  built through VGMBoy. Remaining decoder breadth and fixture coverage should
  be tracked as explicit format work, not as a repository-ownership migration.
- Equalizer (signal stage in the core output path).
- Export WAV→AAC (from CocoaSpice `AudioExportAAC.swift` via AVAssetWriter).
- `playback-core v1` control-point protocol, then wire parent apps (SPCBoy, CocoaSpice) in.
- MediaScanner remains the sole schema-23 catalog writer. ScanSong consumes
  VGMBoy-built inspection outputs, while VGMBoy remains database-free.

## Repo

- Branch `main`, remote `git@github.com:johnszewczyk/vgmboy.git`.
- Checkpoints: 1 (libgme) → 5 (Play! PSF + session fade). Docs follow the DocMan spec
  (`ai/subsystem-agent/`, `ai/subsystem-human/`, `ai/project-info.md`).
