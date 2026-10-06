# AGENTS

In the `Code/` workspace, start with `../DocMan/AGENTS.md` and
`../DocMan/project-info.md`, then follow the VGMMan family route through
`../AGENTS.md` and `../project-info.md`.

Read `ai/AGENTS.md`, `ai/project-info.md`, and the focused display note before
editing the renderer. LineBoy lives in the VGMMan family Git repository; run
Git commands from the family root and do not create a nested repository.

LineBoy owns its monochrome screen layout, 8×16 font, WebGL2 beam pass, WebKit
presentation bridge, and app build/launch scripts. The HTML owns presentation;
the Swift bridge routes catalog reads through CatalogReader, favorites and
queue policy through FrontendCore, and playback through VGMBoy. LineBoy is a
standalone app, not a ViewBoy renderer mode.

Build the native app and static preview with `./LineBoy/build.sh`; launch the
fresh native app with `./LineBoy/launch.sh`. The browser preview in `.build/site`
uses sample data only. Neither host changes the selected raster or screen grid.
