# Shared playback workflow consolidation plan

Status: research and staged implementation plan, 2026-10-28. See the checkpoint
below for the first pass and its verification limits; remaining phases are open.
Recheck paths, working-tree changes, and findings before continuing.

## Implementation checkpoint, 2026-10-28

- Reload-boundary pass, 2026-10-29: replacement preparation remains outside
  the active session, and the prior audible position is now captured after the
  old transport pauses and completes its short ramp. A focused integration
  test used a temporary wrapper that delayed 7zz by 0.5 seconds: playback
  advanced during archive preparation, and the replacement resumed at or
  beyond the position observed during preparation. The optional test runs with
  `VGM_TEST_SLOW_ARCHIVE=1` and a deliberately slow `VGMBOY_7Z_BINARY`. All
  33 shared-transport tests (including this optional test skipped in the normal
  run), five focused timeline tests, and the three frontend builds passed; the
  slow-archive test passed separately with the wrapper enabled. These checks
  do not establish sample-identical or audible continuity.

- Tempo position pass, 2026-10-29: mode/tempo reloads now translate the
  previous logical output time by the old effective tempo divided by the new
  effective tempo before seeking. Direct tempo changes use the same reload,
  preserve existing timing settings, and update the native generation; an
  unchanged effective rate remains a no-op. Authored-loop seek mapping handles
  the translated logical time, and libvgm Long Play repetition length scales
  with effective tempo. SB2's displayed output-time clock advances at one
  second per second and accepts the translated position after reconfiguration.
  Controlled decoder tests distinguish source tones across one and multiple
  rate changes; controller tests verify translated positions with and without
  authored repeats. All 32 shared-transport tests, five focused VGMBoy
  timeline tests, the SB2 clock projection check and all three frontend Swift
  builds passed. These checks do not establish sample-identical or audible
  continuity, every decoder format, or packaged-app behavior. See the later
  reload-boundary pass above for the status-capture change.

- Loop seek mapping, 2026-10-29: a regression test showed that seeking to
  1.75 seconds in a two-repeat 0.25–0.75-second loop incorrectly ended a
  two-second source at 3.5 seconds instead of 3.0. Session seeking now maps
  logical elapsed output through completed authored repeats and restores repeat
  counts on backward seeks; unbounded loops map through their cycle. Authored
  loop sample bounds also account for the effective native tempo. Four focused
  shared-transport tests passed for finite, backward, unbounded and reconfigured
  loops. A generated eight-second VGM at 2× with two half-second source repeats
  drained at approximately 4.5 seconds; two decoder timeline tests also passed.
  All 31 PlaybackTransportCore tests and all three frontend Swift builds passed.
  This does not yet establish source-position preservation across a speed change
  or sample-identical loop audio, nor does it verify a packaged frontend.

- Controlled tempo timeline, 2026-10-29: `TempoSeekTimelineTests` generates
  an eight-second VGM with a different SN76489 tone each source second. For
  both the installed libgme and the vendored libvgm, after 1× playback followed
  by 2×, a newly opened decoder at 2× sought to `sourceSeconds / 2` produces
  the same tone as the continuous decoder; seeking to the old unconverted
  output time produces a different tone. A second case follows 1×, 2× and
  0.5× segments and confirms `sum(outputSeconds × segmentTempo) / newTempo`
  selects the matching tone. Both focused decoder tests passed. This establishes
  the seek-coordinate relationship for this synthetic SN76489 VGM through the
  tested libraries; it does not prove sample-identical output, every libgme
  format, loop mapping, or audible continuity. A session fix must account for
  buffered old-rate PCM, loop repeats, elapsed-time presentation and effective
  rates, not just multiply the last elapsed counter by its most recent tempo.

- Effective tempo pass, 2026-10-29: the shared format registry now resolves
  the wrapper's accepted multiplier (libgme 0.02–4×, libvgm 0.05–4× rounded
  to 0.001, unsupported families 1×). Session status, shared timing preview,
  ViewBoy timing preview, CocoaSpice playback timing and SB2 track timing use
  that rate while the saved requested preference remains unchanged. Direct
  commands that resolve to the current effective tempo no longer clear queued
  PCM; direct changes to a different effective tempo still need the position
  and buffer work below. All 28 PlaybackTransportCore tests passed, including
  endpoint, paused-PCM and archive cases, and all three frontend Swift builds passed.
  A focused SB2 JavaScript projection check verified the 8× and 1/32× libvgm
  cases. This is not packaged-UI or audible verification; backend behavior at
  other versions and source-time mapping still need validation. The existing
  macOS 26/27 linker warnings remain.

