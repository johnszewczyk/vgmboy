# Options

## Window

SPCBoy WK opens Settings in a separate native macOS window. The root library and playback window
remains independent while Settings is open.

## Components

Settings groups app-owned controls above VGMBoy playback controls in the same compact sidebar used
by the current renderer skin. App controls cover theme, database location, and browser behavior.
VGMBoy controls cover playback, routing, tempo, fade, equalizer, and archive-cache behavior.

## Persistence

Appearance, database, playback, and cache choices are applied through the WebKit/native bridge and
persist in SPCBoy's existing application preferences. Changing the selected database does not make
SPCBoy a catalog writer; MediaScanner remains responsible for scanning and publication.

## Database panel layout

The Database page shows the configured MediaScanner catalog path as a full-width readout.
Database actions run as equal-width controls across the bottom of that panel; archive-cache
actions use the same full-width treatment in their own panel.

Playback values such as volume and equalizer gain use plain numeric text fields. The transport
seek bar remains a transport control, not a settings input.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/index.html`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/styles.css`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
