# Artwork Gallery

## Scope

- Title Snap artwork Gallery tab, projection loading, image preparation, and
  activation into a playable queue.

## Ownership

- `CatalogReader.CatalogSidebarReader.titleSnapGalleryGames` owns the read-only
  catalog projection and console-preference ordering.
- `FrontendCore.ArchiveMaterializationCore.TitleSnapArtworkReader` validates
  catalog PNG locators and reads loose artwork safely. Archive-member artwork
  uses VGMBoyArchiveCore for extraction; FrontendCore supplies an isolated
  cache policy for the artwork copy.
- CocoaSpice owns the Gallery tab, native grid, thumbnail downsampling, bounded
  image cache, and game activation.

## Invariants

- Gallery is persisted as a special playlist tab with no queue tracks. Version-1
  tab snapshots continue to restore as ordinary playlist tabs.
- Do not query the Gallery projection during model initialization. Load it only
  after startup becomes ready and while the Gallery tab is active; Gallery work
  never delays startup readiness.
- Use the independent shared `.gallery` catalog session scope. Catalog reload
  invalidates the projection and closing the Gallery tab cancels its request.
- Use `LazyVGrid`; fetch, decode, and downsample only materialized cells. Keep
  image work at utility priority, bounded to three concurrent tiles, with a
  bounded in-memory image cache.
- A single click selects a title. Double-click or the Play Now context action
  creates a normal playlist tab and starts that title while preserving Gallery.
- Never scan source folders or write to ScanSong's catalog for Gallery.

## Files

- `Sources/CocoaSpice/App/PlayerViewModel.swift`
- `Sources/CocoaSpice/App/PlaylistTabs.swift`
- `Sources/CocoaSpice/App/MainView.swift`
- `Sources/CocoaSpice/App/GalleryView.swift`
- `Sources/CocoaSpice/App/CocoaSpiceGalleryArtwork.swift`
- `../../../CatalogReader/Sources/CatalogSessionCore/CatalogSessionCore.swift`
- `../../../FrontendCore/Sources/ArchiveMaterializationCore/TitleSnapArtworkReader.swift`
