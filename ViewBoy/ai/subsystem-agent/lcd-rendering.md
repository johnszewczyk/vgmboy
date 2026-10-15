# LCD Rendering

## Ownership

`lcd-panel.js` owns the spatial aperture, linear-light tone mixing, and contrast
gain. `yoga-app.js` owns semantic framebuffer drawing, display preferences,
controls, and packed canvas presentation. The native resource scheme explicitly
admits every imported module.

## Invariants

- Framebuffer labels describe ink, muted ink, selection, and substrate. Their
  tone mapping works in both polarities; it must not assume ink is darker.
- Rendering, palette and Contrast Boost never change dot pitch, matrix enablement,
  aperture selection, layout, fonts, hit targets, or native playback state.
- The STN aperture integrates a centered fractional square into each device
  pixel. Its side/pitch ratio is 0.39/0.43, from Displaytech 128128A v1.1 p2.
  This is a standard-component reference, not measured Game Boy geometry.
- Classic aperture preserves the old one-device-pixel right/bottom gutters.
  An explicitly saved matrix-off setting is retained. New installations use
  four-tone LCD mode and an enabled STN aperture.
- Contrast Boost is output gain, not calibrated contrast voltage. Its edge
  adjustment retains a visible matrix and does not modify the coverage mask.
  At zero boost Direct mode retains exact configured ink/substrate endpoints. Classic binary gutters receive up to 65% ink tint as an explicit readability override; their face/gutter distinction survives at maximum boost and saturated endpoints. Zero boost leaves binary coverage exact.
- Tone and coverage math is cached as packed device-cell tables when settings
  change. Full and partial framebuffer updates use those same tables; no
  color-space conversion occurs inside the per-frame device-pixel loop.
- Dot-size, aperture, matrix, color, method, and boost changes invalidate the
  tables before repainting. CSS surface color matches the semantic substrate.
- Options uses one scrolling column of unframed sections at every width. Shaded headers divide sections. Compact controls use the right half and gauges use a whole line. Shared spacing stays in logical dots, with no dialog padding. Library width is adaptive or user-resized; Options keeps compact navigation. Page rows retain four extra dots around glyphs and the shared SB2 timing curve.
- Contrast slider previews without writing preferences until pointerup; pointercancel restores its starting value. Its numeric row reserves the common value width; its separate full-width gauge keeps drag geometry stable across 0-100%. Keyboard focus is active only on Display in Options.

- Rendering and palette persist independently, with migration from the old combined mode. Direct interpolates semantic UI tones in sRGB while LCD mixes reflectance in linear light. Keep both intermediate tones distinct from endpoints when grayscale range provides enough levels; headers must not collapse into BG.

## Evidence and Planning

[Emulation plan](../plans/lcd-emulation.md) separates primary-source facts,
component reference values, readability adjustments, and outstanding calibration.
[Verification](../verification/lcd-rendering.md) records package and UI evidence.

## Files

- `Sources/ViewBoy/Resources/lcd-panel.js`
- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/ViewBoyResourceSchemeHandler.swift`
- `Tests/LCDPanel.test.mjs`
- `Tests/LCDCanvas.test.mjs`
