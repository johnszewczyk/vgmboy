# Main Shell

## Display

- Main window: two-pane layout.
- Left pane: database browser.
- Right pane: editable playlist.
- Playlist tabs: sit above the playlist table; each tab owns its queue and selection.
- Main-window navigation toolbar: individual Console View, Path View,
  Favorites, plus a fold/unfold-all
  item beside the native sidebar disclosure control. These remain individual
  native toolbar items rather than a grouped capsule.
- Main transport toolbar order: Previous, Stop, Play/Pause, Next, then Long Play, repeat, random playback, and Equalizer on/off. Stop uses a square glyph; the infinity button turns Long Play on or off.
- The sidebar begins with search and list content.
- Startup: if loading lasts beyond a short reveal delay, a four-step screen shows workspace restore, library connection, sidebar preparation, and playlist restore, with elapsed time. It briefly confirms readiness and stays visible with the error if startup fails.
- Sidebar: shows a loading indicator while its current database view loads after startup. Games load first; the potentially large Files tree loads only after Files is opened.
- Status bar: elapsed time / current-track total / playlist total duration. A plus suffix means some queued tracks do not yet have a known duration.

## Options

- Options: opens with `Command+,`.
- Options: utility window sized for preference editing.

## About

- About CocoaSpice: opens from the standard App menu.
- About: identifies CocoaSpice and its bundled VGMBoy playback core. The current upstream component inventory, licenses, and source links live in VGMBoy's README.

## Files

- [MainView.swift](../../Sources/CocoaSpice/App/MainView.swift)
- [CocoaSpiceApp.swift](../../Sources/CocoaSpice/App/CocoaSpiceApp.swift)
- [AboutView.swift](../../Sources/CocoaSpice/App/AboutView.swift)
