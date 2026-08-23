# Options

## Window

SPCBoy WK opens Settings in a separate native macOS window. The root library and playback window
remains independent while Settings is open.

## Components

Settings groups app-owned controls above VGMBoy playback controls in the same compact sidebar used
by the current renderer skin. App controls cover theme, database location, and browser behavior.
VGMBoy controls cover playback, routing, tempo, fade, volume, mono, equalizer, and archive-cache behavior.
Diagnostics is its own VGMBoy page and reports live transport, buffer, output, decode, and underrun values.

## Persistence

Appearance, database, playback, and cache choices are applied through the WebKit/native bridge and
persist in SPCBoy's existing application preferences. Changing the selected database does not make
SPCBoy a catalog writer; MediaScanner remains responsible for scanning and publication.

## Database panel layout

The Database page shows the configured MediaScanner catalog path as a full-width readout.
Database actions run as three equal-width controls across the bottom of that panel—Reload Library,
Use Default, and Show in Finder. The catalog browse action is the folder button at the end of the
path bar. Archive-cache actions use the same aligned toolbar treatment in their own panel, with
Show in Finder last.

Playback controls are ordered Volume, Mono, Equalizer. Volume and each equalizer band use animated range bars with live values. The transport
seek bar remains a transport control, not a settings input.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/index.html`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/styles.css`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
