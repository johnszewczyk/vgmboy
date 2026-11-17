# Private Admin Agent Notes

## Scope & Ownership

- `SBONLINE/server/` owns the Django application (`precalc_admin` + `accounts`),
  templates, and static assets deployed to `https://admin.pre-calc.com/`.
- `SBONLINE/ops/server/` owns `sbonline-deploy.sh`, `sbonline-setup.sh`,
  `sbonline.nginx.conf`, and `private-admin.service`.
- Do not deploy from or sync presentation assets to `MathBook`; use
  `python3 SB2/scripts/sync-online-presentation.py --check` to verify that
  `sb-presentation.css` and `sb-presentation.js` in
  `SBONLINE/server/static/accounts/` match `SB2/Sources/SB2/Resources/`.

## Runtime & Operational Invariants

- **Service & Droplet Limits**: Production runs on a 2 vCPU / 4 GiB RAM
  Ubuntu 24.04 droplet (`68.183.113.4`) under `private-admin.service`
  (`precalc-admin` user, `/opt/precalc-admin/venv/bin/gunicorn`,
  `127.0.0.1:8001`).
- **Stop Service Before Index/Gallery Rebuilds**: `sbonline-setup.sh` stops
  `private-admin.service` before running `build_spcboy_search_index` and
  `build_spcboy_gallery_cache` so the droplet does not OOM while Gunicorn holds
  the parsed catalog in memory.
- **Audio Streaming Pipeline**: `spcboy_audio` (`GET /audio/spcboy/<track_id>/`)
  verifies the signed `pageLoad` token against the session limit, checks the
  10 GB monthly quota (`MonthlyUsage.audio_bytes`), materializes only the
  requested archive member into a request-scoped temporary directory via
  `accounts/vgmboy_prepare.py` (`VGMBoy/scripts/vgmboy-prepare-source.py`), and
  pipes `spcboy_streamer` PCM into `ffmpeg` (`-c:a aac -profile:a aac_low -f
  adts`). It includes a 100 ms `adelay` pre-roll when `start_ms == 0` and
  batches `MonthlyUsage` SQLite writes (~128 KB or 5 s) while well under quota.

## Split-Skin Frontend Invariants

- **Desktop Skin (`min-width: 781px`)**:
  - On `/spcboy/`, `.topbar` is hidden (`--site-navigation-height: 0px`) and
    `moveTransportForViewport()` places `#site-player-actions-slot`
    (`#spcboy-settings-toggle`) inside `.sbonline-playlist-heading` right after
    `#sbonline-add-tab` (`#site-player-queue-toggle` is hidden).
  - `#spcboy-settings-panel` uses a single compact header
    (`.spcboy-settings-header-main`) and shares the mobile card/switch/slider
    visual system across `Navigation`, `Sound`, `Interface`, `Playback`
    (`Long Play`, `Slow Play`, `Fade Out`), and owner-only `Admin`.
  - `sb-interface.js` applies desktop UI preferences (`--sb-playlist-font-size`,
    `--sb-sidebar-font-size`, `--sb-row-gap`, `--site-motion-duration`) from
    `Options → Interface` (`#spcboy-settings-page-interface`).
- **Mobile Skin (`max-width: 780px`)**:
  - On `/spcboy/`, `spcboy-mobile.css` hides `.topbar`, `#site-player`,
    `#spcboy-library`, `#spcboy-settings-panel`, and `#site-player-queue-panel`
    and displays `#spcboy-mobile-app` (`partials/spcboy_mobile_shell.html`).
  - Core top tabs are `Playing`, `Library`, `Recent`, `Favorites`,
    `Sound`, and `Nav`. `Nav` (`#spcboy-mobile-screen-nav`) provides the deeper
    vertical navigation (`Site & Account`, superuser `Admin Console`, and `Other sites`).
  - Equalizer presets (`1`, `2`, `3`) auto-save band adjustments immediately, and
    toggling `OFF` dims the fader bank without discarding the selected preset's
    saved curve.
  - Profile pictures/avatars are not used anywhere on the site.

## Verification

- Run Node UI/unit tests:
  `node --test SBONLINE/server/tests/*.test.cjs`
- Run presentation sync check:
  `python3 SB2/scripts/sync-online-presentation.py --check`
- Run Django unit tests (when a configured Django environment is active):
  `python3 SBONLINE/server/manage.py test accounts`
