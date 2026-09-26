# Display

ViewBoy has a compact instrument rail above its library and playlist. Brand,
transport state, and track position share the display's top line; the title and
source details sit beside elapsed, track, and playlist times inside the LCD.
Playback keys stay in their own adjacent bank, with a short segmented seek rail
below. The compact layout leaves more room for the text-first library and
playlist. Game Boy Core is the only presentation: a molded DMG-gray shell,
charcoal screen bezel, pea-green LCD, blue-purple markings and keys, muted
maroon Play key, and a red power lamp. Engraved labels and inset seams give the
deck its console character. The player, library, and playlist each sit in a
recessed LCD screen. The library and playlist use a fine 2 px square-cell
texture; their controls, tabs, and column headings remain inside the lit glass.
The player renders its own 5×7 glyph cells over a quiet LCD surface.
Folder rows
expand with one click anywhere on the row; nested folders and game rows indent
without bullet markers. The bundled Doto face remains consistent across the
library and playlist at a compact 0.9 rem base, with Interface Scale applied
globally.

The bundled Doto face covers controls, lists, headings, and fallback readouts. One
Interface Scale setting resizes text throughout the player, library, playlist,
and Settings. High-contrast dark text stays readable on the pale shell and LCD.
The player LCD draws supported Latin letters, digits, and common punctuation
as discrete 5×7 square-cell glyphs. Its cells grow with Interface Scale and
the title is sized around 1.2 rem. A soft pixel shadow strengthens the glyphs,
and the time readout sits directly on the glass without its former box. Long
titles truncate within the screen. Titles with characters outside that
alphabet remain in the bundled Doto face, preserving their original spelling.
The library and playlist use the bundled dotted face with a restrained stroke
and shadow, keeping long and multilingual catalog text in selectable DOM rows.
Reduced-motion settings remove control and selection transitions.

The interface remains in WebKit and CSS. A transparent, click-through Metal
overlay aligns fine plastic grain to the deck, matte shading to the screen
bezel, and scanlines and glass sheen to the LCD. It adds a glow around the
power lamp during playback. A short pale phosphor sweep crosses the LCD when
transport state or track generation changes. The sweep is disabled with
Reduced Motion. The overlay does not change layout or controls and stays
paused between state changes. Previous,
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
- `Sources/ViewBoy/Resources/lcd-pixels.js`
- `Sources/ViewBoy/Resources/Fonts/`
- `Sources/ViewBoy/ViewBoyPhosphorShader.swift`
