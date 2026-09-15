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

UACMan had no Git repository when it was brought into the family tree; its
current source and tests are included, but there is no earlier UACMan commit
history to retain. Dirty source from the existing CocoaSpice and FrontendCore
checkouts is represented in the family tree. Build caches and packaged outputs
are local, reproducible artifacts, not source history.

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
the GitHub source backup. The local `SPCBoy-electron.zip` is retained as an
ignored recovery bundle; its current source and Git history are already
represented by `SPCBoy/` and the `archive/SPCBoy/...` refs, while its generated
dependencies and app bundles are intentionally excluded. Never remove local
fixtures or archives as part of repository cleanup without a separate, explicit
request.

## Build and verify

From the repository root, build native decoder products as needed, then run
`./scripts/verify-family.sh`. The verifier writes evidence to a new private
temporary directory unless `--output-dir` is supplied. See `verification.md`
for coverage and evidence limits.
