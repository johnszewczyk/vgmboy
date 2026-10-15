# Frontend parity

LineBoy remains a separate 8×16 DOM/CRT client over CatalogReader, FrontendCore and VGMBoy. Parity means useful shared commands and predictable controls, while preserving its DOS raster and stationary scanline mask. The frontends need not mirror layouts or visuals; keep each pass focused on concrete usability issues.

## First pass

- Readable fixed-cell tabs, full-name tooltips, active-tab visibility and horizontal strip scrolling.
- Shared snappy selector timing.
- Whole-device-pixel glyph advances and uncapped device ratio for mask sizing.

## Next work

1. Apply ViewBoy's simple section headers, left labels, bounded right-side controls and full-width gauges to LineBoy Options. Retain DOS cell alignment.
2. Audit each profile at normal and high-density scales: font baseline, frame origin phase, scanline alignment, sidebar minimums, clipping and keyboard focus. The grid calculation is not measured CRT hardware calibration.
3. Map command/playlist/queue/favorites behavior against the shared frontend contracts. Keep catalog and playback policy in their owners.
4. Exercise native local-file playback separately from visual sample tests. Enable the live catalog gate only for deliberate catalog integration work; do not mix that proof with sample UI verification.
