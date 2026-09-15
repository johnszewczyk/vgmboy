# Family Verification

## Scope

`scripts/verify-family.sh` records the state of this single family repository
and checks all nine maintained Swift packages/apps: CatalogReader, VGMBoy,
FrontendCore, MetaMan, UACMan, UACMan/Wrapper, ScanSong, CocoaSpice, and
SPCBoyWK. The wrapper has its own package check so the app and consumer
dependencies do not hide a wrapper regression.
The archived Electron source under `SPCBoy/` is retained for recovery but is
not a supported build or release target and is not run by the verifier.

## Inventory

Every run records:

- root branch, HEAD, upstream, ahead/behind counts, and dirty-file count;
- a SHA-256 hash of the binary tracked patch;
- paths and SHA-256 hashes for untracked regular files without copying them;
- the family repository's archived component-history refs;
- submodule state (the family tree currently has no Git submodules);
- macOS, architecture, Xcode, Swift, Homebrew, and relevant formula prefixes.

The default output is a new private temporary directory. Use `--output-dir`
only for an explicit retained evidence location.

## Checks

The default mode first builds VGMBoy's pinned native dependency products, then
runs package checks in dependency order, builds SPCBoyWK, and runs its
JavaScript syntax and renderer/transport tests. Every command,
duration, exit status, and complete log is retained in the result directory.

`--inventory-only` records source and tool state without building or testing.

FrontendCore currently runs with `--no-parallel` as an explicit temporary
workaround. Remove that flag after the default-parallel archive-test lifecycle
is repaired and repeatedly verified.

## Current Package Evidence

- **MetaMan:** the full Debug suite passes all 92 tests, including the complete
  GSF/miniGSF reader and recursive PSFLib-context fixtures.
- **ScanSong:** `ScanSongKit` builds, and all 123 test cases pass from an
  isolated test-only package harness that excludes the app and CLI executables.
  The ordinary `swift test --package-path ScanSong` command still attempts to
  link both executables and fails with unresolved `_ScanSongApp_main` and
  `_scansong_main` symbols (plus a missing `CoreAudioTypes` linker warning).
  This does not invalidate the library build or isolated test result, but the
  app/CLI executable link remains an open gate. A read-only root-1
  XA differential through the production MetaMan-backed scanner route matches
  all 867 catalog rows across 827 files and 18 archives. Running this corpus
  test alongside the timing-sensitive process-runner test once caused that
  unrelated test to exceed its two-second timeout; a clean full-suite rerun
  without the corpus environment passed.
- **UACMan:** `UACMan/Wrapper` passes all 18 Swift tests and 5 Python tests;
  `UACMan` passes all 13 Swift tests. The relocated wrapper/application source
  paths are included in these package checks.
- **UAC integration reference:** a prior synthetic PSID v2 member passed the
  Release MetaMan CLI through `pack` and `pack-source-tree`, then unpack;
  projected metadata survived and source bytes matched exactly.
- **FrontendCore blocked:** both its full suite and a filtered archive-
  materialization test stop before tests while SwiftPM compiles VGMBoy's
  `CHighlyComplete/highlycomplete_bridge.cpp`; the vendored include
  `mgba/flags.h` is missing. No FrontendCore tests ran in this pass.
- **Not freshly verified:** VGMBoy and CocoaSpice full package suites, the
  remaining family verifier checks, and packaged UI/playback. The earlier
  CocoaSpice build report named the same missing mGBA header, but CocoaSpice
  itself was not retried here.

A full family verification was not run; these per-package results do not imply
that the whole family is green.

On this host, `xcrun --sdk macosx --show-sdk-path` currently fails because the
selected Command Line Tools SDK path is missing; SwiftPM resolves the Xcode
26.5 SDK instead. SwiftPM's default user caches are also not writable in this
workspace. Use a writable task-local Clang/Swift module cache and
`--disable-sandbox` when nested SwiftPM sandboxing is denied; these settings
do not bypass the separate ScanSong executable-link issue above.

## Evidence Levels

Verification claims stay explicit:

- **Contract**: focused/package tests prove shared policy, typed bridge codecs,
  and renderer ordering behavior.
- **Package**: the participating targets build and their full suites pass.
- **Packaged UI**: a newly built app launches and visibly reaches the named UI
  state.
- **Live fixture**: a real catalog item or source file crosses the relevant
  catalog/materializer/decoder/transport boundary and reaches the stated user
  result.

Record fixture paths and exact UI actions for the last level. Missing archive
paths, unavailable hardware, code-signing trust, capacity, or an automation
limitation remain evidence gaps, not a source regression. The current
cross-frontend evidence index belongs in `PARITY-WIP-REPORT.md`; extraction
ownership belongs in `WIP-PLAN.md`. Keep these documents current-state only;
Git, not the documentation tree, retains prior runs and investigations.

## Usage

```sh
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" ./scripts/verify-family.sh
./scripts/verify-family.sh --inventory-only
./scripts/verify-family.sh --output-dir /private/tmp/vgmman-release-evidence
```

## Boundary

The verifier does not commit, stash, reset, copy source trees, or change Git
configuration. SwiftPM may update each package's ignored `.build` scratch
directory during verification.
