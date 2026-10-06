# ViewBoy UI Design

This page is the published Markdown specification for ViewBoy's screen colors,
spacing, and shared controls. The app renders its content in one LCD pixel grid.
Direct mode uses exact PIXEL and BG endpoint colors. Optional 8- and 16-shade
methods use a stepped black-to-white grayscale ramp while preserving the same
cell geometry and configured gaps. The LCD surface reaches every window edge;
the eight-pixel content inset keeps controls and panes clear of the frame
without adding a bezel.

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
uses two columns: the live LCD palette preview and screen profile sit at left,
while transport, layout, window, and motion controls sit at right. Each Display
section uses a full card with a shared filled title bar and enclosing outline.
Options pane insets, card insets, gaps, and control padding use a fixed four-dot
grid, independent of the adjustable home-screen spacing.

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

For the current contrast setup, the endpoints are a yellow-green background
(`BG #9BBC0F`) and black pixels (`PIXEL #000000`). New installations use the
16-shade method, with TEXT SHADE at black and BG SHADE chosen independently for
legibility. Direct mode keeps four framebuffer labels for layout and maps
shades 0–1 directly to PIXEL and shades 2–3 directly to BG. Optional 8- and
16-shade methods expose evenly stepped sRGB gray values from black to white.
The BG and PIXEL inputs seed their independent tone positions from relative
luminance; **TEXT SHADE** and **BG SHADE** adjust those positions across the
full ramp. Selection bands and filled card title bars use a lighter semantic
shade while their lettering retains the darkest ink. Matrix gaps use the
selected BG shade in grayscale modes. All methods preserve the same
framebuffer cell mask, gap dimensions, grid, and spacing.

BG and PIXEL are the only color controls. Inputs accept three- or six-digit hex
with or without `#`, space- or comma-separated RGB channel values, CSS color
names, and supported CSS color functions. ViewBoy preserves the entered text,
including names such as `rebeccapurple`, and stores the resolved RGB value
separately for rendering. Enter applies a valid value and Escape cancels.

## Grid and Fidelity

The canvas grid scales with the window and is not the Game Boy's fixed 160×144
panel. **LCD Dot Size** selects 2–6 device pixels per logical cell; smaller
values give the same canvas a finer grid. **Pixel Matrix Gaps** is off by
default. In Direct mode each device cell uses one of the two exact endpoints;
when gaps are enabled, its right and bottom edges use exact BG. In grayscale
modes, text cells use the selected TEXT SHADE and gaps use the selected BG
SHADE. The method changes only the output color mapping; dot size, gap setting,
cell geometry, and framebuffer pixels remain the same.

Direct mode shows a two-color grid, not a four-tone STN panel. It does
not claim to reproduce measured panel response. It does not model
reflectance, viewing-angle response, row/column crosstalk, liquid-crystal
transition time, or panel aging. Nintendo lists the classic screen as a
160×144 STN dot-matrix LCD with four shades and a contrast controller; the
Game Boy Color uses a TFT screen. [Nintendo Game Boy specifications](https://www.nintendo.com/en-gb/Hardware/Nintendo-History/Game-Boy/Game-Boy-627031.html),
[Nintendo technical data](https://www.nintendo.com/en-gb/Support/Legacy-system/Technical-data-619585.html).

The **LCD PALETTE** group is always visible on the Display page.
**PIXEL METHOD** selects Direct, 8 shades, or 16 shades. Its preview shows the
two endpoints twice in Direct mode and every grayscale step in 8/16 mode, with
markers for the active text and background shades. The separate **BG** and
**PIXEL** fields accept three- or six-digit hex
(`333`, `ABC`, `1122FF`, with or without `#`), three RGB channels separated by
spaces or commas (`30 30 30`), CSS color names, and colors accepted by native
CSS color parsing. In Direct mode, the renderer uses these endpoint colors
exactly. In grayscale modes, changing either input recalculates its initial
tone position while preserving the original entered text (for example,
`rebeccapurple`) and storing the resolved RGB value separately. Enter applies
a valid color; Escape cancels the edit. Method and tone selections persist in
display preferences.

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
