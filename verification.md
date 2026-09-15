# Family Verification

## Scope

`scripts/verify-family.sh` records the state of this single family repository
and checks all eight maintained Swift packages/apps: CatalogReader, VGMBoy,
FrontendCore, MetaMan, UACMan, ScanSong, CocoaSpice, and SPCBoyWK.
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

## Current Known Test Gap

The latest local family run builds all packages and passes CatalogReader,
FrontendCore, MetaMan, UACMan, ScanSong, CocoaSpice, and SPCBoyWK checks. VGMBoy's
suite runs 79 tests but currently reports four issues in two audio-dependent
tests: AAC export returns `.audioToolbox(1718449215)`, and live transport does
not report playing after start/resume (resume is returned as an error). Treat
these as unresolved playback/test failures until they are reproduced and
explained; the rest of the VGMBoy suite passes. The temporary evidence directory
contains the exact command and log for this run.

On this host, set `SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"` when running
the family check: the default Command Line Tools SDK stub is rejected by the
installed linker. Redirect Swift and Clang module caches to a writable
task-local directory if the default user cache is unavailable in the sandbox.

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
