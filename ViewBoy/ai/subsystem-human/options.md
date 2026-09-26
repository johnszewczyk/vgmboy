# Options

- ViewBoy-owned pages use the shared organization: Database, Interface, and Windows, while VGMBoy pages provide Audio, Diagnostics, Playback, and Routing in the same WebKit settings window.
- Interface > Animations exposes one shared 200 ms duration for playlist column resizing and selection movement, configurable from 0–1000 ms. Auto-Resize and Selection Bar can be disabled independently; disabling an effect uses 0 ms while retaining the shared configured value.
- Playlist Options exposes Column Auto-size, enabled by default, with the description “Automatically resize columns for content width on selection.” Columns without meaningful values in the active playlist hide automatically and return when content appears; manual visibility choices remain saved. The `#` column displays row position and does not sort.
- Interface is the fixed Game Boy Core presentation: sampled gray plastic, maroon accents, a subtle 4 px square-cell LCD grid with one-pixel gaps, a pea-green playlist, and bundled Doto. Interface Scale applies one 8–18 pt size across the player, library, playlist, and Settings. Text color and accent remain adjustable.
- Windows has independent Always on Top switches for Main Window and Options Window; both default off. Main keeps the main window on top of other apps; Options keeps the options window on top of the main window.
- Archive Cache uses the shared 2 GB default and 2, 4, 8, or 16 GB choices.
- AAC Export exposes a destination folder and a playlist context-menu action. New installs default to Downloads, matching CocoaSpice. ViewBoy supplies the selected path, timing plan, and destination; VGMBoyKit performs the offline conversion, including archive-member materialization through the native bridge. Only one export runs at a time. Folder chooser controls use the shared folder glyph.
- Settings persistence is a typed native Swift snapshot. Electron/WebKit localStorage and the retired favorites migration payload are no longer read or written.
- Windows and Routing use the same page framing as Audio: their page titles sit outside the headed content cards, with each headed group retaining its own card.

## Window

ViewBoy opens Settings in a separate native macOS window. The root library and playback window
remains independent while Settings is open.

## Components

Settings groups app-owned controls above VGMBoy playback controls in a dedicated navigation rail.
The rail separates ViewBoy and VGMBoy pages; one persistent maroon underline glides between active pages. The same scale-aware font system covers Settings and the main window.
Settings content uses two-column charcoal panels when the window is wide and collapses to one column on
narrow windows. App controls cover Interface, Windows, database location, and browser behavior.
VGMBoy controls cover playback, routing, tempo, fade, volume, mono, equalizer, and archive-cache behavior.
Diagnostics is its own VGMBoy page and reports live transport, buffer, output, decode, and underrun values.
Its page title is page-level content; Transport, Buffer, and Decoder are separate sibling panels.

## Persistence

Appearance, database, playback, and cache choices are applied through the WebKit/native bridge and
persisted by the native host. Changing the selected database does not make
ViewBoy a catalog writer; ScanSong remains responsible for scanning and publication.

## Database panel layout

The Database page begins with Local Files and Favorites panels. Local Files stores one selected folder;
enabling it disables the catalog controls and opens that folder in the direct browser. Favorites chooses
Historical or Alphabetical display without changing shared history.
Database actions run as three equal-width controls across the bottom of that panel—Use Default,
Reload Library, and Show in Finder. The catalog browse action is the folder button at the end of the
path bar. Archive Cache uses the identical empty placeholder readout and uses Use Default, Clear Cache,
and Show in Finder, with Show in Finder last.

Audio controls are ordered AAC Export, Equalizer, Mono, and Volume. Volume and each equalizer band use animated range bars with live values. The transport
seek bar remains a transport control, not a settings input.

Playback controls are ordered End Fade, Play Time, and Play Speed. Play Time keeps Long Play and the configurable Unknown-length default. The default End Fade is six
seconds; Faded Skip is an option within that panel and does not have a separate page.

Faded Skip is presented inline in the Play Time panel with End Fade behavior; it has no separate panel. ViewBoy's toolbar is rendered by WKWebView HTML. It uses the shared native playback command boundary, but it is not the same native SwiftUI macOS toolbar view used by CocoaSpice.

Favorites is a playlist projection, not a library/sidebar view. Local Files remains an explicit
configured state rather than part of the two-view catalog toggle. Command-Shift-D
replaces the playlist with a snapshot of shared Favorites without changing the
sidebar. Command-D toggles the selected track or selected database game/group.
Both playlist headers use a visible star for the favorite column. Command-click and Shift-click select
multiple playlist rows. Favorites are shared with CocoaSpice through VGMMan's application-support data
store and remain separate from the read-only schema-24 scan catalog.

## Files

- `../../Sources/ViewBoy/Resources/index.html`
- `../../Sources/ViewBoy/Resources/styles.css`
- `../../Sources/ViewBoy/main.swift`
