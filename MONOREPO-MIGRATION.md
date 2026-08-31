# VGMMan Monorepo Migration Snapshot

This tree is a source snapshot of the six VGMMan components plus the
coordination documents. The original child repositories remain untouched beside
this staging tree.

The snapshot excludes local Git metadata, Swift build directories, packaged
applications, Node modules, and source/fixture archives. Vendor source trees
present in the working tree are retained so the imported path reflects the
current software checkout.

The existing VGMBoy remote history is being preserved separately. This
snapshot is published first on a migration branch; no existing remote branch is
replaced by this operation.

The current feature path keeps the six component directories in this single
Git history. Dumper metadata is owned by ScanSong, exposed read-only by
CatalogReader, and rendered by CocoaSpice and SPCBoyWK; no frontend writes or
rescans the catalog.

## Bootstrap and verification

From the repository root, build the native VGMBoy dependency products first:

    ./VGMBoy/scripts/build-dependencies.sh

Then run the family checks. The verifier writes its evidence to a temporary
directory unless `--output-dir` is supplied:

    ./scripts/verify-family.sh

The generated `.build` trees and local archives are intentionally ignored and
are not part of the source snapshot.
