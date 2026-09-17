# Local recovery inventory

These ignored payloads were retained while the component repositories and
standalone frontends were consolidated into this family repository. They are
not active source or build inputs. Git preserves maintained source and imported
history; these files preserve unique local archives and fixtures.

| Path | SHA-256 | Purpose and source |
| --- | --- | --- |
| `SPCBoy/SPCBoy-electron.zip` | `454a99e941bc622877fdf6821a0b7256fa30514f004d65e0f19d24962e80eee4` | Local Electron SPCBoy recovery archive from the legacy checkout staging tree. Current recovery source is also `../SPCBoy/`; Git history is kept in `archive/SPCBoy/...`. |
| `CocoaSpice/CocoaSpice-project-backup-2026-07-08.tar.gz` | `a77d7731e01823cbf2d3771354e67920eb8889e6b1892a540b3dbf088f44a4b9` | Earlier CocoaSpice source backup; maintained source is `../CocoaSpice/`. |
| `ViewBoy/ViewBoy-legacy-2026-09-01.zip` | `8ffa7797888aa131e2a087755d01266e9ff11e509af2cb5507b90369a30d9b6d` | Earlier ViewBoy backup; maintained source is `../ViewBoy/`, and imported history is `archive/ViewBoy/heads/main`. |
| `fixtures/Silent Hill 2 (EMU).zophar.zip` | `c4f1579ffbcf2199cbb6b4cc5a6d2be2a3cf8cbb155fdfe51a9db15bd02f3007` | Unique local playback/test fixture retained from the legacy checkout staging tree. |

The archives are intentionally ignored by Git and can be large. Keep them in
this folder when cleaning generated build output or retiring duplicate
checkouts. Do not treat these historical bundles as the current source of
truth.
