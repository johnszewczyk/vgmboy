# Shared playback workflow consolidation plan

Status: implementation and verification remain in progress. SB2 is the primary
interface and the only frontend in the current regression-testing scope, per
user direction. Finish the shared VGMBoy and FrontendCore work using SB2 before
returning to ViewBoy and CocoaSpice; LineBoy is deprecated and excluded. Earlier
cross-frontend checkpoints are historical evidence, not current scope. Recheck
paths, working-tree changes, and findings before continuing.

## Remaining work, 2026-10-30

The checkpoints below are historical; later entries may resolve earlier gaps.
The remaining work is grouped by the current SB2-first scope:

1. Verify the current SB2 faded handoff in a packaged app: prove the fade is
   queued before a missing or valid replacement; exercise a second Next/Previous,
   direct selection, old-session end during preparation, and newer stop/start.
   Check track identity, output gain, queue and history, not just the clock.
2. Assess what remains duplicated between SB2's renderer and shared transport,
   especially queued-fade lifecycle and cancellation. Move UI-neutral ownership
   to FrontendCore where its contract can preserve the existing queue behavior;
   do not treat renderer-only consolidation as shared-module completion.
3. Finish the shared producer and transport verification gates: live drain and
   exactly-once end, loop/repeat boundaries, partial/zero/error decoding,
   reconfiguration while paused or buffered, and representative archive/UAC
   sources including dependencies and authored loop metadata. Distinguish cases
   already covered by injected or native tests from missing packaged coverage.
4. Measure live audio transitions and callback performance around pause, fade,
   seek, loop, speed and mode changes. Controlled offline PCM results do not
   prove live audible continuity or performance; investigate any regression.
5. Complete the SB2 end-to-end matrix: repeat/shuffle, timed skip, rapid controls,
   failure/retry, WebView recreation and persistence, plus effective tempo and
   timing for representative formats. Check supported macOS packaging, including
   the previously observed macOS 26/27 dependency linker warnings.
6. After the shared module and SB2 gate are complete, return to ViewBoy and
   CocoaSpice for adapter migration and compatibility/regression checks. Review
   direct VGMBoy clients and any affected hosted integration before declaring
   shared API compatibility. LineBoy remains excluded.
7. Refresh owner documentation, run the applicable package and documentation
   checks, record fixture and release evidence, and commit/push task-owned work.

No reliable percentage is assigned: implementation is substantial, but the
remaining live verification and deferred frontend work are not yet bounded.

## Implementation checkpoint, 2026-10-28

- SB2 stale start error, 2026-10-30: an older failed start could show its error
  after a newer playback intent began. A renderer check reproduced the stale
  toast; errors now display only for the current intent, including after an
  asynchronous gain restore. The focused four-case recovery check and the full
  50-case renderer run passed. No native or packaged app build was attempted in
  this disk-constrained pass.

- Slow-archive retry interrupted, 2026-10-30: a concurrent disk-space cleanup
  removed temporary verification and Swift build directories during a retry,
  causing a build-database disk I/O error. The retry and a subsequent dependency
  rebuild were stopped; neither is verification evidence. Earlier completed
  checks remain as recorded. Before further builds, check available disk space,
  use bounded build output and avoid recreating large caches unnecessarily.

- Ordered SB2 output ramps, 2026-10-30: with fades active, detached native
  workers can reorder fade and restore requests for the same generation. SB2
  now reserves a shared transport ramp revision at message receipt, and the
  coordinator rejects an older numbered request on its serialized queue.
  Legacy unnumbered calls remain supported. A native integration check sends a
  newer restore before an older fade, verifies rejection and exercises later
  and legacy requests. The full shared transport suite passed 52 tests, the
  SB2 renderer suite passed 50, and SB2 built. This deterministically tests
  command ordering. An isolated release app with test-only fade tracing queued
  a 6,000 ms fade, accepted repeated Next, showed the missing-source error and
  kept the original WAV's clock moving from 0:07 to 0:09. Stop during a later
  queued fade stayed stopped beyond the six-second timer. This did not force
  detached-worker reordering or measure the audible envelope.

- SB2 scalar bridge replies and faded handoff, 2026-10-30: an instrumented
  isolated package using `3656a811` and temporary state showed a valid shared
  fade request returning null: the host serializer rejected top-level numbers.
  Bridge serialization now admits valid JSON fragments and rejects invalid
  values before encoding. A focused test covers numbers, booleans, null, escaped
  strings, objects and nonfinite numbers. After rebuilding, the same test app
  reported a 6,000 ms queued fade. A second Next led to the missing-source
  error while the original WAV continued (0:07 to 0:10); a later faded
  selection started the second WAV and the isolated history recorded it. The
  renderer included a test-only on-screen trace, and its behavior was not an
  audible or sample-level gain measurement. Old-end/stop races and broader
  packaged verification remain open. Full VGMBoy (96), shared transport (51),
  and SB2 playback renderer checks passed on this host.

