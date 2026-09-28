# AGENTS

Read this file, then `ai/AGENTS.md`, then `ai/project-info.md`, then the narrow
subsystem note routed by the task.

ViewBoy is a maintained app package inside the VGMMan monorepo. Run Git
commands from the VGMMan root; do not create a nested repository or edit
SPCBoyWK as part of ViewBoy work.

ViewBoy owns the screen-first Yoga LCD interface, its bitmap fonts and
framebuffer, the AppKit/WebKit host, and its settings. All ViewBoy presentation
work belongs under this directory. `SPCBoyWK/` is a separate app and is not a
ViewBoy implementation target; `LocalRecovery/ViewBoy/` contains historical
archives, not current source. Use ViewBoy's native bridge and preference
types; do not route work based on stale `SPCBoyWK` identifiers in older builds.

Use CatalogReader for read-only catalogs, FrontendCore for shared frontend
policy and archive materialization, and VGMBoy for decoding and playback.

`launch.sh` must clean-build and package before each launch. Verify renderer
contracts and the packaged app after changes that affect the host boundary.
