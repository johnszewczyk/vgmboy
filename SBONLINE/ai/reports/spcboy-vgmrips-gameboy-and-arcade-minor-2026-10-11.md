# SPCBOY VGMRIPS Game Boy and arcade minor sets — 2026-10-11

Replaced the hosted Game Boy Mono selection with the compressed VGMRIPS Nintendo Game Boy VGM set, and published the four VGMRIPS arcade vendor sets transferred earlier.

- **Nintendo Game Boy:** 256 compressed UACs, 46,191,982 source bytes, 3,937 unique VGM tracks selected from complete playlists; all 256 packages include artwork.
- **Arcade minor vendors:** 427 compressed UACs, 665,135,497 source bytes, 6,874 VGM tracks: Konami (97 games / 1,861 tracks), Namco (96 / 1,991), SegaSys (118 / 1,455), and Taito (116 / 1,567).
- **Prior Game Boy set removed:** 32 Game Boy Mono packages, 795 old catalog tracks, and 896,731 remote source bytes. The local Audio collection was not modified. Existing history snapshots remain but are not remapped to the new track IDs.
- **Catalog:** 1,865 games / 30,985 tracks across the existing NES, SNES, Genesis, Arcade (Mixed), and Arcade (Capcom) groups plus the new sets. Arcade (Mixed) and Arcade (Capcom) remain hosted.
- All newly uploaded UAC source SHA-256 values match, and UAC manifests/compressed payload BLAKE3 checks passed before publish. Every referenced archive resolves; none of the new audio members were permanently extracted and no AAC copies were stored.
- The deployed libvgm streamer emitted PCM for representative tracks from Game Boy and each of the four arcade vendor groups. It produced 882,000 PCM bytes for the five-second Game Boy, Konami, and Namco samples; the shorter SegaSys and Taito tracks ended normally.
- Search index integrity and all 30,985 rows were verified. The gallery cache now covers 1,795/1,865 albums, including all 256 Game Boy albums, with 10,358,290 WebP bytes and zero unreadable UACs.
- A fresh 14,841,455-byte recovery archive contains the updated catalog and gallery but no compressed game payloads. The service is active; the droplet has 3.1 GB free.
- Published catalog SHA-256: `c665bb36d659eae6868eb9ee9353cdc33d4e4738fd9e1781a87fa9106ba439b1` (21,306,427 bytes). Previous catalog SHA-256: `5df04b516a636d0ea5ecae9f23bab9b9db750a43774ee3917a64465425ba3eb0`; its catalog-only snapshot remains at `/var/lib/precalc-admin/media/spcboy/catalog.json.20261011-before-vgmrips-gb`.

The JSON manifest contains source paths, byte sizes, SHA-256 values, playlists, archive destinations, and per-package counts. It also records live index, gallery, decoder, and backup verification. During this operation, the 458 MiB droplet ran out of memory during on-server index/backup work. The search index was therefore rebuilt off-server and installed only after its SQLite integrity and catalog size/mtime state matched; gallery generation ran with the service stopped. systemd restarted the service, and the final service check is active.
