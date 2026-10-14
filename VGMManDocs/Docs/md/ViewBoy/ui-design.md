# ViewBoy UI Design

ViewBoy renders one responsive LCD pixel grid. Four-tone **LCD** output keeps
its yellow-green substrate and independently controlled ink. **DIRECT**, **8**,
and **16** remain available. Contrast Boost changes optical output while the
matrix, dot pitch, bitmap font, and hit areas remain intact. The surface reaches
every window edge with an eight-dot content inset.

## One Display Page

ViewBoy's Options table of contents has one **Display** page for screen profile,
LCD colors, transport labels, playlist sizing, spacing, window behavior, and
motion. There is no separate Interface page.

Options reuses the home screen shell. The transport toolbar, sidebar pane, and
playback footer remain visible; the playlist area becomes the selected options
page. The sidebar action row remains in place and its rows become grouped
ViewBoy and VGMBoy page links. The adjacent content pane scrolls internally on
long pages. Changing pages or controls keeps Options open; the gear, Escape, or
Command-comma returns to the library using the shared roll transition. Display
uses two columns in wide panes and stacks its cards in narrow panes: the live
LCD palette preview and screen profile sit at left, while one Interface card
groups button labels, column sizing and window behavior, followed by spacing and
motion cards. Each Display section uses a full card with a shared filled title
bar and enclosing outline. Options pane insets, card insets, gaps, and control
padding use a fixed four-dot grid, independent of the adjustable home-screen
spacing. The Options sidebar fits its six icons instead of inheriting the wider
library minimum. Page rows leave room around the bitmap glyphs. One shaded marker glides between
page links, including across the section headings.

In the Path sidebar, root chevron ink shares the leading edge of the search and
toolbar controls. Nested disclosures move inward by two bitmap glyph advances
per depth; folder and file labels share a column at each depth. Chevrons align
vertically with row text.

The main toolbar contains eight equal-width buttons in this order: Previous,
Stop, Play/Pause, Next, Long Play, Repeat One, Playlist Random, and Library
Random. All eight use the same template for width, height, border, and default
text inset. The symbol Previous label `<<` is left-aligned just inside its
border; other labels are centered. The Next symbol remains `>>`. The four mode
controls use the same darker selected fill while active. This state tint is the
expected visual difference from an inactive button.

## LCD Colors

New installations use four-tone **LCD**, BG `#9BBC0F`, PIXEL `#000000`, and an
enabled STN aperture. Saved method and matrix enablement are retained. LCD maps
ink, muted ink, selection and substrate to four distinct tinted levels using
linear-light mixing. Both dark pixels on a light background and light pixels on
a dark background work. DIRECT uses the two endpoint colors; 8 and 16 use
grayscale ramps with independent TEXT SHADE and BG SHADE controls.

**Contrast Boost** ranges from 0 to 100 percent. Drag the slider, use the
minus/plus buttons in five-percent steps, or focus the slider and use arrows in
one-percent steps (Shift: ten); Home and End select the endpoints. Its label, minus/plus buttons and fixed-width readout share the common numeric
row. A full-width framed, filled and ticked gauge sits beneath that row. Dragging previews the change and commits on release; pointer
cancellation restores the previous value. It increases ink separation from the
substrate and the density of partially covered STN edges. In 1 PX mode it also
tints the gutters toward the pixel color, up to 65 percent at maximum boost.
Gutters remain distinct even when PIXEL is fully black or white. This is an
intentional usability adjustment to the optical output; zero boost retains the
exact one-pixel aperture. The coverage mask and dot pitch remain intact. At zero
boost, DIRECT retains exact endpoint colors. This is a readability control, not
a voltage calibration.

BG and PIXEL accept short/long hex, RGB channels, CSS names and supported CSS
color functions. Their exact entered text persists beside resolved RGB. Enter
applies a valid value and Escape cancels. Editing hints appear only during
entry; invalid drafts stay editable and leave the previous palette intact. The
live preview shows the output palette; grayscale methods mark the selected text
and background positions.

## Uniform Controls and Motion

Selectors of the same kind are grouped together. Aperture and Font are adjacent
and alphabetical, using identical two-way selector columns. Selectors retain bounded widths in wider panes and place labels above their
buttons when space is tight. Queue places Random before Repeat with matching
geometry. Numeric controls share square minus/plus buttons
and one reserved readout width. Contrast, Volume and FPS each place a full-width
gauge on the following row. FPS buttons change ten FPS; its existing arrow,
Shift-arrow and Home/End controls remain available.