- Isolated SB2 missing-source check, 2026-10-30: a packaged test app used the
  renderer from `5f96ad8d` (SHA-256
  `7d8e84920d318896581f979a2a3562885d671cac224ab441549bec58a3b35bbf`),
  a separate bundle ID, temporary state and catalog, and generated WAV fixture
  SHA-256 `3b3d841026ae67ff1e39853ee25b3e0edaa4415f184a1b4f844ab4a15390247c`.
  With Faded Skip enabled, a missing ZIP request displayed its error while the
  WAV retained a Pause control and the displayed clock advanced from 0:03 to
  0:09. The UI observations did not establish that the queued fade had begun,
  and do not prove audible gain recovery or repeated-navigation behavior.

- SB2 repeated navigation, 2026-10-30: a second Next/Previous during a queued
  fade now hands off through replacement preparation instead of stopping the
  current session first. Direct track selection superseding a queued fade also
  requests a generation-guarded gain restore on failure. Restore ownership uses
  playback intent rather than renderer generation, so timing replanning does not
  suppress it and a newer intent is not overwritten. All 49 SB2 renderer checks
  and the SB2 build passed. These are simulated renderer and package-build
  checks; packaged interaction and audible envelope behavior remain unverified.

- SB2 faded replacement, 2026-10-30: a completed queued fade now resolves its
  target and calls the existing replacement transaction without retiring the old
  session first. Preparation failure requests a guarded gain restore; newer
  intents are not modified. Native ends are deferred during the handoff and an
  end arriving before it is retained for replay. Renderer checks cover failure,
  duplicate completion, supersession and the early-end handoff; all 44 SB2
  playback checks and the SB2 build passed. This is simulated bridge evidence,
  not packaged or audible proof. A second navigation while a skip is already
  queued still follows the older stop-and-advance path and needs separate review.

- SB2 faded-skip status failure, 2026-10-30: both delayed skip paths now use
  one completion helper. A failed native status lookup cancels the still-current
  skip and requests a generation-guarded gain restore; a late failure leaves a
  newer skip alone. Renderer checks cover failure, supersession and matching or
  mismatched generations. This is simulated bridge evidence, not a packaged or
  audible reproduction. Replacement after the fade still retires the previous
  session before the target is prepared, so failed-target preservation remains
  outstanding.

- AAC export speed, 2026-10-30: SB2 captures one speed for the timing preview
  and export request, and the shared exporter applies the prepared decoder
  family's effective tempo. Missing tempo remains 1x for older callers. Native
  SPC export checks compare decoded samples at 1x and 2x and verify the 4x cap;
  the renderer check covers a setting change during preview. An isolated SB2
  bundle exported the same SPC at normal speed and requested 8x (effective 4x):
  ADTS frame counts correspond to approximately 86 and 26 seconds including
  fade. This verifies rendered files, not a listening test.

- SB2 completion during replacement, 2026-10-29: renderer completion now waits
  while an explicit start or navigation is pending. It replays an end for the
  retained session after failure, drops an old end after successful replacement,
  and retains a new session's end if it arrives before the start reply. Renderer
  checks cover these cases, supersession, stop and newer status ordering. The
  isolated package completed a two-WAV queue with the earlier gate revision;
  the short-new-session race remains simulated, not packaged or audible proof.

- SB2 immediate replacement handoff, 2026-10-29: SB2 now leaves the current
  session and identity in place while the shared start prepares a replacement,
  adopting the new track and staged queue only after an accepted start. It
  checks native status after failure and keeps an unchanged loaded generation;
  failure after native retirement follows stopped-session cleanup. Renderer
  checks cover preserved and retired failures, delayed success, supersession
  and cross-tab queue staging. The isolated bundle reproduced the earlier
  missing-ZIP case with the old WAV still playing and its clock advancing from
  0:13 to 0:20. It also replaced one valid WAV with another, paused and resumed,
  and advanced through a two-WAV queue to stop. All 28 SB2 playback checks and
  51 transport checks passed, and SB2 built. The packaged failure check was
  run before the queue-staging follow-up; audible transitions, forced old-end
  races during renderer planning and faded-skip failure remain unverified.

- SB2 replacement handoff reproduction, 2026-10-29: with Faded Skip disabled, an
  isolated SB2 bundle based on `4c62c869` played a valid 30-second WAV. A
  double-click on an unavailable ZIP member showed the expected missing-source
  error, but the previous WAV stopped; selecting the valid WAV again restarted
  it. SB2's `playTrackNow` calls `stopAllOutput` and clears the native snapshot
  before submitting the replacement, so the shared controller's pre-load
  preservation could not protect that session. The later checkpoint above
  implements the immediate replacement handoff. Further verification must cover
  stale status/end, newer start/stop and faded-skip behavior, including audible
  transitions and old-session completion during preparation.

