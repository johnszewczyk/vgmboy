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
- `aosdk`, `libvgm`, `lazyusf2`, `Play!`, `vgmstream`, and `psgplay` are Git submodules in that garden; a fresh checkout
  must run `git submodule update --init --recursive` before building. The small `2sf2wav`, mGBA,
  and PSFLib source snapshots remain ordinary tracked source because they are not independent
  submodules in the existing app-family checkouts.
- The lazyUSF safety patch is tracked at
  `patches/lazyusf2-render-safety.patch` and `scripts/build-lazyusf.sh`
  applies it to the checked-out `vendor/lazyusf2` source before building. A
  parent-repository gitlink alone does not contain that source change; the
  dependency script also hashes a gitlink working tree so local source edits
  cannot hide behind a stale dependency product.
- Compiled archives and scanner-plugin outputs belong under VGMBoy's `.build`.
- The MDX scanner handoff is the release `vgmboy-mdx-inspect` product copied to
  `.build/scanner-plugins`; its vendored mdxmini source and compatibility patch
  participate in the scanner input signature.
- The MDX handoff includes the vendored X68000 LZX 0.32/0.42 decoder. It is
  applied inside mdxmini for both playback and inspection, so ScanSong does not
  maintain a second decompressor or rewrite the preserved source library.
- The Amiga scanner handoff is the release `vgmboy-amiga-inspect` product copied
  to `.build/scanner-plugins`; it links the Homebrew UADE runtime and uses the
  same `AmigaFormatManifest` admission source as VGMBoyKit.
- APE is no longer a scanner-helper product. ScanSong reads its native header
  timing and tags directly; `CFFmpeg` remains a VGMBoy playback dependency for
  APE, MP2, and TAK.
- `Docs/plugin-versions.json` is the canonical milestone inventory for every
  decoder/core input. `scripts/audit-plugin-versions.sh` is read-only and
  reports upstream tags, installed Homebrew versions, missing source trees, and
  unpinned snapshots; it never changes a checkout or build product.
- Native dependency products are keyed by source revision/diff, build script,
  compatibility patch, compiler, and CMake version. `build-app.sh` removes only
  its clean Swift release directory and app staging directory; it preserves the
  validated dependency products and stamps.
- The vgmstream scanner executable has a combined input stamp; a warm
  scanner-plugin build must reuse its product instead of recompiling the
  vgmstream source tree during every ScanSong package.
- ScanSong receives the built vgmstream CLI, MDX inspector, and Amiga inspector
  from VGMBoy. ScanSong owns direct APE, GSF/miniGSF, and QSF/miniQSF readers;
  no Highly Complete or QSF inspector executable is part of the scanner handoff.
  The scanner-plugin builder removes retired QSF and FFmpeg inspector binaries
  from its shared output folder without touching their playback libraries.
  The current scanner-plugin script still invokes the broad playback dependency
  builder, so mGBA and the QSF core are prepared as build-time collateral even
  though the scanner does not link or run them. A scanner-only dependency build
  is not yet separated. ScanSong must not copy a CocoaSpice app resource or
  invoke a CocoaSpice launcher/build entry point.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/build-app.sh)
- [build-scanner-plugins.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/build-scanner-plugins.sh)
- [build-dependencies.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/build-dependencies.sh)
- [build-psgplay.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/build-psgplay.sh)
- [stage-aosdk-qsf.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/stage-aosdk-qsf.sh) and
  [aosdk-qsf-lifecycle.patch](/Users/john/Downloads/Code/VGMMan/VGMBoy/patches/aosdk-qsf-lifecycle.patch)
- [plugin-versions.json](/Users/john/Downloads/Code/VGMMan/VGMBoy/Docs/plugin-versions.json)
- [audit-plugin-versions.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/audit-plugin-versions.sh)
- [check-plugin-docs.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/check-plugin-docs.sh)
