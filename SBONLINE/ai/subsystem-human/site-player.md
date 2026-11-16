# Hosted Site Player

## Split-Skin Player Architecture

SBONLINE uses an intentional split-skin setup over one shared audio engine
(`site-player.js`) and account preference store (`site-preferences.js`):

- **Desktop / Landscape Skin (`min-width: 781px`)**: Uses the two-pane
  `#spcboy-library` workspace (`partials/spcboy_catalog_workspace.html`),
  remembered workspace tabs with the Settings/Menu button nested right next to
  the New Tab (`+`) button at the top-most rightmost corner (no separate
  top-most `.topbar` on `/spcboy/`), draggable/resizable playlist columns,
  bottom `#site-player` status dock, and slide-over `#spcboy-settings-panel`
  drawer (`Navigation`, `Sound`, `Interface`, `Playback`). The desktop sidebar
  browses the library, recent plays, and favorites; it has no Gallery view.
- **Mobile / Portrait Skin (`max-width: 780px`)**: Uses the dedicated
  `#spcboy-mobile-app` shell (`partials/spcboy_mobile_shell.html` and
  `spcboy-mobile.css`) with core playback tabs (`Playing`, `Library`, `Recent`,
  `Favorites`, `Sound`) plus `Nav` (a deeper vertical navigation
  screen for site/account links and owner `Admin`), and a persistent mini-player
  dock (`#spcboy-mobile-dock`) on non-`Playing` tabs. Mobile Library browses
  consoles and games; there is no Gallery or separate album-detail page.

### Playing & Navigation

- **Now Playing (both skins)**: Retains the current track's album artwork from
  the catalog artwork URL. **Mobile Playing** shows centered square artwork,
  track/album metadata, an
  elapsed / duration time readout (`0:00 / 0:00`), a centered three-button
  transport row (`|◀`, `▶`, `▶|`), and the current album track list with inline
  favorite toggles. There is no seek slider on either skin because seeking can
  interrupt live transcoded streams.
- **Desktop Workspace**: Sidebar Row 1 houses transport, EQ, Long Play, Slow
  Play, and Volume; Sidebar Row 2 houses game-title search, view tabs (`All`,
  `Favorites`, `Recent`), and Fold/Unfold All. Main Row 1 houses
  remembered workspace tabs, New Tab (`+`), and the rightmost Settings/Menu
  button.

### Sound, Playback, and Desktop Interface Options

- **Sound**: Groups Volume (20 steps of 5%), the 10-band Equalizer (−12 to
  +12 dB in 0.5 dB steps) with a segmented `OFF / 1 / 2 / 3` preset bar, `Reset
  to Flat`, and `Save to Preset N`. Both skins share the same saved presets and
  smoothly animate fader transitions; selecting `OFF` moves all sliders to their
  default (`0.0`) positions.
- **Playback**: Ordered `Long Play`, `Slow Play`, and `Fade Out` across the
  drawer and mobile Sound screen:
  1. **Long Play** (seconds, `M:SS`, or `H:MM:SS`; `0` means unlimited up to the
     page session limit).
  2. **Slow Play** (source-decoder speed fractions from `1/2×` to `2×` in `1/64`
     increments).
  3. **Fade Out** (0–30 s) with Faded Skips.
- **Desktop Interface (`Options → Interface`)**: Desktop-only UI preferences for
  `Track text size` (`--sb-playlist-font-size`, 10–20 px), `Game list text size`
  (`--sb-sidebar-font-size`, 10–20 px), `Row spacing` (`--sb-row-gap`, 0–32 px),
  interface animation toggle/duration (`--site-motion-duration`, 0–600 ms), and
  playlist column visibility. Mobile does not expose font or column settings.

## Audio and Account Behavior

Selected tracks stream as live ADTS AAC at the owner-configured global bitrate
(default 192 kbps). Source packages stay compressed on the server; only the
requested member is materialized for a playback request through VGMBoy's
preparation helper. Web Audio processes volume, 10-band EQ, and faded skips in
the browser when supported; iOS / `ManagedMediaSource` clients automatically
fall back to server-encoded `?eq=` and `?volume=` stream parameters.

## Prototype

[`prototypes/mobile/index.html`](../../prototypes/mobile/index.html) remains a
sample-data design fixture. It is not connected to the hosted catalog, account,
or audio stream and is not playback evidence.

## Production Source

- [Player template](../../server/templates/accounts/spcboy.html)
- [Desktop workspace partial](../../server/templates/accounts/partials/spcboy_catalog_workspace.html)
- [Mobile shell partial](../../server/templates/accounts/partials/spcboy_mobile_shell.html)
- [Base account template and shared drawer](../../server/templates/accounts/base.html)
- [Hosted theme](../../server/static/accounts/sb-theme.css)
- [Desktop player stylesheet](../../server/static/accounts/sbonline.css)
- [Mobile player stylesheet](../../server/static/accounts/spcboy-mobile.css)
- [Site mobile stylesheet](../../server/static/accounts/sb-mobile.css)
- [Player page adapter](../../server/static/accounts/spcboy.js)
- [Audio engine](../../server/static/accounts/site-player.js)
- [Desktop interface preferences](../../server/static/accounts/sb-interface.js)
- [Account and site administration](site-admin.md)
