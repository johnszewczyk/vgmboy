# FrontendCore project information

## Boundary

FrontendCore contains reusable, UI-neutral services needed by native frontend
hosts. It must not become a second catalog writer or playback engine.

## Current ownership

- `CatalogReader`: read-only schema-23 catalog access and archive identity.
- `ArchiveMaterializationCore`: selected-entry temporary extraction and cleanup.
- `VGMBoy`: decoder, timing, transport, and audio output.
- Frontends: queue, presentation, options state, and user-facing policy.

## Next extraction candidates

Port librarian-facing CocoaSpice behavior here only after its persistence and
ownership are explicit: archive cache policy, frontend options contracts, and
shared file/entry presentation. Do not copy `PlayerViewModel` or SwiftUI state
into this package.
