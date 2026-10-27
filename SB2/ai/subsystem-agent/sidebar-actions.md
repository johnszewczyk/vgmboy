# Sidebar Actions and Gallery Projection

## Scope

The database sidebar, Gallery library projection, and asynchronous row actions
in the SB2 home view.

## Ownership

- `app-ui.js` owns tab-scoped sidebar actions, Gallery projection filtering,
  thumbnails, and console/path mode policy.
- `app.js` binds the Gallery library toolbar control.
- `app-core.js` exposes the control reference.
- `WKNativeBridge.swift` serves read-only Gallery metadata and artwork through
  CatalogReader and FrontendCore. `TitleSnapArtworkReader` in
  `ArchiveMaterializationCore` owns the safe PNG locator boundary; VGMBoyArchiveCore
  reads archive members, while SB2 keeps its app-specific artwork cache and
  data-URL bridge.

## Invariants

- Gallery is a library view and has a dedicated square button in the sidebar
  library toolbar. It is represented by a playlist tab, but its sidebar always
  uses Console View and displays only consoles with indexed `Title Snap`
  artwork. Gallery rows keep the normal sidebar spacing, font, and leaf marker;
  selecting a console filters the full Gallery grid. Do not unfold game rows or
  render artwork thumbnails in the sidebar.
- Gallery-filtered games must keep a stable array identity until the database
  or Gallery projection changes. The sidebar inserts large game lists in
  batches, and replacing an equivalent array on each render cancels pending
  batches and can leave rows missing or inactive.
- Gallery cards keep square artwork separate from a bordered, bottom nametag.
  The artwork fit setting chooses centered crop or centered padding; frame gap
  applies at grid edges as well as between cards.
- Gallery cards use inset, clipped artwork and a fixed one-line title using the
  same font size as sidebar and playlist rows; truncate long titles with an
  ellipsis so card geometry stays uniform. Persist gallery size, gap, radius,
  and fit mode in `SB2PreferencesSnapshot` as well as the JavaScript settings
  projection.
- A delayed sidebar preview and a context-menu action belong to the tab where
  the user invoked them. Tab activation invalidates pending sidebar work. Any
  asynchronous catalog action must recheck its captured tab before replacing
  playlist content, queuing tracks, or starting playback.
- Playlist loads are transactions: query and sort a candidate array first,
  then commit it only if its request generation, active tab ID, sidebar
  interaction generation, and (for path browsing) browser-selection
  generation still match. Do not write candidate tracks or projection hints
  into shared UI state before the final guard; tab rendering snapshots that
  shared state into the active tab.
- Async sorts are bound to both the active tab ID and the exact playlist array
  they started with. Duplicate tabs may contain identical track IDs, so IDs
  alone are not a sufficient stale-response check.
- Playlist-tab select and close controls resolve their current tab ID from the
  rendered tab container. A close request must resolve to a live tab before
  applying the single-tab window-close behavior.
- A Gallery row click only selects the title because Gallery does not display a
  playlist table. Enter or double-click opens a regular playlist tab and starts
  playback, leaving the Gallery tab intact.
- Gallery artwork loads share the bounded Gallery artwork cache and request
  queue. Sidebar thumbnails use an observer rooted to the sidebar scroll pane;
  do not eagerly materialize every image in the Gallery projection.
- The expand/collapse control switches to Collapse All when any console group
  or user-expandable folder is open. The permanent Path View root anchor does
  not count. The action collapses all in that case, and expands all only when
  none are open.
- Late shared console-state responses cannot overwrite selection after a tab
  switch or newer sidebar action.

- Sidebar snapshots belong to the catalog session, not individual playlist
  tabs. Loaded empty results are cached. Search filters those snapshots locally;
  switching tabs or entering search must not refresh Games, Files, or Gallery.
  Explicit Reload Library invalidates their generations.
- Favorites and Recent are playlist projections in the existing two-pane
  workspace. The sidebar keeps the selected Console or Path library view and
  its disclosure controls while either collection is active. Favorites default
  to FavoriteStore insertion order (the existing option can choose alphabetical
  order) and carry each row's `addedAtMilliseconds`; Recent preserves
  newest-first history order and carries each play's timestamp. The shared
  timestamp column is labeled Added or Played by projection.

## Album favorite margin

- Album rows wrap the existing selection button and a sibling favorite button;
  never nest buttons or change the selection/navigation target. Search hides the
  wrapper whenever its label is hidden. Count and star margins stay aligned.
- FavoriteStore's existing group toggle is authoritative: partial groups add
  missing members and complete groups remove all members. Fetch album rows only
  on an explicit star click, without adopting the playlist projection or starting
  playback. Disable the button until its mutation completes.
- Favorite snapshots maintain an ID set and metadata lookup for rendered stars.
  Explicitly fetched album IDs provide exact completion checks; invalidate those
  IDs on catalog reload. Do not issue per-album database reads during startup.

## Files

- `Sources/SB2/Resources/index.html`
- `Sources/SB2/Resources/app-core.js`
- `Sources/SB2/Resources/app.js`
- `Sources/SB2/Resources/app-ui.js`
- `Sources/SB2/Resources/styles.css`