- Explicit-loop verification, 2026-10-29: a generated two-second PCM source
  with a supplied 0.25–0.75-second loop and two repeats was started through
  `PlaybackTransportStartRequest`, reconfigured through the shared operation,
  and completed after approximately three seconds with an empty output ring.
  The focused FrontendCore test passed and verifies that the supplied loop
  payload survives this reload. It does not verify UAC manifest parsing,
  sample-level loop continuity, tempo changes inside a loop, or packaged UI.

- Tempo range research, 2026-10-29: on macOS 27.0.1 with the installed
  Homebrew game-music-emu 0.6.5, temporary decoder harnesses rendered 131,072
  frames in 4,096-frame calls at 1/32×, 0.05×, 1×, 4× and 8×. SPC and GBS
  produced identical non-silent PCM at 4× and 8×, while their 1× and 4×
  outputs differed. GBS produced different PCM at 1/32× versus 0.05×; SPC
  produced identical non-silent PCM for that pair. The vendored libvgm VGM
  fixture produced identical non-silent PCM at 4× and 8×, consistent with the
  wrapper's 4× clamp; its first 131,072 low-tempo frames were silent, so the
  low-end PCM comparison does not independently establish effective speed.
  These are fixture-specific observations, not a universal capability matrix.
  `sos.gbs` SHA-256:
  `dc753eb0426082f1134246dc15e4ee84668f93f61330606dd94ca785960436d8`.
  The transcript is `/private/tmp/vgmman-tempo-range-research.log` while it
  exists. Do not silently display 8× as an established effective rate; decide
  how to expose per-backend effective rates and preserve persisted preferences
  before changing the shared UI range.

- Archive verification, 2026-10-29: a generated ZIP containing the vendored
  SPC fixture was loaded, played and reconfigured, then its source archive was
  removed. A further reconfiguration failed during preparation while the
  original generation remained loaded and playing. A second generated ZIP
  contained the `ending3.txtp`/`ending3.rsf` dependency pair from the prior
  plugin fixture set. After the same preparation failure, its active session
  stayed loaded and playing and could seek and refill its ring. Both focused
  FrontendCore tests passed. These checks establish the exercised native
  transport and dependency preparation paths, not audible or packaged-UI
  behavior, PSF-family dependencies, or UAC loop handling. The optional TXTP
  test requires `VGM_TXTP_ARCHIVE_FIXTURE_DIR` and skips if it is not set.
  Fixture SHA-256 values: TXTP
  `4980c5ed7d4bc65c1cc984387208eeb7cf8818bae08424288f8f5b5ddf243c66`, RSF
  `b07ca78bb9998177a219d3cf8f5b20822113a342abac28283e29c73848317`.

- Fourth pass, 2026-10-29: priming and periodic refill now use the same buffer
  producer, preserving their existing distinct error/publication paths. Ten
  focused FrontendCore integration checks passed, including bounded Long Play
  with a fade on real SPC and VGM fixtures and natural-end delivery after the
  output ring drained. SB2, ViewBoy and CocoaSpice Swift builds and both
  documentation checks passed. This verifies those paths, not audible
  continuity, loop transitions, partial writes or complete packaged-app behavior.
- An exploratory PCM comparison rendered two seconds at 1×, switched to 2×,
  and compared the next 4,096 left-channel samples against newly started
  decoders at 2× after seeks of 0.5, 1, 2 and 4 seconds. The SPC fixture's mean
  absolute differences were 0.0794, 0.0409, 0.0728 and 0.0749; the VGM
  fixture's were 0.2207, 0.1616, 0.1797 and 0.1576. Decoder startup/seek state
  and waveform phase were not controlled, so these scores do not establish the
  correct seek conversion. The libvgm source confirms its sample-to-tick mapping
  changes with playback speed; verify GME and multi-segment tempo behavior with
  a controlled timeline before changing position semantics. Fixtures: vendored
  `f-zero - big blue.spc` SHA-256
  `c2e3fbc4ecee60a2f9102acd374387438ac3a9ba5bfaca2f02a12fc6315bee85`;
  `TwinCobra.vgm` SHA-256
  `4d2c6b387499cac407bd969d92c88b6a32285bc965e0452ef6a0294ea2107ebc`.
  The exploratory harness was temporary; its transcript is
  `/private/tmp/vgmman-tempo-seek-research.log` while that file exists.

