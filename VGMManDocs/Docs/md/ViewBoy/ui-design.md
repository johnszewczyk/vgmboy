# ViewBoy UI Design

This page is the published Markdown specification for ViewBoy's screen colors,
spacing, and shared controls. The app renders its content in one four-tone LCD
canvas. The LCD surface reaches every window edge; the eight-pixel content
inset keeps controls and panes clear of the frame without adding a bezel.

## One Display Page

ViewBoy's Options table of contents has one **Display** page for screen profile,
LCD colors, transport labels, playlist sizing, spacing, window behavior, and
motion. There is no separate Interface page.

Every Options page uses one alphabetized navigation rail and one open content
area. The rail is capped at 176 logical dots or 24% of the available width; a
single LCD divider separates it from the content. Display uses two open
columns: the live LCD palette preview and screen profile sit at left, while
transport, layout, window, and motion controls sit at right. Shared filled title bars divide
sections without enclosing cards. Longer pages scroll within the content
area.

The main toolbar contains eight equal-width buttons in this order: Previous,
Stop, Play/Pause, Next, Long Play, Repeat One, Playlist Random, and Library
Random. All eight use the same template for width, height, border, and default
text inset. The symbol Previous label `<<` is left-aligned just inside its
border; other labels are centered. The Next symbol remains `>>`.
The four mode controls use the same darker selected fill while active. This
state tint is the expected visual difference from an inactive button.

## LCD Colors

The default endpoints are the traditional Game Boy yellow-green background
(`BG #9BBC0F`) and dark pixel color (`PIXEL #222222`). ViewBoy renders exactly
four tones: PIXEL, two intermediate tones, and BG. It derives the middle tones
at one-third and two-thirds of the endpoint distance in CIELAB L*, with a* and
b* interpolated at the same fractions.

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
each ink cell.

This reproduces a four-tone palette and visible pixel grid, not the original
STN panel. The middle colors follow equal CIELAB L* intervals; they do not
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
| UI Button Pad | 1–8 px; default 4 | Text inset inside controls and standard control height | App-edge inset or playlist/sidebar text-row height |
| UI Chrome Gap | 1–8 px; default 4 | Separation between controls, groups, panes, tabs, headings, and playlist columns; Options pane inset is twice this value | Blank space between playlist/sidebar text rows |
| Text Line Gap | 1–8 px; default 1 | Blank vertical space between playlist and sidebar text rows | Control height, pane inset, or other chrome gaps |

### Padding, Gaps, and Margins

- **Padding** is space inside a component: UI Button Pad insets control text;
  UI Chrome Gap also insets the framed Options panes and setting groups.
- **Gaps** separate sibling controls or sections. UI Chrome Gap is the shared
  gap; Text Line Gap is reserved for the two text lists.
- **Margins** are local corrections for one widget relationship, such as the
  one-pixel separation before a boxed gauge value. Margins do not define the
  app grid or replace the shared gap settings.
- The content inset stays eight pixels even when UI Button Pad changes. The
  canvas background still paints to all four window edges.

Buttons and framed panes use a one-pixel LCD border. The upper toolbar's shared
button builder keeps its eight controls at matching size and format; the
left-aligned `<<` label is its only alignment exception.
