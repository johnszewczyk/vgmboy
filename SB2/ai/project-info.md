# Project Info

## Product

SPCBOY SB2 is an independent WebKit player frontend under development. It shares catalog and
playback contracts with the VGMMan family while keeping its app identity,
preference namespace, archive cache, and renderer distinct.

## Ownership

- SB2 owns the dense pixel-style home and Options subpage, WebKit rendering,
  native host adapter, and app-local presentation state.
- CatalogReader owns read-only library access and browser projections.
- FrontendCore owns shared archive, favorite, preference, queue, and transport
  policies.
- VGMBoy owns format admission, decoding, timing, and audio output.
- ScanSong remains the only catalog writer.

## Current UI

- Home uses one compact transport/function strip at the top of the sidebar,
  the search field at the bottom of the sidebar, and aligned timing in the
  bottom status bar.
- The title strip identifies SPCBOY, console, album, and CPU usage.
- Options open in the playlist pane as a subpage. SPCBOY-owned database and
  interface sections remain separate from VGMBoy-owned playback, routing,
  audio, and diagnostics sections.
- The progress slider is hidden in this skin. Other frontends keep their own
  approved controls and layouts.

## Build

- `./build.sh` packages the standalone `SPCBOY SB2.app`.
- `SB2_BUILD_DIR` and `SB2_APP_DIR` can route build output to an isolated path.
- `./launch.sh` builds and opens the SB2 app.
