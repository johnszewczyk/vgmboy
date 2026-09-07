# WIP crash report: CocoaSpice heap corruption during MediaRemote work

**Status:** Investigation active. First narrow MediaRemote hardening slice is implemented; root cause remains unconfirmed.

**Reported:** 2026-09-05 10:39:15 -0400  
**Process:** CocoaSpice 0.1.0 (1), arm64 native  
**Host:** MacBookAir10,1, macOS 26.6.2 (25G83)  
**Crash reporter key:** `FF548ADB-AD3C-2E7F-949A-7192EC307D6D`  
**Incident identifier:** `EAD055C0-6E25-4CA4-98F5-A973DE245A89`

## Executive finding

The process was terminated by macOS after detecting heap corruption:

```text
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
Exception Type: EXC_BREAKPOINT (SIGTRAP)
```

The crashed thread was:

```text
com.apple.MediaRemote.PlaybackQueue.serialQueue
```

Its visible stack is inside Apple MediaRemote/Foundation serialization while encoding a playback queue. This identifies where the allocator detected the damaged heap, not necessarily where the damage was introduced.

At the same time, the main thread was completing playback, refreshing playlist metadata, and performing a stable sort through `PlaylistPresentation.compare`. The report therefore places playback completion, playlist sorting, and Now Playing/MediaRemote activity in the same incident window, but does not yet establish which component corrupted memory.

## Relevant stack excerpts

### Crashed MediaRemote thread

```text
libsystem_malloc.dylib
CoreFoundation __CFBasicHashRehash
Foundation NSKeyedArchiver replaceObject:withObject:
Foundation archivedDataWithRootObject:requiringSecureCoding:error:
MediaServices MSVArchivedDataWithRootObject
MediaRemote MREncodeObjectWithEncoding
MediaRemote MRContentItemMetadata protobufWithEncoding:
MediaRemote MRPlaybackQueue protobufWithEncoding:
MediaRemote MRAddPlaybackQueueToXPCMessage
MediaRemote MRServiceHandleNowPlayingPlaybackQueueRequest
```

### Main thread at the same time

```text
CocoaSpice PlaylistPresentation.compare
CocoaSpice PlaylistPresentation.compareTracks
CocoaSpice PlayerViewModel.applyPlaylistSort
CocoaSpice PlayerViewModel.refreshPlaylistMetadata
CocoaSpice PlayerViewModel.finishPlaybackRequest
CocoaSpice PlayerViewModel.play
```

## Current interpretation

The most important fact is the allocator diagnostic, not the `localizedStandardCompare` frame. The sort may simply have been the last application work before the system detected corruption elsewhere.

The MediaRemote path is nevertheless a high-priority boundary to audit. CocoaSpice currently publishes a locally constructed `[String: Any]` Now Playing dictionary from the main-actor-owned `RemoteTransportController`:

- `CocoaSpice/Sources/CocoaSpice/App/RemoteTransportController.swift`
- `CocoaSpice/Sources/CocoaSpice/App/PlayerViewModel.swift` (`updateRemoteTransportState`)

The crash report refers to an Apple playback-queue request rather than directly naming `nowPlayingInfo`, so this is a lead, not a confirmed root cause.

The source audit found one concrete amplification risk: `PlayerViewModel.startPlaybackTimer()` runs every 250 ms and calls `updateRemoteTransportState()`. Because the elapsed position changes on each tick, the existing equality check did not coalesce normal progress. This allowed up to four asynchronous `MPNowPlayingInfoCenter` metadata publications per second for the lifetime of a playback session.

The first hardening slice now:

- coalesces ordinary elapsed-position updates to one publication per second;
- still publishes immediately for track, title, duration, play/pause, and large seek changes;
- sanitizes elapsed and duration values to finite, non-negative numbers before the MediaPlayer boundary;
- uses explicit `NSNumber` values for the numeric MediaRemote fields; and
- adds pure unit coverage for the publication policy and sanitization.

This reduces pressure on the suspected system boundary but is not yet a demonstrated fix for the heap corruption.

Verification for this slice: `swift test` in `CocoaSpice/` built the executable and test bundle successfully; 60 tests passed. Optional archive-backed tests were skipped because their fixture environment variables were not set.

Other live possibilities include:

- an earlier out-of-bounds write or use-after-free in a decoder/audio bridge;
- mutable playlist or metadata state being observed while it is replaced or sorted;
- an object crossing into MediaRemote/Foundation with an unsafe lifetime or unexpected value;
- a race between playback completion, playlist metadata refresh, and remote transport publication;
- an Apple framework failure triggered by malformed or unusually large queue metadata.

