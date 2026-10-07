# Shared UI features and controls map

## Purpose

Map the shared behavior contracts that can support tabs, views, search, and
options across the VGMMan frontends. This is an architecture map; it does not
introduce a cross-renderer widget toolkit or change app behavior.

## Current ownership

| Feature | Shared foundation today | App-owned today | Current boundary |
| --- | --- | --- | --- |
| Tabs | `FrontendCore/PlaylistIdentityCore` defines stable playlist row IDs. `PlaylistTabsPersistenceCore` now owns the common version-1 WebKit snapshot envelope, validation, and bounded atomic file I/O used by SPCBoyWK and SB2. | Apps still own tab lifecycle, ordering, selection restoration, rendering, and storage location. CocoaSpice has its own typed snapshot format; ViewBoy persists through UserDefaults. | WebKit persistence policy is shared between SPCBoyWK and SB2; the tab state transition contract remains app-specific. LineBoy has no playlist-tab UI identified in its current source. |
| Views | `CatalogReader/CatalogBrowserCore` defines catalog modes/state, temporary search view, content/result source, projections, and sidebar row intent. `FrontendCommandCore` shares command and shortcut identifiers. | Each app owns its navigation surface, view composition, focus, geometry, and transitions. LineBoy lays out its own fixed-cell display. | Share view semantics and commands; keep view widgets and layout with each renderer. Favorites remains a playlist projection rather than a catalog view. |
| Search | `CatalogBrowserCore` provides canonical game/file search text and search indexes; browser mode/query state is also defined there. | Apps own input controls, focus/clear behavior, result rendering, and adapters. WebKit clients locally filter bridge-published search projections. | The shared text projection and matching semantics exist. Some client-side filtering and state adaptation remain duplicated. |
| Options | `FrontendCore/FrontendPreferencesCore` owns common preference values/store behavior, animation bounds, window roles, and `FrontendOptionsManifest`. The manifest currently describes Database, Interface, and Windows sections. | Each app owns its option schema, settings commands, page/dialog structure, and native/WebKit/Canvas/WebGL controls. | Shared preferences and categories are data contracts, not shared controls or a common option renderer. |

## Existing library map

- **CatalogReader** owns read-only catalog access, browse/search projections,
  file-tree policy, and catalog playlist presentation/sorting contracts.
- **FrontendCore** owns frontend preferences plus stable playlist identity,
  startup, favorites/history, queue, archive/cache, and transport policy.
- **PlaylistTabsPersistenceCore** owns shared WebKit tab snapshot validation and
  file I/O; app targets provide their own storage URL and render/state adapter.
- **FrontendCommandCore** owns renderer-neutral command and shortcut IDs.
- **VGMBoy** owns playback admission, decoding, timing, and audio output.
- **App targets** own their visual and interaction adapters: AppKit/SwiftUI in
  CocoaSpice, DOM/WebKit in SPCBoyWK and SB2, Yoga/Canvas in ViewBoy, and the
  fixed-cell WebGL experiment in LineBoy.

This keeps the common libraries focused on data, state transitions, and
policy. A shared widget library would have to erase real differences between
SwiftUI, DOM, Canvas, and LineBoy's character-cell layout, so it is not the
right first extraction.

SPCBoyWK and SB2 also carry tiny parallel JavaScript option and playlist
selection helpers; the checked-in copies currently differ only in their
exported app namespace. That is a real duplication, but a small one. It is
lower priority than agreeing on tab state and option schemas.

## Recommended shared contracts

1. **Tabs — next contract candidate.** The shared persistence envelope is in
   place for SPCBoyWK and SB2. Define a renderer-neutral reducer for
   create/duplicate, activate, close, reorder, restore, and active-tab fallback
   only after comparing behavior with CocoaSpice and ViewBoy. Keep app storage
   locations, host bridges, and visual tab components local.
2. **Views — keep the existing CatalogBrowserCore boundary.** Treat the
   catalog mode, temporary search mode, and row intents as semantic state.
   Reconcile `FrontendSidebarView` with `CatalogBrowserMode` only if the
   supported mode sets are intended to match; do not force LineBoy's display
   layout into catalog navigation enums.
3. **Search — consolidate policy at the existing boundary.** Keep canonical
   searchable fields, normalization, token matching, and file-tree search in
   CatalogBrowserCore. Reduce client-side copies by consuming the shared
   projections/index behavior where practical; keep keyboard and field
   interaction local to each UI.
4. **Options — evolve the manifest before sharing controls.** Extend the
   existing manifest only when apps need common option IDs, value types,
   defaults, constraints, or host actions. Keep rendering and native-only
   settings local. Do not infer that a shared category list means all apps
   should have identical pages.

## First implementation sequence

1. Compare tab semantics and persisted payloads across CocoaSpice, SPCBoyWK,
   SB2, and ViewBoy; write the contract and compatibility cases before moving
   code.
2. Audit remaining duplicated browse/search algorithms against
   CatalogBrowserCore and route only policy duplication into that package.
3. Inventory shared option values separately from app-specific settings, then
   add schema fields to `FrontendOptionsManifest` only for genuinely common
   controls.
4. Keep the visual control systems app-owned and verify each host after any
   shared-contract change.

## Source anchors

- `CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `CatalogReader/Sources/FrontendCommandCore/FrontendCommandCore.swift`
- `CatalogReader/Sources/CatalogPlaylistPresentationCore/CatalogPlaylistPresentationCore.swift`
- `FrontendCore/Sources/FrontendPreferencesCore/FrontendPreferencesCore.swift`
- `FrontendCore/Sources/PlaylistIdentityCore/PlaylistIdentityCore.swift`
- `FrontendCore/Sources/PlaylistTabsPersistenceCore/PlaylistTabsPersistenceCore.swift`
- `CocoaSpice/Sources/CocoaSpice/App/PlaylistTabs.swift`
- `SPCBoyWK/Sources/SPCBoyWK/PlaylistTabsStore.swift`
- `SB2/Sources/SB2/PlaylistTabsStore.swift`
- `ViewBoy/Sources/ViewBoy/WKNativeBridge.swift`
- `LineBoy/Sources/LineBoy/main.swift`
