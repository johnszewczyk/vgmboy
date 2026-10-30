# Project Info

## Product

APPBOY is the responsive iOS player package in the VGMMan family. It brings
SPCBOY SB2's pixel-style theme, monospace chrome, selection motion, and trusted
`WKWebView` bridge to iPhone and iPad devices as a standalone sideloadable iOS
app with native background audio and lock-screen media controls.

## Major Components

- [`../Package.swift`](../Package.swift) and [`../Sources/APPBOY/`](../Sources/APPBOY/)
  own the UIKit/WebKit application host, content trust policy, typed native
  request/event bridge, local persistence, catalog/stream adapter seam, and
  `AVPlayer` / `MediaPlayer` playback coordinator.
- [`../Sources/APPBOY/Resources/WebUI/`](../Sources/APPBOY/Resources/WebUI/)
  owns the responsive mobile/tablet WebKit presentation derived from SB2's
  visual tokens and portable `sb-presentation.{css,js}` primitives.
- [`../build.sh`](../build.sh), [`../app-info.plist`](../app-info.plist), and
  [`../app-icon.png`](../app-icon.png) own iOS device/simulator compilation,
  ad-hoc or identity signing, and sideload `.ipa` packaging.

## Task Routing

- Responsive mobile/tablet layout, navigation, and options behavior:
  [subsystem-human/mobile-ui.md](subsystem-human/mobile-ui.md)
- UIKit container, WebKit content trust, native bridge, and state persistence:
  [subsystem-agent/host-and-bridge.md](subsystem-agent/host-and-bridge.md)
- Background audio session, remote transport, and sideload `.ipa` build:
  [subsystem-agent/audio-and-packaging.md](subsystem-agent/audio-and-packaging.md)
- Overhauled architecture critique and instantiation plan:
  [plans/appboy-architecture-and-build-plan.md](plans/appboy-architecture-and-build-plan.md)
- Build and packaging verification record:
  [verification/sideload-build.md](verification/sideload-build.md)

## Local Rules

- Retain SB2's obsidian/charcoal/cyan palette, monospace tabular hierarchy,
  crisp `1px` structural chrome, shared selector motion, and top-down Options
  sheet while designing natively for touch and responsive iOS viewports.
- Do not clone SBONLINE Django templates, hosted social/account navigation, or
  the `SBONLINE/prototypes/mobile/` rounded-card mock, and do not dump SB2's
  desktop macOS window/Finder/path-picker codebase verbatim onto mobile.
- Preserve independent APPBOY bundle identity (`com.john.spcboy.appboy`),
  preference storage, and sideload packaging without modifying macOS-only
  sibling packages unless cross-package scope is explicitly requested.
- Run Git commands from the VGMMan family root (`../`).

## Human Docs

- [subsystem-human/mobile-ui.md](subsystem-human/mobile-ui.md) records the
  implemented iPhone and iPad interface behavior.
- [`../README.md`](../README.md) documents standalone build and sideload
  packaging commands.
