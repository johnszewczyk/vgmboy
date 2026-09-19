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
- Decoder inputs and their required nested sources are ordinary files in the
  family repository's `vendor/` tree; a fresh family checkout needs no Git
  submodule initialization. Upstream pins, snapshot digests, and known source
  limitations are recorded in `vendor/PROVENANCE.md`.
- The lazyUSF safety patch is tracked at
  `patches/lazyusf2-render-safety.patch`; `scripts/build-lazyusf.sh` applies it
  when preparing the lazyUSF dependency. The dependency input signature
  includes source contents and the patch so edits cannot hide behind a stale
  built product.
- Compiled archives and scanner-plugin outputs belong under VGMBoy's `.build`.
- `build-scanner-plugins.sh` creates `.build/scanner-plugins` before staging
  products, so a clean checkout can build ScanSong without prior output state.
- Its CMake build uses the SDK reported by the active `xcrun`, keeping the
  selected compiler and SDK in sync when the Command Line Tools SDK is newer.
- The MDX scanner handoff is the release `vgmboy-mdx-inspect` product copied to
  `.build/scanner-plugins`; its vendored mdxmini source and compatibility patch
  participate in the scanner input signature.
- The MDX handoff includes the vendored X68000 LZX 0.32/0.42 decoder. It is
  applied inside mdxmini for both playback and inspection, so ScanSong does not
  maintain a second decompressor or rewrite the preserved source library.
- The Amiga scanner handoff is the release `vgmboy-amiga-inspect` product copied
  to `.build/scanner-plugins`; it links the Homebrew UADE runtime and uses the
  same `AmigaFormatManifest` admission source as VGMBoyKit.
- Scanner inspection APIs are split by format. The MDX inspector depends on
  `VGMBoyMDXInspectionCore` plus `VGMBoyCMDX`; the Amiga inspector depends on
  `VGMBoyAmigaInspectionCore` plus `VGMBoyCUADE`. Neither depends on the
  all-decoder `VGMBoyKit` umbrella. The MDX scanner process only confirms that
  mdxmini can open the module and its dependencies; MetaMan owns scan metadata
  and duration. The Amiga inspector continues to return UADE subsongs and
  their metadata.
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
  from VGMBoy. MetaManCore owns direct APE and GSF/miniGSF readers; ScanSong
  retains the specialized QSF/miniQSF reader;
  no Highly Complete or QSF inspector executable is part of the scanner handoff.
  The scanner-plugin builder removes retired QSF and FFmpeg inspector binaries
  from its shared output folder without touching their playback libraries.
  Scanner-plugin preparation builds the two narrow inspector products and the
  vgmstream CLI directly; it no longer invokes `build-dependencies.sh`, so
  playback-only mGBA, QSF, libgme, 2SF, LazyUSF, and Play! are not scanner-build
  prerequisites. The full `build-dependencies.sh` path remains VGMBoy playback
  ownership. ScanSong must not copy a CocoaSpice app resource or invoke a
  CocoaSpice launcher/build entry point.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](../../Package.swift)
- [build-app.sh](../../build-app.sh)
- [build-scanner-plugins.sh](../../scripts/build-scanner-plugins.sh)
- [build-dependencies.sh](../../scripts/build-dependencies.sh)
- [build-psgplay.sh](../../scripts/build-psgplay.sh)
- [stage-aosdk-qsf.sh](../../scripts/stage-aosdk-qsf.sh) and
  [aosdk-qsf-lifecycle.patch](../../patches/aosdk-qsf-lifecycle.patch)
- [plugin-versions.json](../../Docs/plugin-versions.json)
- [audit-plugin-versions.sh](../../scripts/audit-plugin-versions.sh)
- [check-plugin-docs.sh](../../scripts/check-plugin-docs.sh)
