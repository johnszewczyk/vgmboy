# SPCBOY JohnS Master Nintendo SNES replacement — 2026-10-28

Published 2026-10-28T18:45:39+00:00 UTC. Replaced the hosted Nintendo SNES selection with the top-level UAC listing from `Audio/JohnS/Nintendo SNES`.

## Result

- **Source:** 1,414 compressed UAC packages, 219,274,926 bytes, and 32,990 playable SPC members. The source files were left unchanged; every uploaded package SHA-256 matches the source snapshot.
- **Catalog:** 1,414 SNES games and 32,990 tracks. The full online catalog now has 3,583 games and 67,605 tracks. Non-SNES catalog records are unchanged.
- Track IDs were regenerated for the replacement. The 2,747 prior SNES IDs were retired without remapping favorites or history. 2,081 source members lack a Title tag; those rows use their stored track number.
- The Gallery index now has 2,967 entries, including 803 new SNES thumbnails. The gallery builder reported zero unreadable archives.

## Retired server files

Removed the 69 old SNES archive files (13,246,900 bytes), the `Super Nintendo/` directory, the root-level `Chrono Trigger.uac`, and the task-specific `catalog.json.pre-snes-expansion-20261008.bak`. No rollback copy was retained. The temporary transfer bundle and staging directory were removed after verification.

## Verification

- Search index: 67,605 rows, SQLite integrity `ok`, and catalog size/mtime state matches the published catalog.
- All active catalog archive paths resolve on the server.
- A representative Master SPC member decoded through the hosted `spcboy-stream` binary to 529,200 bytes of 44.1 kHz stereo signed 16-bit PCM (3 seconds).
- The account quota remains 10,000,000,000 bytes per month.
- Volume gain tests passed (2/2): gain follows the selected level and EQ headroom, and an adjustment does not restart the stream. The player script cache key is now `20261028-volume-1`; an already-open player page needs a full reload to fetch the current bundle. Audible output was not measured in the active Safari session.
