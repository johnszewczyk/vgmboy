# APPBOY

APPBOY is the responsive iOS player package in the VGMMan family, adapting
SPCBOY SB2's obsidian/cyan pixel-style presentation, monospace tabular chrome,
and trusted native WebKit bridge to iPhone and iPad touch viewports.

## Build and Package

Build the signed iOS `.app` bundle and sideloadable `.ipa` archive (plus optional
Simulator bundle verification):

```sh
./build.sh
```

Useful options and environment overrides:

- `./build.sh --target device` — build `APPBOY.app` and `APPBOY.ipa` for `iphoneos` (`arm64`, default).
- `./build.sh --target simulator` — build `APPBOY-Simulator.app` for `iphonesimulator`.
- `./build.sh --target all` — build both device (`.app` + `.ipa`) and simulator bundles.
- `APPBOY_BUNDLE_IDENTIFIER` — override the default `com.john.spcboy.appboy` bundle identifier.
- `APPBOY_SIGNING_IDENTITY` — sign with a specific Apple Development identity (falls back to ad-hoc `-` for AltStore, Sideloadly, or TrollStore).
- `APPBOY_BUILD_DIR` / `APPBOY_IPA_PATH` — relocate build outputs outside `.build/`.

## Requirements

- macOS with Xcode command-line tools and the iOS SDK (`iphoneos` / `iphonesimulator`, deployment target iOS 17.0+).
- Sideload tool (AltStore, Sideloadly, TrollStore, or Xcode Devices window) to install `.build/APPBOY.ipa` on a physical iPhone or iPad, or an installed Xcode iOS Simulator runtime to launch `.build/APPBOY-Simulator.app`.

See [AGENTS.md](AGENTS.md) and [`ai/project-info.md`](ai/project-info.md) for the
component route.
