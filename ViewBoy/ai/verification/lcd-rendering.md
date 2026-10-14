# LCD Rendering Evidence

## Contract

`node --test ViewBoy/Tests/LCDPanel.test.mjs ViewBoy/Tests/LCDCanvas.test.mjs`
passes seven tests. Coverage includes aperture area across device scales 2-6,
black-ink reconstruction with a visible matrix, gain in both polarities,
four-tone ordering, unchanged substrate endpoints, and actual packed ImageData
changes through display controls. Renderer tests preserve matrix and layout
across LCD, Direct, 8 and 16 modes and check stacked card bounds with Standard
5x7 text in a narrow pane. The 1 PX regression checks monotonic boost for saturated black/white at every supported dot size, exact unboosted gutters and visible face/gutter separation at maximum boost. Slider checks cover live pointer preview, completion persistence, cancellation, keyboard steps and fixed geometry across 0-100 percent. Invalid color entry preserves the previous palette; page selection borders clear both bitmap fonts.

`node --check` passes for `yoga-app.js` and `lcd-panel.js`. The component geometry
is checked against Displaytech 128128A v1.1 p2; p9's response table and waveform
definitions were visually inspected separately for the next-stage plan.

## Package

`ViewBoy/build.sh` clean-builds and packages the release app with the LCD module
admitted by `ViewBoyResourceSchemeHandler`. `codesign --verify --deep --strict`
passes. Packaged JavaScript is compared byte-for-byte with source.

## First-Pass Packaged UI

The real WKWebView app loads its native catalog and saved playlist. Its Display
cards stack within the narrow native window instead of squeezing labels and
readouts into two small columns. Native screenshots verify:

- LCD mode, BG `9BBC0F`, PIXEL `000000`, Contrast Boost 40%, dot size 3,
  STN aperture and Pixel Matrix Gaps enabled: black text is visible and matrix
  edges remain present.
- LCD mode with BG `223`, PIXEL `CCC`: light ink, muted ink, selection and
  substrate remain distinct in inverse polarity.
- 8-shade inverse output preserves enabled matrix and STN aperture, with text
  and background selectors following the chosen polarity.
- Relaunch retains Contrast Boost 40%, the enabled matrix and STN aperture.
  That first pass left the app on Display with LCD mode, green substrate and black ink.

## Display Refinement Packaged UI (2026-10-14)

A fresh clean release build, signature verification and byte-for-byte resource
comparison pass. In the native 840-CSS-pixel-wide window, dot size 4 and Standard
5x7 text, the Display cards stack with the compact Options sidebar. Its selection
border clears the text; method labels, inputs, contrast slider, readout and
Interface controls fit their cards. The lower Spacing and Motion cards remain
within the scroll viewport, above the playback footer.

- LCD, BG `9BBC0F`, PIXEL `000000`, grid enabled, aperture 1 PX: native slider
  focus and Home/End show visibly different output at 0 and 100 percent, with
  unchanged cell pitch and a distinct grid at maximum boost.
- LCD, BG `111111`, PIXEL `FFFFFF`, grid enabled, aperture 1 PX, boost 100:
  white pixels and muted/selection tones remain distinct, including gutters.
- The catalog and saved playlist finish restoring in the background while
  Display remains open; the native path index reaches readiness.

Later window settings changed during verification; no further preference
restoration or relaunch was performed. New drag completion/cancel persistence
is covered in the canvas test; this pass does not repeat the native relaunch
check recorded for the first pass.

## Limits

The older broad `YogaCanvas.test.mjs` already fails before this work: it expects
four default tones while the previous renderer defaulted to 16, and its native
bridge fixture lacks `playlistTabsReduce`. Its catalog fixture also predates the
current `{games, groups}` projection. It remains unchanged; repairing unrelated
playlist, catalog and historical layout assertions is separate work. The new
tests exercise the LCD changes with the current bridge shape.

The spatial model is sourced to a standard STN component, not calibrated against
a physical DMG panel. Ghosting, voltage response, angle dependence and aging are
planned rather than claimed as implemented. Native visual evidence establishes
display behavior, not new playback or audio fidelity.
