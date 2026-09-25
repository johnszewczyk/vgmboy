# Display

ViewBoy has a compact instrument rail above its library and playlist. Brand,
transport state, and track position share the display's top line; the title and
source details sit beside elapsed, track, and playlist times inside the LCD.
Playback keys stay in their own adjacent bank, with a short segmented seek rail
below. The compact layout leaves more room for the text-first library and
playlist. Nightglass uses black and charcoal molded plastic with a faint static
grain; LCD and panel glass use inset edges and fixed CSS reflections. The
selectable LightMode theme takes its shell gray, blue-violet bezel, and muted
maroon button accents from high-resolution original Game Boy references. Its
sidebar uses one smooth gray surface without a repeating texture; the playlist
keeps its pea-green LCD field and #333 text. Both themes retain the bundled
Doto face.

The bundled Doto face covers controls, lists, headings, and readouts. One
Interface Scale setting resizes text throughout the player, library, playlist,
and Settings. Text is high contrast over the dark panes. Fine borders, inset
readouts, and selected controls give the screen a hardware appearance. Lighting
stays on fixed surfaces and controls; scrolling rows stay simple. Reduced-motion
settings remove control and selection transitions.

The interface remains in WebKit and CSS. A transparent, click-through Metal
overlay confines restrained scanlines, edge shading, and LCD sheen to the
player deck so the library and playlist surfaces stay clear. A short pale
phosphor sweep crosses the deck when transport state or track generation
changes. The sweep is disabled with Reduced Motion. The overlay does not
change layout or controls and stays paused between state changes. LightMode
lays Previous, Play/Pause, Next, Stop, Equalizer, Long Play, Repeat, Mono, and
Mute out as a 3x3 button matrix.

File, playlist, and Settings selections use a persistent 1 px rectangular
locator in the active font color that glides under the selected row or section.
The locator stays mounted while virtualized rows are patched, then follows the
visible selected row without fading. Large-playlist scrolling retains existing
row nodes and creates or removes only rows entering or leaving the visible
window. Rows keep a restrained glass tint and readable text. Reduced Motion
stops the locator transition.

## Files

- `Sources/ViewBoy/Resources/styles.css`
- `Sources/ViewBoy/Resources/viewboy-nightglass.css`
- `Sources/ViewBoy/Resources/viewboy-lightmode.css`
- `Sources/ViewBoy/Resources/viewboy-polymer-grain.svg`
- `Sources/ViewBoy/Resources/viewboy-deck-machining.svg`
- `Sources/ViewBoy/Resources/viewboy-glass-catchlight.svg`
- `Sources/ViewBoy/Resources/Fonts/`
- `Sources/ViewBoy/ViewBoyPhosphorShader.swift`
