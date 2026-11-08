# SPCBOY VGMRIPS Arcade set — 2026-10-10

Added the 467 compressed UAC files directly under `Audio/JohnS/VGMRIPS/Arcade`; nested manufacturer folders were separate imports.

- Arcade packages: 467 (352,741,327 compressed bytes / 336.4 MiB).
- Playable VGM members: 6,923; published playlist tracks: 6,894.
- Whole catalog after addition: 1,115 games and 17,970 tracks.
- UAC manifests and compressed payload hashes were verified. VGM durations use each selected member’s native total-sample header field, read from only the indexed seekable frame needed for the header; the value is used for both playback timing and displayed duration.
- Each package uses its longest nonempty VGM playlist; the single package without a playlist contributes its playable members. Duplicate VGM playlist entries were removed within packages, and equal-length winning playlists were checked for identical member sets.
- Gallery inputs: 467/467 Arcade UACs contain PNG members; first PNG members total 5,781,006 bytes. The production rebuild found artwork in all 467 and generated 19,770,853 bytes of optimized 240×240 PNG thumbnails (24,184,530 bytes across the full library); it reported zero unreadable UACs.
- Source UAC files remain compressed and unchanged. No persistent extracted audio or pre-encoded AAC files were created. A live decoder check materialized only `10-Yard Fight` → `Game Start` temporarily and produced a 16,830-byte 64 kbps AAC stream.
- The rebuilt search index contains all 17,970 tracks; every new artwork tile is cached and the service is active. The prior catalog remains available at `/var/lib/precalc-admin/backups/spcboy-arcade-20261010/catalog.before.json` for rollback.
- Base catalog SHA-256: `781e298053bdaefe7c03c862f559e103d8e9e01a74ba8299a09b3cc26d66c74f`; staged catalog SHA-256: `7ee5677934fc2ef9bdea43e1f94c49f39c997fa5629d090745d8b49f6b82fadc` (12,353,182 bytes).

The JSON manifest records every source archive path, byte size, SHA-256, payload-verification status, selected playlist, track count, display title, artwork metadata, and destination path.
