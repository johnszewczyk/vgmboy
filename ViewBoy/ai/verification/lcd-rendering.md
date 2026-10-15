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
  matching alignment. Every EQ band now uses a numeric row above a full-width gauge.
- SB2's cubic-bezier(0.2, 0, 0, 1) is correctly inverted in time, monotonic and
  bounded. The page selector reaches the expected 60.7% position at a quarter
  duration and paints shade 2 at that moving position in the actual framebuffer.

- Sidebar depth advances one character per unfold and keeps the trailing margin
  independent of depth. Hover preserves the complete filename. Width dragging
  previews without persistence, cancellation restores the starting width, release
  saves the fraction, and double-click restores adaptive width.
- Options uses unframed shaded sections in one column at every width. Labels
  occupy the left half; compact fields occupy the right half and numeric groups
  align to its trailing edge. Large selectors stack; gauges fill their own line.
  UI Gap sets row spacing; section and header/content gaps use 2× UI Gap.
  Button Pad changes control height; Line Gap changes category spacing.
- PREVIEW, RENDERING and PALETTE labels remain present. All six rendering/palette
  combinations retain matrix geometry and distinct header/background tones.
  Rendering and palette persist independently; legacy Direct settings migrate.
  One continuous strip paints four semantic tones or all 8/16 grayscale tones.
- Selectors and color inputs share the right half. Numeric groups retain fixed
  readout widths. Pane and section titles align left.
- Crowded tabs reserve square bitmap close targets within their tab bounds. The
  five-dot X has a clear surrounding ring inside its seven-dot square frame.
  The icon and square hit target have separate margins from the tab border;
  clicking the target closes its own tab. The frame remains present through its far corner at its centered raster coordinates,
  including fourteen tabs at 840 CSS pixels, 4 PX dots and 3/7/3 spacing. This
  catches the one-dot Yoga child/parent rounding mismatch. Previous/Next bitmap
  chevrons are centered independently of font text spacing.

## Package

`ViewBoy/build.sh` clean-builds and signs the release app. The new `motion.js`
module is explicitly admitted by `ViewBoyResourceSchemeHandler`. Packaged
JavaScript is compared byte-for-byte with source, and
`codesign --verify --deep --strict` verifies the bundle.

## Packaged UI

The previous native pass checked the unframed Display and Audio sections at
840 CSS pixels, Standard 5x7, 4 PX dots, classic aperture and the user's saved
amber colors and 3/7/3 spacing. Headers, right-side fields and full-width Contrast
and Volume gauges were visible; the footer stayed outside the scroll viewport.

The final full-width EQ rows and revised five-dot tab-close icon are covered by
the focused Canvas tests. The rebuilt native package also shows the revised
close icons centered with clear margins in its three-tab library strip. The
fourteen-tab case and close action are checked in the Canvas fixture. Final
full-width EQ rows have not received another native visual pass.

## Limits

Native screenshots establish control geometry and settled pointer/readout
results. The intermediate movement timing and raster position are established by
the controlled Canvas test; this pass does not claim a native high-speed motion
capture or an audible EQ/volume sweep.

The older broad `YogaCanvas.test.mjs` remains unchanged. Its pre-existing default
palette and missing `playlistTabsReduce`/obsolete catalog fixtures are recorded
in the prior commit's evidence. The focused fixture uses the current bridge and
catalog shapes and covers the changed rendering and interaction paths.
