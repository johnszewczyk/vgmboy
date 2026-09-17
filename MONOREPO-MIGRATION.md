# Repository Model

This is the canonical family-level source tree for VGMMan. All maintained
components live in one Git repository and use one root history. The component
directories remain separate Swift packages and retain their own ownership,
tests, app bundles, build scripts, and release boundaries.

## History

The family tree is maintained on `main` in `johnszewczyk/vgmboy`. Prior
component branches and remote-tracking tips are retained as archival refs named
`archive/<component>/heads/<branch>` and
`archive/<component>/remotes/<remote>/<branch>`. Recoverable unreachable commits
are pinned as `archive/<component>/unreachable/<object-id>`. These refs preserve
old commit histories for recovery and inspection; do not develop on them. The
current family tree is the source of truth.

The retired Electron frontend is stored under `SPCBoy/` without its generated
`node_modules`, `.build`, or `dist` output. Its local and remote branches,
recoverable unreachable commit, and current working-tree source are preserved
in the family tree and `archive/SPCBoy/...` refs. It is archival only; routine
verification covers the native `SPCBoyWK` app instead.

ViewBoy is a separate maintained frontend package, originally forked from the
SPCBoyWK WebKit frontend. Its former standalone Git history is retained at
`archive/ViewBoy/heads/main`; its current source is `ViewBoy/` and its build
output is local-only. Keep it separate from SPCBoyWK: the apps have distinct
bundle identities, preference keys, and presentation while using the shared
family packages.

UACMan had no Git repository when it was brought into the family tree; its
current source and tests are included, but there is no earlier UACMan commit
history to retain. Dirty source from the existing CocoaSpice and FrontendCore
checkouts is represented in the family tree. Build caches and packaged outputs
are local, reproducible artifacts, not source history.

The former standalone GitHub repositories for CocoaSpice, ScanSong, and the
retired Electron SPCBoy remain untouched and unarchived. Their histories are
preserved here, but this family repository's `main` is the only canonical
source of current work. Archive the old remotes only after checking for outside
consumers and links that still depend on those repository URLs.

## Dependency source

`VGMBoy/vendor/` contains the decoder source snapshots needed by the family as
ordinary tracked files, not Git submodules. Upstream locations, pins, license
notes, and snapshot limitations are documented in
`VGMBoy/Docs/plugin-catalog.md`, `VGMBoy/Docs/plugin-versions.json`, and
`VGMBoy/vendor/PROVENANCE.md`. Platform libraries and tools remain external
build prerequisites.

## Exclusions

The root `.gitignore` excludes generated `.build`/`DerivedData` output,
packaged `dist` applications, `node_modules`, local `.git` metadata, `.DS_Store`,
and local ZIP/TAR archives and fixture payloads. These files are not part of
the GitHub source backup. Ignored local archives and fixtures are retained
below `LocalRecovery/`; see `LocalRecovery/README.md` for paths, hashes, and
provenance. The legacy component-checkout staging tree and standalone ViewBoy
checkout are redundant: their tracked history is retained in this repository
and their maintained current sources are checked in here. Do not rebuild those
source trees beside the family repository. Do not remove `LocalRecovery/`
payloads as part of ordinary source cleanup.

## Build and verify

From the repository root, build native decoder products as needed, then run
`./scripts/verify-family.sh`. The verifier writes evidence to a new private
temporary directory unless `--output-dir` is supplied. See `verification.md`
for coverage and evidence limits.