- Packaged SB2 failure and recovery, 2026-10-29: an isolated SB2 bundle based
  on `4c62c869`, with temporary user data and a two-game test catalog, showed
  a playback-failed message for a missing WAV. A subsequent valid 30-second
  WAV started, its displayed clock advanced to 0:04, and isolated history
  recorded the valid source without recording the failed attempt. Valid WAV
  SHA-256: `16fa5b7e500f1e23848800a953a097eb7815400a5885af18ca6d38c436914d93`.
  This resolves the earlier missing-WAV UI evidence gap; it does not exercise
  archive preparation failure, every retry sequence, or audible output.

- Whole-second timing bounds, 2026-10-29: extreme public timing plans could
  overflow while summing seconds or converting them to milliseconds before the
  native validation boundary. Plan totals now saturate on integer overflow;
  shared start, reconfigure and AAC export reject out-of-range seconds before
  conversion. The direct AAC exporter also checks each duration and their sum
  before opening a decoder or output file. A focused native check covers all
  three fields, preserves the current session on rejection and exercises both
  export boundaries. All 51 shared transport and 21 SB2 playback renderer
  checks passed, as did a normal VGMBoy AAC export check and the SB2 build.

- Ordered seeks, 2026-10-29: session identity alone did not order two seeks
  for the same loaded track. SB2 now reserves a transport-owned seek revision
  at message receipt; shared transport rejects an older numbered seek even if
  its worker arrives later. A native integration check exercises reversed order,
  subsequent newer seeks and legacy wire decoding. All 50 transport and 21 SB2
  playback renderer checks passed and SB2 built. This does not force the worker
  race in a packaged WebView.

- Failure and retry boundary, 2026-10-29: the existing shared integration
  check verifies that archive preparation failure preserves the prior session,
  while a failed replacement after decoder retirement clears the session and a
  subsequent valid load succeeds. It passed in the 49-test transport run. An
  isolated SB2 missing-WAV UI attempt could not be completed: computer-use
  reported the app state changed during the attempted action. Packaged error
  presentation and retry therefore remain unverified.

- Session-scoped controls, 2026-10-29: SB2 now forwards its observed native
  generation for pause, resume and seek, and shared transport rejects delayed
  controls for a replaced session on its serialized queue. Existing callers may
  omit the guard. Native coverage checks stale requests and valid controls;
  renderer coverage checks identity forwarding. All 49 transport and 21 SB2
  playback renderer checks passed and SB2 built. The rebuilt isolated bundle
  paused and resumed a 30-second WAV and its displayed clock advanced from
  0:04 to 0:12. This does not force the race through a live WebKit worker,
  exercise packaged seek, or prove audible continuity.

- SB2 lifecycle request ordering, 2026-10-29: SB2's detached workers previously
  reserved start ownership after dispatch, allowing worker scheduling to invert
  message order. Start, stop, unload and cache-clear now reserve at message
  receipt, and stop checks ownership on the shared transport queue. Native
  integration checks exercise reversed reserved starts and stale stops; the
  optional slow-archive cancellation test also passed in this pass. All 48
  transport and 20 SB2 playback renderer checks passed and SB2 built. In a
  rebuilt isolated bundle, Stop followed by a second WAV start left the second
  session playing with its clock advancing. This does not force a WebKit worker
  inversion or scope unrelated control commands.

- Session-scoped output ramps, 2026-10-29: delayed SB2 fade or restore requests
  could otherwise act on a replacement session. A typed optional generation
  travels with the ramp, and shared transport checks it on its serialized
  queue before modifying output. Requests without a generation remain compatible.
  Native checks cover stale, current and legacy requests; a renderer check
  verifies fade and restore retain the originating identity. All 47 shared
  transport tests and 20 SB2 playback renderer tests passed, and SB2 built.
  A rebuilt isolated SB2 bundle with the small catalog and two generated
  30-second WAVs advanced on faded Next and continued playing; this does not
  establish the audible envelope or reproduce delayed delivery in the app.

- Packaged SB2 queue progression, 2026-10-29: the isolated bundle based on
  `0c8d54fa` plus the stopped-timing fix used two generated three-second WAVs
  and the isolated schema-24 catalog. With repeat off, playback history recorded
  `one.wav` then `two.wav` once each and the UI returned to stopped. Repeat All
  wrapped from the second track to the first, Repeat One restarted the first,
  and manual Next/Previous produced the expected adjacent history entries.
  WAV SHA-256 values: one
  `125a2fc533ad0d91e0b443897a61b93d0d087f39bbb3ea0662d085cdac1aeece`, two
  `fc2e69c7ade6def80e3015ed033b58628fca0c44f59b88ff7ca7c67fb7202fe7`.
  This verifies the exercised UI and history path, not audible quality,
  shuffle, failed-source recovery, or other formats.

