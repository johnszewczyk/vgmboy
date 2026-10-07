# AGENTS

In the `Code/` workspace, start with `../DocMan/AGENTS.md` →
`../DocMan/project-info.md` and the narrow DocMan method routed by the task.
In a standalone checkout, start here. Then read `project-info.md` and the
owning component's `AGENTS.md` → `ai/AGENTS.md` → `ai/project-info.md` →
focused-note route. A direct entry into a component still uses this family
route before source inspection. `ai/verification/family.md` contains the standalone
clean checkout procedure and evidence levels.

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

SPCBoyWK is the maintained SPCBoy player. SPCBOY SB2 is a fourth frontend under
development with its own package and release boundary. LaunchPad has separate
entries for SPCBoyWK, ViewBoy, LineBoy, and VGMManDocs. The active player apps are
CocoaSpice, SPCBoyWK, and ViewBoy; LineBoy remains a separate experimental
player. VGMManDocs owns the published Markdown library and its viewer. Keep
each frontend as a separate presentation client over the shared catalog,
frontend, and playback packages; do not merge one skin into another.

For a ViewBoy task, the active application and UI live in `ViewBoy/`; use its
`README.md` and `AGENTS.md` route and launch with `ViewBoy/launch.sh`. `SPCBoyWK/`
is a separate product, and `LocalRecovery/ViewBoy/` contains historical
archives only. ViewBoy's implementation and launch script are in `ViewBoy/`
regardless of historical bridge names.

For a LineBoy task, use the standalone family subproject at `LineBoy/`, follow
its `AGENTS.md` route, and build/launch with `LineBoy/build.sh` and
`LineBoy/launch.sh`. LineBoy is a separate monochrome line-grid experiment; it
does not use ViewBoy's native host or playback bridge.
