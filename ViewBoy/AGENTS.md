# AGENTS

Read this file, then `ai/AGENTS.md`, then `ai/project-info.md`, then the narrow
subsystem note routed by the task.

ViewBoy is a maintained app package inside the VGMMan monorepo. Run Git
commands from the VGMMan root; do not create a nested repository or edit
SPCBoyWK as part of ViewBoy work.

Keep ViewBoy's app identity, WebKit presentation, Metal overlay, and settings
local to this app. Use CatalogReader for read-only catalogs, FrontendCore for
shared frontend policy and archive materialization, and VGMBoy for decoding
and playback. Preserve the inherited `SPCBoyWK` JavaScript dispatcher as a
compatibility boundary until an explicit bridge migration is designed.

`launch.sh` must clean-build and package before each launch. Verify renderer
contracts and the packaged app after changes that affect the host boundary.
