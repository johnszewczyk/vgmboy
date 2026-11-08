# SBO top-bar album label — 2026-11-07

## Current evidence

- MathBook commit `4254907` deployed with `bash ops/server/private-admin-deploy.sh`.
- `private-admin.service` is active after deployment. Migrations were current;
  the hosted search index was already current. Static collection completed.
- The cache-busted asset
  `/static/accounts/spcboy.js?v=20261107-mobile-app-3` returned HTTP 200 and
  contains the section-only top-bar context label. The album link remains in
  the playback dock.
- Django's deployment check reported one non-fatal warning: `SECURE_HSTS_PRELOAD`
  is not enabled. No authenticated browser check was performed.
