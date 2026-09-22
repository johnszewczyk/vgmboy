# Family Verification

## Scope

`scripts/verify-family.sh` inventories the VGMMan Git repository and checks its
ten maintained Swift packages/apps: CatalogReader, VGMBoy, FrontendCore,
MetaMan, UACMan, UACMan/Wrapper, ScanSong, CocoaSpice, SPCBoyWK, and ViewBoy.
It also checks current documentation links and canonical project-info routing,
UACWrapper's Python CLI, every
active WebKit renderer JavaScript source file, and each renderer's `*.test.js`
suite. Archived Electron source under `SPCBoy/` is recovery-only and excluded
from routine checks.

The checker records branch and dirty state, Git archive refs, toolchain and
external-library versions, commands, durations, and full logs. It allocates
writable SwiftPM, Clang, and XDG caches under its evidence directory unless
the caller supplies other paths. It does not stage, commit, stash, reset, or
change Git configuration.

## Current evidence

The current worktree check included the active ScanSong UI/progress and
documentation changes plus other already-dirty family work. At committed
source revision `5f8e59c3`, a separate detached checkout
without copied build products established the clean-source baseline. Both runs
reached every check using task-local module caches. macOS, Xcode, Homebrew
libraries, and host audio services remain external inputs.

| Boundary | Result |
| --- | --- |
| Vendored dependency preparation | Passed from tracked source. |
| Swift package tests | CatalogReader 26, FrontendCore 84, MetaMan 167, UACWrapper 23, UACMan 25, ScanSong 152, CocoaSpice 59 passed in the current worktree. |
| UACWrapper Python | 26 tests passed. |
| WebKit packages and renderers | SPCBoyWK and ViewBoy builds, checked JavaScript files, and renderer suites passed (82 and 22 tests). |
| VGMBoy | Built; 75 tests ran. AAC export returned `.audioToolbox(1718449215)` and live transport did not start/resume on this host. The same two tests recorded five issues in both runs; the full family command exited nonzero. |
| ScanSong packaged UI | A release app built and launched; it opened the existing default catalog (15 paths, 546,365 tracks). An isolated temporary catalog added one fixture path, scanned six SPC files into six tracks with zero issues, and updated its enabled state. The default catalog selection was restored without scanning or mutating it. |

The two VGMBoy integration paths still need a host with working audio output
and AAC encoding. The ScanSong fixture proves a small native source-to-catalog
path, not responsiveness under a large archive or a live playback boundary.
The documentation link checker covers tracked and newly added maintained
Markdown files, reports optional DocMan workspace links separately, and
excludes archived, recovery, and vendored documents.

## Clean checkout procedure

An isolated Git worktree checks the committed source without inheriting this
checkout's untracked files or `.build` products:

```sh
cd /path/to/VGMMan
git status --short
git rev-parse HEAD
verification_root="$(mktemp -d /private/tmp/vgmman-verification.XXXXXX)"
git worktree add --detach "$verification_root/checkout" HEAD
cd "$verification_root/checkout"
./scripts/verify-family.sh --output-dir "$verification_root/evidence"
```

Review `repositories.tsv`, `toolchain.tsv`, `checks.tsv`, `commands.tsv`, and
the logs before reporting a result. This is a clean source checkout, not a
hermetic or offline build: Xcode/macOS SDK, Homebrew libraries, CMake, Node,
Python, Zstandard, and host audio services remain external inputs. Vendored
decoder source is tracked in `VGMBoy/vendor/`; no submodule initialization or
copied dependency products are required. The source checkout remains separate
from the evidence directory.

## Direct commands

```sh
./scripts/verify-family.sh
./scripts/verify-family.sh --inventory-only
./scripts/verify-family.sh --output-dir /private/tmp/vgmman-family-evidence
```

The default evidence directory is a new private temporary directory. Run
`node scripts/check-doc-links.js` for a documentation-only link check; run
`node scripts/check-doc-paradigm.js` for the active DocMan routing shape; run
`--inventory-only` to record source and toolchain state without building.

## Evidence levels

- **Contract:** focused tests cover shared policies, typed bridge codecs, and
  renderer behavior.
- **Package:** builds and test suites cover participating code, subject to
  the host-dependent integration failures above.
- **Packaged UI:** a newly built app starts and reaches a visible interface.
- **Live fixture:** a real catalog/source crosses the relevant archive,
  decoder, and playback boundary to the stated result.

Keep fixture paths, UI actions, and hardware limitations explicit. Missing
fixtures, unavailable host hardware, signing trust, or automation limits remain
evidence gaps rather than source guarantees.
