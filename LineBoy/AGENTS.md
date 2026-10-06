# AGENTS

In the `Code/` workspace, start with `../DocMan/AGENTS.md` and
`../DocMan/project-info.md`, then follow the VGMMan family route through
`../AGENTS.md` and `../project-info.md`.

Read `ai/AGENTS.md`, `ai/project-info.md`, and the focused display note before
editing the renderer. LineBoy lives in the VGMMan family Git repository; run
Git commands from the family root and do not create a nested repository.

LineBoy owns its monochrome screen layout, 8×16 font, WebGL2 beam pass, static
demo behavior, and local build/launch scripts. It is a standalone browser
experiment, not a ViewBoy renderer mode. It does not access the catalog or
playback engine.

Build the static site with `./LineBoy/build.sh`; launch it with
`./LineBoy/launch.sh`. The launcher serves the built `.build/site` output on
loopback and does not change the selected raster or screen grid.
