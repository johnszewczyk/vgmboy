# Shared UI features and controls map

## Purpose

Map the shared behavior contracts currently used by the active VGMMan
frontends. This is an architecture map; it does not introduce a cross-renderer
widget toolkit.

## Current ownership

| Feature | Shared foundation today | App-owned today | Current boundary |
| --- | --- | --- | --- |
| Tabs | `FrontendCore/PlaylistIdentityCore` defines stable playlist row IDs. `PlaylistTabsPersistenceCore` owns ordinary tab transitions for activation, insertion, close fallback, move, and restore. CocoaSpice calls the reducer directly; SB2 and ViewBoy call it through their native bridges. | Apps own tab payloads, final-tab/window behavior, selection restoration, rendering, and storage location. CocoaSpice uses its typed snapshot format; SB2 and ViewBoy keep their own snapshot adapters. | Ordinary tab ordering and active fallback now share one policy across the three active frontends. |
| Playlist sorting | `CatalogPlaylistPresentationCore.CatalogPlaylistSorting` owns field comparison, stable natural-order ties, missing track-number handling, and explicit direction. | Frontends provide their visible row values and map sorted IDs back to rows while preserving selection. | CocoaSpice, SB2, and ViewBoy use the same explicit sort policy. |
| Views | `CatalogReader/CatalogBrowserCore` defines catalog modes/state, temporary search view, content/result source, projections, and sidebar row intent. `FrontendCommandCore` shares command and shortcut identifiers. | Each active app owns its navigation surface, view composition, focus, geometry, and transitions. | Share view semantics and commands; keep view widgets and layout with each renderer. Favorites remains a playlist projection rather than a catalog view. |
| Search | `CatalogBrowserCore` provides canonical game/file search indexes, console groups, row identities, and browser state. | Apps own input controls, focus/clear behavior, result rendering, and adapters. ViewBoy requests matching IDs from the shared indexes and maps them onto Canvas rows. | ViewBoy no longer rebuilds console grouping or game/path matching in JavaScript. Search controls and rendering remain skin-owned. |
| Options | `FrontendCore/FrontendPreferencesCore` owns common preference values/store behavior, animation bounds, window roles, and `FrontendOptionsManifest`. The manifest currently describes Database, Interface, and Windows sections. | Each app owns its option schema, settings commands, page/dialog structure, and native/WebKit/Canvas/WebGL controls. | Shared preferences and categories are data contracts, not shared controls or a common option renderer. |

## Existing library map

- **CatalogReader** owns read-only catalog access, browse/search projections,
  file-tree policy, and catalog playlist presentation/sorting contracts.
- **FrontendCore** owns frontend preferences plus stable playlist identity,
  startup, favorites/history, queue, archive/cache, and transport policy.
- **PlaylistTabsPersistenceCore** owns ordered tab-state transitions and shared
  WebKit snapshot validation/file I/O; app targets provide their own storage
  format, persistence location, payload adapter, and renderer.
- **FrontendCommandCore** owns renderer-neutral command and shortcut IDs.
- **VGMBoy** owns playback admission, decoding, timing, and audio output.
- **App targets** own their visual and interaction adapters: AppKit/SwiftUI in
  CocoaSpice, DOM/WebKit in SB2, and Yoga/Canvas in ViewBoy.

This keeps the common libraries focused on data, state transitions, and
policy. A shared widget library would have to erase real differences between
SwiftUI, DOM, and Canvas, so it is not the right first extraction.

The active app set is CocoaSpice, SB2, and ViewBoy. SPCBoyWK is retired and is
not a parity target for new shared UI work.

## Recommended shared contracts

1. **Tabs — reducer adopted.** Keep ordinary tab order and active selection
   transitions in `PlaylistTabsPersistenceCore`. Keep app storage locations,
   payloads, final-tab behavior, and visual components local.
2. **Views — keep the existing CatalogBrowserCore boundary.** Treat the
   catalog mode, temporary search mode, and row intents as semantic state.
   Reconcile `FrontendSidebarView` with `CatalogBrowserMode` only if the
   supported mode sets are intended to match; keep each frontend's display
   layout out of catalog navigation enums.
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

1. Keep tab payload compatibility and host-specific final-tab behavior
   documented while all three active apps use the shared reducer.
2. Route future catalog group and search changes through CatalogBrowserCore;
   do not add renderer-local comparison or grouping rules.
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
- `SB2/Sources/SB2/PlaylistTabsStore.swift`
- `ViewBoy/Sources/ViewBoy/WKNativeBridge.swift`
