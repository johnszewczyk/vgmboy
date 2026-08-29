# VGMBoy — WIP Handoff

Status: **active shared core** — the playback/decoder and scanner-plugin build
boundary for the CocoaSpice/SPCBoy/ScanSong family.
This note hands off current state and next steps. Verification below uses the
repository's local fixture hooks and the JoshW RE2/QSF archives when available;
archive payloads and generated databases are not committed.

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
- The current VGMBoy suite passes 64 tests across 9 suites. ScanSong's suite
  passes 46 tests, including the RE2 PSF archive scan and the QSF archive scan
  when their scanner inspection products are configured.
- RE2 PSF direct decoding produces audio; ScanSong's 75-track PSF archive
  fixture records the expected 43-second play and 10-second fade metadata.
- The RE2 GameCube archive reaches the vgmstream inspector and passes its
  underscore-TXTH alias check when the VGMBoy-built `vgmstream-cli` is supplied.

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
- Scanner tests that invoke external inspectors require those staged products
  through `SCANSONG_VGMSTREAM_CLI`, `SCANSONG_QSF_INSPECT`, or the packaged
  bundle resources. Without them, ScanSong fails explicitly with “required
  adapter unavailable”; it does not flatten a structured format into a false
  single track.
- The current FrontendCore Swift Testing helper can remain resident instead of
  returning results on this host. Its package builds and test discovery works,
  but a clean focused-run result is still outstanding.

## Next steps

- Scanner-facing vgmstream and Highly Complete inspection products are now
  built through VGMBoy. Keep the staged inspector paths part of release
  packaging and continue decoder breadth and fixture coverage as explicit
  format work.
- Equalizer (signal stage in the core output path).
- Export WAV→AAC (from CocoaSpice `AudioExportAAC.swift` via AVAssetWriter).
- Continue playback-core contract cleanup and fixture coverage. CocoaSpice and
  SPCBoy are already wired to the extracted native transport/request boundaries;
  remaining app work belongs in explicit parity or format slices, not initial
  parent-app wiring.
- ScanSong remains the sole schema-23 catalog writer. ScanSong consumes
  VGMBoy-built inspection outputs, while VGMBoy remains database-free.

## Repo

- Branch `main`, remote `git@github.com:johnszewczyk/vgmboy.git`.
- Checkpoints: 1 (libgme) → 5 (Play! PSF + session fade). Docs follow the DocMan spec
  (`ai/subsystem-agent/`, `ai/subsystem-human/`, `ai/project-info.md`).
