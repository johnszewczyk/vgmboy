# Shared playback workflow consolidation plan

Status: research and implementation plan, 2026-10-28. No implementation or
runtime playback verification is implied by this document. Recheck all paths,
working-tree changes, and findings before implementing after the next session.

## Objective and boundaries

SB2, ViewBoy, and CocoaSpice should use one efficient, coherent playback
workflow through the shared playback core. This means one shared implementation
and one independent coordinator/session per app process; it does not require a
cross-app service or one audio session shared between running applications.
Preserve each product's interface, queue behavior, preferences, history,
metadata, and supported sources. The shared workflow owns playback decisions;
frontend adapters translate user intent and display authoritative results.

| Responsibility | Owner |
| --- | --- |
| Decode, source preparation, timing, playback session and audio output | VGMBoy / VGMBoyKit |
| Shared frontend transport coordination, generation and event routing | FrontendCore / PlaybackTransportCore |
| App-specific controls, navigation, queue policy and presentation | SB2, ViewBoy, CocoaSpice |
| Archive and UAC interpretation | Existing owning components; preserve their contracts |

Review direct PlaybackController clients, including VGMBoy itself, and affected
shared clients such as LineBoy. Investigate hosted SBONLINE integration before
changing a shared contract it consumes; do not alter its separately owned
production deployment as part of this plan without an explicit cross-project
scope. Avoid introducing a second playback engine or frontend-specific transport
implementation.

## Research findings to reproduce

These are source observations and risk hypotheses, not confirmed packaged-app
or audible failures. The working tree contains ongoing playback changes, so
recheck exact code and report the revision and dirty inputs used for each result.

1. `PlaybackTransportCoordinator` already centralizes part of the workflow, but
   SB2 and ViewBoy's WebKit bridges apply tempo and playback mode separately;
   CocoaSpice uses the coordinator's `reconfigureCurrentTrack`. In
   `VGMBoyKit/PlaybackController.swift`, changing mode can reload the session
   and change its generation. The coordinator's low-level `perform` updates
   its expected generation on explicit load, so a reconfiguration-induced reload
   may leave its natural-end gate expecting the old generation. ViewBoy's
   renderer also appears to retain the start generation after reconfiguration;
   SB2 has a generation update path. Trace both event filters and reproduce
   before labeling either a defect.
2. `PlaybackSession.finishReachedEnd` queues a completion without an attached
   generation, and the controller later reads session status. A replacement
   between those steps could attribute an old completion to a new session. This
   interleaving is a hypothesis; exercise it deterministically.
3. Direct session tempo changes pause and discard queued audio before priming;
   the decoder may already be ahead of the audible position. This can cause a
   skip, and direct status tempo may remain stale because `currentTempo` is not
   updated on that path. Check actual call paths: the WebKit adapters currently
   follow tempo with a mode operation, while CocoaSpice reloads through its own
   route. Measure instead of assuming every frontend is affected.
4. Shared preference normalization allows 1/32–8× while `VGMDecoder` clamps
   to 0.05–4×. Identify each backend's real effective range, persisted values,
   display, and format-specific behavior before selecting a compatibility policy.
   Never silently present a requested rate as effective if the backend clamps it.
5. The controller's conversion of millisecond play/fade values to whole seconds
   may turn a positive subsecond limit into zero. This is an API contract risk;
   establish actual callers, fixtures, and intended zero semantics before changing
   it. Existing frontend controls commonly use whole seconds.
6. Current uncommitted session work includes long-play repetition, frame tracking,
   and seek logic. It is an input to coordinate with and preserve, not a baseline
   to reset. Review its final form before designing a consolidation around it.

Relevant entry points: `FrontendCore/Sources/PlaybackTransportCore/PlaybackTransportCoordinator.swift`,
`VGMBoy/Sources/VGMBoyKit/PlaybackController.swift`,
`VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift`,
`VGMBoy/Sources/VGMBoyKit/VGMDecoder.swift`,
`SB2/Sources/SB2/WKPlaybackBridge.swift`,
`ViewBoy/Sources/ViewBoy/WKPlaybackBridge.swift`, and
`ViewBoy/Sources/ViewBoy/Resources/yoga-app.js`.

## Required behavior contract

- Serialize each session's start, replacement, reconfiguration, seek, pause,
  resume, fade, stop and end handling. Define ordering and cancellation of
  overlapping operations; reject stale commands and events without blocking the
  audio callback. Keep real-time callback work free of new locks, allocation or
  blocking I/O, and retain existing output/declick behavior.
- Return an authoritative status snapshot containing source identity, playback
  generation, effective settings, position and state. A reload gets a new
  generation; an operation that retains the session does not. Publish status
  and generation together and propagate them through native and WebKit adapters.
  End events carry the originating generation, fire at most once after output
  drains, and cannot advance a replacement track. Decide and document which
  operations invalidate an in-flight request.
- Define audible position separately from decoded, produced, enqueued and
  consumed frames. Specify source-time and output-time conversion under tempo,
  seek, loops and repeats, including decoder seek precision and partial enqueue,
  zero-read and error handling. Reconfigure from the audible point where the
  backend supports it; document and measure any unavoidable discontinuity rather
  than promise sample-perfect playback without evidence.
- Preserve pause and buffered-output semantics, volume, mono, EQ, progress,
  playback modes, loops, fades, skip behavior, remote controls and progress/end
  ordering. Verify preview timing uses the same effective policy as playback.
  Preserve authoritative UAC loop metadata and archive member/dependency
  lifetimes, including in-memory SPC/SAP and other supported source paths.
- Define failure and replacement semantics explicitly: after a failed start or
  reconfiguration, return a consistent state and error, release resources and
  never expose a stale loaded track as playing. Preserve the old session only
  when the native resources and chosen transactional boundary make that safe.
