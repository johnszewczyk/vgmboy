# Family Verification

## Scope

`scripts/verify-family.sh` records and verifies the exact source combination of
the six independent VGMMan repositories.

## Inventory

Every run records:

- branch, HEAD, upstream, ahead/behind counts, and dirty-file count;
- a SHA-256 hash of the binary tracked patch;
- paths and SHA-256 hashes for untracked regular files without copying them;
- recursive submodule state and its SHA-256 hash;
- macOS, architecture, Xcode, Swift, Homebrew, and relevant formula prefixes.

The default output is a new private temporary directory. Use `--output-dir`
only for an explicit retained evidence location.

## Checks

The default mode runs package checks in dependency order, then builds SPCBoyWK
and runs its JavaScript syntax and renderer/transport tests. Every command,
duration, exit status, and complete log is retained in the result directory.

`--inventory-only` records source and tool state without building or testing.

FrontendCore currently runs with `--no-parallel` as an explicit temporary
workaround. Remove that flag after the default-parallel archive-test lifecycle
is repaired and repeatedly verified.

## Usage

```sh
./scripts/verify-family.sh
./scripts/verify-family.sh --inventory-only
./scripts/verify-family.sh --output-dir /private/tmp/vgmman-release-evidence
```

## Boundary

The verifier does not commit, stash, reset, copy source trees, or change Git
configuration. SwiftPM may update each repository's existing `.build` scratch
directory during verification.

