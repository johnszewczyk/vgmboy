# AGENTS

Read this file, then `ai/AGENTS.md`, then `ai/project-info.md`, then the narrow
subsystem note routed by the task.

ViewBoy is a maintained app package inside the VGMMan monorepo. Run Git
commands from the VGMMan root; do not create a nested repository or edit the
archived SPCBoyWK snapshot as part of ViewBoy work.

ViewBoy owns the screen-first Yoga LCD interface, its bitmap fonts and
framebuffer, the AppKit/WebKit host, and its settings. All ViewBoy presentation
work belongs under this directory. SPCBoyWK's local archive and
`LocalRecovery/ViewBoy/` historical archives are not current source. Use
ViewBoy's native bridge and preference types; do not route work based on stale
`SPCBoyWK` identifiers in older builds.

Use CatalogReader for read-only catalogs, FrontendCore for shared frontend and
archive-cache policy, and VGMBoy for playback-source preparation, decoding,
and playback.

`launch.sh` must clean-build and package before each launch. Verify renderer
contracts and the packaged app after changes that affect the host boundary.
