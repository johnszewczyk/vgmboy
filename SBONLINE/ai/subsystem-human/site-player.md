# Hosted Site Player

## Playback

The private site's SPCBOY page streams a selected track as 64 kbps AAC. Source
packages remain compressed; the server reads and decodes only the requested
track. The shared player and queue stay available while members move between
site pages. Tracks linked from member profiles, Community activity, Feed
listening snapshots, and Played can be played or added to the queue.

Long Play offers Off, 5, 10, or 15 minutes. Playback speed ranges from 0.5× to
2×. Account favorites and personal Recents are available in the player; the
site-level Played page includes plays from all members, with profile icons,
Today/Yesterday filters, and daily counts.

The hosted player is integrated with the site's passkey accounts, profiles,
Community, shared Feed, and Now Playing. See the
[private-admin behavior note](../../../../MathBook/ai/subsystem-human/private-admin.md)
for the complete site workflow.

## Standalone Concept

[`prototypes/mobile/index.html`](../../prototypes/mobile/index.html) is a
visual concept with sample entries. It does not connect to the hosted catalog,
accounts, or audio stream.

## Files

- `prototypes/mobile/index.html`
- [MathBook player source](../../../../MathBook/private-admin/static/accounts/site-player.js)
- [MathBook production template](../../../../MathBook/private-admin/templates/accounts/base.html)
