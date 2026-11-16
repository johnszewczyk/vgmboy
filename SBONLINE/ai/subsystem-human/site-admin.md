# Private Admin & Community Space

## Access & Sign-In

The private account and player area is served at `https://admin.pre-calc.com/`.
The root page renders the passkey/password sign-in portal when signed out and
redirects to `/spcboy/` after sign-in.

- **Enrollment**: New members join only through an owner-issued 8-character
  one-time invitation code at `/join/` (valid for 24 hours; five failed attempts
  in 15 minutes pause that connection for 24 hours). Enrollment assigns an
  internal username automatically and signs the member in after their first
  passkey is registered.
- **Sign-In Credentials**: Members sign in with discoverable WebAuthn passkeys
  (no username prompt) or an optional 43-character generated login password for
  devices without passkey support. Generated passwords can be created, replaced,
  or revoked in `Profile → Sign-in` (or the owner's mobile `Admin` tab) and are
  displayed once.

## Split-Skin Site Layout

- **Desktop (`min-width: 781px`)**: On `/spcboy/`, eliminates the top-most
  `.topbar` and places the Settings/Menu button right next to the New Tab (`+`)
  button at the top-right of the workspace tab bar, paired with the 24 px bottom
  `#site-player` status dock and the right slide-over `#spcboy-settings-panel`
  drawer (with a single compact header showing display name, play/online counts,
  and close button above `Navigation`, `Sound`, `Interface`, `Playback`).
- **Mobile (`max-width: 780px`)**:
  - On `/spcboy/`, renders the dedicated `#spcboy-mobile-app` portrait shell
    (`Playing`, `Library`, `Gallery`, `Recent`, `Favorites`, `Sound`, and `Nav`)
    with `#spcboy-mobile-dock`. Tapping `Nav` opens the deeper vertical
    navigation screen (`Site & Account`, owner-only `Admin`, and `Other sites`).
  - On community and account pages (`/history/`, `/profile/`, `/accounts/`,
    `/usage/`), uses the compact mobile top header (Home link to `/spcboy/`,
    inline transport, game search, and Menu drawer with `Navigation`, `Sound`,
    and `Playback`). Mobile does not expose font or column settings.

## Community & Profile Pages

- **Listening (`/history/`)**: Combines live `Now Playing` cards (75-second TTL
  presence heartbeats) and paginated `Played` history grouped by Detroit local
  day (`All`, `Today`, `Yesterday`).
- **Profile (`/profile/` & `/members/<id>/`)**: Displays the member's display
  name, join date, paginated `Favorites` (tracks and albums), `Recents`, monthly
  bandwidth summary, and (on the signed-in member's own profile) `Profile` and
  `Sign-in` management tabs. There is no profile picture / avatar system.
- **Book of Mormon (`/bom/`)**: Owner-only static research reader served under
  `/bom/` (`Sites/V4/reader.html`).

## Owner Administration & Usage

- **Desktop Admin (`/accounts/`, `/usage/`, `/log/`)**:
  - `/accounts/` configures global `SiteSettings` (`aac_bitrate`: 96/128/160/192/256
    kbps, default 192; `player_session_limit_minutes`: 1–1,440, default 120),
    creates/cancels member invitations, and lists member accounts and active
    browser sessions.
  - `/usage/` reports monthly authenticated response-body bytes, per-account
    10 GB monthly AAC streaming quotas, `vnStat` `eth0` traffic, droplet
    memory/disk/load/uptime, and daily backup status.
  - `/log/` lists active sessions and 24-hour/historical sign-in events.
- **Mobile Owner Admin (`#spcboy-mobile-screen-admin`, `/spcboy/admin.json`)**:
  - Available only to superusers inside the mobile player shell.
  - Provides native mobile cards for `Site Controls` (bitrate and session
    limit), `Invitations` (create, copy code/link, revoke), `Accounts` (status,
    active sessions, audio quota, suspend/reactivate, recovery invite, delete),
    owner `Account & Sign-In` (display name, login password, sign out), and
    `Server & Sign-In Log`.

## Hosted Catalog & Media

- The hosted catalog currently serves 3,583 games and 67,605 tracks across 25
  console groups from compressed `.uac` packages under
  `/var/lib/precalc-admin/spcboy/packages`.
- Gallery thumbnails (240 px WebP) and detail covers (1,200 px WebP) are served
  from `/var/lib/precalc-admin/spcboy-gallery/` (`schemaVersion: 6`).
- Search uses the SQLite FTS5 index at
  `/var/lib/precalc-admin/spcboy-search.sqlite3`.
