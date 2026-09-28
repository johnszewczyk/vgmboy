# ViewBoy

ViewBoy is the VGMMan family's native macOS Yoga LCD player. Its compact, four-shade canvas front end reads the shared catalog and sends playback through VGMBoy. AppKit and WebKit host the screen and native bridge; CatalogReader, FrontendCore, and VGMBoy retain their shared responsibilities.

Run `./launch.sh` from this directory to build, package, and open `.build/ViewBoy.app`. The current screen has a system/game sidebar, track table, full-width Queue page, transport buttons, and a full-screen Options page. Double-click or press Enter on a track to play; Space toggles playback. Open Path in the File menu loads local tracks.

`node --test Tests/YogaCanvas.test.mjs` exercises the canvas module with the real Yoga runtime and a simulated native catalog/playback bridge.

Read `AGENTS.md`, then `ai/project-info.md` for the implementation routes and current behavior.