- Packaged SB2 timing and stop, 2026-10-29: an isolated bundle based on
  `0c8d54fa` with isolated user data and a small schema-24 test catalog played
  the SPC fixture (SHA-256
  `c2e3fbc4ecee60a2f9102acd374387438ac3a9ba5bfaca2f02a12fc6315bee85`).
  The interface showed pause/resume state changes, rapid Long Play and speed
  changes, and matching 3:06, 1:26 and 0:26 timing projections. Stopping after
  the changes exposed a 3:06 stale total while the selected track projected
  0:26. SB2 now uses the selected track's timing plan on stop; a test failed
  before the change and passed afterward, and a rebuilt isolated bundle showed
  0:00 / 0:26 / 0:20 after stopping. All 19 SB2 playback renderer checks passed.
  This does not prove audible continuity or WebView recreation. With the real
  large catalog expanded, UI automation stalled and a WebKit sample showed
  style recalculation; the cause and product impact remain unconfirmed. The
  sample is `/private/tmp/sb2-webcontent-busy-pass.txt` while present.

- Fade duration bounds, 2026-10-29: shared faded skip rejects nonfinite and
  unrepresentable durations before integer conversion; finite negative values
  retain their minimum-duration behavior. The VGMBoy session rejects ramps
  that cannot fit the audio unit's frame counter, including direct control
  requests. A focused integration check exercises both entry points and verifies
  the active generation survives rejected requests. All 46 transport tests
  passed and SB2 built; this does not establish audible fade behavior.

- SB2 guarded settings adoption, 2026-10-29: live timing requests now carry
  the observed native generation. The native bridge assigns a transport-owned
  settings revision on message receipt before detached dispatch, so revisions
  remain monotonic across WebView recreation. Shared lineage and revision tests
  cover consecutive and out-of-order changes and replacement; an SB2 renderer
  test checks generation forwarding and missing identity. The SB2 build,
  18 renderer checks and all 45 transport tests passed. Actual WebView recreation, packaged rapid settings
  changes and audible behavior still require verification.

- Ordered settings reconfiguration, 2026-10-29: shared transport accepts an
  earlier generation only within the current loaded track's reload lineage and
  rejects older settings revisions or a replacement track's old generation.
  Focused native tests cover successive reloads, out-of-order requests,
  replacement and wire compatibility. At this checkpoint SB2 adoption was
  deferred because WebView recreation can reset its local revision counter while
  the native session survives. The later SB2 adoption checkpoint above moves
  revision reservation into the native transport; live recreation still needs validation.
  Packaged races and audible transitions remain unverified. Three focused
  transport checks and 17 SB2 renderer checks passed, and SB2 built. The full
  transport run failed device-driven drain cases with zero consumed frames; a
  focused retry and the same case in the earlier isolated checkout failed the
  same way. macOS listed the built-in speakers, but this does not establish why
  the output callback did not drain. A later focused retry and the complete
  transport suite passed after the output environment became active again:
  45 tests passed. The earlier failure's precise cause remains unconfirmed.

- Stale reconfiguration boundary, 2026-10-29: a focused native test reproduced
  an old request reloading a replacement track. Shared reconfiguration now
  accepts an optional expected native generation and rejects mismatches before
  changing playback; requests that omit it remain compatible. The matching
  generation still reconfigures. At this checkpoint SB2 did not send the guard:
  two rapid settings changes can both observe the same generation, so an earlier
  accepted reload could cause the latest setting to be rejected. See the later
  ordering and SB2 adoption checkpoints above for the follow-up.

- Superseded preparation preservation, 2026-10-29: the first cancellation
  fix still replaced and retired an already-playing track after an archive
  request became stale. A signaling slow-archive test reproduced that loss.
  Request-aware shared loading now checks ownership after preparation and
  before timing changes or native replacement, preserving the previous playing
  track and generation. Typed and async starts are both covered; invalidation
  after replacement begins still follows the existing retirement boundary. An
  additional timed SPC case ends during the slow preparation and delivers one
  completion for its original generation after cancellation.

- Superseded archive start, 2026-10-29: a signaling slow-7zz test reproduced
  an invalidated start loading and playing after source preparation. Shared
  start now rechecks request ownership after load, after seek and after play,
  retiring its replacement on cancellation. Both typed and async start routes
  pass the test, including a queued newer in-memory SPC that remains loaded
  and playing. Run the optional check with `VGM_TEST_SLOW_START_MARKER` and a
  signaling `VGMBOY_7Z_BINARY`; the temporary wrapper used for this pass was
  `/private/tmp/vgmman-signaling-7zz`. This is native integration evidence,
  not a packaged reproduction or proof that an already executing play call
  cannot produce a brief transition before cancellation is noticed.

