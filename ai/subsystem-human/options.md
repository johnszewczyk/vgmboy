# Options

- SPCBoy-owned pages mirror CocoaSpice organizationally: Database, Interface, and Windows, while retaining SPCBoy's WebKit styling.
- Interface > Animations exposes Auto-Resize and Selection Bar timings; both default to 200 ms and accept 0–1000 ms.
- Windows has independent Always on Top switches for Main Window and Settings Window; both default off.
- Settings persistence is a typed native Swift snapshot. Electron/WebKit localStorage and the retired favorites migration payload are no longer read or written.

## Window

SPCBoy WK opens Settings in a separate native macOS window. The root library and playback window
remains independent while Settings is open.

## Components

Settings groups app-owned controls above VGMBoy playback controls in the same compact sidebar used
by the current renderer skin. App controls cover Interface, Windows, database location, and browser behavior.
VGMBoy controls cover playback, routing, tempo, fade, volume, mono, equalizer, and archive-cache behavior.
Diagnostics is its own VGMBoy page and reports live transport, buffer, output, decode, and underrun values.
Its page title is page-level content; Transport, Buffer, and Decoder are separate sibling panels.

## Persistence

Appearance, database, playback, and cache choices are applied through the WebKit/native bridge and
persisted by the native host. Changing the selected database does not make
SPCBoy a catalog writer; MediaScanner remains responsible for scanning and publication.

## Database panel layout

The Database page begins with Local Files and Favorites panels. Local Files stores one selected folder;
enabling it disables the catalog controls and opens that folder in the direct browser. Favorites chooses
Historical or Alphabetical display without changing shared history.
Database actions run as three equal-width controls across the bottom of that panel—Use Default,
Reload Library, and Show in Finder. The catalog browse action is the folder button at the end of the
path bar. Archive Cache uses the identical empty placeholder readout and uses Use Default, Clear Cache,
and Show in Finder, with Show in Finder last.

Playback controls are ordered Volume, Mono, Equalizer. Volume and each equalizer band use animated range bars with live values. The transport
seek bar remains a transport control, not a settings input.

Favorites is a library view beside Console View and Path View. Local Files remains an explicit
configured state rather than part of that three-view toggle. Command-D toggles the
selected track or selected database game/group, and the favorite sidebar uses compact path-free labels.
Both playlist headers use a visible star for the favorite column. Command-click and Shift-click select
multiple playlist rows. Favorites are shared with CocoaSpice through VGMMan's application-support data
store and remain separate from the read-only schema-23 scan catalog.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/index.html`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/styles.css`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
