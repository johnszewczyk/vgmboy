# SPCBOY gallery WebP and arcade groups — 2026-10-11

## Catalog grouping

Split the former `Arcade` catalog group into `Arcade (Mixed)` and
`Arcade (Capcom)`, in that order. The groups contain 467 games / 6,894 tracks
and 99 games / 2,999 tracks respectively. Catalog totals remain 1,214 games
and 20,969 tracks. None of the game names overlap between the groups.

The live catalog SHA-256 is
`5df04b516a636d0ea5ecae9f23bab9b9db750a43774ee3917a64465425ba3eb0`
(10,466,700 bytes). Before regrouping, it was
`597438b5988996dac4c19c9badafa84321f3ced985c7cf574230c849d96e83fa`.
The pre-change catalog is retained at
`/var/lib/precalc-admin/backups/spcboy-arcade-groups-20261011/catalog.before.json`.
Album favorite IDs remain stable: the gallery ID function maps both new arcade
labels to the former `Arcade` identity.

## Gallery thumbnails

The cache now uses schema 4 and serves private 240×240 WebP thumbnails. It has
artwork for 1,117 of 1,214 albums and totals 6,155,488 bytes, down from
30,551,465 bytes of PNG thumbnails (about 80% smaller). The build read
8,534,699 source PNG bytes from the compressed UAC packages, indexed
604,745,960 source-package bytes, and reported zero unreadable UACs. All 566
arcade albums, including all 99 Capcom albums, have artwork.

The builder center-crops artwork. Images with at most 256 colors use nearest
neighbor scaling and lossless WebP; other images use Lanczos scaling and WebP
quality 90. The source packages and embedded PNG artwork remain compressed and
unchanged. WebP is the delivery format because it retains sharp pixel-art
edges losslessly where possible and produces a compact browser cache. HEIC is
less suitable for a cross-browser site, and JPEG quality 90 is lossy even for
pixel art.

## Verification and deployment boundary

- The live `/spcboy/` page reports 1,214 games and orders the arcade tabs as
  `Arcade (Mixed)`, then `Arcade (Capcom)`.
- Selecting `Arcade (Capcom)` in Gallery reports 99 albums and displays the
  cover thumbnails.
- The live cache index reports `WEBP`, 1,117 albums, and 6,155,488 thumbnail
  bytes. `private-admin.service` is active.
- The application deploy ran through installation and service restart, but
  the deploy's final recovery-backup step failed safely: the droplet had
  552 MB free, while a recent backup archive is about 630 MB. The backup
  service refused to create a backup without sufficient headroom. Existing
  backups were left untouched; do not rerun that backup step until space is
  available.
