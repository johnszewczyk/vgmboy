# Project Info

## Product

APPBOY is the responsive iOS player package in the VGMMan family. It mirrors
SPCBOY SB2's compact desktop chrome, obsidian/cyan palette, monospace tabular
hierarchy, selection motion, and trusted `WKWebView` bridge on iPhone Plus and
iPad viewports, directly linking the family's shared Swift cores (`CatalogReader`,
`FrontendCore`, `UACWrapperCore`, and `VGMBoyEmbeddedCore`) with native
background audio and lock-screen media controls.

## Major Components

- [`../Package.swift`](../Package.swift) and [`../Sources/APPBOY/`](../Sources/APPBOY/)
  own the UIKit/WebKit application host, content trust policy, typed native
  request/event bridge, shared family module bridges (`CatalogReader`,
  `FrontendCore`, `UACWrapperCore`, `VGMBoy`), and `AVAudioEngine` /
  `AVPlayer` / `MediaPlayer` playback coordinator.
- [`../Sources/APPBOY/Resources/WebUI/`](../Sources/APPBOY/Resources/WebUI/)
  owns the desktop-coherent responsive WebKit presentation derived from SB2's
  toolbar, search/action strip, playlist/gallery workspace, status bar, Options
  modal, and portable `sb-presentation.{css,js}` primitives. Shared DOM range
  controls come from `../../SharedWebUI/` and are synced into this bundle.
- [`../build.sh`](../build.sh), [`../app-info.plist`](../app-info.plist), and
  [`../app-icon.png`](../app-icon.png) own iOS device/simulator compilation,
  ad-hoc or identity signing, and sideload `.ipa` packaging.

## Task Routing

- Responsive mobile/tablet layout, navigation, and options behavior:
  [subsystem-human/mobile-ui.md](subsystem-human/mobile-ui.md)
- UIKit container, WebKit content trust, native bridge, and family store bridges:
  [subsystem-agent/host-and-bridge.md](subsystem-agent/host-and-bridge.md)
- Embedded `VGMBoyEmbeddedCore` audio engine, remote transport, and `.ipa` build:
  [subsystem-agent/audio-and-packaging.md](subsystem-agent/audio-and-packaging.md)
- Overhauled architecture critique and instantiation plan:
  [plans/appboy-architecture-and-build-plan.md](plans/appboy-architecture-and-build-plan.md)
- Build and packaging verification record:
  [verification/sideload-build.md](verification/sideload-build.md)

## Local Rules

- Mirror SB2 desktop's compact top transport toolbar, search + library action
  strip, equal-width playlist tabs, hidden progress slider rule, grouped
  `SPCBoy` / `VGMBoy` Options modal, and bottom status strip across responsive
  iOS viewports without platform noise labels or redundant mobile tab bars.
- Consume shared family modules (`CatalogReader`, `FrontendCore`,
  `UACWrapperCore`, `VGMBoyEmbeddedCore`, `SharedWebUI`) rather than
  re-implementing catalog queries, favorite/history persistence, UAC readers,
  or decoders inside APPBOY.
- Preserve independent APPBOY bundle identity (`com.john.spcboy.appboy`),
  preference storage, and sideload packaging without regressing macOS sibling
  targets.
- Run Git commands from the VGMMan family root (`../`).

## Human Docs

- [subsystem-human/mobile-ui.md](subsystem-human/mobile-ui.md) records the
  implemented iPhone Plus and iPad interface behavior.
- [`../README.md`](../README.md) documents standalone build and sideload
  packaging commands.
