# Playback History Playlist

## Scope

Implement the matching playback-history playlist in ViewBoy. CocoaSpice and
SPCBoyWK establish the family behavior; ViewBoy remains a separate frontend
and owns its own Yoga/LCD presentation work.

## User behavior

- Command-Shift-H replaces the visible playlist with playback history, newest
  event first. It does not change the catalog sidebar or write to ScanSong.
- Each successful playback start is one history event. Replaying the same song
  creates another row. Failed starts, pause/resume, and seek do not create rows.
- Each row retains source path, optional archive member, subtrack index/count,
  and the available display metadata. Selecting a row plays that exact source
  member and subtrack.
- The sortable Date/Time column displays the local timestamp in
  `YYYY.MM.DD-HH.MM.SS.MS` form. Store and sort the absolute Unix timestamp in
  milliseconds; do not sort the formatted display string.
- Timestamp visibility follows the existing content-aware column machinery.
  History rows show it unless the user explicitly hid it. When a normal
  playlist without timestamps replaces History, automatic visibility hides the
  empty column even if the saved visibility choice is on. It appears again for
  timestamp-bearing history rows.

## Shared family contracts

- Use `PlaybackHistoryCore` from FrontendCore. Its shared JSON file is
  `~/Library/Application Support/VGMMan/PlaybackHistory.json`; do not create a
  ViewBoy-specific history file or database. The store serializes cross-process
  writes and returns the newest events first.
- `PlaybackHistoryRecord` uses a unique event `id`,
  `timestampMilliseconds`, and a `FavoriteTrackSnapshot`. Event IDs are
  required because one source may occur multiple times in history.
- Add the `PlaybackHistoryCore` product to ViewBoy and expose list/record
  operations only through ViewBoy's typed native WebKit bridge. The renderer
  must not read the shared file directly.
- `FrontendCommandCore` already defines the `playbackHistory` command at
  Command-Shift-H. `CatalogPlaylistSortColumn.timestamp` and
  `CatalogPlaylistSortRecord.timestampMilliseconds` provide the shared sort
  contract for timestamp-bearing playlist projections.
- Record only after ViewBoy's native playback-start request succeeds. Capture
  `playedAtMilliseconds` at that success boundary and supply it with the same
  source/member/subtrack identity and metadata snapshot used to start playback.
  Keep playback, catalog reads, and history writes as separate boundaries.

## Acceptance checks

- Command-Shift-H opens the shared history while leaving the sidebar selection
  alone; newest timestamp is initially at the top.
- Sorting Date/Time reverses the order correctly and preserves distinct rows
  for repeated plays of the same song.
- The formatted value has three millisecond digits and follows local time;
  ordering remains based on the stored absolute timestamp.
- Starting a row plays its exact file/archive member/subtrack. Failed starts do
  not add entries; successful starts in ViewBoy appear in CocoaSpice and
  SPCBoyWK through the shared store.
- Date/Time auto-hides on a normal playlist without history values and returns
  on a history projection unless the user explicitly hid it.
- ViewBoy does not create or alter catalog records.
