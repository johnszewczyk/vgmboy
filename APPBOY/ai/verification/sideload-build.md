# Sideload Build Verification

## Scope

Build inputs, binary/package checks, and evidence boundaries for the `APPBOY`
iOS package (`com.john.spcboy.appboy`).

## Build Inputs

- **Tracked source**: `APPBOY/Package.swift`, `APPBOY/app-info.plist`,
  `APPBOY/app-icon.png`, `APPBOY/build.sh`, `APPBOY/Sources/APPBOY/*.swift`, and
  `APPBOY/Sources/APPBOY/Resources/WebUI/*`.
- **Generated products** (excluded under `.build/`): `.build/APPBOY.app`,
  `.build/APPBOY.ipa`, `.build/APPBOY-Simulator.app`, and SwiftPM/Clang caches.
- **External toolchain**: Xcode 27.1 (`27A9275`), Apple Swift 6.4,
  `iPhoneOS27.1.sdk`, `iPhoneSimulator27.1.sdk`, `sips`, `plutil`, `codesign`,
  `ditto`, and Node.js (`node --check` for script syntax verification).
- **Fixtures / runtime hardware**: Built-in starter VGM catalog and native PCM
  WAV preview synthesizer require no external fixture files; physical iOS device
  or installed Xcode iOS Simulator runtime is required for live UI and audible
  verification.

## Current Evidence Index

| Check | Level | Command / Artifact | Result |
| --- | --- | --- | --- |
| Bundled WebUI JavaScript syntax | Package | `node --check Sources/APPBOY/Resources/WebUI/*.js` | Passed (`sb-presentation.js`, `app-state.js`, `app-playback.js`, `app-ui.js`, `app.js`). |
| iOS device compilation & `.ipa` archive | Package | `./build.sh --target device` → `.build/APPBOY.app`, `.build/APPBOY.ipa` | Passed; `vtool` confirms `LC_BUILD_VERSION` `platform IOS`, `minos 17.0`; `plutil -lint` `OK`; `codesign --verify --deep --strict` valid; clean 31-entry `Payload/APPBOY.app` `.ipa` without `__MACOSX` metadata. |
| iOS Simulator bundle compilation | Package | `./build.sh --target simulator` → `.build/APPBOY-Simulator.app` | Passed; `vtool` confirms `LC_BUILD_VERSION` `platform IOSSIMULATOR`, `minos 17.0`; `codesign --verify --deep --strict` valid. |
| DocMan routing & link integrity | Contract | `node scripts/check-doc-links.js && node scripts/check-doc-paradigm.js` | Passed across repository links and routed `project-info.md` files. |

## Environmental Evidence Gaps

- **Packaged UI** and **Live fixture**: `xcrun simctl list runtimes` reports no
  installed iOS Simulator runtimes on this macOS host, and no physical iOS
  device is attached. Launching `.build/APPBOY-Simulator.app` in Simulator or
  sideloading `.build/APPBOY.ipa` via AltStore, Sideloadly, TrollStore, or Xcode
  onto an iPhone/iPad is required to establish visible safe-area layout and
  audible background/Lock Screen playback on target hardware.