- Decoded tempo invariants, 2026-10-29: JSON decoding had bypassed the shared
  tempo initializer, allowing zero denominators, out-of-range components and
  unreduced fractions into preference calculations. Decoding now uses the same
  normalization and 1x invalid-value fallback as construction. A focused test
  failed for all four cases before the fix and now checks preference
  normalization, display and Codable round trips.

- Shared numeric input bounds, 2026-10-29: asynchronous transport seek now
  rejects nonfinite and out-of-range values before converting to milliseconds,
  retaining finite negative-value clamping. Shared decimal tempo parsing rejects
  unrepresentable integers and arithmetic overflow. Focused tests check that
  rejected seeks preserve a loaded session and that large tempo strings fail
  parsing; ordinary fraction and decimal parsing remains covered.

- Packaged SB2 Long Play observation, 2026-10-29: an isolated bundle rebuilt
  with the current producer and loop-boundary code displayed 3:06 for the
  three-minute Long Play setting with six-second fade. After restart, the
  displayed clock advanced to 1:29 and then 2:20 on the temporary SPC fixture.
  UI automation timed out during the restart and was slow to reconnect; a
  process sample showed the main event loop waiting and a refill reading SPC
  PCM, rather than a blocked playback queue. These observations do not prove
  pause/resume, audible continuity, or completion ordering. The test copy was
  closed; the sample is `/private/tmp/sb2-mode-stall-sample.txt` while present.

- In-memory source verification, 2026-10-29: the shared coordinator started,
  paused and reconfigured vendored SPC and SAP bytes using nonexistent file
  paths. Both retained track identity and paused state through a new generation;
  the requested 2x applied to SPC and resolved to 1x for SAP. Fixture SHA-256:
  SPC `c2e3fbc4ecee60a2f9102acd374387438ac3a9ba5bfaca2f02a12fc6315bee85`,
  SAP `a2b8e006e28f40ff638b657645f8002c70c9a8f0979b462b4a68613bc8442454`.
  This is native integration evidence, not SB2 packaged or audible evidence.

- Loop and seek bounds, 2026-10-29: extreme valid-looking loop metadata could
  trap while converting to output frames, and extreme direct seeks could
  overflow decoder conversions. Session load now rejects loop boundaries that
  exceed native seek range or collapse below an output frame, and seek rejects
  nonfinite, negative and out-of-range positions before changing playback.
  Injected checks verify cleanup and unchanged buffered state; existing authored
  loop/tempo and transport tests exercise ordinary behavior.

- Loop-tag file access, 2026-10-29: the shared reader opened every source
  before checking whether it supported that format. It now opens only FLAC and
  APE for tag inspection, leaving other decoders to perform their own reads.
  A generated FLAC-comment test verifies the supported path and that SPC/WAV
  bypass the loader; an overflowing loop-start plus length is rejected. This
  removes unnecessary source I/O but does not establish the cause of the
  Downloads-path stall recorded below.

- Decoder setup cleanup, 2026-10-29: injected start and metadata failures showed
  that a newly created decoder was not explicitly closed before session
  ownership began. The session now owns the decoder immediately after creation,
  so setup and priming failures use the same cleanup path. Additional injected
  tests cover transient empty reads, invalid stereo PCM, thrown decode errors,
  and recovery after an empty read; focused checks passed. A further injected
  periodic-refill failure stopped output, reported the error without reporting
  natural end, and released the decoder on stop. Packaged playback with the
  setup-cleanup follow-up still needs verification.

- Packaged producer smoke, 2026-10-29: rebuilt isolated SB2 from `178e8bc1`
  producer sources and played the vendored SPC copied into the temporary test
  directory (SHA-256 `c2e3fbc4ecee60a2f9102acd374387438ac3a9ba5bfaca2f02a12fc6315bee85`).
  With an 8x request, the preview showed 0:26 and the clock advanced from 0:00
  to 0:05. The first attempt using its path under Downloads stalled in a file
  open before decoding; the process sample is `/private/tmp/sb2-producer-sample.txt`
  while available. No conclusion about its cause or audible continuity is made.

- Shared producer short-write pass, 2026-10-29: an offline small-ring test
  reproduced DSP state advancing for PCM that the ring rejected, and a real
  generated VGM primed into an 88-frame ring exposed 4,008 falsely audible
  frames after a 4,096-frame decode. Output DSP now processes only writable
  frames; the producer bounds reads by ring capacity, counts accepted frames,
  and fails explicitly on an invalid decoder result or unexpected short write.
  Tests compare retried EQ output sample-for-sample with an uninterrupted
  reference and exercise small-ring priming and seeking. Eight focused VGMBoy
  tests, 40 shared transport tests and 17 SB2 renderer tests passed; SB2
  built successfully. Packaged UI and
  audible device behavior after this core change still require verification.

