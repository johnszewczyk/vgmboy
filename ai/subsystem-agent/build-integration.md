# Build Integration

## Scope

How VGMBoy owns the shared upstream decoder source, builds the decoder libraries, and supplies
scanner-facing plugins without frontend-local copies.

## Ownership

`Package.swift` links VGMBoy-specific bridge targets and the dependency archives staged under
VGMBoy's `.build/dependencies` directory. CocoaSpice links VGMBoyKit and never its former playback
bridge targets, so a bundled frontend has exactly one copy of every bridge module.
`build-dependencies.sh` owns staging, and `build-scanner-plugins.sh` is the VGMBoy-owned handoff
for ScanSong's external inspection executables.

## Invariants

- VGMBoy bridge module names are VGMBoy-specific to avoid Swift module-map collisions with a host.
- A frontend links VGMBoyKit as its only audio-core product; duplicate native bridge objects are a linker error.
- Never fork an upstream decoder library per frontend.
- The canonical upstream checkout is VGMBoy's `vendor/` garden. CocoaSpice and SPCBoy contain no
  decoder source or decoder build scripts.
- `libvgm`, `lazyusf2`, `Play!`, and `vgmstream` are Git submodules in that garden; a fresh checkout
  must run `git submodule update --init --recursive` before building. The small `2sf2wav`, mGBA,
  and PSFLib source snapshots remain ordinary tracked source because they are not independent
  submodules in the existing app-family checkouts.
- Compiled archives and scanner-plugin outputs belong under VGMBoy's `.build`.
- ScanSong receives the built vgmstream CLI and Highly Complete inspector from VGMBoy; it must not
  copy a CocoaSpice app resource or invoke a CocoaSpice launcher/build entry point.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMBoy/build-app.sh)
- [build-scanner-plugins.sh](/Users/john/Downloads/Code/VGMBoy/scripts/build-scanner-plugins.sh)
- [build-dependencies.sh](/Users/john/Downloads/Code/VGMBoy/scripts/build-dependencies.sh)
