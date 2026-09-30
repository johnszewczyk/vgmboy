# ViewBoy

ViewBoy is the VGMMan family's native macOS player with a screen-first Yoga LCD interface. Its four-shade canvas reads the shared catalog and sends playback through VGMBoy. AppKit and WebKit host the screen and native bridge; CatalogReader, FrontendCore, and VGMBoy retain their shared responsibilities. This directory is the active ViewBoy source. The `SPCBoyWK/` app is separate, and archives under `LocalRecovery/ViewBoy/` are historical.

Run `./launch.sh` from this directory to clean-build, package, and open `.build/ViewBoy.app`. The single LCD screen has Console and Path sidebar views, a metadata track table, Favorites and Playback History playlists, transport controls, and in-screen Options. Double-click or press Enter on a track to play; Space toggles playback. Options includes database and archive-cache controls. Command-1/2/3 switch Path, Console, and Disk Path views; Command-Shift-D opens Favorites; Command-Shift-H opens History; Command-comma opens Options; Command-W closes the active playlist tab; Command-Option-1…9 select playlist tabs.

`node --test Tests/YogaCanvas.test.mjs` exercises the canvas module with the real Yoga runtime and a simulated native catalog/playback bridge.

Read `AGENTS.md`, then `ai/project-info.md` for the implementation routes and current behavior.
