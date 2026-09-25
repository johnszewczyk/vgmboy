# Display

ViewBoy has a compact instrument rail above its library and playlist. Brand,
transport state, and track position share the display's top line; the title and
source details sit beside elapsed, track, and playlist times inside the LCD.
Playback keys stay in their own adjacent bank, with a short segmented seek rail
below. The compact layout leaves more room for the text-first library and
playlist. The chrome uses black and charcoal molded plastic with a faint static
grain; LCD and panel glass use inset edges and fixed CSS reflections. Those
panes use pale green-gray readouts. The Settings window uses the same palette.

The bundled Doto face covers controls, lists, headings, and readouts. One
Interface Scale setting resizes text throughout the player, library, playlist,
and Settings. Text is high contrast over the dark panes. Fine borders, inset
readouts, and selected controls give the screen a hardware appearance. Lighting
stays on fixed surfaces and controls; scrolling rows stay simple. Reduced-motion
settings remove control and selection transitions.

The interface remains in WebKit and CSS. A transparent, click-through Metal
overlay adds restrained scanlines, a soft edge vignette, and a faint LCD sheen.
A short pale phosphor sweep crosses the player deck when transport state or
track generation changes. The sweep is disabled with Reduced Motion. The
overlay does not change layout or controls and stays paused between state
changes.

File, playlist, and Settings selections use a persistent pale LCD locator that
glides under the active row or section. The locator stays mounted while
virtualized rows are patched, then follows the visible selected row without
fading out. Large-playlist scrolling retains existing row nodes and creates or
removes only rows entering or leaving the visible window. Rows keep a restrained
glass tint and readable text. Reduced Motion stops the locator transition.

## Files

- `Sources/ViewBoy/Resources/styles.css`
- `Sources/ViewBoy/Resources/viewboy-nightglass.css`
- `Sources/ViewBoy/Resources/viewboy-polymer-grain.svg`
- `Sources/ViewBoy/Resources/Fonts/`
- `Sources/ViewBoy/ViewBoyPhosphorShader.swift`
