# AGENTS

Read this file, then `project-info.md`, then follow the owning component's
`AGENTS.md` → `ai/AGENTS.md` → `ai/project-info.md` → focused-note route.

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

`SPCBoy/` is archived Electron source, retained for recovery only. The active
player apps are CocoaSpice, SPCBoyWK, and ViewBoy. Keep all three as separate
presentation clients over the shared catalog, frontend, and playback packages;
do not merge one skin into another.
