# ViewBoy Integration

ViewBoy owns its AppKit host, Yoga canvas presentation, in-screen Options page, and preference namespace. CatalogReader supplies read-only game and track projections; FrontendCore supplies queue, archive, preference, and transport contracts; VGMBoy supplies decoding and audio. Keep package dependencies relative to their sibling repositories.

The bundle identifier is `com.john.viewboy`. The injected bridge remains `window.spcBoyWK`, and the macOS menu dispatcher remains `window.SPCBoyWK.dispatch`. The current menus expose only implemented Library, Queue, Settings, Open Path, and transport actions. Playlist tabs and Favorites from the retired interface have not been ported.

`./build.sh` makes a clean release app and signs it. `./launch.sh` then opens that app. Validate the packaged canvas and live catalog/transport at the app boundary; syntax or Swift compilation alone does not establish interactive behavior.
