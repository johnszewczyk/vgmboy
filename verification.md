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

## Current Package Evidence

- The family check passes CatalogReader (25 tests), FrontendCore (84),
  MetaMan (148), UACWrapper (18 Swift tests), UACMan (15), ScanSong (148), and
  CocoaSpice (58). UACWrapper's separate Python suite also passes all five
  tests.
- **VGMBoy:** the package builds and 68 of 72 tests pass. Four AAC/live-output
  assertions fail because this host has no CoreAudio output device and its
  AudioToolbox AAC path returns `1718449215` (`fmt?`); a separate `afconvert`
  probe fails the same way. The playback code and tests are unchanged here.
  Rerun those integration checks on a Mac with an output device and working
  AAC encoder; this environment cannot establish that boundary.
- **SPCBoyWK:** the Swift package builds; its JavaScript syntax checks and
  renderer/transport tests pass.
- **ScanSong packaged UI:** `ScanSong/build-app.sh` completes a clean release
  build, including the three VGMBoy scanner helpers. LaunchPad's ScanSong row
  then builds and opens the app; the visible window reports schema 23 and the
  existing 530,403-track catalog. No new scan was started for this check.
- **LaunchPad:** its standalone Swift package builds. It is a separate Git
  repository from this family and has no configured remote.
- **Native dependency build:** VGMBoy's dependency build passes. The 2SF
  builder now stages its make copy under `.build` so the tracked vendor archive
  remains unchanged.

The family check exits nonzero on this host because VGMBoy's system-audio
integration checks cannot run here; the other package checks pass. Its evidence
directory and full logs are emitted by `verify-family.sh`.

This host selects Xcode 26.6 and its macOS 26.5 SDK through `xcode-select` and
`xcrun`. The Command Line Tools SDK symlink is newer and must not be mixed with
the selected Xcode linker; the ScanSong CMake build pins the active SDK.
SwiftPM's default cache location is read-only in this workspace, so package
checks need a task-local module and cache directory.

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
mkdir -p .build/verification-module-cache .build/verification-cache
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/verification-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/verification-module-cache" \
XDG_CACHE_HOME="$PWD/.build/verification-cache" \
  ./scripts/verify-family.sh
./scripts/verify-family.sh --inventory-only
./scripts/verify-family.sh --output-dir /private/tmp/vgmman-release-evidence
```

## Boundary

The verifier does not commit, stash, reset, or change Git configuration.
Native builders may copy inputs and write derived dependencies beneath ignored
`.build` directories; maintained source inputs should remain unchanged.
