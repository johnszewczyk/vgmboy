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
  pixel; tick endpoints match the true track bounds; cancellation clears fill.
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
  palette preview shares the card inset and profile bottom padding is exactly
  1× UI Gap.

## Package

`ViewBoy/build.sh` clean-builds and signs the release app. The new `motion.js`
module is explicitly admitted by `ViewBoyResourceSchemeHandler`. Packaged
JavaScript is compared byte-for-byte with source, and
`codesign --verify --deep --strict` verifies the bundle.

## Packaged UI

The native WKWebView app loads its catalog and saved playlist and reaches path
index readiness while Options remains open. At the native 840-CSS-pixel-wide
window, Standard 5x7 text and 3 PX dots:

- Display shows adjacent matching Aperture/Font selectors, bounded BG/PIXEL
  fields, aligned stepper/readout columns and a full-width Contrast gauge.
  Dragging Contrast from 0 to 100 changes the readout and fills the whole track;
  the selected classic 1 PX matrix remains visible. Zero was restored afterward.
- The shaded sidebar marker follows the selected page. Queue Random and Repeat
  have matching bounded rows instead of stretched buttons. Audio and Queue remain
  separate pages in the existing native shell.
- Audio shows Volume on two rows. A native drag to 50% produces matching half
  fill and readout. Volume returns to its original 100% setting.
- The 31 Hz EQ band reaches +12.0 with full fill through the final tick and returns
  to its original +0.0. The other nine bands retain identical columns and zeros;
  EQ enablement is unchanged.
- Motion shows aligned duration/FPS numeric controls with a separate full-width
  FPS gauge and the persisted 60 FPS readout. The footer stays outside the scroll
  viewport.

- At saved pad/gap/line values 3/4/3, the refined packaged Display page shows
  eight logical dots below pane/card headers and between cards. Palette
  swatches share the other controls' content edges. Preferences were unchanged.
- The packaged app also shows aligned filled OPTIONS/DISPLAY headers.
  Native Button Pad 1→2 and UI Gap 6→7 adjustments visibly resize controls and
  pane/card spacing; the original 1/6/1 values were restored.
- Unfolding the real 1943 system moves game labels inward by one Standard-font
  character. Dragging the dotted sidebar edge reveals the complete second game
  title and longer system names; double-click returns to adaptive width.

The saved custom purple/green palette, aperture, font and matrix preference were
used for visual inspection. No new hardware calibration claims are made.

## Limits

Native screenshots establish control geometry and settled pointer/readout
results. The intermediate movement timing and raster position are established by
the controlled Canvas test; this pass does not claim a native high-speed motion
capture or an audible EQ/volume sweep.

The older broad `YogaCanvas.test.mjs` remains unchanged. Its pre-existing default
palette and missing `playlistTabsReduce`/obsolete catalog fixtures are recorded
in the prior commit's evidence. The focused fixture uses the current bridge and
catalog shapes and covers the changed rendering and interaction paths.