- Isolated SB2 tempo UI, 2026-10-29: an app copy built from the current shared
  bridge and SB2 renderer used a separate bundle ID and temporary playlist,
  history, favorites and cache. With the vendored F-Zero SPC fixture and an
  80-second catalog duration plus six-second fade, the UI showed 0:46 at 2x
  and 0:26 at a requested 8x, reflecting the 4x decoder limit. Playback was
  resumed at the latter setting and the displayed clock reached 0:26. The
  renderer resource hash matched the source. The catalog was opened read-only;
  this check does not prove audible continuity or every live transition.

- Typed tempo integration, 2026-10-29: a shared transport test starts and
  reconfigures an SPC and generated WAV with requested 8x tempo and shared
  Long Play previews. Native status reports 4x for the SPC and 1x for WAV,
  while retaining the requested track identity. This exercises the typed SB2
  request shape against real decoder sessions, not a packaged UI or audible
  transition. The SPC is the vendored F-Zero fixture identified below.

- SB2 tempo policy extraction, 2026-10-29: timing previews, native start and
  reconfiguration now forward the selected tempo to shared format policy,
  rather than applying SB2's backend limits before those requests. SB2 retains
  a local estimate only while a shared timing preview is unavailable. Renderer
  tests cover enabled and disabled intent and forwarding; shared transport
  coverage verifies effective decoder limits. Packaged speed changes and audible
  continuity remain open.

- Shared preview bounds, 2026-10-29: timing preview now rejects negative or
  larger-than-native input durations before scaling. This prevents an oversized
  bridge request from trapping during integer conversion; tests cover an
  oversized Swift request, a negative decoded request and a supported boundary
  at slow tempo.

- Precise shared timing preview, 2026-10-29: the shared bridge previously
  rounded timing to whole seconds before SB2 used it, despite millisecond
  playback support. It now supplies output-time millisecond fields alongside
  the original whole-second fields and decodes older replies. SB2 consumes the
  precise values when present. Contract checks cover 750 ms at 2x with a
  250 ms fade, a subsecond Long Play window, unbounded Long Play, and old/new
  wire decoding. All 15 SB2 renderer checks and 38 shared transport checks
  passed, and SB2 built successfully. Packaged and audible verification of
  these subsecond cases remains open.

- Shared timing adoption, 2026-10-29: SB2 applied tempo scaling to an already
  scaled shared timing preview, producing 22.5 seconds from a 45-second preview
  at 2x. It now uses the shared output duration and total directly, including
  for its Long Play start window. A renderer test reproduces the old result;
  fallback catalog estimates and unbounded Long Play have separate checks.
  All 14 SB2 renderer checks, 38 shared transport checks, the updated shared
  timing contract test and the SB2 Swift build passed. Packaged and audible
  behavior at changed speed remain to be verified.

- SB2 start/settings race, 2026-10-29: a timing change can overlap timing
  planning, native initialization or native start. A start now replans if its
  settings changed before native start, and reconfigures the accepted session
  if they changed during the native request. A newer playback generation
  cancels the old request. Four renderer tests exercise these interleavings:
  three fail against the preceding checkpoint and all pass with the change.
  All 11 SB2 focused tests and the SB2 Swift build pass. The build emits
  WebKit delegate-signature warnings and warns that some linked Homebrew
  libraries target a newer macOS than SB2; compatibility requires separate
  investigation. Packaged playback and audible behavior for this race remain
  unverified.

- SB2 timing-preview pass, 2026-10-29: the isolated player showed a stopped
  track's old Long Play duration after the setting was disabled. Timing plans
  were cached by track ID and a settings change returned before invalidating
  them when no track was active. SB2 now invalidates all plans for timing and
  speed changes, refreshes the stopped preview through shared timing, and
  prevents replies for old settings or selections from updating the cache.
  Three focused renderer checks cover the cache and reply-order cases; all seven
  SB2 focused checks, 38 shared transport checks, and four VGMBoy timing/tempo
  checks passed. A rebuilt isolated SB2 package showed 3:06 with Long Play on
  and 0:09 after it was disabled for a three-second WAV with six-second fade.
  This does not establish audible continuity or all playback mode transitions.

- SB2-primary scope, 2026-10-29: the user directed shared-module regression
  testing through SB2 and deferred ViewBoy and CocoaSpice until the shared work
  is finished. SB2's focused completion tests exercise its actual renderer
  handler for a current retirement, declined claim, changed track or generation,
  and a stale same-generation end. This covers deterministic event ordering;
  it does not replace live playback, audible checks or the remaining shared-core
  gates.

