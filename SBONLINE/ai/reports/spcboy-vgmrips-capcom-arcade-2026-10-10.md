# SPCBOY VGMRIPS Capcom Arcade set — 2026-10-10

Added all 99 compressed UAC packages from the nested `Audio/JohnS/VGMRIPS/Arcade/Capcom` folder.

- Source package bytes: 186,938,646 (178.3 MiB); each source UAC remains compressed.
- The packages contain 3,001 playable VGM members. The longest nonempty playlist per package publishes 2,999 unique tracks; none are playlistless.
- All 99 package manifests and compressed-payload BLAKE3 values verified. The 99 source SHA-256 values matched the files installed on the droplet.
- VGM durations use each selected member's explicit total-sample count, read through seekable Zstandard frames. No audio members were persistently extracted and no AAC copies were stored.
- Every package has PNG artwork. The live gallery cache contains all 99 albums; this addition uses 1,337,996 source-image bytes and 6,366,935 optimized 240×240 PNG thumbnail bytes.
- The two `Mega Man: The Power Battle` packages are shown with their CP System and CP System II suffixes to keep those albums distinct.
- The catalog now contains 1,214 games and 20,969 tracks. Arcade has 566 games and 9,893 tracks. All 1,217 referenced archive paths resolve; the search index rebuilt and `private-admin.service` is active.
- Published catalog SHA-256: `597438b5988996dac4c19c9badafa84321f3ced985c7cf574230c849d96e83fa` (14,379,641 bytes).
- The prior catalog is preserved at `/var/lib/precalc-admin/backups/spcboy-capcom-20261011/catalog.before.json` with SHA-256 `7ee5677934fc2ef9bdea43e1f94c49f39c997fa5629d090745d8b49f6b82fadc`.

The JSON manifest records every source UAC path, source byte size and SHA-256, selected playlist, display game name, archive destination, published tracks, member paths, and timing.
