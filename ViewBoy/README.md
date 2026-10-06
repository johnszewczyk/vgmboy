# ViewBoy

ViewBoy is the VGMMan family's native macOS player with a screen-first Yoga LCD interface. Its semantic four-shade framebuffer supports Direct, 8-step, and 16-step grayscale output, reads the shared catalog, and sends playback through VGMBoy. AppKit and WebKit host the screen and native bridge; CatalogReader, FrontendCore, and VGMBoy retain their shared responsibilities. This directory is the active ViewBoy source. The `SPCBoyWK/` app is separate, and archives under `LocalRecovery/ViewBoy/` are historical.

Run `./launch.sh` from this directory to clean-build, package, and open `.build/ViewBoy.app`. The edge-to-edge LCD screen has equal square sidebar icons for Library, Path, Favorites, History, Fold/Unfold Tree, and Options; it also has a metadata track table, playlist tabs, a four-step startup screen, and transport controls. Double-click or press Enter on a track to play; Space toggles playback. Options includes database reload and archive-cache controls. Playback Queue, Path, Console, and Disk Path are available from the View menu. Command-1…9 select playlist tabs; Command-Shift-F opens Favorites and Command-Shift-H opens History as ordinary tabs; Command-comma toggles Options; Command-W closes the active playlist tab.

`node --test Tests/YogaCanvas.test.mjs` exercises the canvas module with the real Yoga runtime and a simulated native catalog/playback bridge.

Read `AGENTS.md`, then `ai/project-info.md` for the implementation routes and current behavior.
