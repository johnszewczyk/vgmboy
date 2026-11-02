# Mobile UI

## Scope

User-visible layout, navigation, playback controls, gallery, and options
behavior in APPBOY across iPhone Plus and iPad viewports.

## Shell and Chrome

- The top title strip spans the device safe area (`env(safe-area-inset-top)`)
  and displays `SPCBOY`, the active console name, and the tappable current album
  or playlist title without platform noise labels, desktop window buttons, or
  CPU meters.
- Directly below the title strip sits SB2's 10-button equal-width transport
  toolbar: Previous, Stop, Play/Pause (switching to the animated 4-bar playback
  meter while playing), Next, Repeat (`off` / `all` / `one`), Equalizer toggle,
  Long Play toggle, Playback Speed toggle, Volume (opening a downward 20-step
  `5%` detent popover with tick marks and `%` readout), and Options.
- Directly below the transport toolbar sits SB2's search and library action row,
  pairing a zoom-safe `Search` input (`16px` rendered font size) with 5 square
  glyph buttons: View Toggle (switching Library and Playlist on compact
  portrait, or returning from Gallery to Playlist in split view), Gallery,
  Recent, Favorites, and Collapse/Expand All.
- The bottom status strip spans the home-indicator safe area and displays
  concise SB2 library stats (`X GAMES · Y SYSTEMS`) on the left, playback state
  (`READY`, `PLAYING`, `PAUSED`, `ERROR`) with a status dot, and
  `elapsed / length / total` tabular clocks on the right. There is no bottom
  transport deck or visible progress scrubber rail, matching SB2's presentation
  contract.

## Responsive Layout

- Primary touch proportions are tuned around the **iPhone Plus** canvas
  (`430 × 932 pt` portrait, `932 × 430 pt` landscape) with `38 × 38 pt` toolbar
  glyph buttons and 2-column square album frames at `1.00×` gallery scale.
- Unified zero-duplication CSS Grid:
  - On compact viewports (`< 768px`, iPhone portrait), `.app-shell` stacks the
    titlebar, 10-button transport toolbar, search + 5 action buttons, active
    workspace pane (`#library-pane` or `#content-pane`), and status bar in a
    single column.
  - On regular viewports (`>= 768px`, iPhone Plus landscape and iPad),
    `.app-shell` switches to SB2's exact 2-column desktop split
    (`minmax(356px, 39%) 1px minmax(0, 1fr)`), stacking the transport toolbar,
    search/action bar, and Library tree in the left column while the Playlist or
    Gallery pane spans full height in the right column.

## Library, Playlist, and Gallery

- Console rows expand or collapse their games with disclosure markers and game
  counts; game rows show clean titles, optional track counts, and a star toggle
  without soundchip format badge clutter.
- Open playlist tabs share width equally (`flex: 1 1 0`) above the track table,
  with `+` to create a tab and `×` to close tabs when multiple are open. The tab
  bar hides automatically while Gallery is active.
- Compact track rows display `#`, `TITLE` (with artist/game subtitle), `★`, and
  `TIME`; regular split viewports add `GAME` and `SYSTEM` columns. Active and
  selected rows render SB2's `1px` bottom accent underline.
- Gallery renders square framed cards and lazily upgrades visible cards with
  embedded UAC Title Snap artwork via `galleryArtworkRead`.

## Options Modal

- Options slides top-down between the titlebar and status bar, grouping sections
  under **SPCBoy** (`Database`, `Gallery`, `UI Chrome`, `UI Fonts`) and
  **VGMBoy** (`Audio`, `Diagnostics`, `Playback`).
- `VGMBoy / Audio` uses `SharedWebUI/range-controls.{css,js}` for the 10-band
  peaking Equalizer (`-12` to `+12 dB`, `0.5 dB` steps, automatic headroom
  compensation, `Reset`), `Mono`, and `Volume`.
- `VGMBoy / Diagnostics` displays live decoder backend, transport state, sample
  rate, queued/target engine buffers, scheduled frames, `1/32` tempo ratio, EQ
  headroom, container summary, and position in whitespace-separated rows.
- `VGMBoy / Playback` configures `Long Play`, `Fade Out`, and `1/32`-quantized
  `Playback Speed` accepting fractions (`3/4`, `5/4`, `3/2`, `2/1`) or decimals.

## Files

- `Sources/APPBOY/Resources/WebUI/index.html`
- `Sources/APPBOY/Resources/WebUI/styles.css`
- `Sources/APPBOY/Resources/WebUI/sb-presentation.css`
- `Sources/APPBOY/Resources/WebUI/sb-presentation.js`
- `Sources/APPBOY/Resources/WebUI/range-controls.css`
- `Sources/APPBOY/Resources/WebUI/range-controls.js`
- `Sources/APPBOY/Resources/WebUI/app-state.js`
- `Sources/APPBOY/Resources/WebUI/app-ui.js`
- `Sources/APPBOY/Resources/WebUI/app-playback.js`
- `Sources/APPBOY/Resources/WebUI/app.js`