- Third pass, 2026-10-29: SB2 and ViewBoy send the shared typed
  reconfiguration request, and CocoaSpice's timing-plan route invokes the same
  coordinator operation. Mode and tempo are applied in one controller reload;
  unsupported decoder families receive 1×. Existing queue and app presentation
  remain separate. This replaces the WebKit adapters' preceding in-place tempo
  operation, but does not resolve source-time versus output-time seeking or the
  direct tempo API's buffer handling and effective libvgm range.
- Focused integration checks cover paused/playing transitions, end delivery,
  unsupported tempo, CocoaSpice's native-plan entry and 1.5× reported status for
  vendored SPC and VGM fixtures. Nine focused FrontendCore tests passed. The
  existing libvgm fixture test also observed different PCM at 2×, but does not
  measure a live reconfiguration transition. Reported tempo alone is not audible
  or effective speed proof. SB2, ViewBoy and CocoaSpice Swift builds passed; packaged UI,
  audible output, live seeking at changed tempo and archive-backed transitions
  remain open. The pre-existing ViewBoy renderer failure and macOS 26/27 linker
  warnings remain applicable.

- Second pass: ordinary status callbacks are generation-filtered before
  publication; failed replacement clears partial session and controller state
  once native replacement begins, while failure during source preparation keeps
  the old session. Failed mode preparation restores prior mode settings. Both
  typed start and reconfiguration paths now clear track identity when a
  replacement or its follow-up seek/play fails. These boundaries do not yet
  constitute the shared atomic reconfiguration transaction in phase 2.
- Focused integration coverage exercises delayed old status, failed archive
  preparation, missing-decoder replacement, typed-start failure, retry, reload
  end and delayed completion. It uses generated silent WAV files; dependency
  archive leases, injected prime/seek/play failures, packaged UI, and audible
  behavior remain unverified. Six focused FrontendCore tests and SB2, ViewBoy
  and CocoaSpice Swift builds passed; these do not prove packaged playback.
  Homebrew FFmpeg and libsidplayfp still produced macOS 27 versus target
  macOS 26 linker warnings.

- Family work in progress was captured and pushed as `e8de10f2`; this is a
  checkpoint, not a verified release. The generated Python bytecode cache was
  left untracked. The checkpoint contains Markdown hard-break trailing spaces that
  `git diff --check` reports.
- First pass: a drained session's captured status now accompanies its end
  callback; the coordinator updates generation after low-level mode reloads
  and filters stale end events before publication. ViewBoy adopts new native
  generations and guards delayed reconfiguration replies by playback token and
  track ID. The public zero-argument session completion API remains available.
- Four focused FrontendCore tests passed, including live silent-WAV reload/end
  and a deliberately delayed completion after replacement. Swift builds of SB2,
  ViewBoy and CocoaSpice and the ViewBoy JavaScript syntax check passed. The existing YogaCanvas test failed at
  its LCD dot default assertion before playback checks; the same failure was
  reproduced from the clean checkpoint in a temporary archive. Its new playback
  assertion is therefore not yet verified. No packaged frontend interaction or
  audible comparison was performed. Linker warnings report macOS 27 Homebrew
  dylibs linked into macOS 26 targets.
- Continue phase 1 with packaged SB2/ViewBoy/CocoaSpice verification and
  ViewBoy renderer tests, including a completion arriving before a
  reconfiguration reply and rapid replacement. Audit queued ordinary status
  events across replacement as well as the now-filtered end events. Then address failure cleanup,
  audible-position/tempo semantics and the shared typed transaction in later
  phases; this pass does not complete the consolidation.

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

