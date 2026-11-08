# SBONLINE workspace and site presentation

> Ownership update (2026-11-08): Production source now lives in VGMMan/SBONLINE. MathBook is reserved for math content.

Production: <https://admin.pre-calc.com/spcboy/>.

## Delivered

- One `.sb-toolbar` inset/gap contract (3px), 24px desktop controls, dense
  playlist/sidebar rows, and a split catalog/playback/time footer.
- Account/browser saved tabs with stable album IDs, per-tab view/search/scroll,
  a rightmost plus button, close controls, keyboard navigation, and album/track
  context actions. Background opens do not replace the audio queue. Limit: 24.
- Full-width top Options drawer; Interface controls for 10–20px playlist and
  sidebar text, animation enablement, and 0–600ms duration. Default motion is
  SB2's 200ms cubic-bezier(.2,0,0,1), with reduced-motion precedence.
- Shared charcoal/cyan site theme, compact desktop Favorites rows, persistent
  playback across desktop site navigation, and the same existing hosted engine.
- Phone saved-tab strip, larger track targets, compact top controls, and
  responsive Options navigation and audio controls.

## Recovery and ownership

Baseline `7b73dde` is tagged and pushed as
`sbonline-before-workspace-tabs-20261020`. Its source UI archive is
`/Users/john/Library/Application Support/SBONLINE UI Backups/ui-before-tabs-20261020.tar.gz`.
Earlier local and server UI backups remain available. Source implementation
was still in MathBook at the time; production source moved to VGMMan on 2026-11-08.

Implementation commits: `f9fdd83`, `1ddf5dc`, `fd26626`.

## Verification

JavaScript syntax, Django system checks, and whitespace checks passed.
Disposable local catalog fixtures exercised desktop and 390 x 844 phone views,
context-menu tab creation, reload restoration, independent searches, closing
tabs, changing playlist text to 16px and back to 13px, Gallery, Favorites, Queue,
and Options. The measured desktop toolbars all used 3px padding and gaps.
Phone Options had no horizontal document overflow. Desktop site navigation
retained one audio element, one transport, and the cached workspace. A detached
workspace save/measurement error found during the preview was fixed before release.

Normal deployment completed successfully; no migrations were pending. The only
deployment system-check warning was the existing HSTS preload warning.
The service was active after release. Final assets use `20261021-sb2-5` and
`sb-theme.css?v=20261021-2`.

Authenticated live checks loaded 2,235 games / 37,362 tracks, restored tabs for
1941: Counter Attack and 1942, and displayed the new full-width Options drawer.
Real Stage 1 AAC playback advanced beyond 11 seconds without an audio error.
Playback continued into the real Favorites page and reached 41.6 seconds with
one audio element and no error. Returning to the cached workspace retained both
tabs. Stop reset playback to 0:00 and showed Stopped. The final browser log was
clear of errors. The stopped live workspace screenshot is saved at
`/tmp/sbonline-workspace-refined.png`; Favorites at
`/tmp/sbonline-favorites-refined.png`.

## Limits

Tabs and presentation preferences are saved per account in the current browser;
they do not sync between devices. Local fixtures establish responsive layout,
not physical-phone audio behavior. Native-only filesystem, window, and decoder
routing controls remain outside the hosted interface.
