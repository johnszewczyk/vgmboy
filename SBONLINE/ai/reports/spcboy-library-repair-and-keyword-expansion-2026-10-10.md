# SPCBOY library repair and keyword expansion — 2026-10-10

## Repair

The live catalog referenced 139 unique archive files, but 111 were absent from their catalog paths. All 111 exact compressed files were present under the retained server staging tree. They were moved into their already-cataloged paths without changing bytes: 81 UAC packages and 30 ZIP packages, totaling 39,377,456 bytes. Every catalog archive reference now resolves. The retained staging tree had been left behind by the earlier import instead of atomically promoted.

GBS playback also failed for ZIP-backed tracks because the application expected `/usr/bin/7zz`, while the installed Ubuntu `7zip` package provides `/usr/bin/7z`. The application now uses the installed executable and logs pipeline-start failures. No source archive was expanded in persistent storage; playback still extracts only the selected member to a request-scoped temporary file.

## Catalog update

- Base catalog SHA-256: `60bafda6f07f4abbf6077c43098777d9310ed140d0da1e817c8f64071499e226`
- New catalog SHA-256: `8df66f98eebf38cbb6b01aee75f319c7f26bed8e14552df1e992af3941483bf7`
- Final catalog: 4,734 tracks across 149 games.
- New content: 13 UAC packages, 204 tracks, 1,926,173 compressed bytes.
- Canonical systems and game counts: Nintendo Game Boy (32), Nintendo NES (32), Nintendo SNES (66), Sega Genesis (19).
- Existing IDs and track records are retained. Console labels in catalog display metadata were normalized; archive paths and package bytes were preserved.
- Tetris & Dr. Mario was already hosted and was not added again.