These observations were recorded before the first pass above. They are source observations and risk hypotheses, not confirmed packaged-app
or audible failures. The targeted sweep below adds bounded shared-core runtime
reproductions. The working tree contains ongoing playback changes, so
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

## Targeted sweep results and reproduction recipes

Sweep baseline: family HEAD `fb3a7180`, 2026-10-28, with pre-existing
uncommitted edits including `PlaybackSession.swift` and `VGMDecoder.swift`.
The observations below describe that working tree, not necessarily the commit
alone. They are source-level findings unless explicitly labeled as a runtime
result. Recheck them when implementation begins; in-flight edits may change them.

### Generation and end-event handoff

- Concrete source path: the WebKit bridges call `perform(.setTempo)` then
  `perform(.setPlaybackMode)`; the latter calls controller
  `configurePlaybackMode`, which reloads the current source through
  `PlaybackSession.load`, increasing generation. Coordinator `perform` updates
  `currentPlaybackGeneration` for `.load`, but not `.setPlaybackMode`. Its
  `publish` then compares the ended status generation to that stored value.
  Therefore, if a mode reload occurs through this path, the later natural-end
  notification is rejected in the controlled shared-core reproduction below;
  the resulting behavior in each packaged frontend remains unverified.
- ViewBoy's `applyNativeStatus` updates `nativeGeneration`, whereas
  `handleNativeEnded` compares against `playbackGeneration`; the latter is set
  from the start response, and the settings reconfigure response only calls
  `applyNativeStatus`. A new-generation end would therefore also be rejected by
  this renderer if delivered. SB2 explicitly allows a native generation change
  when applying its reconfigure response; its JavaScript `playbackGeneration`
  is a separate frontend request token. Do not merge those two identities.
- CocoaSpice calls the coordinator's typed `reconfigureCurrentTrack`, whose
  internal `load` refreshes `currentPlaybackGeneration`. It still needs the
  asynchronous completion-origin audit and position/tempo checks; do not infer
  the WebKit-specific mismatch applies identically to it.
- `finishReachedEnd` schedules a zero-argument callback on main. The controller
  samples `session.status()` when that callback executes; a replacement in
  between can make the event carry the replacement's status. Even a matching
  generation gate cannot detect an old event mislabeled this way. Reproduce by
  holding delivery of the callback, replacing the session, and then releasing
  it; assert no end or retirement for the replacement. Also control ordering
  between queued status and reconfiguration response to test both renderers.
- Existing `PlaybackNaturalEndGateTests` check a gate supplied with explicit
  matching/mismatching integers. They do not exercise controller reload,
  callback provenance, bridge delivery, or either renderer. Add those integration
  scenarios at implementation time in authorized test owners.

### Tempo capabilities and timing

- `FormatRegistry` marks only libgme and libvgm as tempo-capable. SB2 and
  ViewBoy resolve the descriptor from the source/member extension and send 1×
  for unsupported families; CocoaSpice and the coordinator's typed `setTempo`
  also gate on the registry. Several decoder `setTempo` implementations are
  intentionally no-ops. Preserve this existing capability behavior when moving
  policy into the shared workflow; do not assume every backend can change rate.
- Shared preferences normalize 1/32–8× in 1/32 steps; libvgm clamps to
  0.05–4× and rounds to 1/1000 before applying it. That yields a concrete
  mismatch at 1/32× and above 4×, but libgme's effective limits and actual
  error handling require backend-specific verification. `VGMDecoder.setTempo`
  frees a returned error without surfacing it, so determine how the underlying
  API signals rejection before defining authoritative effective status.
- `AudioOutput` is configured for 44,100 frames/sec and a 2-second ring;
  priming targets half capacity and refill targets 75% in 4,096-frame chunks.
  These imply nominal targets of 1 and 1.5 seconds of queued output, with chunk
  overshoot and callback timing affecting actual occupancy. They are not an
  observed skip duration. Direct `setTempo` ramps/pause-stops output, clears
  queued PCM and primes from the decoder's current position without an explicit
  rewind. Capture `bufferedFrames`, audible position and waveform immediately
  before/after this operation while paused and playing; repeat at 1/2×, 1× and
  2× on exact libgme and libvgm fixtures, including a near-end transition.
  Compare source-time and output-time separately and account for the 10 ms
  gain ramp. The WebKit sequence then reloads and seeks, so measure its full
  sequence separately rather than extrapolating from direct `setTempo` alone.
