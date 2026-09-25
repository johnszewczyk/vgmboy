# Display

ViewBoy has a compact instrument rail above its library and playlist. Brand,
transport state, and track position share the display's top line; the title and
source details sit beside elapsed, track, and playlist times inside the LCD.
Playback keys stay in their own adjacent bank, with a short segmented seek rail
below. The compact layout leaves more room for the text-first library and
playlist. Game Boy Core is the only presentation: a sampled DMG-gray shell,
muted maroon controls, and a pea-green LCD field with #333 text. The LCD,
content area, and playlist use a subtle 4 px square-cell grid with one-pixel
gaps, matching the tiny square cells visible in original DMG LCD macro photos.
The sidebar stays smooth gray plastic without a tiled texture. Folder rows
expand with one click anywhere on the row; nested folders and game rows indent
without bullet markers. Small raised seams and inset edges give the panels
hardware character without large textures or heavy effects. The bundled Doto
face remains consistent across the app at a compact 0.9 rem base, with
Interface Scale applied globally.

The bundled Doto face covers controls, lists, headings, and readouts. One
Interface Scale setting resizes text throughout the player, library, playlist,
and Settings. High-contrast dark text stays readable on the pale shell and LCD.
Fixed highlights and inset readouts give the screen a hardware appearance;
scrolling rows stay simple. Reduced-motion settings remove control and
selection transitions.

The interface remains in WebKit and CSS. A transparent, click-through Metal
overlay confines restrained scanlines, edge shading, and LCD sheen to the
player deck so the library and playlist surfaces stay clear. A short pale
phosphor sweep crosses the deck when transport state or track generation
changes. The sweep is disabled with Reduced Motion. The overlay does not
change layout or controls and stays paused between state changes. Previous,
Play/Pause, Next, Stop, Equalizer, Long Play, Repeat, Mono, and Mute use a 3x3
button matrix.

File, playlist, and Settings selections use a persistent 1 px rectangular
locator in the active font color that glides under the selected row or section.
The locator stays mounted while virtualized rows are patched, then follows the
visible selected row without fading. Large-playlist scrolling retains existing
row nodes and creates or removes only rows entering or leaving the visible
window. Rows keep a restrained LCD tint and readable text. Reduced Motion
stops the locator transition.

## Files

- `Sources/ViewBoy/Resources/styles.css`
- `Sources/ViewBoy/Resources/viewboy-gameboy.css`
- `Sources/ViewBoy/Resources/Fonts/`
- `Sources/ViewBoy/ViewBoyPhosphorShader.swift`
