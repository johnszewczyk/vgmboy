# ViewBoy and SPCBoyWK UI parity

This is the current UI boundary for ViewBoy's skin work. Both apps use the
shared catalog, frontend, and playback packages; each owns its WebKit layout
and preference namespace. Parity means the same user capability, with a
ViewBoy-specific presentation.

| Surface | ViewBoy status | Remaining gate |
| --- | --- | --- |
| Library search, Console and Path views, favorites, row selection | Present | Verify loaded catalog gestures in the packaged app. |
| Transport, timing, and playback position | Present in a ViewBoy player deck above the library and playlist; the deck also shows cued track, source, state, and queue size | Verify resizing and playback in the packaged app. |
| Playlist columns, sorting, resizing, visibility | Present in both; `#` is non-sortable and empty content columns now hide for the active playlist | Verify mixed-content playlists and saved manual visibility in the packaged app. |
| Multiple playlist tabs and restoration | Implemented with a ViewBoy-owned native tab store and one shared playback session | Audio continuation across a tab switch remains unverified. |
| Interface controls | ViewBoy has one content font/color pair, accent, spacing, and animation timing | Decide whether separate chrome/content palette roles add value to the demo skin. |
| Playback speed | Both expose libgme/libvgm controls; ViewBoy now formats clean small-denominator rates as fractions | Verify the options input visually. |
| Local Files | ViewBoy has a separate local-folder browser | Preserve this ViewBoy capability during parity work. |

## Evidence

- Source mapping: current `SPCBoyWK/ai/subsystem-human/playlist-tabs.md`, both
  apps' `Resources/index.html`, `app-core.js`, `app-ui.js`, and native bridge.
- Contract: 23 renderer and bridge tests pass, including the deck's cued and
  playing readouts.
- Package: ViewBoy's clean release build passes with the deck, tab store, and
  revised settings skin. The packaged resources match the edited sources.
- Packaged UI: the player deck, denser bright text, library, playlist tabs,
  and A62800 playlist were visible in the packaged app. Its deck changed from
  CUED to PLAYING and then PAUSED through the playback control.
- Metal: the host builds with event-driven phosphor rendering, but this
  environment has no CLI Metal device or Metal compiler toolchain. The brief
  transport sweep was not captured in the packaged UI check.
- Live fixture: A62800 MDX transport reached PLAYING and the visible clock
  advanced from 0:00 to 0:15 before pause. Audible output and audio
  continuation across tab switches remain unverified.
