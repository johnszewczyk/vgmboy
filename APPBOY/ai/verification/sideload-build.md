# Sideload Build Verification

## Scope

Build inputs, binary/package checks, and evidence boundaries for the `APPBOY`
iOS package (`com.john.spcboy.appboy`).

## Build Inputs

- **Tracked source**: `APPBOY/Package.swift`, `APPBOY/app-info.plist`,
  `APPBOY/app-icon.png`, `APPBOY/build.sh`, `APPBOY/launch.sh`,
  `APPBOY/Sources/APPBOY/*.swift`, and `APPBOY/Sources/APPBOY/Resources/WebUI/*`.
- **Generated products** (excluded under `.build/`): `.build/APPBOY.app`,
  `.build/APPBOY.ipa`, `.build/APPBOY-Simulator.app`, and SwiftPM/Clang caches.
- **External toolchain**: Xcode 27.1 (`27A9275`), Apple Swift 6.4,
  `iPhoneOS27.1.sdk`, `iPhoneSimulator27.1.sdk`, installed iOS 27.0 Simulator
  runtime (`24A434`, `arm64`, `com.apple.CoreSimulator.SimRuntime.iOS-27-0`),
  `sips`, `plutil`, `codesign`, `ditto`, and Node.js (`node --check`).
- **Fixtures / runtime hardware**: Built-in starter VGM catalog and native stereo
  `44.1 kHz` 16-bit PCM WAV loop synthesizer (`AppBoyChiptuneSynth`) require no
  external fixture files; **iPhone 16 Plus** Simulator
  (`com.apple.CoreSimulator.SimDeviceType.iPhone-16-Plus`, `430 × 932 pt` /
  `1290 × 2796 @3x`) provides live Simulator UI and `AVAudioEngine` verification.

## Current Evidence Index

| Check | Level | Command / Artifact | Result |
| --- | --- | --- | --- |
| Bundled WebUI JavaScript syntax | Package | `node --check Sources/APPBOY/Resources/WebUI/*.js` | Passed (`sb-presentation.js`, `app-state.js`, `app-playback.js`, `app-ui.js`, `app.js`). |
| iOS device compilation & `.ipa` archive | Package | `./build.sh --target device` → `.build/APPBOY.app`, `.build/APPBOY.ipa` | Passed; `vtool` confirms `LC_BUILD_VERSION` `platform IOS`, `minos 17.0`; `plutil -lint` `OK`; `codesign --verify --deep --strict` valid; clean `Payload/APPBOY.app` `.ipa` without `__MACOSX` metadata. |
| iOS Simulator UI, equal-width tabs & Options | Packaged UI | `./launch.sh` → `iPhone 16 Plus` (`iOS 27.0` `24A434`, `1290 × 2796 @3x`) | Passed; verified noise-free `SPCBOY` title strip, soundchip-clutter-free Library console tree, equal-width open Playlist tabs (`flex: 1 1 0`), 6 equal-width Options tabs (`Chrome`, `Fonts`, `Gallery`, `Audio`, `Playback`, `Catalog`), 10-band Equalizer UI, and 2-column square Gallery frames. |
| Live `AVAudioEngine` 10-band EQ, Long Play & Speed | Live fixture | `xcrun simctl launch ... com.john.spcboy.appboy --url appboy://play/snes-chrono-echoes-t01 --url appboy://transport/newTab --url appboy://view/playlist` | Passed; verified `AppBoyChiptuneSynth` generated stereo `44.1 kHz` `snes-chrono-echoes-t01-24s.wav` under `tmp/APPBOY-Synth-v2/`, `AVAudioEngine` (`AVAudioPlayerNode` → `AVAudioUnitTimePitch` at `1.25×` → 10-band `AVAudioUnitEQ` with headroom compensation) looped track `01` seamlessly past its `0:24` natural loop into `PLAYING 1:12 / 3:00 / 15:00` under Long Play, and persisted `preferences.json`, `history.json`, and `playlist-tabs.json`. |
| DocMan routing & link integrity | Contract | `node scripts/check-doc-links.js && node scripts/check-doc-paradigm.js` | Passed across repository links and routed `project-info.md` files. |

## Environmental Evidence Gaps

- **Physical iOS hardware sideload**: Simulator verification is complete on
  `iPhone 16 Plus` (`iOS 27.0`), while physical-device installation of
  `.build/APPBOY.ipa` (via AltStore, Sideloadly, TrollStore, or Xcode Devices) and
  physical hardware Lock Screen / Bluetooth route interruption checks require an
  attached iPhone or iPad.