Do not currently classify `PlaylistPresentation.compare` as the root cause. The report only shows that it was active on the main thread.

## WIP to-do

### P0: preserve and identify the exact build

- [ ] Keep the complete original crash report with the incident record. The pasted source used for this document was `/Users/john/.codex/attachments/9c9401ca-348d-4193-bcde-01b8f8db1a94/pasted-text.txt`.
- [ ] Record the exact app bundle, executable build, commit, and matching dSYM for the crashed `0.1.0 (1)` build.
- [ ] Symbolicate all CocoaSpice frames before changing code. In particular, confirm the source revisions for `applyPlaylistSort`, `refreshPlaylistMetadata`, `finishPlaybackRequest`, and `updateRemoteTransportState`.
- [ ] Record whether the crash followed a normal end, Repeat Song, manual sort, queue replacement, or a remote-control request. The report alone does not include the user action.

### P0: isolate the boundary

- [ ] Add a reproducibility switch or test build that disables MediaRemote publication while leaving playback and playlist sorting enabled. Compare stability under the same playback/playlist workload.
- [ ] Run the inverse comparison: keep MediaRemote enabled with playlist sorting and playback completion exercised, then disable only the relevant queue/Now Playing update path if the implementation allows that distinction.
- [ ] Stress the sequence `track ends -> finish playback -> refresh metadata -> apply sort -> publish Now Playing` with large and changing playlists.
- [ ] Run with the strongest practical malloc diagnostics for the app build, such as Guard Malloc, Malloc Scribble, and Address Sanitizer where the target can be built with them. Record which instrumentation was actually active.
- [ ] Check for decoder/bridge writes that can corrupt process memory before MediaRemote is called. Prioritize C bridges and buffers touched during playback completion.

### P1: audit ownership and serialization

- [ ] Ensure every value sent to MediaRemote is an immutable, primitive snapshot created before the framework call; never expose live playlist arrays, mutable metadata containers, decoder objects, or Swift storage with a shorter lifetime.
- [ ] Audit whether any MediaRemote call can be initiated concurrently with an update to the source playlist or current-track metadata.
- [ ] Confirm all `RemoteTransportController` calls remain main-actor serialized and that no callback retains application-owned mutable state across the framework boundary.
- [x] Add pure coverage for repeated Now Playing publication coalescing, immediate state/seek changes, and numeric sanitization.
- [ ] Add an integration test for repeated Now Playing publication while tracks are completed, sorted, replaced, and removed.
- [ ] Add logging around publication generation, playlist count, current-track identity, title/album lengths, duration, and elapsed time. Avoid logging full paths or unbounded metadata.

### P1: verify the playlist-sort path independently

- [ ] Exercise `PlaylistPresentation.compare` with empty strings, long Unicode strings, duplicate titles, changing metadata, numeric-looking titles, and concurrent refresh requests.
- [ ] Confirm `applyPlaylistSort` always sorts a private value snapshot and does not mutate an array or metadata map being used by another task.
- [ ] Confirm completion handling cannot start overlapping `refreshPlaylistMetadata`/sort operations for multiple playback generations.

### P2: hardening after reproduction

- [ ] If MediaRemote is implicated, introduce one narrow shared snapshot/publish boundary and test it in CocoaSpice before considering SPCBoy parity.
- [ ] If an audio/decoder bridge is implicated, reduce the reproducer to the smallest format and playback transition before modifying the bridge.
- [ ] Add the final cause, reproducer, fix, and verification evidence here or in the owning subsystem note once the investigation is complete. Do not turn this WIP report into a changelog.

## What is not established

- The crash is not yet proven to be caused by playlist sorting.
- The crash is not yet proven to be caused by MediaRemote; MediaRemote may be where earlier heap damage was detected.
- No evidence in this report identifies UADE, MDX, a particular decoder, or a particular media file as the source.
- The current publication change is a mitigation only; no root-cause fix should be declared until the crash boundary is reproduced or otherwise confirmed.

## Source and ownership references

- Crash source: the pasted macOS translated report listed above.
- MediaRemote integration: `CocoaSpice/Sources/CocoaSpice/App/RemoteTransportController.swift`.
- Playback-completion caller: `CocoaSpice/Sources/CocoaSpice/App/PlayerViewModel.swift`.
- Shared queue policy: `FrontendCore/Sources/PlaybackQueueCore/PlaybackQueueNavigation.swift`.
- Shared playback transport: `FrontendCore/Sources/PlaybackTransportCore/PlaybackTransportCoordinator.swift`.
