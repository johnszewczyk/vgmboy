# Frontend parity

LineBoy remains a separate 8×16 DOM/CRT client over CatalogReader, FrontendCore and VGMBoy. Parity means useful shared commands and predictable controls, while preserving its DOS raster and stationary scanline mask. The frontends need not mirror layouts or visuals; keep each pass focused on concrete usability issues.

## Design direction

LineBoy is ViewBoy in high-resolution DOS: retain the 8×16 font, dense lists,
monochrome shading and stationary CRT mask. Use simple curses-style toolbars and
framed tabs. The separate modern graphical mockup remains deferred.

## Implemented

- Framed flexible tabs with reserved pixel close icons, full-name tooltips, active-tab visibility and horizontal strip scrolling.
- Uniform command toolbar, aligned search/tab bands, legible track headings, wider sidebar minimums, and shaded Display sections.
- Shared snappy selector timing.
- Whole-device-pixel glyph advances and uncapped device ratio for mask sizing.
- DOS-aligned AUDIO and PLAYBACK pages use VGMBoy's shared audio, timing, and
  tempo controls; native settings persist across relaunches.

## Next work

1. Audit each profile at normal and high-density scales: font baseline, frame origin phase, scanline alignment, sidebar minimums, clipping and keyboard focus. The grid calculation is not measured CRT hardware calibration.
2. Map command/playlist/queue/favorites behavior against the shared frontend contracts. Keep catalog and playback policy in their owners.
3. Exercise native local-file playback separately from visual sample tests. Enable the live catalog gate only for deliberate catalog integration work; do not mix that proof with sample UI verification.
