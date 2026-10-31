(() => {
const playbackApp = window.SB2App;
const {
  state,
  refs,
  formatTime,
  currentFadeSeconds,
  targetPlaybackSeconds,
  currentTrack,
  selectedTrack,
  activeTrackInfo
} = playbackApp;

let playbackGeneration = 0;
let nativePlaybackInitialized = false;
let mediaSessionHandlersBound = false;
const playbackBackends = window.SB2PlaybackBackends;
let queuedSkipRequest = null;
let queuedSkipTimer = 0;
let queuedSkipToken = null;
let queuedSkipSerial = 0;
const queuedSkipSession = `${Date.now()}-${Math.random()}`;
let playbackErrorTimer = 0;
let playbackWindow = null;
let playbackClockHandle = 0;
let playbackClockUsesAnimationFrame = false;
let nativeClockAnchor = null;
const timingPlans = new Map();
let pendingPlaybackIntent = null;
let deferredNativeEnds = [];

function beginPlaybackIntent(trackId = null) {
  const intent = { trackId };
  pendingPlaybackIntent = intent;
  return intent;
}

async function finishPlaybackIntent(intent) {
  if (pendingPlaybackIntent !== intent) return;
  pendingPlaybackIntent = null;
  const deferred = deferredNativeEnds.find(item => state.currentTrackId === item.trackId
    && Number(state.nativePlayback?.generation) === item.nativeGeneration);
  deferredNativeEnds = [];
  if (deferred) {
    // A start reply may already report this generation as ended with a newer
    // sequence than the one-shot event. Preserve that confirmed end while
    // still letting ordinary stale-event checks reject a resumed session.
    const event = state.nativePlayback?.transportState === "ended"
      ? { ...deferred.event, status_sequence: Math.max(Number(deferred.event.status_sequence) || 0,
          Number(state.nativePlayback.statusSequence) || 0) }
      : deferred.event;
    await handleNativePlaybackEnded(event);
  }
}

function cancelPlaybackIntent() {
  pendingPlaybackIntent = null;
  deferredNativeEnds = [];
}

function clearPlaybackError() {
  window.clearTimeout(playbackErrorTimer);
  playbackErrorTimer = 0;
  refs.playbackErrorToast?.classList.add("is-hidden");
  if (refs.playbackErrorToast) refs.playbackErrorToast.textContent = "";
}

function showPlaybackError(error) {
  if (!refs.playbackErrorToast) return;
  const message = String(error?.message || error || "Unable to play this file.").trim();
  refs.playbackErrorToast.textContent = `Playback failed: ${message}`;
  refs.playbackErrorToast.classList.remove("is-hidden");
  window.clearTimeout(playbackErrorTimer);
  playbackErrorTimer = window.setTimeout(clearPlaybackError, 8000);
}
// Settings writes are separate from playback replacement, but their native
// replies are still asynchronous. Keep only the newest timing/tempo result
// for the current renderer generation.
let playbackSettingsGeneration = 0;
const TRANSPORT_DECLICK_MS = 10;

function playbackPlaylist() {
  return state.playingPlaylist?.length ? state.playingPlaylist : state.playlist;
}

function waitForAudioEnvelope(durationMs) {
  return new Promise((resolve) => window.setTimeout(resolve, Math.max(0, Math.ceil(durationMs))));
}

async function fadeActiveOutput(durationMs = TRANSPORT_DECLICK_MS, { onRampReady = null, expectedGeneration = null } = {}) {
  const activeTrack = activeTrackInfo();
  const generation = Number(expectedGeneration ?? state.nativePlayback?.generation);
  if (nativePlaybackInitialized && activeTrack && Number.isSafeInteger(generation) && generation > 0) {
    try {
      await window.spcBoySB2.nativePlaybackRampGain?.({ outputGain: 0, rampMilliseconds: durationMs, expectedGeneration: generation });
    } catch {
      // The normal stop path still has to complete if a helper exited between
      // the transition request and its short output envelope.
    }
  }
  if (onRampReady) {
    onRampReady();
    return;
  }
  await waitForAudioEnvelope(durationMs);
}

function clearQueuedSkipTimer() {
  if (queuedSkipTimer) window.clearTimeout(queuedSkipTimer);
  queuedSkipTimer = 0;
  const token = queuedSkipToken;
  queuedSkipToken = null;
  if (token) void window.spcBoySB2.queuedFadeCancel({ token }).catch(() => {});
}

function scheduleQueuedSkipFade(request, plan, errorContext) {
  const token = `${queuedSkipSession}-${++queuedSkipSerial}`;
  queuedSkipToken = token;
  request.fadeErrorContext = errorContext;
  let sharedStarted = false;
  const current = () => queuedSkipToken === token && queuedSkipRequest === request
    && request.generation === playbackGeneration && !request.completing;
  const armFallback = (delay) => {
    if (!current()) return;
    if (queuedSkipTimer) window.clearTimeout(queuedSkipTimer);
    queuedSkipTimer = window.setTimeout(() => {
      if (!current()) return;
      void completeQueuedSkip().catch(error => console.error(errorContext, error));
    }, delay);
  };
  // Keep a bounded local fallback if a bridge reply or native event is lost.
  // Both paths check the same request before completing.
  armFallback(plan.fallbackMilliseconds);
  void window.spcBoySB2.queuedFadeStart({ token, ...plan }).then(() => {
    if (!current()) return;
    sharedStarted = true;
    armFallback(plan.fallbackMilliseconds);
  }).catch(error => console.error(errorContext, error));
  void fadeActiveOutput(plan.durationMilliseconds, { expectedGeneration: request.nativeGeneration,
    onRampReady: () => {
      if (!current()) return;
      armFallback(sharedStarted ? plan.fallbackMilliseconds : plan.durationMilliseconds);
      void window.spcBoySB2.queuedFadeRampReady({ token }).catch(error => console.error(errorContext, error));
    } }).catch(error => console.error(errorContext, error));
}

function handleQueuedFadeReady(event) {
  const request = queuedSkipRequest;
  if (!request || event?.token !== queuedSkipToken || request.generation !== playbackGeneration || request.completing) return;
  clearQueuedSkipTimer();
  void completeQueuedSkip().catch(error => console.error(request.fadeErrorContext, error));
}

function monotonicNow() {
  const performanceNow = window.performance?.now?.();
  return Number.isFinite(performanceNow) ? performanceNow : Date.now();
}

function cancelPlaybackClock() {
  if (!playbackClockHandle) return;
  if (playbackClockUsesAnimationFrame && window.cancelAnimationFrame) {
    window.cancelAnimationFrame(playbackClockHandle);
  } else {
    window.clearTimeout(playbackClockHandle);
  }
  playbackClockHandle = 0;
}

function renderPlaybackClock(timestamp) {
  playbackClockHandle = 0;
  const track = activeTrackInfo();
  if (!state.isPlaying || !nativeClockAnchor || !track || track.id !== nativeClockAnchor.trackId) {
    return;
  }

  const elapsedSinceAnchor = Math.max(0, (Number(timestamp) - nativeClockAnchor.timestamp) / 1000);
  const projectedSeconds = clampPosition(
    nativeClockAnchor.positionSeconds + elapsedSinceAnchor,
    state.totalSeconds
  );
  if (projectedSeconds > state.elapsedSeconds) {
    state.elapsedSeconds = projectedSeconds;
    updateElapsedReadout();
  }
  if (state.isPlaying && (state.totalSeconds <= 0 || projectedSeconds < state.totalSeconds)) schedulePlaybackClock();
}

function schedulePlaybackClock() {
  if (playbackClockHandle || !state.isPlaying || !nativeClockAnchor) return;
  if (typeof window.requestAnimationFrame === "function") {
    playbackClockUsesAnimationFrame = true;
    playbackClockHandle = window.requestAnimationFrame(renderPlaybackClock);
  } else {
    playbackClockUsesAnimationFrame = false;
    playbackClockHandle = window.setTimeout(() => renderPlaybackClock(monotonicNow()), 50);
  }
}

function anchorPlaybackClock(track, snapshot, elapsedSeconds) {
  if (!track || snapshot?.transport_state !== "playing") {
    nativeClockAnchor = null;
    cancelPlaybackClock();
    return;
  }
  nativeClockAnchor = {
    trackId: track.id,
    positionSeconds: elapsedSeconds,
    timestamp: monotonicNow()
  };
  cancelPlaybackClock();
  schedulePlaybackClock();
}

function setPlaybackClockPosition(positionSeconds) {
  if (!state.isPlaying || !nativeClockAnchor || !activeTrackInfo()) return;
  nativeClockAnchor.positionSeconds = clampPosition(positionSeconds, state.totalSeconds);
  nativeClockAnchor.timestamp = monotonicNow();
}

function resetNativePlaybackSnapshot() {
  nativeClockAnchor = null;
  cancelPlaybackClock();
  state.nativePlayback = {
    transportState: "stopped",
    outputState: "idle",
    generation: 0,
    statusSequence: 0,
    trackLoaded: false,
    decodeError: false,
    reachedEnd: false,
    bufferedFrames: 0,
    ringBufferFrames: 0,
    underrunCount: 0,
    framesRequested: 0,
    framesSupplied: 0,
    decoderFamily: "",
    decoderSampleRate: 0,
    outputSampleRate: 0,
    decodedFrames: 0,
    audiblePositionFrames: 0,
    tempo: 1,
    positionMs: 0
  };
}

function currentTotalSeconds(track) {
  const plan = track ? timingPlans.get(track.id) : null;
  if (plan) return plan.total_seconds;
  return currentOutputBasePlaybackSeconds(track) + currentFadeSeconds(track);
}

function effectiveTotalSeconds(track) {
  return playbackWindow && playbackWindow.trackId === track?.id
    ? playbackWindow.totalSeconds
    : currentTotalSeconds(track);
}

function requestedPlaybackSpeed() {
  return state.playbackSpeedEnabled ? state.playbackSpeed : { numerator: 1, denominator: 1 };
}

function currentNativeGeneration() {
  const generation = Number(state.nativePlayback?.generation);
  if (!Number.isSafeInteger(generation) || generation <= 0) {
    throw new Error("Playback session identity is unavailable; retry the control.");
  }
  return generation;
}

function fallbackPlaybackSpeedForTrack(track) {
  const sourceName = track?.archiveEntry || track?.sourceFilename || track?.path || "";
  const backend = playbackBackends.forPath(sourceName);
  const extension = playbackBackends.extensionForPath(sourceName);
  const supportsNativeTempo = backend?.playbackSpeedExtensions?.some(
    (candidate) => playbackBackends.normalizeExtension(candidate) === extension
  );
  if (backend?.playbackSpeedMode === "native-tempo" && supportsNativeTempo && state.playbackSpeedEnabled) {
    const requested = state.playbackSpeed.numerator / state.playbackSpeed.denominator;
    const minimum = Number(backend.tempoMinimum) || requested;
    const maximum = Number(backend.tempoMaximum) || requested;
    const precision = Number(backend.tempoPrecision) || 0;
    const bounded = Math.min(maximum, Math.max(minimum, requested));
    const effective = precision ? Math.round(bounded / precision) * precision : bounded;
    if (Math.abs(effective - requested) < 1e-9) return state.playbackSpeed;
    return { numerator: Math.round(effective * 1000), denominator: 1000 };
  }
  return { numerator: 1, denominator: 1 };
}

function currentOutputBasePlaybackSeconds(track) {
  const plan = track ? timingPlans.get(track.id) : null;
  // The shared preview is already scaled to output time at the effective tempo.
  if (plan) return plan.pre_fade_seconds;
  const speed = fallbackPlaybackSpeedForTrack(track);
  const baseSeconds = track?.basePlaybackSeconds > 0 ? track.basePlaybackSeconds : state.unknownDurationSeconds;
  const milliseconds = Math.max(0, Math.round(baseSeconds * 1000));
  return Math.round(milliseconds * speed.denominator / speed.numerator) / 1000;
}

async function resolveTimingPlan(track, { force = false, cache = true, tempo = requestedPlaybackSpeed() } = {}) {
  if (!track) {
    return null;
  }
  if (!force && timingPlans.has(track.id)) {
    return timingPlans.get(track.id);
  }

  const settingsGeneration = playbackSettingsGeneration;
  const plan = await window.spcBoySB2.nativePlaybackTiming({
    path: track.archiveEntry || track.sourceFilename || track.path || "",
    playMilliseconds: Math.max(0, Math.round((Number(track.basePlaybackSeconds) || 0) * 1000)),
    manualPlayMilliseconds: Math.max(0, Math.round(state.manualPlayTimeSeconds * 1000)),
    fadeMilliseconds: Math.max(0, Math.round(currentFadeSeconds(track) * 1000)),
    unknownDurationMilliseconds: Math.max(1, Math.round(state.unknownDurationSeconds * 1000)),
    tempo,
    longPlayEnabled: state.longPlayEnabled
  });
  if (!plan || !Number.isFinite(Number(plan.pre_fade_seconds))) {
    throw new Error("VGMBoy returned no playback timing plan.");
  }
  const isLongPlay = Boolean(plan.is_long_play);
  const precise = plan.pre_fade_milliseconds != null && plan.fade_milliseconds != null
    && plan.total_milliseconds != null && Number.isFinite(Number(plan.pre_fade_milliseconds))
    && Number.isFinite(Number(plan.fade_milliseconds)) && Number.isFinite(Number(plan.total_milliseconds));
  const preFadeSeconds = precise ? Number(plan.pre_fade_milliseconds) / 1000 : Number(plan.pre_fade_seconds);
  const normalized = {
    pre_fade_seconds: Math.max(0, preFadeSeconds),
    fade_seconds: Math.max(0, Number(precise ? plan.fade_milliseconds / 1000 : plan.fade_seconds) || 0),
    total_seconds: isLongPlay && preFadeSeconds <= 0
      ? 0
      : Math.max(0, Number(precise ? plan.total_milliseconds / 1000 : plan.total_seconds) || 0),
    is_long_play: isLongPlay,
    uses_native_ending: Boolean(plan.uses_native_ending)
  };
  if (cache && settingsGeneration === playbackSettingsGeneration) timingPlans.set(track.id, normalized);
  return normalized;
}

function matchesCurrentPlaybackSettings(requestGeneration, generation, trackID) {
  return requestGeneration === playbackSettingsGeneration
    && generation === playbackGeneration
    && state.currentTrackId === trackID
    && currentTrack()?.id === trackID;
}

function clampPosition(positionSeconds, durationSeconds) {
  const position = Number(positionSeconds) || 0;
  const duration = Number(durationSeconds);
  // A zero duration is the explicit unbounded Long Play policy, not a
  // zero-length track. Keep the elapsed clock moving until native playback
  // reports an actual end.
  if (!Number.isFinite(duration) || duration <= 0) return Math.max(0, position);
  return Math.max(0, Math.min(position, duration));
}

function shouldPreserveFieldValue(element) {
  return document.activeElement === element;
}

async function chooseAACExportDirectory() {
  const path = await window.spcBoySB2.chooseAACExportDirectory();
  if (!path) return null;
  state.aacExportDirectory = path;
  state.aacExportStatus = `AAC exports will be written to ${path}`;
  persistSettings();
  updatePlaybackReadout();
  playbackApp.ui.renderAll();
  return path;
}

async function exportTrackAsAAC(track) {
  if (!track || state.aacExportInProgress) return;
  state.aacExportInProgress = true;
  try {
    let directory = state.aacExportDirectory;
    if (!directory) directory = (await window.spcBoySB2.defaultAACExportDirectory?.()) || "";
    if (!directory) return;
    const tempo = { ...requestedPlaybackSpeed() };
    const plan = await resolveTimingPlan(track, { force: true, tempo });
    state.aacExportStatus = `Exporting ${track.title || track.filename || "track"}…`;
    playbackApp.ui.renderAll();
    const result = await window.spcBoySB2.nativeExportAAC({
      path: track.path,
      archivePath: track.archivePath || null,
      archiveEntry: track.archiveEntry || null,
      trackIndex: track.trackIndex || 0,
      outputDirectory: directory,
      filenameStem: track.title || track.filename || "Untitled Track",
      playMilliseconds: Math.max(1, Math.round(plan.pre_fade_seconds * 1000)),
      fadeMilliseconds: Math.max(0, Math.round(plan.fade_seconds * 1000)),
      tempo
    });
    state.aacExportStatus = `Exported AAC: ${result?.path || "complete"}`;
  } catch (error) {
    state.aacExportStatus = error?.message || "AAC export failed.";
    throw error;
  } finally {
    state.aacExportInProgress = false;
    state.aacExportID = null;
    playbackApp.ui.renderAll();
  }
}

function handleAACExportEvent(event) {
  if (!event) return;
  state.aacExportID = event.id || state.aacExportID;
  const stateName = event.state || "rendering";
  if (stateName === "rendering") {
    const total = Number(event.total_frames) || 0;
    const rendered = Number(event.rendered_frames) || 0;
    const percent = total > 0 ? ` ${Math.min(100, Math.round((rendered / total) * 100))}%` : "";
    state.aacExportStatus = `Exporting ${event.message || "track"}…${percent}`;
  } else if (stateName === "completed") {
    state.aacExportStatus = `Exported AAC: ${event.message || "complete"}`;
  } else if (stateName === "cancelled") {
    state.aacExportStatus = "AAC export cancelled; incomplete output removed.";
  } else if (stateName === "failed") {
    state.aacExportStatus = event.message || "AAC export failed.";
  }
  playbackApp.ui.renderAll();
}

async function cancelAACExport() {
  if (!state.aacExportInProgress) return;
  state.aacExportStatus = "Cancelling AAC export…";
  playbackApp.ui.renderAll();
  await window.spcBoySB2.nativeCancelAACExport({ id: state.aacExportID });
}

async function stopAllOutput({ declick = true, keepNativeOutput = false, generation = playbackGeneration } = {}) {
  if (declick) await fadeActiveOutput();
  if (generation !== playbackGeneration) return;
  if (nativePlaybackInitialized) {
    try {
      if (keepNativeOutput) await window.spcBoySB2.nativePlaybackUnload();
      else await window.spcBoySB2.nativePlaybackStop();
    } catch {
      // A stopped or not-yet-primed native session is already safe to replace.
    }
  }
}

function updateTimingSummary() {
  const track = activeTrackInfo();
  const totalSeconds = currentTotalSeconds(track);
  state.totalSeconds = totalSeconds;
  refs.songLengthLabel.textContent = totalSeconds > 0 ? formatTime(totalSeconds) : "∞";
  const playlistTotalSeconds = state.playlist.reduce((sum, entry) => sum + currentOutputBasePlaybackSeconds(entry), 0);
  refs.playlistTotalLabel.textContent = formatTime(playlistTotalSeconds);
  refs.progressSlider.max = String(Math.max(totalSeconds, 1));
  if (!shouldPreserveFieldValue(refs.spcLengthInput)) {
    refs.spcLengthInput.value = formatTime(state.manualPlayTimeSeconds);
  }
  if (!shouldPreserveFieldValue(refs.spcUnknownDurationInput)) {
    refs.spcUnknownDurationInput.value = formatTime(state.unknownDurationSeconds);
  }
  if (!shouldPreserveFieldValue(refs.spcFadeInput)) {
    refs.spcFadeInput.value = formatTime(state.spcFadeSeconds);
  }
  if (!shouldPreserveFieldValue(refs.uiItemSpacingInput)) {
    refs.uiItemSpacingInput.value = String(state.uiItemSpacingPx);
  }
  refs.spcForceLengthCheckbox.checked = state.longPlayEnabled;
  refs.queuedSkipsCheckbox.checked = state.queuedSkipsEnabled;
  refs.spcFadeCheckbox.checked = state.fadeEnabled;
  if (!shouldPreserveFieldValue(refs.sidebarFontSizeInput)) {
    refs.sidebarFontSizeInput.value = String(state.contentFontSizePt);
  }
  if (!shouldPreserveFieldValue(refs.sidebarWidthInput)) {
    refs.sidebarWidthInput.value = String(state.sidebarWidthPercent);
  }
}

function bindMediaSessionHandlers() {
  if (mediaSessionHandlersBound || !("mediaSession" in navigator)) {
    return;
  }

  const handlers = {
    previoustrack: () => playAdjacent(-1),
    nexttrack: () => playAdjacent(1),
    play: () => {
      void togglePlayback().catch((error) => {
        console.error(error);
      });
    },
    pause: () => {
      if (!state.isPlaying) {
        return;
      }

      void togglePlayback().catch((error) => {
        console.error(error);
      });
    }
  };

  for (const [action, handler] of Object.entries(handlers)) {
    try {
      navigator.mediaSession.setActionHandler(action, handler);
    } catch {
      // Unsupported action handlers are ignored per runtime.
    }
  }

  mediaSessionHandlersBound = true;
}

function syncMediaSessionState() {
  const track = state.currentTrackId ? activeTrackInfo() : null;
  const nativeInfo = track ? {
    title: track.title || track.displayName || track.filename || "SPCBoy",
    artist: track.artist && track.artist !== "—" ? track.artist : "",
    albumTitle: track.game || "",
    elapsedSeconds: state.elapsedSeconds,
    durationSeconds: state.totalSeconds,
    isPlaying: state.isPlaying
  } : null;
  window.spcBoySB2?.setNowPlayingInfo(nativeInfo).catch((error) => {
    console.error("[SPCBoy] Now Playing update failed", error);
  });

  if (!("mediaSession" in navigator)) {
    return;
  }

  bindMediaSessionHandlers();

  navigator.mediaSession.playbackState = state.isPlaying ? "playing" : "paused";

  if (!track) {
    navigator.mediaSession.metadata = null;
    return;
  }

  navigator.mediaSession.metadata = new MediaMetadata({
    title: track.title || track.displayName || track.filename || "SPCBoy",
    artist: track.artist && track.artist !== "—" ? track.artist : "",
    album: track.game || "",
    sourceTitle: track.system || "SPCBoy"
  });
}

function updateElapsedReadout() {
  refs.elapsedLabel.textContent = formatTime(state.elapsedSeconds);
  refs.songLengthLabel.textContent = state.totalSeconds > 0 ? formatTime(state.totalSeconds) : "∞";
  const currentValue = state.totalSeconds > 0
    ? Math.min(state.elapsedSeconds, state.totalSeconds)
    : Math.max(0, state.elapsedSeconds);
  // Keep the range input useful in unbounded Long Play: its visible extent
  // grows with the elapsed clock instead of clamping the control at 1 second.
  refs.progressSlider.max = String(Math.max(state.totalSeconds, currentValue, 1));
  refs.progressSlider.value = String(currentValue);
  const percent = state.totalSeconds > 0 ? (currentValue / state.totalSeconds) * 100 : 0;
  refs.progressSliderShell.style.setProperty("--progress-percent", `${Math.max(0, Math.min(percent, 100))}%`);
}

function updatePlaybackReadout() {
  updateElapsedReadout();
  const playlistTotalSeconds = state.playlist.reduce((sum, entry) => sum + currentOutputBasePlaybackSeconds(entry), 0);
  refs.playlistTotalLabel.textContent = formatTime(playlistTotalSeconds);
  playbackApp.ui?.updateSB2Titlebar?.();
  refs.playButton.querySelector("use")?.setAttribute("href", "#icon-play");
  refs.playButton.classList.toggle("sb-is-playing", state.isPlaying);
  refs.playButton.setAttribute("aria-label", state.isPlaying ? "Pause" : "Play");
  refs.stopButton.disabled = !state.currentTrackId && !state.currentTrackInfo;
  syncMediaSessionState();
}

function updateNativeDiagnostics() {
  const snapshot = state.nativePlayback;
  const transportLabel = snapshot.trackLoaded
    ? `${snapshot.transportState} / ${snapshot.outputState}`
    : "native idle";
  const bufferedFrames = Number(snapshot.bufferedFrames) || 0;
  const ringBufferFrames = Number(snapshot.ringBufferFrames) || 0;
  const underrunCount = Number(snapshot.underrunCount) || 0;
  const framesRequested = Number(snapshot.framesRequested) || 0;
  const framesSupplied = Number(snapshot.framesSupplied) || 0;
  const decoderSampleRate = Number(snapshot.decoderSampleRate) || 0;
  const outputSampleRate = Number(snapshot.outputSampleRate) || 0;
  const decodedFrames = Number(snapshot.decodedFrames) || 0;
  const audiblePositionFrames = Number(snapshot.audiblePositionFrames) || 0;
  const tempo = Number(snapshot.tempo) || 1;
  const positionSeconds = Math.max(0, (Number(snapshot.positionMs) || 0) / 1000);
  const bufferFill = ringBufferFrames > 0 ? Math.round((bufferedFrames / ringBufferFrames) * 100) : null;
  const decodeError = Boolean(snapshot.decodeError);

  refs.nativeTransportLabel.textContent = transportLabel;
  refs.nativeTrackLabel.textContent = snapshot.trackLoaded ? "Loaded" : "Not loaded";
  refs.nativeOutputLabel.textContent = snapshot.outputState || "idle";
  refs.nativePositionLabel.textContent = formatTime(positionSeconds);
  refs.nativeBufferLabel.textContent = `${bufferedFrames.toLocaleString()} / ${ringBufferFrames ? ringBufferFrames.toLocaleString() : "—"} frames`;
  refs.nativeBufferFillLabel.textContent = bufferFill === null ? "—" : `${bufferFill}%`;
  refs.nativeUnderrunLabel.textContent = String(underrunCount);
  refs.nativeFramesLabel.textContent = `${framesRequested.toLocaleString()} / ${framesSupplied.toLocaleString()}`;
  refs.nativeDecoderLabel.textContent = snapshot.decoderFamily || "—";
  refs.nativeRatesLabel.textContent = `${decoderSampleRate ? decoderSampleRate.toLocaleString() : "—"} / ${outputSampleRate ? outputSampleRate.toLocaleString() : "—"} Hz`;
  refs.nativeDecodedLabel.textContent = `${decodedFrames.toLocaleString()} / ${audiblePositionFrames.toLocaleString()}`;
  refs.nativeTempoLabel.textContent = `${tempo.toLocaleString(undefined, { maximumFractionDigits: 3 })}×`;
  refs.nativeDecodeLabel.textContent = decodeError ? (snapshot.errorMessage || "Error") : "OK";

  for (const element of [
    refs.nativeTransportLabel,
    refs.nativeTrackLabel,
    refs.nativeOutputLabel,
    refs.nativePositionLabel,
    refs.nativeBufferLabel,
    refs.nativeBufferFillLabel,
    refs.nativeUnderrunLabel,
    refs.nativeFramesLabel,
    refs.nativeDecoderLabel,
    refs.nativeRatesLabel,
    refs.nativeDecodedLabel,
    refs.nativeTempoLabel,
    refs.nativeDecodeLabel
  ]) {
    element.className = "play-stat-value";
  }

  if (snapshot.transportState === "playing") {
    refs.nativeTransportLabel.classList.add("is-active");
  }

  if (bufferedFrames > 0 && ringBufferFrames > 0 && bufferedFrames < Math.min(2048, ringBufferFrames / 8)) {
    refs.nativeBufferLabel.classList.add("is-warning");
    refs.nativeBufferFillLabel.classList.add("is-warning");
  }

  if (underrunCount > 0) {
    refs.nativeUnderrunLabel.classList.add("is-warning");
  }

  if (decodeError) {
    refs.nativeTransportLabel.classList.add("is-error");
    refs.nativeUnderrunLabel.classList.add("is-error");
    refs.nativeDecodeLabel.classList.add("is-error");
  }
}

function handleNativePlaybackState(snapshot) {
  if (!snapshot) {
    return;
  }

  const track = activeTrackInfo();
  if (!track) {
    state.nativePlayback = {
      transportState: snapshot?.transport_state || "stopped",
      outputState: snapshot?.output_state || "idle",
      generation: Number(snapshot?.generation) || 0,
      statusSequence: Number(snapshot?.status_sequence) || 0,
      trackLoaded: Boolean(snapshot?.track_loaded),
      decodeError: Boolean(snapshot?.decode_error),
      reachedEnd: Boolean(snapshot?.reached_end),
      bufferedFrames: Number(snapshot?.buffered_frames) || 0,
      ringBufferFrames: Number(snapshot?.ring_buffer_frames) || 0,
      underrunCount: Number(snapshot?.underrun_count) || 0,
      framesRequested: Number(snapshot?.frames_requested) || 0,
      framesSupplied: Number(snapshot?.frames_supplied) || 0,
      decoderFamily: snapshot?.decoder_family || "",
      decoderSampleRate: Number(snapshot?.decoder_sample_rate) || 0,
      outputSampleRate: Number(snapshot?.output_sample_rate) || 0,
      decodedFrames: Number(snapshot?.decoded_frames) || 0,
      audiblePositionFrames: Number(snapshot?.audible_position_frames) || 0,
      tempo: Number(snapshot?.tempo) || 1,
      positionMs: Number(snapshot?.position_ms) || 0,
      errorMessage: snapshot?.error || ""
    };
    updateNativeDiagnostics();
    return;
  }

  const applied = applyNativePlaybackSnapshot(track, snapshot, playbackGeneration);
  if (!applied) {
    return;
  }
}

async function handleNativePlaybackEnded(event) {
  const generation = playbackGeneration;
  const expectedNativeGeneration = Number(state.nativePlayback?.generation) || 0;
  const observedNativeGeneration = Number(event?.generation) || 0;
  if (pendingPlaybackIntent && observedNativeGeneration > 0 && event?.transport_state === "ended") {
    const trackId = observedNativeGeneration === expectedNativeGeneration && state.currentTrackId
      ? state.currentTrackId : pendingPlaybackIntent.trackId;
    if (trackId) {
      deferredNativeEnds = deferredNativeEnds.filter(item => item.nativeGeneration !== observedNativeGeneration);
      deferredNativeEnds.push({ event, trackId, nativeGeneration: observedNativeGeneration });
    }
    return;
  }
  if (!activeTrackInfo() || !state.currentTrackId
      || (expectedNativeGeneration > 0
          && observedNativeGeneration > 0
          && expectedNativeGeneration !== observedNativeGeneration)) {
    return;
  }

  const applied = applyNativePlaybackSnapshot(activeTrackInfo(), event, generation);
  if (!applied || event?.transport_state !== "ended") return;
  await finalizePlaybackEnded(event);
}

async function setPlaybackPowerSaveBlocker(enabled) {
  try {
    await window.spcBoySB2.setPlaybackPowerSaveBlocker(enabled);
  } catch {
    // Power-save blocker is best-effort support around playback.
  }
}

async function ensureNativePlaybackInitialized(generation) {
  if (nativePlaybackInitialized) {
    return;
  }

  await window.spcBoySB2.nativePlaybackInit();
  if (generation !== playbackGeneration) return;
  // Startup belongs to the playback generation. Do not wait behind a stale
  // settings write from a previous start; the shared native transport already
  // serializes both complete snapshots.
  await window.spcBoySB2.nativePlaybackAudioConfig({
    appVolume: state.appVolume,
    equalizerEnabled: state.equalizerEnabled,
    equalizerBandGains: state.equalizerBandGains,
    monoEnabled: state.monoEnabled
  });
  if (generation !== playbackGeneration) return;
  nativePlaybackInitialized = true;
}

function applyNativePlaybackSnapshot(
  track,
  snapshot,
  generation,
  { allowNativeGenerationChange = false, allowPositionRewind = false } = {}
) {
  if (generation !== playbackGeneration) {
    return;
  }

  const activeTrack = track ?? activeTrackInfo();
  const observedNativeGeneration = Number(snapshot?.generation) || 0;
  const expectedNativeGeneration = Number(state.nativePlayback?.generation) || 0;
  if (!allowNativeGenerationChange && activeTrack && expectedNativeGeneration > 0 && observedNativeGeneration > 0
      && observedNativeGeneration !== expectedNativeGeneration) {
    return false;
  }
  const totalSeconds = effectiveTotalSeconds(activeTrack);
  const transportState = snapshot?.transport_state || "stopped";
  const previous = state.nativePlayback || {};
  const observedStatusSequence = Number(snapshot?.status_sequence) || 0;
  const previousStatusSequence = Number(previous.statusSequence) || 0;
  if (observedStatusSequence > 0
      && previousStatusSequence > 0
      && observedStatusSequence < previousStatusSequence) {
    return false;
  }

  const nativeElapsedSeconds = clampPosition((Number(snapshot?.position_ms) || 0) / 1000, totalSeconds);
  const sameLoadedTrack = Boolean(activeTrack)
    && state.currentTrackId === activeTrack.id
    && Boolean(previous.trackLoaded)
    && previous.transportState !== "stopped"
    && transportState !== "ended";
  // Native status is authoritative, but a queued status can legitimately be
  // older in position than the visible renderer clock (for example while the
  // decoder is refilling). Do not make the clock jump back to zero. Explicit
  // starts and seeks opt into rewinding below.
  const elapsedSeconds = !allowPositionRewind && sameLoadedTrack
    ? Math.max(nativeElapsedSeconds, Number(state.elapsedSeconds) || 0)
    : nativeElapsedSeconds;

  state.nativePlayback = {
    transportState,
    outputState: snapshot?.output_state ?? previous.outputState ?? "idle",
    generation: observedNativeGeneration,
    statusSequence: snapshot?.status_sequence === undefined
      ? previousStatusSequence
      : observedStatusSequence,
    trackLoaded: Boolean(snapshot?.track_loaded),
    decodeError: snapshot?.decode_error === undefined ? Boolean(previous.decodeError) : Boolean(snapshot.decode_error),
    reachedEnd: Boolean(snapshot?.reached_end),
    bufferedFrames: snapshot?.buffered_frames === undefined ? (previous.bufferedFrames || 0) : (Number(snapshot.buffered_frames) || 0),
    ringBufferFrames: snapshot?.ring_buffer_frames === undefined ? (previous.ringBufferFrames || 0) : (Number(snapshot.ring_buffer_frames) || 0),
    underrunCount: snapshot?.underrun_count === undefined ? (previous.underrunCount || 0) : (Number(snapshot.underrun_count) || 0),
    framesRequested: snapshot?.frames_requested === undefined ? (previous.framesRequested || 0) : (Number(snapshot.frames_requested) || 0),
    framesSupplied: snapshot?.frames_supplied === undefined ? (previous.framesSupplied || 0) : (Number(snapshot.frames_supplied) || 0),
    decoderFamily: snapshot?.decoder_family ?? previous.decoderFamily ?? "",
    decoderSampleRate: snapshot?.decoder_sample_rate === undefined ? (previous.decoderSampleRate || 0) : (Number(snapshot.decoder_sample_rate) || 0),
    outputSampleRate: snapshot?.output_sample_rate === undefined ? (previous.outputSampleRate || 0) : (Number(snapshot.output_sample_rate) || 0),
    decodedFrames: snapshot?.decoded_frames === undefined ? (previous.decodedFrames || 0) : (Number(snapshot.decoded_frames) || 0),
    audiblePositionFrames: snapshot?.audible_position_frames === undefined ? (previous.audiblePositionFrames || 0) : (Number(snapshot.audible_position_frames) || 0),
      tempo: snapshot?.tempo === undefined ? (previous.tempo || 1) : (Number(snapshot.tempo) || 1),
    positionMs: Number(snapshot?.position_ms) || 0,
    errorMessage: snapshot?.error ?? previous.errorMessage ?? ""
  };

  state.totalSeconds = totalSeconds;
  state.elapsedSeconds = elapsedSeconds;
  state.isPlaying = transportState === "playing";

  if (transportState === "ended") {
    state.isPlaying = false;
    state.elapsedSeconds = totalSeconds;
  }

  anchorPlaybackClock(activeTrack, snapshot, state.elapsedSeconds);

  updatePlaybackReadout();
  updateNativeDiagnostics();
  return true;
}

async function finalizePlaybackEnded(event = null) {
  if (queuedSkipRequest) {
    // Preserve an end that arrived before the skip's replacement intent. If
    // preparation fails, the normal completion path can still consume it.
    if (event) deferredNativeEnds.push({ event, trackId: state.currentTrackId,
      nativeGeneration: Number(event.generation) || 0 });
    return completeQueuedSkip();
  }
  const finalizationGeneration = playbackGeneration;
  const completedTrackId = state.currentTrackId;
  const nativeGeneration = Number(state.nativePlayback?.generation) || finalizationGeneration;
  // The coordinator owns the one-shot natural-end claim and queue decision.
  const retirementDecision = await window.spcBoySB2.playbackCompletionRetire({
    generation: nativeGeneration,
    state: {
      currentTrackId: completedTrackId,
      selectedTrackId: state.selectedTrackId,
      pendingTrackId: null
    },
    playlistIds: playbackPlaylist().map((track) => track.id),
    repeatMode: state.repeatMode === "all"
      ? "playlist"
      : state.repeatMode === "one"
        ? "song"
        : "off"
  });
  if (!retirementDecision) return;
  if (finalizationGeneration !== playbackGeneration
      || state.currentTrackId !== completedTrackId
      || (Number(state.nativePlayback?.generation) || nativeGeneration) !== nativeGeneration) {
    return;
  }
  await continueAfterPlaybackRetirement({
    finalizationGeneration,
    completedTrackId,
    retirementDecision
  });
}

async function continueAfterPlaybackRetirement({
  finalizationGeneration,
  completedTrackId,
  retirementDecision
}) {
  const completionTargetId = retirementDecision?.action === "play"
    ? retirementDecision.trackId
    : null;
  state.isPlaying = false;
  state.elapsedSeconds = state.totalSeconds;
  updatePlaybackReadout();
  updateNativeDiagnostics();

  queuedSkipRequest = null;
  clearQueuedSkipTimer();
  await stopPlaybackState({ declick: false, nativeAlreadyRetired: true });

  // The native retirement operation already invalidated the completed
  // session. stopPlaybackState advances the WebKit presentation generation
  // once; a newer user request advances it again, so only the expected single
  // retirement may continue into queue advance.
  if (playbackGeneration !== finalizationGeneration + 1 || state.currentTrackId) {
    return;
  }

  if (completionTargetId) {
    await playTrack(completionTargetId, 0);
  }
}

async function stopPlaybackState({ declick = true, keepNativeOutput = false, nativeAlreadyRetired = false } = {}) {
  cancelPlaybackIntent();
  queuedSkipRequest = null;
  clearQueuedSkipTimer();
  const generation = ++playbackGeneration;
  if (!nativeAlreadyRetired) {
    await stopAllOutput({ declick, keepNativeOutput, generation });
  }
  if (generation !== playbackGeneration) return;

  await setPlaybackPowerSaveBlocker(false);
  if (generation !== playbackGeneration) return;
  state.currentTrackId = null;
  state.currentTrackInfo = null;
  playbackWindow = null;
  state.isPlaying = false;
  state.elapsedSeconds = 0;
  const previewTrack = activeTrackInfo();
  state.totalSeconds = previewTrack ? currentTotalSeconds(previewTrack) : targetPlaybackSeconds();
  resetNativePlaybackSnapshot();
  updatePlaybackReadout();
  updateNativeDiagnostics();
  playbackApp.ui.refreshPlaylistPlaybackState();
}

async function cancelQueuedSkip({ restoreOutput = false } = {}) {
  const request = queuedSkipRequest;
  queuedSkipRequest = null;
  clearQueuedSkipTimer();
  if (restoreOutput && request && nativePlaybackInitialized && state.nativePlayback?.trackLoaded
      && Number.isSafeInteger(request.nativeGeneration) && request.nativeGeneration > 0
      && Number(state.nativePlayback.generation) === request.nativeGeneration) {
    try {
      await window.spcBoySB2.nativePlaybackRampGain({ outputGain: 1, rampMilliseconds: TRANSPORT_DECLICK_MS,
        expectedGeneration: request.nativeGeneration });
    } catch (error) {
      // A stale or unavailable restore must not block the following control;
      // that control carries its own native-generation guard.
      console.warn("[SPCBoy] queued-skip gain restoration failed", error);
    }
  }
}

async function playTrackNow(trackId, startSeconds = 0, playbackOptions = null) {
  let track = (playbackOptions?.pendingQueue || playbackPlaylist()).find((entry) => entry.id === trackId);
  if (!track) {
    return;
  }

  const generation = ++playbackGeneration;
  const settingsGeneration = playbackSettingsGeneration;
  const timingPlan = await resolveTimingPlan(track, { force: true });
  if (generation !== playbackGeneration) {
    return;
  }
  if (settingsGeneration !== playbackSettingsGeneration) {
    return playTrackNow(trackId, startSeconds, playbackOptions);
  }
  // Native-state broadcasts can arrive while the native playback request is in flight.
  // Keep this request's offset immutable so a prior track cannot leak its elapsed position.
  const trackDuration = currentTotalSeconds(track);
  let requestedStartSeconds = trackDuration > 0
    ? Math.max(0, Math.min(startSeconds, trackDuration))
    : Math.max(0, Number(startSeconds) || 0);
  const fadeNowSeconds = Math.max(0, Number(playbackOptions?.fadeNowSeconds) || 0);
  const normalBaseSeconds = currentOutputBasePlaybackSeconds(track);
  let playbackTotalSeconds = fadeNowSeconds > 0
    ? requestedStartSeconds + fadeNowSeconds
    : currentTotalSeconds(track);
  let playbackBaseSeconds = fadeNowSeconds > 0
    ? Math.max(0.001, requestedStartSeconds)
    : normalBaseSeconds;
  const nextPlaybackWindow = fadeNowSeconds > 0
    ? { trackId: track.id, totalSeconds: playbackTotalSeconds, fadeSeconds: fadeNowSeconds }
    : null;
  const previousTrack = state.currentTrackInfo;
  const previousGeneration = Number(state.nativePlayback?.generation) || 0;
  const hadPreviousSession = Boolean(state.currentTrackId && state.nativePlayback?.trackLoaded && previousGeneration > 0);

  try {
    await setPlaybackPowerSaveBlocker(true);
    if (generation !== playbackGeneration) return;
    if (playbackTotalSeconds > 0 && requestedStartSeconds >= playbackTotalSeconds) {
      await stopAllOutput({ keepNativeOutput: true, generation });
      if (generation !== playbackGeneration) return;
      await setPlaybackPowerSaveBlocker(false);
      if (generation !== playbackGeneration) return;
      state.currentTrackId = track.id;
      state.currentTrackInfo = track;
      if (playbackOptions?.pendingQueue) {
        state.playingPlaylist = playbackOptions.pendingQueue;
        state.playbackTabId = playbackOptions.pendingTabId;
      }
      state.totalSeconds = playbackTotalSeconds;
      state.elapsedSeconds = requestedStartSeconds;
      playbackWindow = nextPlaybackWindow;
      state.isPlaying = false;
      resetNativePlaybackSnapshot();
      updatePlaybackReadout();
      playbackApp.ui.refreshPlaylistPlaybackState();
      return;
    }
    await ensureNativePlaybackInitialized(generation);
    if (generation !== playbackGeneration) return;
    if (settingsGeneration !== playbackSettingsGeneration) {
      return playTrackNow(trackId, startSeconds, playbackOptions);
    }
    const snapshot = await window.spcBoySB2.nativePlaybackStart({
      trackId: track.id,
      path: track.path,
      archivePath: track.archivePath || null,
      archiveEntry: track.archiveEntry || null,
      trackIndex: track.trackIndex || 0,
      startMilliseconds: Math.round(requestedStartSeconds * 1000),
      playMilliseconds: Math.round((fadeNowSeconds > 0
        ? playbackBaseSeconds
        : (timingPlan.is_long_play ? playbackBaseSeconds : 0)) * 1000),
      fadeMilliseconds: Math.round((fadeNowSeconds > 0 ? fadeNowSeconds : currentFadeSeconds(track)) * 1000),
      tempo: requestedPlaybackSpeed(),
      longPlayEnabled: timingPlan.is_long_play,
      timedOverride: fadeNowSeconds > 0,
      unknownDurationMilliseconds: Math.round(state.unknownDurationSeconds * 1000),
      expectedPreviousGeneration: playbackOptions?.expectedPreviousGeneration || null
    });
    if (generation !== playbackGeneration) {
      return;
    }

    await setPlaybackPowerSaveBlocker(true);
    if (generation !== playbackGeneration) return;
    state.currentTrackId = track.id;
    state.currentTrackInfo = track;
    if (playbackOptions?.pendingQueue) {
      state.playingPlaylist = playbackOptions.pendingQueue;
      state.playbackTabId = playbackOptions.pendingTabId;
    }
    state.totalSeconds = playbackTotalSeconds;
    state.elapsedSeconds = requestedStartSeconds;
    playbackWindow = nextPlaybackWindow;
    resetNativePlaybackSnapshot();
    applyNativePlaybackSnapshot(track, snapshot, generation, {
      allowNativeGenerationChange: true,
      allowPositionRewind: true
    });
    if (typeof window.spcBoySB2?.playbackHistoryRecord === "function") {
      void window.spcBoySB2.playbackHistoryRecord(track, Date.now()).catch((error) => {
        console.error("[SPCBoy] could not record playback history", error);
      });
    }
    // Native status events advance the readout and native completion events
    // drive the generation-checked end handoff. JavaScript does not poll.
    playbackApp.ui.refreshPlaylistPlaybackState();
    if (settingsGeneration !== playbackSettingsGeneration) {
      await refreshPlaybackForTimingChange();
    }
  } catch (error) {
    if (generation !== playbackGeneration) {
      return;
    }

    let retainedSnapshot = null;
    if (hadPreviousSession) {
      try { retainedSnapshot = await window.spcBoySB2.nativePlaybackState(); } catch {}
      if (generation !== playbackGeneration) return;
      if (!retainedSnapshot || (retainedSnapshot.track_loaded
          && Number(retainedSnapshot.generation) === previousGeneration)) {
        if (retainedSnapshot) applyNativePlaybackSnapshot(previousTrack, retainedSnapshot, generation);
        playbackApp.ui.refreshPlaylistPlaybackState();
        throw error;
      }
      // A different loaded generation may belong to a newer native intent.
      // Never close it as cleanup for this failed request.
      if (retainedSnapshot.track_loaded) throw error;
    }
    await setPlaybackPowerSaveBlocker(false);
    if (generation !== playbackGeneration) return;
    state.currentTrackId = track.id;
    state.currentTrackInfo = track;
    state.totalSeconds = playbackTotalSeconds;
    state.elapsedSeconds = requestedStartSeconds;
    playbackWindow = nextPlaybackWindow;
    state.isPlaying = false;
    resetNativePlaybackSnapshot();
    try { await window.spcBoySB2.nativePlaybackClose(); } catch {}
    if (generation !== playbackGeneration) return;
    nativePlaybackInitialized = false;
    updatePlaybackReadout();
    updateNativeDiagnostics();
    playbackApp.ui.refreshPlaylistPlaybackState();
    throw error;
  }
}

function playTrack(trackId, startSeconds = 0, preserveQueuedSkip = false, playbackOptions = null, restoreNativeGeneration = 0) {
  clearPlaybackError();
  const intent = beginPlaybackIntent(trackId);
  const replacedQueuedSkip = !preserveQueuedSkip ? queuedSkipRequest : null;
  const replacingQueuedSkip = Boolean(replacedQueuedSkip);
  if (!preserveQueuedSkip) {
    queuedSkipRequest = null;
    clearQueuedSkipTimer();
  }
  const requestedTrackIsInPlayingQueue = state.playingPlaylist?.some((track) => track.id === trackId);
  const needsQueue = playbackOptions?.replaceQueue || !state.playingPlaylist?.length || !requestedTrackIsInPlayingQueue;
  const requestOptions = playbackOptions?.pendingQueue ? playbackOptions : needsQueue
    ? { ...playbackOptions, pendingQueue: [...state.playlist], pendingTabId: state.activePlaylistTabId || null }
    : playbackOptions;
  const guardedOptions = preserveQueuedSkip && restoreNativeGeneration > 0
    ? { ...requestOptions, expectedPreviousGeneration: restoreNativeGeneration }
    : requestOptions;
  let request;
  if (!preserveQueuedSkip
      && !replacingQueuedSkip
      && state.currentTrackId
      && state.isPlaying) {
    request = playTrackWithFadedSkip(trackId, startSeconds, guardedOptions);
  } else {
    request = playTrackNow(trackId, startSeconds, guardedOptions);
  }
  const restoreGeneration = Number(replacedQueuedSkip?.nativeGeneration) || restoreNativeGeneration;
  return Promise.resolve(request).catch(async (error) => {
    if (pendingPlaybackIntent === intent && state.currentTrackId
        && state.nativePlayback?.trackLoaded && restoreGeneration > 0) {
      try {
        await window.spcBoySB2.nativePlaybackRampGain({ outputGain: 1, rampMilliseconds: TRANSPORT_DECLICK_MS,
          expectedGeneration: restoreGeneration });
      } catch {}
    }
    if (pendingPlaybackIntent === intent) showPlaybackError(error);
    throw error;
  }).finally(() => finishPlaybackIntent(intent));
}

async function completeQueuedSkip() {
  const request = queuedSkipRequest;
  if (!request || request.generation !== playbackGeneration || request.completing) return;
  request.completing = true;
  const intent = beginPlaybackIntent(request.targetTrackId || null);
  try {
    const decision = await window.spcBoySB2.nativePlaybackQueuedSkipDecision({
      expectedGeneration: request.nativeGeneration > 0 ? request.nativeGeneration : null,
      targetTrackId: request.targetTrackId || null,
      navigation: request.targetTrackId ? null : {
        state: { currentTrackId: state.currentTrackId, selectedTrackId: state.selectedTrackId, pendingTrackId: null },
        playlistIds: playbackPlaylist().map(track => track.id),
        direction: request.delta < 0 ? "previous" : "next",
        wraps: true
      }
    });
    if (request !== queuedSkipRequest || request.generation !== playbackGeneration) return;
    const target = decision?.trackId;
    if (!target) {
      await cancelQueuedSkip({ restoreOutput: true });
      return;
    }
    queuedSkipRequest = null;
    clearQueuedSkipTimer();
    await playTrack(target, request.startSeconds || 0, true, request.playbackOptions || null,
      request.nativeGeneration);
  } catch (error) {
    if (request === queuedSkipRequest && request.generation === playbackGeneration) {
      await cancelQueuedSkip({ restoreOutput: true });
    }
    throw error;
  } finally {
    await finishPlaybackIntent(intent);
  }
}

async function playTrackWithFadedSkip(trackId, startSeconds = 0, playbackOptions = null) {
  const track = (playbackOptions?.pendingQueue || playbackPlaylist()).find((entry) => entry.id === trackId);
  if (!track) return;

  const generation = ++playbackGeneration;
  const current = currentTrack();
  const fadePlan = await window.spcBoySB2.playbackFadePlan({
    enabled: state.queuedSkipsEnabled,
    isPlaying: state.isPlaying,
    hasCurrentTrack: Boolean(current),
    elapsedSeconds: state.elapsedSeconds,
    preFadeSeconds: currentOutputBasePlaybackSeconds(current),
    fadeSeconds: currentFadeSeconds(current),
    totalSeconds: currentTotalSeconds(current)
  });
  if (generation !== playbackGeneration) return;
  if (!fadePlan) return playTrackNow(trackId, startSeconds, playbackOptions);

  queuedSkipRequest = {
    targetTrackId: trackId,
    startSeconds,
    playbackOptions,
    generation,
    nativeGeneration: Number(state.nativePlayback.generation) || 0
  };
  scheduleQueuedSkipFade(queuedSkipRequest, fadePlan, "[SPCBoy] faded playlist activation failed");
}

async function advanceToAdjacent(delta, generation = playbackGeneration) {
  const queue = playbackPlaylist();
  if (queue.length === 0) {
    return;
  }

  try {
    const playlistIDs = queue.map((track) => track.id);
    const navigation = await window.spcBoySB2.playbackQueueAdjacent({
      state: {
        currentTrackId: state.currentTrackId,
        selectedTrackId: state.selectedTrackId,
        pendingTrackId: null
      },
      playlistIds: playlistIDs,
      direction: delta < 0 ? "previous" : "next",
      wraps: true
    });
    const nextID = navigation?.trackId;
    if (generation !== playbackGeneration || !nextID) return;
    await playTrack(nextID, 0);
  } catch (error) {
    console.error(error);
  }
}

function playAdjacent(delta) {
  const intent = beginPlaybackIntent();
  return playAdjacentNow(delta).finally(() => finishPlaybackIntent(intent)).catch((error) => {
    console.error("[SPCBoy] adjacent playback failed", error);
  });
}

async function playAdjacentNow(delta) {
  const generation = ++playbackGeneration;
  if (!state.currentTrackId) {
    await advanceToAdjacent(delta, generation);
    return;
  }

  if (queuedSkipRequest) {
    const previousRequest = queuedSkipRequest;
    clearQueuedSkipTimer();
    // The newer navigation takes over the short remaining fade, then uses the
    // same replacement-safe handoff as an ordinary queued skip.
    queuedSkipRequest = {
      delta: delta || previousRequest.delta,
      generation,
      nativeGeneration: previousRequest.nativeGeneration
    };
    await fadeActiveOutput(TRANSPORT_DECLICK_MS, { expectedGeneration: previousRequest.nativeGeneration });
    if (generation !== playbackGeneration) return;
    await completeQueuedSkip();
    return;
  }

  const track = currentTrack();
  const fadeSeconds = currentFadeSeconds(track);
  const fadePlan = await window.spcBoySB2.playbackFadePlan({
    enabled: state.queuedSkipsEnabled,
    isPlaying: state.isPlaying,
    hasCurrentTrack: Boolean(track),
    elapsedSeconds: state.elapsedSeconds,
    preFadeSeconds: currentOutputBasePlaybackSeconds(track),
    fadeSeconds,
    totalSeconds: currentTotalSeconds(track)
  });
  if (generation !== playbackGeneration) return;
  if (!fadePlan) {
    await advanceToAdjacent(delta, generation);
    return;
  }

  queuedSkipRequest = {
    delta,
    generation: playbackGeneration,
    nativeGeneration: Number(state.nativePlayback.generation) || 0
  };
  scheduleQueuedSkipFade(queuedSkipRequest, fadePlan, "[SPCBoy] faded skip failed");
}

async function togglePlayback() {
  const track = activeTrackInfo();
  const nativeSessionIsPlaying = state.nativePlayback?.transportState === "playing";
  if (!track && !state.isPlaying && !nativeSessionIsPlaying) {
    return;
  }

  // Native transport status is authoritative for this toggle. If a delayed
  // status left the renderer identity or flag behind, do not issue Play
  // against a session that is already running; that can restart the selected
  // item instead of pausing the active one.
  if (state.isPlaying || nativeSessionIsPlaying) {
    if (queuedSkipRequest) {
      queuedSkipRequest = null;
      clearQueuedSkipTimer();
    }
    const generation = ++playbackGeneration;
    const expectedGeneration = currentNativeGeneration();
    try {
      await fadeActiveOutput(TRANSPORT_DECLICK_MS);
      if (generation !== playbackGeneration) return;
      const snapshot = await window.spcBoySB2.nativePlaybackPause({ expectedGeneration });
      if (generation !== playbackGeneration) return;
      await setPlaybackPowerSaveBlocker(false);
      if (generation !== playbackGeneration) return;
      applyNativePlaybackSnapshot(track, snapshot, generation);
      updatePlaybackReadout();
      return;
    } catch (error) {
      if (generation === playbackGeneration && nativePlaybackInitialized && state.nativePlayback?.trackLoaded) {
        try {
          await window.spcBoySB2.nativePlaybackRampGain({ outputGain: 1, rampMilliseconds: TRANSPORT_DECLICK_MS,
            expectedGeneration });
        } catch {}
      }
      throw error;
    }
  }

  if (!track) return;

  if (!state.currentTrackId || state.currentTrackId !== track.id) {
    await playTrack(track.id, 0);
    return;
  }

  if (nativePlaybackInitialized && state.nativePlayback.trackLoaded) {
    const generation = ++playbackGeneration;
    const expectedGeneration = currentNativeGeneration();
    try {
      await setPlaybackPowerSaveBlocker(true);
      if (generation !== playbackGeneration) return;
      const snapshot = await window.spcBoySB2.nativePlaybackResume({ expectedGeneration });
      if (generation !== playbackGeneration) {
        return;
      }
      applyNativePlaybackSnapshot(track, snapshot, generation);
      updatePlaybackReadout();
      return;
    } catch (error) {
      if (generation === playbackGeneration) {
        await setPlaybackPowerSaveBlocker(false);
      }
      throw error;
    }
  }

  await playTrack(track.id, state.elapsedSeconds);
}

async function restartAt(seconds) {
  const track = activeTrackInfo();
  if (!track) {
    return;
  }

  state.elapsedSeconds = state.totalSeconds > 0
    ? Math.max(0, Math.min(seconds, state.totalSeconds))
    : Math.max(0, Number(seconds) || 0);
  updatePlaybackReadout();

  if (state.currentTrackId === track.id) {
    if (nativePlaybackInitialized && state.nativePlayback.trackLoaded) {
      const generation = ++playbackGeneration;
      const expectedGeneration = currentNativeGeneration();
      const requestedMilliseconds = Math.round(state.elapsedSeconds * 1000);
      await cancelQueuedSkip({ restoreOutput: true });
      if (generation !== playbackGeneration) return;
      try {
        const snapshot = await window.spcBoySB2.nativePlaybackSeek({ positionMilliseconds: requestedMilliseconds, expectedGeneration });
        if (generation !== playbackGeneration) {
          return;
        }
        applyNativePlaybackSnapshot(track, snapshot, generation, { allowPositionRewind: true });
        updatePlaybackReadout();
        return;
      } catch (error) {
        if (generation === playbackGeneration) {
          updateNativeDiagnostics();
        }
        throw error;
      }
    }

    await playTrack(track.id, state.elapsedSeconds);
  }
}

async function refreshPlaybackForTimingChange() {
  // Timing changes apply to the loaded session, including a paused session.
  // Do not use activeTrackInfo() here: after a native stop it may return the
  // last presentation track even though no current session exists.
  const requestGeneration = ++playbackSettingsGeneration;
  const generation = playbackGeneration;
  // Timing preferences affect every track, including a stopped selection.
  timingPlans.clear();
  const track = currentTrack();
  if (!track || state.currentTrackId !== track.id) {
    const previewTrack = activeTrackInfo();
    updateTimingSummary();
    updatePlaybackReadout();
    if (!state.currentTrackId && previewTrack) {
      const preview = await resolveTimingPlan(previewTrack, { force: true, cache: false });
      if (requestGeneration !== playbackSettingsGeneration || generation !== playbackGeneration
          || state.currentTrackId || activeTrackInfo()?.id !== previewTrack.id) return;
      timingPlans.set(previewTrack.id, preview);
      updateTimingSummary();
      updatePlaybackReadout();
    }
    return;
  }

  const trackID = track.id;
  const plan = await resolveTimingPlan(track, { force: true, cache: false });
  if (!matchesCurrentPlaybackSettings(requestGeneration, generation, trackID)) return;
  timingPlans.set(trackID, plan);
  if (!nativePlaybackInitialized || !state.nativePlayback.trackLoaded) {
    state.totalSeconds = currentTotalSeconds(track);
    updateTimingSummary();
    updatePlaybackReadout();
    return;
  }

  const expectedGeneration = Number(state.nativePlayback.generation);
  if (!Number.isSafeInteger(expectedGeneration) || expectedGeneration <= 0) {
    throw new Error("Playback session identity is unavailable; retry the timing change.");
  }
  let snapshot;
  try {
    snapshot = await window.spcBoySB2.nativePlaybackReconfigure({
      longPlayEnabled: plan.is_long_play,
      manualPlayMilliseconds: Math.max(0, Math.round(plan.pre_fade_seconds * 1000)),
      fadeMilliseconds: Math.max(0, Math.round(plan.fade_seconds * 1000)),
      unknownDurationMilliseconds: Math.max(1, Math.round(state.unknownDurationSeconds * 1000)),
      tempo: requestedPlaybackSpeed(),
      expectedGeneration
    });
  } catch (error) {
    if (!matchesCurrentPlaybackSettings(requestGeneration, generation, trackID)) return;
    throw error;
  }
  if (!matchesCurrentPlaybackSettings(requestGeneration, generation, trackID)) return;
  applyNativePlaybackSnapshot(track, snapshot, generation, {
    allowNativeGenerationChange: true, allowPositionRewind: true
  });
  state.totalSeconds = effectiveTotalSeconds(track);
  state.elapsedSeconds = state.totalSeconds > 0
    ? Math.max(0, Math.min(state.elapsedSeconds, state.totalSeconds))
    : Math.max(0, state.elapsedSeconds);
  updateTimingSummary();
  updatePlaybackReadout();
}

async function refreshPlaybackForSpeedChange() {
  await refreshPlaybackForTimingChange();
}

playbackApp.playback = {
  updateTimingSummary,
  updatePlaybackReadout,
  updateNativeDiagnostics,
  handleNativePlaybackState,
  handleNativePlaybackEnded,
  handleQueuedFadeReady,
  stopPlaybackState,
  playTrack,
  finalizePlaybackEnded,
  playAdjacent,
  togglePlayback,
  restartAt,
  refreshPlaybackForTimingChange,
  refreshPlaybackForSpeedChange,
  setPlaybackClockPosition,
  chooseAACExportDirectory,
  exportTrackAsAAC,
  handleAACExportEvent,
  cancelAACExport,
  cancelQueuedSkip
};
})();
