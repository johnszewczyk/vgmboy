# Catalog Playlist Presentation Core

## Scope

`CatalogPlaylistPresentationCore` converts published `CatalogReader` and
`CatalogPlaylistCore` rows into one ordered, UI-neutral playlist display
projection. It provides source facts, visible fallback fields, and longest
content strings for column measurement.

## Ownership

- CatalogReader owns the source and metadata facts.
- This module owns deterministic display fallback, subtrack suffix, duration
  formatting, archive-member leaf naming, content hints, and the comparison
  policy for an explicit playlist sort.
- CocoaSpice and SPCBoyWK own font metrics, column pixel widths, animation,
  selection, an explicit sort gesture, and actual rendering.

## Invariants

- Input order is preserved by `project`. Sorting is an explicit separate call
  through `CatalogPlaylistSorting`; ties return to the supplied natural order.
- Archive rows present their playable member name, not the container name.
- Width hints describe the same visible fallback text as rows; they are not
  byte counts, source inspection requests, or persisted layout values.
- A bridge that exposes this projection must publish rows and content hints in
  the same response. A frontend may measure the hint strings in its own font;
  it must not rescan catalog rows to reinvent the content policy.
- Frontends may retain their visible column IDs (`filename`, `artist`, and
  `lengthLabel`), but must map them through `CatalogPlaylistSortColumn` and
  use the shared comparator rather than introducing a per-skin sort policy.
- Catalog-backed WebKit lists use their native retained projection session;
  bounded local, mixed, and Favorites lists use the Codable
  `CatalogPlaylistSortRequest` and receive only ordered row IDs. Neither route
  permits a renderer-owned field comparator.
- Empty title, game, author, system, and duration values use the visible
  fallbacks (`displayName`, group name, `—`, `—`, `—`) in every frontend.
- There are no AppKit, SwiftUI, WebKit, DOM, decoder, scanner, write, or
  playback dependencies.

## Files

- `../../Sources/CatalogPlaylistPresentationCore/CatalogPlaylistPresentationCore.swift`
- `../../Tests/CatalogPlaylistPresentationCoreTests/CatalogPlaylistPresentationCoreTests.swift`
