# Repository Recovery

## Scope

Current Git ownership and recovery boundaries for the VGMMan application
family.

## Ownership

- The VGMMan root is the single Git repository for maintained family source.
  Component directories are package and release boundaries, not nested Git
  repositories or submodules. Run Git commands from the family root.
- Cross-package changes belong in one family-root commit so the checked-in
  package combination stays reviewable.
- `SPCBoy/` is retained Electron recovery source, not the active player target.
  LaunchPad targets `SPCBoyWK/`. CocoaSpice, SPCBoyWK, and ViewBoy remain
  separate app packages with independent identities and presentation.
- Vendored decoder snapshots under `VGMBoy/vendor/` are ordinary tracked files,
  not submodules. Their upstream pins and provenance are documented beside the
  vendor tree.

## Invariants

- `main` is the current family source of truth. Archived component refs are for
  recovery and inspection; do not develop on them.
- Do not initialize child repositories, add package submodules, or push to
  retired component remotes.
- Generated build products, app bundles, local archives, and fixtures are not
  family source. Preserve the ignored local recovery payloads; do not remove
  them during ordinary source cleanup.
- The former standalone component remotes remain untouched. Check for outside
  consumers and links before changing or retiring any of them.

## Verification

Use the family verification procedure in
[`../verification/family.md`](../verification/family.md) for clean-checkout
and evidence boundaries.

## Files

- [`../../AGENTS.md`](../../AGENTS.md)
- [`../../.gitignore`](../../.gitignore)
- [`../../LocalRecovery/README.md`](../../LocalRecovery/README.md)
- [`../../scripts/verify-family.sh`](../../scripts/verify-family.sh)
- [`../../VGMBoy/vendor/PROVENANCE.md`](../../VGMBoy/vendor/PROVENANCE.md)
