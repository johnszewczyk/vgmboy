# VGMMan Monorepo Migration Snapshot

This tree is a source snapshot of the six VGMMan child projects plus the
coordination documents. The child repositories remain untouched beside this
staging tree.

The snapshot excludes local Git metadata, Swift build directories, packaged
applications, Node modules, and source/fixture archives. Vendor source trees
present in the working tree are retained so the imported path reflects the
current software checkout.

The existing VGMBoy remote history is being preserved separately. This
snapshot will first be published on a migration branch; no existing remote
branch is replaced by this operation.
