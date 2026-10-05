# ViewBoy UI Design

This page is the published Markdown specification for ViewBoy's screen colors,
spacing, and shared controls. The app renders its content in one four-tone LCD
canvas. The LCD surface reaches every window edge; the eight-pixel content
inset keeps controls and panes clear of the frame without adding a bezel.

## One Display Page

ViewBoy's Options table of contents has one **Display** page for screen profile,
LCD colors, transport labels, playlist sizing, spacing, window behavior, and
motion. There is no separate Interface page.

Every Options page uses one alphabetized navigation rail and one content area.
The rail is capped at 176 logical dots or 24% of the available width; a single
LCD divider separates it from the content. Display uses two columns: the live
LCD palette preview and screen profile sit at left, while transport, layout,
window, and motion controls sit at right. Each Display section uses a full card
with a shared filled title bar and enclosing outline. Longer pages scroll
within the content area.

In the Path sidebar, root chevron ink shares the leading edge of the search and
toolbar controls. Nested disclosures move inward by two bitmap glyph advances
per depth; folder and file labels share a column at each depth. Chevrons align
vertically with row text.

The main toolbar contains eight equal-width buttons in this order: Previous,
Stop, Play/Pause, Next, Long Play, Repeat One, Playlist Random, and Library
Random. All eight use the same template for width, height, border, and default
text inset. The symbol Previous label `<<` is left-aligned just inside its
border; other labels are centered. The Next symbol remains `>>`.
The four mode controls use the same darker selected fill while active. This
state tint is the expected visual difference from an inactive button.

## LCD Colors

The default endpoints are the traditional Game Boy yellow-green background
(`BG #9BBC0F`) and dark pixel color (`PIXEL #222222`). Standard mode renders
four tones: PIXEL, two intermediate tones, and BG. It derives the middle tones
at one-third and two-thirds of the endpoint distance in CIELAB L*, with a* and
b* interpolated at the same fractions. **High Contrast** keeps four distinct shades and both exact endpoints, with
its middle tones at 15% and 85% of the CIELAB path from PIXEL to BG. Shade 0
remains the exact PIXEL input. Pixel Matrix Gaps use BG-colored edges in both
modes; High Contrast does not tint cell edges or change the grid, spacing, or
presence of pixels.

BG and PIXEL are the only color controls. Inputs accept three- or six-digit hex with or without `#`, space- or
comma-separated RGB channel values, CSS color names, and supported CSS color
functions. ViewBoy preserves the entered text (including names such as
`rebeccapurple`) and stores the resolved RGB value separately for rendering.
Enter applies a valid value and Escape cancels.

## Grid and Fidelity

The canvas grid scales with the window and is not the Game Boy's fixed 160×144
panel. **LCD Dot Size** selects 2–6 device pixels per logical cell; smaller
values give the same canvas a finer grid. **Pixel Matrix Gaps** is off by
default, so every device pixel in a cell uses its framebuffer tone. When on,
the cell's right and bottom device-pixel edges use the LCD background tone.
With gaps off, a custom `000` PIXEL endpoint renders as full black throughout
each ink cell. High Contrast keeps the exact PIXEL endpoint at shade 0 and
changes only the two intermediate palette tones. It preserves the selected dot
size, gap setting, cell geometry, and presence of every framebuffer pixel.

Standard mode reproduces a four-tone palette and visible pixel grid, not the
original STN panel. High Contrast moves the two intermediate tones toward
PIXEL for a stronger dark range; it does not alter device-cell geometry or
claim to reproduce measured panel response.
The middle colors follow equal CIELAB L* intervals; they do not
approximate a measured LCD voltage curve. The renderer does not model
reflectance, viewing-angle response, row/column crosstalk, liquid-crystal
transition time, or panel aging. Nintendo lists the classic screen as a
160×144 STN dot-matrix LCD with four shades and a contrast controller; the
Game Boy Color uses a TFT screen. [Nintendo Game Boy specifications](https://www.nintendo.com/en-gb/Hardware/Nintendo-History/Game-Boy/Game-Boy-627031.html),
[Nintendo technical data](https://www.nintendo.com/en-gb/Support/Legacy-system/Technical-data-619585.html).

The **Custom LCD Colors** group is always visible on the Display page. It has
separate **BG** and **PIXEL** fields. Inputs accept three- or six-digit hex
(`333`, `ABC`, `1122FF`, with or without `#`), three RGB channels separated by
spaces or commas (`30 30 30`), CSS color names, and colors accepted by native
CSS color parsing. The two entered endpoints feed the same automatic four-tone
stepper. The field preserves the entered text (for example, `rebeccapurple`)
and stores the resolved RGB value separately for rendering. Enter applies a
valid color; Escape cancels the edit.

## Spacing Map

Spacing values are measured in logical LCD pixels. The fixed screen inset and
the three adjustable controls have distinct jobs:

| Measure | Value | Applies to | Does not control |
| --- | --- | --- | --- |
| App-edge inset | Fixed 8 px on all four sides | Gap between the LCD edge and the outermost toolbar, pane, or footer content | Control text padding or gaps between sibling elements |
| UI Button Pad | 1–8 px; default 4 | Main-screen control text inset and standard control height | Options grid, app-edge inset, or playlist/sidebar text-row height |
| UI Chrome Gap | 1–8 px; default 4 | Main-screen separation between controls, panes, tabs, headings, and playlist columns | Options grid or blank space between playlist/sidebar text rows |
| Text Line Gap | 1–8 px; default 1 | Blank vertical space between playlist and sidebar text rows | Control height, pane inset, or other chrome gaps |
| Options grid | Fixed: 8 px pane inset, 4 px card inset, 4 px gaps, 4 px control padding | Shared spacing inside every Options page | Main-screen adjustable spacing |

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
