# Options

- SPCBoy-owned pages mirror CocoaSpice organizationally: Database, UI Chrome, UI Fonts, and Windows, while VGMBoy pages provide Audio, Diagnostics, Playback, and Routing in the same WebKit settings window.
- UI Chrome contains the palette, sidebar sizing, playlist layout, selection treatment, and animation controls. Hover color sets the interface hover fill. Divider color remains removed because it did not change the rendered interface.
- UI Fonts contains separate UI Chrome and content font sizes, content color and monospace settings, and the playlist header font color and weight.
- UI Chrome > Animations exposes checkbox-enabled Auto-Resize, Playlist Selection, and Sidebar Folds. Sidebar folders and console groups use the vanilla 200 ms eased slide when enabled; the setting defaults on. Auto-Resize and Playlist Selection timings default on at 200 ms and accept 0–1000 ms. Playlist row and tab selection use the Playlist Selection timing and easing.
- Playlist Options exposes Column Auto-size, enabled by default, with the description “Automatically resize columns for content width on selection.” Playlist headers also have a separate default text color.
- The 24 rem sidebar minimum is enforced in the main window; its width preference remains percentage-based above that minimum.
- CSS color text inputs are 18 characters wide. Playlist header text color is independent of the sidebar and playlist row text color.
- UI Chrome exposes Primary, Secondary, and Pane Background colors. Option fields use Primary as their background.
- The playlist selection marker uses the chosen accent color without changing sidebar or playlist text color. It is outlined by default or filled with the accent color when Solid Playlist Selection Bar is enabled. Sidebar rows have no selected-row marker.
- Windows has independent Always on Top switches for Main Window and Options Window; both default off. Main keeps the main window on top of other apps; Options keeps the options window on top of the main window.
- Archive Cache uses the shared 2 GB default and 2, 4, 8, or 16 GB choices. Usage counts retained archive-cache files whether Cache is enabled or disabled. Clear Cache stops playback and removes cached, disposable, and older archive-cache material.
- AAC Export exposes a destination folder and a playlist context-menu action. New installs default to Downloads, matching CocoaSpice. SPCBoy supplies the selected path, timing plan, and destination; VGMBoyKit performs the offline conversion, including archive-member materialization through the native bridge. Only one export runs at a time. Folder chooser controls use the shared folder glyph.
- Settings persistence is a typed native Swift snapshot. The retired browser-localStorage favorites migration payload is no longer read or written.
- Windows and Routing use the same page framing as Audio: their page titles sit outside the headed content cards, with each headed group retaining its own card.

## Window

SPCBoy WK opens Settings in a separate native macOS window. The root library and playback window
remains independent while Settings is open.

## Components

Settings groups app-owned controls above VGMBoy playback controls in the same compact sidebar used
by the current renderer skin. App controls cover Interface Chrome, Interface Fonts, Windows, and database location.
VGMBoy controls cover playback, routing, tempo, fade, volume, mono, equalizer, and archive-cache behavior.
Diagnostics is its own VGMBoy page and reports live transport, buffer, output, decode, and underrun values.
Its page title is page-level content; Transport, Buffer, and Decoder are separate sibling panels.

## Persistence

Appearance, database, playback, and cache choices are applied through the WebKit/native bridge and
persisted by the native host. Changing the selected database does not make
SPCBoy a catalog writer; ScanSong remains responsible for scanning and publication.

## Database panel layout

The Database page begins with the Favorites panel. Favorites chooses Historical or Alphabetical display
without changing shared history.
Database actions run as three equal-width controls across the bottom of that panel—Use Default,
Reload Library, and Show in Finder. The catalog browse action is the folder button at the end of the
path bar. Archive Cache uses the identical empty placeholder readout and uses Use Default, Clear Cache,
and Show in Finder, with Show in Finder last.

Reload Library shows its in-progress state, reopens the active read-only catalog, and refreshes the
main window's database roots, game projection, and file-tree projection. A failed reload leaves an
error in the Database page status.

Audio controls are ordered AAC Export, Equalizer, Mono, and Volume. Volume and each equalizer band use animated range bars with live values. The transport
seek bar remains a transport control, not a settings input.
Live Equalizer, Mono, and Volume changes use separate native commands; changing EQ does not write
the app-volume setting.

Playback controls are ordered End Fade, Play Time, and Play Speed. Play Time keeps Long Play and the configurable Unknown-length default. The default End Fade is six
seconds; Faded Skip is an option within that panel and does not have a separate page.

Faded Skip is presented inline in the Play Time panel with End Fade behavior; it has no separate panel. SPCBoy WK's toolbar is rendered by WKWebView HTML. It uses the shared native playback command boundary, but it is not the same native SwiftUI macOS toolbar view used by CocoaSpice.

Favorites is a playlist projection, not a library/sidebar view. Command-Shift-D
replaces the playlist with a snapshot of shared Favorites without changing the
sidebar. Command-D toggles the selected track or selected database game/group.
Both playlist headers use a visible star for the favorite column. Command-click and Shift-click select
multiple playlist rows. Favorites are shared with CocoaSpice through VGMMan's application-support data
store and remain separate from the read-only schema-24 scan catalog.

## Files

- `../../Sources/SPCBoyWK/Resources/index.html`
- `../../Sources/SPCBoyWK/Resources/styles.css`
- `../../Sources/SPCBoyWK/main.swift`
