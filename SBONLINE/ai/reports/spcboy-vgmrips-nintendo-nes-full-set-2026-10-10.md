# SPCBOY VGMRIPS Nintendo NES full set — 2026-10-10

Replaced the prior NES library with all 531 compressed UACs in `Audio/JohnS/VGMRIPS/Nintendo NES`. The follow-up clean replacement retired every prior NES track ID and deleted the old package backup; no rollback copy of the former NES set remains on the server.

- NES content: 531 packages, 7,024 unique VGM tracks, 40,279,392 compressed bytes.
- Whole catalog: 648 games and 11,076 tracks across Game Boy (32 / 795), NES (531 / 7,024), SNES (66 / 2,747), and Genesis (19 / 510).
- Both multi-playlist packages use their longest playlist, which contains every unique member also listed by shorter playlists. No track member repeats within the selected playlist or across the 531 packages.
- Source UAC manifests and playable VGM member hashes were checked; durations use each VGM header's total-sample count. All 531 package files remain compressed; no AAC files or persistent extracted tracks were created.
- All 7,024 NES track IDs were regenerated. None of the previous NES IDs were reused; old favorites or history entries that reference those IDs are not automatically remapped.
- The former 32 NES packages (4,511,078 bytes) and saved old catalog were permanently removed from `/var/lib/precalc-admin/backups/spcboy-nes-vgmrips-20261010` after publication and index verification.
- Embedded artwork: 832 PNG references, 1,957,148 bytes, mostly 256×240. Keep source PNG; JPEG/HEIC conversion is not useful at this scale. The current catalog API does not expose artwork for a gallery yet.
- Published catalog SHA-256: `781e298053bdaefe7c03c862f559e103d8e9e01a74ba8299a09b3cc26d66c74f` (5,815,466 bytes). Search index rebuilt to 11,076 rows; service active; all 531 NES archive references resolve.

The JSON report lists each source package's hash, original metadata, chosen playlist, display name, track count, artwork references, and hosted archive path.
