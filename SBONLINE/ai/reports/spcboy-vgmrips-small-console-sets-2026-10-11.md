# SPCBOY VGMRIPS small console sets — 2026-10-11

Added compact root-level VGMRIPS console collections. Packages remain compressed UAC source files; no game audio members or AAC copies were left extracted. The source packages were selected from `Audio/JohnS/VGMRIPS/`.

- **Source:** 370 UAC packages, 184,182,935 bytes.
- **Catalog:** 6,377 new playable VGM/VGZ tracks; 2,235 games and 37,362 tracks total.
- **Verification:** full UAC payload/member BLAKE3 verification; SHA-256 recorded per package; each published track has a positive VGM header duration; duplicate member hashes within a console/game were omitted.
- **Excluded:** Arcade roots, Computers, Neo Geo arcade, Sega 32X (280 MB), and Review. The existing Arcade (Mixed) and Arcade (Capcom) sets remain in place.

| Source root | Packages | Source bytes | Tracks |
|---|---:|---:|---:|
| Atari 5200 | 2 | 13,899 | 5 |
| Atari 7800 | 1 | 25,024 | 10 |
| Atari Lynx | 4 | 3,768,156 | 28 |
| Famicom Disk System | 1 | 4,651 | 1 |
| Intellivision | 1 | 6,160 | 2 |
| NEC TurboGrafx-16 | 243 | 146,727,210 | 4,205 |
| Neo Geo Pocket Color | 1 | 1,040,551 | 41 |
| NeoGeoPocket | 19 | 5,813,189 | 384 |
| Sega CD | 18 | 13,273,958 | 425 |
| Sega Pico | 33 | 3,240,126 | 569 |
| Sega SG-1000 | 3 | 25,504 | 12 |
| Vectrex | 15 | 69,615 | 21 |
| Virtual Boy | 18 | 3,649,362 | 400 |
| WonderSwan | 5 | 874,319 | 67 |
| WonderSwan Color | 6 | 5,651,211 | 207 |

The catalog’s prior SHA-256 was `c665bb36d659eae6868eb9ee9353cdc33d4e4738fd9e1781a87fa9106ba439b1` and the live catalog SHA-256 is `ff2abf3ea6ce53aca73884d3e1b6c907a622ce3572d87694adb52c4c1149f199`. Live verification found all 2,235 game entries and 37,362 tracks, zero missing archive references, and an intact 18,792,448-byte SQLite search index. The gallery cache has 2,165/2,235 covers, uses 12,167,066 bytes of WebP thumbnails, and reported no unreadable UACs. Fifteen representative systems produced PCM and valid 128 kbps AAC frames. The service is active with 3,108,651,008 bytes free. A catalog-only rollback copy is at `/var/lib/precalc-admin/media/spcboy/catalog.json.20261011-before-vgmrips-small-console-sets`; no game payload backup was created.