- Keep frontend queue ordering, repeat/shuffle, timed skip, navigation,
  history/favorites, persistence, remote controls, user settings and source
  identity in their existing owners. An accepted start/end must not create a
  duplicate history entry or advance the wrong queue item.

## Implementation sequence for a later session

### 0. Establish the exact baseline and reproduce

1. Follow DocMan, family, and each touched owner's intake. Record branch, HEAD,
   upstream, working-tree changes and toolchain; inspect ongoing edits and
   coordinate ownership. Preserve all unrelated and concurrent work. Do not
   reset, clean or overwrite the dirty playback files.
2. Map all coordinator and direct-controller callers, requests, status messages,
   event payloads and frontend generation filters. Map archive materializer
   ownership and the lifetime of temporary files and in-memory data. Record
   effective tempo ranges, duration rounding, UI option values and persisted
   preference migration requirements.
3. Build minimal reproducible cases for the suspected stale-generation/end race,
   replacement during queued completion, tempo position discontinuity and
   subsecond duration. Distinguish source reasoning from observed failures.
   Verify fixture provenance and exact source; prior temporary plugin fixtures
   may no longer exist. Use representative read-only local fixtures and never
   mutate a music collection. Record a baseline for CPU, allocations and audio
   discontinuity where measurement is feasible.

Gate: a caller/event map and reproducible observations or clearly labeled
unreproduced risks, with an agreed interpretation of effective tempo, zero
length and position for each relevant backend.

### 1. Make session identity and lifecycle reliable

Carry the originating session/generation through completion and coordinator
handling. Make status publication and generation handoff coherent for every
operation that can reload, including both WebKit renderers. Cover late callbacks,
stop/replacement, failure and drain ordering. Implement against the current
session changes instead of replacing them. Keep any API migration coordinated
across all callers in the same family change.

Gate: deterministic event-order cases show one correct end for the live session,
no old-session advancement, and matching native/renderer generations. Confirm
error and resource cleanup behavior for failed replacement.

### 2. Consolidate the playback transaction

Design a typed shared request/result for the existing start and reconfigure
operations. Route each frontend through the same coordinator operation, applying
mode, tempo, seek and other relevant settings as one ordered transaction.
Determine whether a setting can be applied in place or needs a reload; do not
force unnecessary reloads. Define the effective tempo and precision policy from
phase 0, preserve existing persisted values or migrate them explicitly, and
make the reported effective values match playback and preview.

Gate: equivalent requests from the three apps produce equivalent effective
core settings and position without an intermediate end or queue advance;
frontend-specific queue and display policy remains intact.

### 3. Simplify the session producer

Only after behavior is characterized, consolidate duplicated prime/refill and
long-play handling into a single producer path where practical. Keep source,
output, enqueued and audible frame accounting explicit. Preserve repeat/loop
mapping, fade and drain behavior, pause/resume and decoder error reporting.
Measure callback cost and audio transitions against the baseline; roll back or
revise changes that regress timing or audible continuity.

Gate: fixtures exercise ordinary end, natural looping, repeat and faded long
play, seek near boundaries, partial/zero decode and failure. Position remains
monotonic where appropriate, and playback ends exactly once after draining.

### 4. Adapt and verify the products

Migrate SB2, ViewBoy and CocoaSpice in small reviewable steps to the shared
transaction and authoritative status, removing duplicated transport decisions
only when their behavior is covered. Verify ViewBoy's renderer generation
handling explicitly. Check direct VGMBoy callers and affected LineBoy/hosted
integration for API compatibility. Preserve app-specific options, selection,
archives, queue, navigation and persistence; update implemented current-state
subsystem documentation with the final behavior.

Gate: all three apps exercise the same core sequence for equivalent actions,
while each retains its own queue and UI behavior. Any unsupported format or
frontend difference is documented with evidence, not silently normalized.

### 5. Verification and release evidence

Use layered evidence, recording commands, source revision, dirty inputs, fixture
identity, formats, app build and observed results:

- Focused coordinator/session checks: overlapping commands, generation changes,
  queued old completion, exactly-once end, replacement failure, cleanup and
  progress ordering. Include tempo endpoints, persisted out-of-range values,
  subsecond and zero duration, loops/fades and in-memory/archive sources.
- Package and renderer checks for touched owners; `scripts/verify-family.sh`
  covers several family packages but does **not** cover SB2 or LineBoy. Select
  their own applicable checks explicitly. SB2's `ai/AGENTS.md` says not to add
  tests or run test suites unless requested: obtain authorization through the
  implementation request before doing either. CocoaSpice's instructions prefer
  human testing unless a quick sanity check suffices.
- Build and launch the actual packaged apps; exercise start, pause/resume, seek,
  tempo and mode changes during playback, natural end, next/previous, queue
  repeat/shuffle, timed skip, failure/retry and reopen/persistence. Check that
  status, progress, track identity and history stay consistent. Verify archive
  dependencies and representative formats including UAC loop metadata.
- Capture or listen to representative audible transitions, comparing position
  and waveform around reconfigure, pause, loop/fade and drain. Claim seamless
  continuity only with appropriate sample-level evidence. Record any unavailable
  devices, fixtures, format coverage, OS/toolchain or packaged-UI limitations.
  After decoder dependency changes, rebuild and restage native products; package
  tests alone do not establish packaged app behavior or audible output.
- Update owner documentation and this plan's status as work completes. Run
  applicable documentation checks, inspect the task-only staged diff, commit
  verified task-owned files from the family Git root, and push when an upstream
  exists. Preserve all unrelated changes.

Deliver a concise verification report identifying passed checks, reproduced and
resolved risks, remaining gaps and any behavior decisions made. A clean build
alone is not proof of frontend compatibility or audible playback.