- ViewBoy stale end-status pass, 2026-10-29: a delayed end for the same
  generation could fail the renderer's status-sequence check but still retire
  the current track and advance the queue. A focused renderer test reproduced
  the unwanted retirement with sequence 11 after sequence 12. The completion
  handler now requires an accepted, ended status before retirement; all six
  focused completion-race checks pass. Family verification's ViewBoy test glob
  now selects `.test.mjs` files. The full renderer run passed 15 of 16 tests;
  the existing framebuffer-default assertion and missing tab-reducer mock still
  fail. An isolated harness investigation found the test assumes gapless dots,
  `#222222` ink and equal CIELAB spacing, while current defaults use an enabled
  STN aperture, `#000000` ink and LCD reflectance mixing; the mock also lacks
  the shared playlist-tab reducer. Updating this display fixture needs its own
  rendering-contract review rather than changing production display behavior.
  A rebuilt isolated package played two short WAVs, advanced to the second
  and stopped, recording both in temporary history. The stale-event race itself
  was tested in the renderer harness; audible behavior remains unverified.

- CocoaSpice replacement ownership pass, 2026-10-29: a stale start could call
  the adapter's unconditional stop before the coordinator rejected its request,
  retiring a newer track. The shared coordinator now checks request ownership
  on its serialized queue before that replacement stop, and CocoaSpice uses it.
  A real-WAV CocoaSpice integration check verifies that an older request is
  cancelled while the newer track remains loaded and playing. All 38 shared
  transport tests and three focused CocoaSpice checks passed. A rebuilt isolated
  CocoaSpice package played a two-WAV M3U, advanced to the second track and
  stopped, recording both in isolated history. This is not an audible check or
  a packaged reproduction of the delayed-request race.

- Post-fix packaged CocoaSpice check, 2026-10-29: using the corrected isolated
  package and an M3U containing two generated three-second WAVs, the player
  started the first track, advanced to the second, and stopped. The isolated
  history recorded `one`, then `two`; the process sampled at 0.1% CPU after
  playback, and the earlier persistent status feedback loop did not recur.
  This short run does not establish sustained playback CPU or audible quality.

- CocoaSpice callback pass, 2026-10-29: transport events previously crossed
  a main-queue hop and an additional MainActor task after their source generation
  had been discarded. Its adapter now refreshes current transport status without
  blocking the UI, orders status delivery by sequence, and verifies the ended
  generation and track still own a loaded, ended session before invoking the
  main-actor completion handler. If an ordinary status overtakes the one-shot
  end, it refreshes again rather than dropping that end. A focused guard check
  rejects replaced, resumed and unloaded sessions; a 3-second generated WAV
  produced one natural-end callback in the package integration check. The
  CocoaSpice test target's stale v1 surface reference was updated to v2.
  An isolated packaged check exposed a feedback loop: the new refresh used a
  status command that itself emitted a callback, and the test process reached
  approximately 140% CPU before it was quit. Shared asynchronous and synchronous
  snapshot reads now use the non-emitting controller getter; focused tests verify
  repeated reads do not emit and real playback stays below 100 status callbacks
  while delivering one natural end. All 37 shared transport tests passed. A
  rebuilt isolated package launched without the runaway loop, but its archive
  metadata read stalled in filesystem extended-attribute lookup; the process
  sampled at 0.4% CPU while stalled and was stopped. Sustained post-fix packaged
  playback and CPU behavior are still unverified. The test process used temporary
  data paths. These checks do not simulate every actor scheduling race or
  establish audible output.

- Completion race pass, 2026-10-29: ViewBoy previously continued a completed
  queue after a delayed retirement reply even if the same track had restarted
  or reconfigured; random modes also proceeded when native retirement returned
  no decision. It now checks track, native generation and request token after
  each asynchronous boundary and requires a successful native claim. Four
  focused tests execute the renderer handler and pass; the old handler fails
  three of them. SB2 now checks the native generation after retirement as well
  as its frontend generation and track ID; a temporary focused smoke check
  reproduces the old unwanted advance and passes against the fix. Both isolated
  frontend packages build. In a ViewBoy packaged run, two generated 3-second
  WAVs played to natural completion, advanced from one to two and stopped;
  both appeared in isolated history. This does not prove audible continuity.
  See the later CocoaSpice callback pass for its event-handoff changes and
  remaining verification limits.

- ViewBoy history fix, 2026-10-29: the packaged UI played the SPC but did
  not add it to shared history. The renderer passes one track dictionary to
  `playbackHistoryRecord`, while ViewBoy's bridge tried to parse it directly
  as an array. The bridge now wraps the validated dictionary before mapping
  it, matching SB2. A clean isolated ViewBoy rebuild played the same SPC;
  its temporary history grew from seven to eight records with `big-blue` at
  the head, and Recent reported eight tracks. This verifies the renderer-to-
  native history path for that fixture, not every format or timing race.