- `sessionFrames` advances by decoded frame count before `output.write`; the C
  ring writer can return fewer frames than requested, while the Swift producer
  currently only checks for a zero return. Audit whether reachable ring capacity
  and chunk sizes can cause partial writes, and exercise one deterministically.
  A short write could desynchronize frame accounting and discard a decoded tail;
  this is a source-level possibility, not an observed underrun or audio defect.
- `setTempo` does not assign `currentTempo`, while load does. Compare status
  after a direct tempo update with controller-loaded settings and actual output;
  do not use a status value alone as proof that a decoder applied the rate.

### Archive replacement and failure boundaries

- Controller load prepares a *new* `ArchiveMaterializer` before opening the new
  session, retains the old materializer until the new session loads, swaps on
  success, and defers release of the new materializer on failure. The independent
  export path owns and releases its own materializer. Preserve this separation;
  frontend browsing/artwork cache leases are a different owner.
- Failure before `session.load` can leave the old native session running, though
  mode fields may already have been changed. Once `session.load` starts it calls
  `releaseCurrent` before creating the new decoder; a subsequent open/start/
  prime failure can leave controller `loaded` and the old materializer retained
  even though the old decoder has been released. A prime failure may also leave
  partially initialized new session state. This is a source-level failure-path
  analysis; test injected failures at materialization, decoder creation/start,
  prime, seek and output start before choosing rollback or explicit stopped/error
  semantics. Check `currentTrack`, generation, loaded state, on-disk lease and
  subsequent stop/retry at each point.
- Test replacement and cancellation with selected-member archives, a
  dependency-complete PSF or equivalent, UAC loop metadata and in-memory SPC/SAP.
  Verify a late end cannot release the replacement's lease or advance its queue.
  Existing extracted files in a cache do not prove the decoder's lease is live.

### Evidence and practical fixture notes

On the sweep baseline, temporary FrontendCore test harnesses used generated
silent stereo PCM WAV files at 44,100 Hz; the harnesses and files were removed
immediately afterward. These observations are shared-core runtime evidence,
not packaged-app or audible comparisons:

- A one-second timed load and play, followed by low-level `setPlaybackMode`,
  changed generation 1 to 2. After three seconds status reported
  `reachedEnd=true`, `isPlaying=false`, and the natural-end handler had received
  **zero** events. An otherwise equivalent no-reconfigure control reached end
  with **one** handler event. This demonstrates the shared-core mismatch on
  this fixture and command path; reproduce through each actual frontend before
  asserting the resulting UI or queue symptom.
- A paused six-second WAV load primed 45,056 frames. A direct low-level
  `setTempo(2)` changed reported elapsed position from 0 to 1.021678 seconds,
  retained 45,056 buffered frames after re-priming, and reported tempo 1.0.
  WAV's decoder does not support native tempo, and this experiment deliberately
  bypassed frontend capability gates. It demonstrates the session's buffer/
  status behavior, not an audible or supported-format tempo result. Repeat with
  tempo-capable real fixtures and the complete frontend request sequences.
- Two existing FrontendCore gate tests passed using `swift test --package-path
  FrontendCore --filter 'naturalEndPublishesOnceForTheActiveGeneration|staleNaturalEndCannotPublishAfterReplacement'`.
  The temporary harnesses ran with individually filtered Swift tests and are not
  permanent regression coverage. Test linking warned that Homebrew FFmpeg and
  libsidplayfp dylibs target macOS 27 while the package targets macOS 26; these
  checks do not establish macOS 26 compatibility.

The prior temporary fixture directory and `bionic.sid` existed during this
sweep; the SID SHA-256 was
`8677c86ff14c26ac2d5280bb014b642aa0dbbdddb0ec7608e5201ec61ee326a9`.
Temporary paths are disposable and may disappear. SID is useful for unsupported
native-tempo coverage, not as a libgme/libvgm speed fixture. Find and fingerprint
separate exact fixtures for those engines, plus representative UAC and dependent
archives, before claiming coverage. No waveform capture, packaged-app run or
audible playback comparison was performed during this source sweep.

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
