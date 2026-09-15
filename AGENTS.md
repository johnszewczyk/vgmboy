# AGENTS

Read this file, then `project-info.md`, then follow the owning component's
`AGENTS.md` chain.

This directory is the single Git repository for the VGMMan application family.
Component directories are package and release boundaries, not independent Git
repositories. Run Git commands from this root; do not initialize nested repos,
add component submodules, or push component changes to retired child remotes.

Keep changes scoped to the owning package when possible. Cross-component work
belongs in one family-root commit so the checked-in package combination stays
buildable and reviewable. Vendored decoder sources under `VGMBoy/vendor/` are
ordinary files in this repository; do not run submodule initialization.

Preserve component ownership, provenance, and release boundaries. Compilation
alone does not prove packaged, visible, or audible behavior; use the family
verification script and state any live-fixture gaps explicitly.

`SPCBoy/` is the archived Electron frontend, retained as source/history only;
do not treat it as an active app target or add it to the maintained test matrix
without an explicit request.
