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
- Native dependency products are keyed by source revision/diff, build script,
  compatibility patch, compiler, and CMake version. `build-app.sh` removes only
  its clean Swift release directory and app staging directory; it preserves the
  validated dependency products and stamps.
- The vgmstream and QSF scanner executables have a second combined input stamp;
  a warm scanner-plugin build must reuse both products instead of recompiling
  the AOSDK/QSF and vgmstream source trees during every ScanSong package.
- ScanSong receives the built vgmstream CLI and Highly Complete inspector from VGMBoy; it must not
  copy a CocoaSpice app resource or invoke a CocoaSpice launcher/build entry point.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/build-app.sh)
- [build-scanner-plugins.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/build-scanner-plugins.sh)
- [build-dependencies.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/build-dependencies.sh)

## Verification State (2026-08-23)

- Clean VGMBoy and ScanSong app bundles built and passed strict deep signature
  verification. A warm dependency pass reused all seven native products and
  staged copies in 0.6 seconds; the scanner-plugin pair also reused its stamp.
- Archive-backed GameCube playback opened every admitted fixture and rendered
  non-silent PCM. ScanSong's matching inspector/timing fixture passed.
- The isolated AAC export test currently fails at AudioToolbox format setup
  with `fmt?` (`1718449215`). This is a retained playback/export issue, not
  evidence against the GameCube decoder or scanner admission boundary.
