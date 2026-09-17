# Family Verification

## Scope

`scripts/verify-family.sh` inventories the VGMMan Git repository and checks its
ten maintained Swift packages/apps: CatalogReader, VGMBoy, FrontendCore,
MetaMan, UACMan, UACMan/Wrapper, ScanSong, CocoaSpice, SPCBoyWK, and ViewBoy.
It also runs UACWrapper’s Python CLI tests and both active WebKit renderers’
syntax and transport suites. Archived Electron source under `SPCBoy/` is
recovery-only and is excluded from routine builds.

The checker records branch and dirty state, Git archive refs, toolchain details,
commands, durations, and full logs. It does not stage, commit, stash, reset, or
change Git configuration.

## Current evidence — 2026-09-16

A full family run completed at `/private/tmp/vgmman-doc-cleanup-verification`.
The dependency builder passed. Package suites passed for CatalogReader (25),
FrontendCore (84), MetaMan (148), UACWrapper Swift (18), UACMan (15), ScanSong
(148), and CocoaSpice (58). SPCBoyWK built and its JavaScript syntax and
renderer/transport checks passed (65 tests). ViewBoy built and packaged with
`./build.sh`; its JavaScript syntax checks passed and its renderer/transport
suite passed all 22 tests. The UACWrapper Python suite also passed all five
tests in a targeted run.

VGMBoy is the only failing package check: 68 of 72 tests passed. The four
issues are in two AudioToolbox/live-transport integration tests: AAC export
returned `.audioToolbox(1718449215)`, and the transport test could not start or
resume playback. The unit and other package suites are green. Recheck these
integration paths on a host with a working audio output and AAC encoder before
calling the full family suite green.

Boundary checks around the same work:

- ScanSong’s release product built in an isolated build directory, its current
  app bundle passed strict code-signature verification, and its running UI
  showed the selected schema-23 catalog with 13 paths and 530,403 tracks. No
  second instance or scan was started.
- LaunchPad’s `./launch.sh` build completed. Its 16 configured rows have valid
  field counts, project directories, and local build-script paths. The
  refreshed process launched, but accessibility inspection of its new window
  timed out; the app-row click path was therefore not revalidated after the
  config change.
- The packaged ViewBoy window opened and rendered its library, navigation, and
  playback controls. It had no selected catalog or live playback fixture.
- The family documentation link check resolved all 421 local Markdown links
  outside vendored dependency documentation; no broken links remained.

## Commands

```sh
./scripts/verify-family.sh
./scripts/verify-family.sh --inventory-only
./scripts/verify-family.sh --output-dir /private/tmp/vgmman-family-evidence
```

The default evidence directory is a new private temporary directory. If the
Swift user cache is unavailable, use a writable task-local module/cache path:

```sh
mkdir -p .build/verification-module-cache .build/verification-cache
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/verification-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/verification-module-cache" \
XDG_CACHE_HOME="$PWD/.build/verification-cache" \
  ./scripts/verify-family.sh
```

## Evidence levels

- **Contract:** focused tests cover shared policies, typed bridge codecs, and
  renderer behavior.
- **Package:** builds and test suites cover participating code, subject to
  host-dependent integration failures above.
- **Packaged UI:** a newly built app starts and reaches a visible interface.
- **Live fixture:** a real catalog/source crosses the relevant archive,
  decoder, and playback boundary to the stated result.

Keep fixture paths, UI actions, and hardware limitations explicit. Missing
fixtures, unavailable host hardware, signing trust, or automation limits remain
evidence gaps rather than source guarantees.