- Isolated packaged UI pass, 2026-10-29: built SB2, ViewBoy and CocoaSpice
  at `b8dbbab7` in a temporary detached checkout, using copied native decoder
  products from the source build. The verification copies redirect shared
  favorites, history, playlist files and frontend archive caches to temporary
  paths and use separate bundle identifiers; the catalog remains read-only.
  SB2 played a VGM member of a catalog UAC, and its displayed clock advanced.
  ViewBoy loaded the vendored Big Blue SPC (SHA-256
  `c2e3fbc4ecee60a2f9102acd374387438ac3a9ba5bfaca2f02a12fc6315bee85`),
  played, paused, resumed after a mode change, and stopped. CocoaSpice played
  the same catalog UAC member as SB2, paused, enabled Long Play, resumed,
  advanced to the next member and stopped. These are partial UI checks, not
  audible or sample-level continuity evidence. The user's history, favorites
  database, SB2 tabs and CocoaSpice tabs had unchanged file hashes after the
  checks. The previously running original SB2 process was no longer present
  during this pass; its cause was not established and it was not restarted.
  The full ViewBoy renderer run passed 9 of 10 tests; the existing
  `YogaCanvas.test.mjs` default ink assertion failed and its mock also reported
  a missing `playlistTabsReduce` after test termination. Homebrew FFmpeg and
  libsidplayfp binaries generated macOS 27 versus deployment-target 26 linker
  warnings; compatibility with macOS 26 is not established by these builds.
  The ViewBoy UI pass also exposed a history bridge argument mismatch; see the
  later history-fix checkpoint for its verification status.

- Subsecond timing pass, 2026-10-29: a generated WAV reproduced the 500 ms
  timed play plus 250 ms fade request continuing beyond two seconds because
  both values were truncated to zero. The internal playback plan now retains
  millisecond play and fade values through session cap and fade calculation;
  existing whole-second callers retain their interface, and zero Long Play
  remains unbounded. The same WAV test now drains at about 0.75 seconds.
  Focused tests also passed for generated VGM and vendored SPC at 500+250 ms.
  Oversized millisecond windows are rejected without retiring the current track;
  all 36 shared transport tests passed. This is package/core evidence, not
  packaged-UI or audible verification.

- Unchanged-request pass, 2026-10-29: when timing settings and effective tempo
  match the active controller configuration, reconfiguration retains the
  existing session, generation and queued PCM. A changed setting still reloads.
  The focused integration test covers both cases; all 34 shared transport
  tests passed (the slow-archive case was skipped in that run and passed
  separately with its temporary wrapper). Packaged playback remains unverified.

- Offline transition evidence, 2026-10-29: a focused VGMBoyKit test decoded
  real non-silent PCM from the generated tone VGM and the vendored SPC, then
  used `vgmboy_audio_unit_render_offline` to exercise a 441-frame fade-out,
  buffer clear and 441-frame fade-in after a 1× to 2× decoder restart. For both
  fixtures the faded-out final stereo sample was zero, and the first faded-in
  stereo samples were at most 75 PCM16 units from zero. The offline transition
  and five focused timing/loop tests passed. This exercises the callback and
  decoder PCM in a controlled harness; it does not capture the live
  `PlaybackSession` transition, prove musical phase continuity, or establish
  audible or packaged-app behavior.

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

Review direct PlaybackController clients, including VGMBoy itself. LineBoy is
deprecated and excluded from this plan at the user’s direction. Investigate hosted SBONLINE integration before
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

Gate for the current phase: SB2 requests produce the intended effective core
settings and position without an intermediate end or queue advance. Equivalence
with the other frontends is a deferred follow-up after shared work is finished.

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
handling explicitly. Check direct VGMBoy callers and affected hosted integration
for API compatibility. LineBoy is deprecated and excluded from this plan. Preserve app-specific options, selection,
archives, queue, navigation and persistence; update implemented current-state
subsystem documentation with the final behavior.

Gate for the current phase: SB2 exercises the shared core sequence while
retaining its queue and UI behavior. Equivalent ViewBoy and CocoaSpice checks
are deferred until shared work is finished. Document unsupported formats and
frontend differences with evidence.

### 5. Verification and release evidence

Use layered evidence, recording commands, source revision, dirty inputs, fixture
identity, formats, app build and observed results:

- Focused coordinator/session checks: overlapping commands, generation changes,
  queued old completion, exactly-once end, replacement failure, cleanup and
  progress ordering. Include tempo endpoints, persisted out-of-range values,
  subsecond and zero duration, loops/fades and in-memory/archive sources.
- Package and renderer checks for touched owners; `scripts/verify-family.sh`
  covers several family packages but does **not** cover SB2. Select SB2 checks
  explicitly; deprecated LineBoy is outside this plan. SB2's `ai/AGENTS.md` says not to add
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
