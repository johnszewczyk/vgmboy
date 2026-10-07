# Project Info

LineBoy is a standalone monochrome player UI in the VGMMan family repository.
It uses a fixed 8×16 text grid and WebGL2 beam pass in a native WebKit app;
the browser build retains sample data for renderer preview.

## Routes

- User-visible raster and interaction behavior: `subsystem-human/display.md`.
- Grid, shader, bridge, and build boundaries: `subsystem-agent/rendering.md`.

## Boundaries

- LineBoy owns its HTML, CSS, JavaScript, font asset, native host, sample
  content, app packaging, and browser preview scripts.
- VGMMan is the Git root. LineBoy is a package folder, not a nested repository.
- Catalog reads route through CatalogReader; favorites, queue rules, and
  playlist-tab persistence route through FrontendCore; decoding and audio
  transport route through VGMBoy.
