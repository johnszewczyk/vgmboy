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
  CatalogReader and FrontendCore.

## Invariants

- Gallery is a library view and has a dedicated square button in the sidebar
  library toolbar. It is represented by a playlist tab, but its sidebar always
  uses Console View and displays only games with indexed `Title Snap` artwork.
  Console groups remain foldable; game rows show the corresponding artwork.
- Gallery-filtered games must keep a stable array identity until the database
  or Gallery projection changes. The sidebar inserts large game lists in
  batches, and replacing an equivalent array on each render cancels pending
  batches and can leave rows missing or inactive.
- A delayed sidebar preview and a context-menu action belong to the tab where
  the user invoked them. Tab activation invalidates pending sidebar work. Any
  asynchronous catalog action must recheck its captured tab before replacing
  playlist content, queuing tracks, or starting playback.
- A Gallery row click only selects the title because Gallery does not display a
  playlist table. Enter or double-click opens a regular playlist tab and starts
  playback, leaving the Gallery tab intact.
- Gallery artwork loads share the bounded Gallery artwork cache and request
  queue. Sidebar thumbnails use an observer rooted to the sidebar scroll pane;
  do not eagerly materialize every image in the Gallery projection.
- Late shared console-state responses cannot overwrite selection after a tab
  switch or newer sidebar action.

## Files

- `Sources/SB2/Resources/index.html`
- `Sources/SB2/Resources/app-core.js`
- `Sources/SB2/Resources/app.js`
- `Sources/SB2/Resources/app-ui.js`
- `Sources/SB2/Resources/styles.css`
