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
- **Fixtures / runtime hardware**: Built-in starter VGM catalog and native 16-bit
  PCM WAV preview synthesizer (`AppBoyChiptuneSynth`) require no external fixture
  files; **iPhone 16 Plus** Simulator (`com.apple.CoreSimulator.SimDeviceType.iPhone-16-Plus`,
  `430 × 932 pt` / `1290 × 2796 @3x`) provides live Simulator UI and audio
  verification.

## Current Evidence Index

| Check | Level | Command / Artifact | Result |
| --- | --- | --- | --- |
| Bundled WebUI JavaScript syntax | Package | `node --check Sources/APPBOY/Resources/WebUI/*.js` | Passed (`sb-presentation.js`, `app-state.js`, `app-playback.js`, `app-ui.js`, `app.js`). |
| iOS device compilation & `.ipa` archive | Package | `./build.sh --target device` → `.build/APPBOY.app`, `.build/APPBOY.ipa` | Passed; `vtool` confirms `LC_BUILD_VERSION` `platform IOS`, `minos 17.0`; `plutil -lint` `OK`; `codesign --verify --deep --strict` valid; clean 31-entry `Payload/APPBOY.app` `.ipa` without `__MACOSX` metadata. |
| iOS Simulator bundle & launch | Packaged UI | `./launch.sh` → `iPhone 16 Plus` (`iOS 27.0` `24A434`, `1290 × 2796 @3x`) | Passed; verified Dynamic Island and home-indicator safe-area geometry, clamped `430pt` CSS Grid shell, animated cyan SB2 mode selector, Library console/album tree, Playlist view with `1px` active row underline, and 2-column square Gallery frames. |
| Live PCM WAV synthesis, playback & persistence | Live fixture | `xcrun simctl launch ... com.john.spcboy.appboy --url appboy://play/snes-chrono-t1 --url appboy://view/playlist` | Passed; verified `AppBoyChiptuneSynth` generated `snes-chrono-echoes-t01.wav` and `snes-chrono-echoes-t02.wav` under `tmp/APPBOY-Synth/`, `AVPlayer` advanced live elapsed clocks (`PLAYING 0:22 / 0:24` → natural end auto-advance to track `02 Millennial Fairgrounds`), animated 4-bar play glyph active, and `history.json` + `playlist-tabs.json` persisted under `Application Support/APPBOY/`. |
| DocMan routing & link integrity | Contract | `node scripts/check-doc-links.js && node scripts/check-doc-paradigm.js` | Passed across repository links and routed `project-info.md` files. |

## Environmental Evidence Gaps

- **Physical iOS hardware sideload**: Simulator verification is complete on
  `iPhone 16 Plus` (`iOS 27.0`), while physical-device installation of
  `.build/APPBOY.ipa` (via AltStore, Sideloadly, TrollStore, or Xcode Devices) and
  physical hardware Lock Screen / Bluetooth route interruption checks require an
  attached iPhone or iPad.
