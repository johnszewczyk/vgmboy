# Project Info

## Product

SPCBOY SB2 is the current WebKit SPCBOY frontend under development, superseding
retired SPCBoyWK. It shares catalog and playback contracts with the VGMMan
family while keeping its app identity, preference namespace, archive cache,
and renderer distinct.

## Major Components

- The pixel-style home, playlist tabs, WebKit renderer, native host adapter,
  and app-local presentation state belong to SB2.
- CatalogReader owns read-only library access and browser projections.
- FrontendCore owns shared archive, favorite, preference, queue, transport,
  and startup-progress policies.
- VGMBoy owns format admission, decoding, timing, and audio output.
- ScanSong remains the only catalog writer.

## Task Routing

- Home and playlist behavior: `subsystem-human/home.md`
- Sidebar actions and Gallery projection lifecycle: `subsystem-agent/sidebar-actions.md`
- Selection and hover motion: `subsystem-agent/selection-animation.md`
- Options behavior: `subsystem-human/options.md`
- Startup progress ownership: `subsystem-agent/startup-experience.md`
- Swift package and app bundle: `Package.swift`, `Sources/SB2/`
- WebKit presentation and host adaptation: `Sources/SB2/Resources/`, `Sources/SB2/`

## Local Rules

- Keep the pixel-style home controls compact: transport fills the first sidebar
  toolbar, while search shares its row with square library-view, Gallery,
  History, Favorites, and expand/collapse controls. The bottom sidebar status bar
  reports catalog totals.
- Keep SPCBOY-owned Database, Interface, and Windows options separate from
  VGMBoy-owned Playback, Routing, Audio, and Diagnostics options.
- The progress slider is hidden in this skin. Other frontends keep their own
  approved controls and layouts.
- Preserve independent SB2 bundle identity, preference namespace, archive
  cache, and renderer.

## Human Docs

- `subsystem-human/home.md` records the implemented home behavior.
- `subsystem-human/options.md` records options ownership and current behavior.
- `README.md` documents standalone build and launch commands.
