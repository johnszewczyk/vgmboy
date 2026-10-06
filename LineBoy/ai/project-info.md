# Project Info

LineBoy is a standalone browser-based monochrome display experiment in the
VGMMan family repository. It uses a fixed 8×16 text grid, sample local data,
and a WebGL2 scanline pass.

## Routes

- User-visible raster and interaction behavior: `subsystem-human/display.md`.
- Grid, shader, and local build boundaries: `subsystem-agent/rendering.md`.

## Boundaries

- LineBoy owns its HTML, CSS, JavaScript, font asset, sample content, and static
  site scripts.
- VGMMan is the Git root. LineBoy is a package folder, not a nested repository.
- Catalog access and audio playback are not implemented in this experiment.