Gauge ticks use the whole track. Zero has no fill and maximum fills the final
track pixel. EQ keeps ten aligned bands; narrower panes put each band's gauge
below its control row. Audio gauges support pointer dragging and keyboard
steps. A drag previews locally, applies the audio setting on release, and
restores the starting value when cancelled.

ViewBoy uses SB2's `cubic-bezier(0.2, 0, 0, 1)` for its shared animations. For a
Bezier parameter `u`, time is `x(u) = 0.6u(1-u)^2 + u^3` and distance is
`y(u) = 3u^2 - 2u^3`. The renderer solves `x(u) = elapsed/duration`, then uses
`y(u)` to interpolate. Feeding elapsed time directly into `y` would produce a
different curve.

| Elapsed duration | SB2 curve: distance covered | Previous quadratic ease |
| --- | --- | --- |
| 10% | 15.6% | 2% |
| 25% | 60.7% | 12.5% |
| 50% | 87.8% | 50% |
| 75% | 97.5% | 87.5% |

The curve gives fast travel with a settling tail, stays monotonic and does not
overshoot. Duration, animation enablement and FPS remain user controls;
retargeted motion starts from the currently visible position.

## Grid and Fidelity

**LCD Dot Size** selects 2 through 6 device pixels per logical dot. **Pixel
Grid** enables the matrix independently of pixel method and Contrast Boost.
**Aperture STN** uses a centered fractional aperture rather than rounding a thin
gap to a full device pixel. **Aperture 1 PX** retains the classic right/bottom
one-pixel gutters. Turning the matrix off remains an explicit user preference.

The STN reference uses the 0.39 mm dot / 0.43 mm pitch ratio documented in a
[Displaytech component
specification](https://docs.rs-online.com/6412/0900766b806dda0d.pdf). It covers
about 82 percent of each cell at every dot size; the classic 3-pixel cell covers
four of nine pixels. These are component-based spatial proportions, not a
measurement of the original Game Boy panel.

Nintendo specifies a 160x144, four-shade STN screen for the [original Game
Boy](https://www.nintendo.com/en-gb/Hardware/Nintendo-History/Game-Boy/Game-Boy-627031.html).
ViewBoy's grid remains responsive to its window. Its current LCD model covers
aperture geometry and output tones; measured panel timing, viewing angle,
reflectance, crosstalk and aging are not yet reproduced.

## Spacing Map

Spacing values are measured in logical LCD pixels. The fixed screen inset and
the three adjustable controls have distinct jobs:

| Measure | Value | Applies to | Does not control |
| --- | --- | --- | --- |
| App-edge inset | Fixed 8 px on all four sides | Gap between the LCD edge and the outermost toolbar, pane, or footer content | Control text padding or gaps between sibling elements |
| UI Button Pad | 1–8 px; default 4 | Main-screen control text inset and standard control height | Options grid, app-edge inset, or playlist/sidebar text-row height |
| UI Chrome Gap | 1–8 px; default 4 | Main-screen separation between controls, panes, tabs, headings, and playlist columns | Options grid or blank space between playlist/sidebar text rows |
| Text Line Gap | 1–8 px; default 1 | Blank vertical space between playlist and sidebar text rows | Control height, pane inset, or other chrome gaps |
| Options grid | Fixed: 4 px pane inset, 4 px card inset, 4 px gaps, 4 px control padding | Shared spacing inside every Options page | Main-screen adjustable spacing |

### Padding, Gaps, and Margins

- **Padding** is space inside a component: UI Button Pad insets main-screen
  control text. Options uses fixed grid values so saved main-screen spacing
  cannot shrink settings controls or clip labels.
- **Gaps** separate sibling controls or sections. UI Chrome Gap is the shared
  main-screen gap; Text Line Gap is reserved for the two text lists.
- **Margins** are local corrections for one widget relationship, such as the
  one-pixel separation before a boxed gauge value. Margins do not define the
  app grid or replace the shared gap settings.
- The content inset stays eight pixels even when UI Button Pad changes. The
  canvas background still paints to all four window edges.

Buttons and framed panes use a one-pixel LCD border. The upper toolbar's shared
button builder keeps its eight controls at matching size and format; the
left-aligned `<<` label is its only alignment exception.