# LCD and Options Rendering Evidence

## Contract

`node --test ViewBoy/Tests/Sidebar.test.mjs ViewBoy/Tests/Motion.test.mjs ViewBoy/Tests/LCDPanel.test.mjs ViewBoy/Tests/LCDCanvas.test.mjs`
passes nine focused tests. JavaScript syntax checks pass.

- LCD aperture area, dark/inverse tones and saturated endpoints at dot sizes 2-6;
  1 PX boost stays monotonic and retains distinct gutters, including maximum.
- Actual packed ImageData changes without disabling the matrix or changing pitch.
- Contrast drag preview, completion persistence, cancellation and keyboard steps;
  its geometry stays stable across 0-100 percent. Invalid color drafts preserve
  the previous palette.
- Aperture/Font selector columns match and are alphabetical; Queue Random/Repeat
  geometry matches and widths stay bounded. Motion value columns align.
- Contrast, Volume and FPS gauges use the complete content width on their own
  rows. Volume/EQ gestures preview without saving, commit on release, restore on
  cancellation and accept keyboard endpoints. Maximum EQ fills the final track
  pixel; both inner edges stay filled without thumb cutouts. Tick endpoints are
  the outline borders, with only internal notches painted; cancellation clears fill.
- Narrow Standard-font Audio bars remain within the pane and all ten bands use
  matching columns, including the stacked layout at 640 CSS pixels and 4 PX dots.
- SB2's cubic-bezier(0.2, 0, 0, 1) is correctly inverted in time, monotonic and
  bounded. The page selector reaches the expected 60.7% position at a quarter
  duration and paints shade 2 at that moving position in the actual framebuffer.

- Sidebar depth advances one character per unfold and keeps the trailing margin
  independent of depth. Hover preserves the complete filename. Width dragging
  previews without persistence, cancellation restores the starting width, release
  saves the fraction, and double-click restores adaptive width.
- Options headers share fill, position and height. Button Pad changes header and
  control height, UI Gap changes card insets, and Line Gap changes page-link
  spacing. Reset writes 4/4/1 in one update; minimum padding reserves glyphs and
  borders, and cards stay within the content viewport. Header-to-content and
  card gaps equal 2× UI Gap at values 4 and 5. Wide columns use the same factor;
  the PREVIEW row shares the card inset and profile bottom padding is exactly
  1× UI Gap.
- PREVIEW, RENDERING and PALETTE labels remain present. All six rendering/palette
  combinations retain matrix geometry and distinct header/background tones.
  Rendering and palette persist independently; legacy Direct settings migrate.
  One continuous strip paints four semantic tones or all 8/16 grayscale tones.
- Selector, color-input and numeric control groups share the leading field
  column; pane/card titles align left. Numeric value columns retain fixed widths.
- Crowded tabs reserve square bitmap close targets within their tab bounds. The
  framed X is present through its far corner at its centered raster coordinates,
  including fourteen tabs at 840 CSS pixels, 4 PX dots and 3/7/3 spacing. This
  catches the one-dot Yoga child/parent rounding mismatch. Previous/Next bitmap
  chevrons are centered independently of font text spacing.

## Package

`ViewBoy/build.sh` clean-builds and signs the release app. The new `motion.js`
module is explicitly admitted by `ViewBoyResourceSchemeHandler`. Packaged
JavaScript is compared byte-for-byte with source, and
`codesign --verify --deep --strict` verifies the bundle.

## Packaged UI

The clean signed native WKWebView build loads the real catalog and saved
playlists while preserving the user's active Journey tab and Options state.
At the 840-CSS-pixel window with Standard 5x7 text, classic aperture, matrix on,
custom dark/amber colors and saved 3/7/3 spacing:

- Direct/Color retains shaded pane and card headers. Headings align left;
  Preview, Rendering, Palette, BG/Pixel and Contrast numeric controls share the
  leading field column. Aperture, Font, Dot Size and spacing controls follow it.
- Previous and Next use centered mirrored bitmap chevrons. The actual crowded
  tab strip shows centered framed bitmap X icons, with the title budget separate.
- At 4 PX dots, the Volume 100% gauge fills the complete interior; its outline
  supplies endpoint notches. The 31 Hz EQ band reaches +12.0 with fill through
  both inner edges and returns to its original +0.0. EQ remains disabled.
- A native Contrast 100% state also fills completely. Its setting and dot size
  were adjusted by the user during inspection; the agent preserved them.
- The footer remains outside the clipped scrolling Options viewport. Narrow
  rows stack labels above the common numeric controls instead of clipping them.

Optical aperture/matrix invariants and all six rendering/palette combinations
are additionally checked by controlled framebuffer/device-cell tests.

## Limits

Native screenshots establish control geometry and settled pointer/readout
results. The intermediate movement timing and raster position are established by
the controlled Canvas test; this pass does not claim a native high-speed motion
capture or an audible EQ/volume sweep.

The older broad `YogaCanvas.test.mjs` remains unchanged. Its pre-existing default
palette and missing `playlistTabsReduce`/obsolete catalog fixtures are recorded
in the prior commit's evidence. The focused fixture uses the current bridge and
catalog shapes and covers the changed rendering and interaction paths.