| Console | Game | Tracks | Source path | Source bytes | Source SHA-256 | Hosted archive |
| --- | --- | ---: | --- | ---: | --- | --- |
| Nintendo SNES | Top Gear | 7 | `Audio/JohnS/SNESMusicOrg/Nintendo SNES/Top Gear.uac` | 48,230 | `7f735ea943e43d1caca161f0964702ee678377656b79725740b1bcd64e26a015` | `Super Nintendo/Added 2026-10/Top Gear.uac` |
| Nintendo SNES | Top Gear 2 | 6 | `Audio/JohnS/SNESMusicOrg/Nintendo SNES/Top Gear 2.uac` | 104,181 | `1bb22a29e0188764edddfcde9cd90fe11a73d872d905655a7cd9e20d9666cbf0` | `Super Nintendo/Added 2026-10/Top Gear 2.uac` |
| Nintendo SNES | Top Gear 3000 | 7 | `Audio/JohnS/SNESMusicOrg/Nintendo SNES/Top Gear 3000.uac` | 93,242 | `956b1ca3316c364e9d139d1309c0a63bd8a16a6459df8c67f62744a8ed660463` | `Super Nintendo/Added 2026-10/Top Gear 3000.uac` |
| Nintendo SNES | Super Metroid | 38 | `Audio/JohnS/SNESMusicOrg/Nintendo SNES/Super Metroid.uac` | 322,989 | `3526d71ae51a6a8eded96338fe3392fe97b3324c080824b5ff47a515215a5998` | `Super Nintendo/Added 2026-10/Super Metroid.uac` |
| Nintendo SNES | Tetris 2 | 27 | `Audio/JohnS/JoshW/Nintendo SNES/Tetris 2.uac` | 80,409 | `bb997a0c07d77ec7b5c72edca8062b43211260b1eaea30db0a1f8a2d626cb5d5` | `Super Nintendo/Added 2026-10/Tetris 2.uac` |
| Nintendo SNES | Super Tetris 3 | 33 | `Audio/JohnS/Nintendo SNES/Super Tetris 3.uac` | 211,194 | `7de5e07577bc9d68e6678b89fb2c41c7c75d0af9899d8bca8dc9005fddc5d891` | `Super Nintendo/Added 2026-10/Super Tetris 3.uac` |
| Sega Genesis | Top Gear 2 | 4 | `Audio/JohnS/VGMRIPS/Sega Genesis/Top Gear 2.uac` | 677,454 | `6da8408e239b02f92caa4fe7eef66e1eba67b3ef6a3be8b929e7f68eee5eac12` | `Sega Genesis/Added 2026-10/Top Gear 2.uac` |
| Sega Genesis | Tetris | 9 | `Audio/JohnS/VGMRIPS/Sega Genesis/Tetris.uac` | 45,187 | `1bf143d40e957c41fe5db3530f4539eafd88e98b36c160d46bede40da725ed0f` | `Sega Genesis/Added 2026-10/Tetris.uac` |
| Nintendo NES | Metroid | 12 | `Audio/JohnS/VGMRIPS/Nintendo NES/Metroid.uac` | 26,137 | `d6cef6e1f2bd2062fffe11ae89d30f73e04a4e1ef20597167cb31ff6fcef23a4` | `Nintendo Entertainment System/Added 2026-10/Metroid.uac` |
| Nintendo NES | Tetris | 7 | `Audio/JohnS/VGMRIPS/Nintendo NES/Tetris.uac` | 32,320 | `69e186795915b4394795563618c5b6d16ddeb618c83a667b7f88334de563fa0f` | `Nintendo Entertainment System/Added 2026-10/Tetris.uac` |
| Nintendo Game Boy | Metroid II: Return of Samus | 19 | `Audio/JohnS/VGMRIPS/Nintendo Game Boy/Metroid II - Return of Samus.uac` | 83,856 | `31d861532603a11485af3ea3953dd8308f1c75c8d34379338f2af66c947746f9` | `Game Boy Mono/Added 2026-10/Metroid II - Return of Samus.uac` |
| Nintendo Game Boy | Tetris Plus | 23 | `Audio/JohnS/VGMRIPS/Nintendo Game Boy/Tetris Plus.uac` | 175,012 | `886dcfbe5ce7cfccf86231a027ddaed3b3d6389080a7caef80fac45c98a5113d` | `Game Boy Mono/Added 2026-10/Tetris Plus.uac` |
| Nintendo NES | The Adventures of Bayou Billy | 12 | `Audio/Mr Norbert/source-docs/!NSFE!/Adventures of Bayou Billy, The.nsfe (wrapped as UAC; MetaMan timing retained)` | 34,478 → 25,962 | `2c7b5bb3b137f3c3111fc4b71e95628cbc223b57f0c9fd05b2bd806011a25fc5; output SHA-256 aebe37482673c0a3097f3d3b9010c273ea6ac51a857c2bca49232f18d3c73509` | `Nintendo Entertainment System/Added 2026-10/The Adventures of Bayou Billy.uac` |

## Playback verification

- After restoring the 111 existing packages, hosted ZIP-backed GBS, UAC-backed VGM, and SPC samples each produced 2 seconds of PCM (352,800 bytes) through the live `spcboy-stream` binary; FFmpeg encoded each to 64 kbps AAC ADTS.
- A standard `.nsf` sample from VGMBoy’s bundled zxtune fixtures produced 1 second of PCM and AAC ADTS through the same live streamer.
- Bayou Billy’s `.nsfe` opens as 12 libgme decoder tracks. MetaMan exposes a source track ID of 74 for “Death,” which is not a valid libgme decoder index. Catalog entries use the zero-based playlist decoder order (0–11); `gme_track_info` names matched the playlist labels, and all 12 indexes decoded successfully.
- These checks exercised the server decoder and AAC encoder locally on the droplet, not an authenticated browser request or monthly-usage accounting.

Exact per-package source paths, byte sizes, hashes, base/catalog fingerprints, and runtime results are in [`spcboy-library-repair-and-keyword-expansion-2026-10-10.json`](spcboy-library-repair-and-keyword-expansion-2026-10-10.json).
