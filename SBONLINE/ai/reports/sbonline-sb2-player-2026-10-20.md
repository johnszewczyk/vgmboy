# SBONLINE SB2 presentation rollout

The hosted player at `https://admin.pre-calc.com/spcboy/` now uses SB2's dark
monospace presentation, compact sidebar transport, library controls, playlist
table, persistent status footer, and simpler Options sections. Gallery keeps
console navigation in the desktop sidebar. Existing hosted authentication,
catalog, favorites, queue, and streaming remain the functional foundation.
This is a presentation adaptation, not complete native feature parity.

## Source and recovery

- Production owner: `MathBook/private-admin/`; `VGMMan/SBONLINE/` remains intake
  and documentation only.
- Baseline: `bc9e159`, pushed tag
  `sbonline-ui-before-sb2-20261021T011335Z`.
- Local source UI backup:
  `/Users/john/Library/Application Support/SBONLINE UI Backups/ui-before-sb2-20261021T011335Z.tar.gz`.
- Live source UI backup:
  `/var/backups/precalc-admin/ui-before-sb2-20261021T011335Z.tar.gz`
  (mode 600, 90,345 bytes). These archives contain account templates/static UI,
  not database, credentials, or user media.
- Implementation commits: `f5e1750`, `418ed83`, `93350e2`.
- SBONLINE owner note updated in VGMMan commit `bb230c39`.

## Validation and deployment

- JavaScript syntax, Django system check, and Git whitespace checks passed.
- Disposable local catalog fixture exercised desktop and 390 x 844 layouts,
  Options, volume popover, Gallery, Recent, and Favorites. EQ and Long Play
  toolbar controls update the existing player settings. One audio element and
  one transport are retained; page navigation relocates those existing controls.
- Deployed through `bash ops/server/private-admin-deploy.sh`; final deployment
  completed successfully, with no pending migrations. Only the existing
  `security.W021` HSTS preload warning remained.
- Authenticated live catalog loaded 2,235 games. Actual AAC playback of
  Stage 1 from 1941: Counter Attack advanced beyond 13 seconds without an audio
  error. Stop paused playback and reset it to 0:00 while retaining the selected
  track and its 27-track queue. No browser console errors were found during
  that check.
- Final deployed assets verified:
  `sbonline.css?v=20261021-sb2-2` and `spcboy.js?v=20261021-sb2-3`.
  At a 1,065px desktop viewport, Gallery's sidebar occupied x=0..320 and its
  stage x=320..1065; real artwork and console navigation displayed correctly.
- Restored Library and left playback stopped. Live screenshots saved at
  `/tmp/sbonline-sb2-live.png` and `/tmp/sbonline-sb2-gallery.png`.

Native filesystem editing, native window controls, and offline-only operations
were not added to the hosted player. Account pages retain their existing theme.
