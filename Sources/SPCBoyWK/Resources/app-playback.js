(() => {
const playbackApp = window.SPCBoyApp;
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

const NATIVE_STATE_POLL_MS = 1000;

let playbackGeneration = 0;
let nativeStatePollTimer = 0;
let nativePlaybackInitialized = false;
let mediaSessionHandlersBound = false;
let finalizePlaybackPromise = null;
const playbackBackends = window.SPCBoyPlaybackBackends;
let queuedSkipRequest = null;
let queuedSkipTimer = 0;
let playbackWindow = null;
const timingPlans = new Map();
const TRANSPORT_DECLICK_MS = 10;

function waitForAudioEnvelope(durationMs) {
  return new Promise((resolve) => window.setTimeout(resolve, Math.max(0, Math.ceil(durationMs))));
}

async function fadeActiveOutput(durationMs = TRANSPORT_DECLICK_MS) {
  const activeTrack = activeTrackInfo();
  if (nativePlaybackInitialized && activeTrack) {
    try {
      await window.spcBoyWK.nativePlaybackRampGain?.(0, durationMs);
    } catch {
      // The normal stop path still has to complete if a helper exited between
      // the transition request and its short output envelope.
    }
  }
  await waitForAudioEnvelope(durationMs);
}

function clearQueuedSkipTimer() {
  if (!queuedSkipTimer) return;
  window.clearTimeout(queuedSkipTimer);
  queuedSkipTimer = 0;
}

function setAudioSettings(settings = {}) {
  if (settings.appVolume !== undefined) playbackApp.state.appVolume = playbackApp.normalizeAppVolume(settings.appVolume);
  if (typeof settings.equalizerEnabled === "boolean") playbackApp.state.equalizerEnabled = settings.equalizerEnabled;
  if (Array.isArray(settings.equalizerBandGains)) playbackApp.state.equalizerBandGains = settings.equalizerBandGains.map(playbackApp.normalizeEqualizerGain);
}

function resetNativePlaybackSnapshot() {
  state.nativePlayback = {
    transportState: "stopped",
    outputState: "idle",
    generation: 0,
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
  return currentOutputBasePlaybackSeconds(track) + currentFadeSeconds(track);
}

function effectiveTotalSeconds(track) {
  return playbackWindow?.trackId === track?.id
    ? playbackWindow.totalSeconds
    : currentTotalSeconds(track);
}

function currentBasePlaybackSeconds(track) {
  const plan = track ? timingPlans.get(track.id) : null;
  if (plan && Number.isFinite(plan.pre_fade_seconds)) {
    return plan.pre_fade_seconds;
  }
  return track?.basePlaybackSeconds > 0
    ? track.basePlaybackSeconds
    : state.unknownDurationSeconds;
}

function playbackSpeedForTrack(track) {
  const sourceName = track?.archiveEntry || track?.sourceFilename || track?.path || "";
  const backend = playbackBackends.forPath(sourceName);
  const extension = sourceName.slice(sourceName.lastIndexOf(".")).toLowerCase();
  if (backend?.playbackSpeedMode === "native-tempo" && backend.playbackSpeedExtensions?.includes(extension)) {
    if (backend.id === "libgme" && state.playbackSpeedEnabled) return state.playbackSpeed;
    if (backend.id === "libvgm" && state.libvgmPlaybackSpeedEnabled) return state.libvgmPlaybackSpeed;
  }
  return { numerator: 1, denominator: 1 };
}

function currentOutputBasePlaybackSeconds(track) {
  return playbackApp.scalePlaybackMilliseconds(
    Math.round(currentBasePlaybackSeconds(track) * 1000),
    playbackSpeedForTrack(track)
  ) / 1000;
}

async function resolveTimingPlan(track, { force = false } = {}) {
  if (!track) {
    return null;
  }
  if (!force && timingPlans.has(track.id)) {
    return timingPlans.get(track.id);
  }

  const plan = await window.spcBoyWK.nativePlaybackTiming({
    path: track.archiveEntry || track.sourceFilename || track.path || "",
    playMilliseconds: Math.max(0, Math.round((Number(track.basePlaybackSeconds) || 0) * 1000)),
    manualPlayMilliseconds: Math.max(1, Math.round(state.manualPlayTimeSeconds * 1000)),
    fadeMilliseconds: Math.max(0, Math.round(currentFadeSeconds(track) * 1000)),
    unknownDurationMilliseconds: Math.max(1, Math.round(state.unknownDurationSeconds * 1000)),
    tempo: playbackSpeedForTrack(track),
    longPlayEnabled: state.longPlayEnabled
  });
  if (!plan || !Number.isFinite(Number(plan.pre_fade_seconds))) {
    throw new Error("VGMBoy returned no playback timing plan.");
  }
  const normalized = {
    pre_fade_seconds: Math.max(1, Number(plan.pre_fade_seconds)),
    fade_seconds: Math.max(0, Number(plan.fade_seconds) || 0),
    total_seconds: Math.max(1, Number(plan.total_seconds) || 0),
    is_long_play: Boolean(plan.is_long_play),
    uses_native_ending: Boolean(plan.uses_native_ending)
  };
  timingPlans.set(track.id, normalized);
  return normalized;
}

function clampPosition(positionSeconds, durationSeconds) {
  const position = Number(positionSeconds) || 0;
  const duration = Math.max(0, Number(durationSeconds) || 0);
  return Math.max(0, Math.min(position, duration));
}

function shouldPreserveFieldValue(element) {
  return document.activeElement === element;
}

async function chooseAACExportDirectory() {
  const path = await window.spcBoyWK.chooseAACExportDirectory();
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
    if (!directory) directory = (await window.spcBoyWK.defaultAACExportDirectory?.()) || "";
    if (!directory) return;
    const plan = await resolveTimingPlan(track, { force: true });
    state.aacExportStatus = `Exporting ${track.title || track.filename || "track"}…`;
    playbackApp.ui.renderAll();
    const result = await window.spcBoyWK.nativeExportAAC({
      path: track.path,
      archivePath: track.archivePath || null,
      archiveEntry: track.archiveEntry || null,
      trackIndex: track.trackIndex || 0,
      outputDirectory: directory,
      filenameStem: track.title || track.filename || "Untitled Track",
      playMilliseconds: Math.max(1, Math.round(plan.pre_fade_seconds * 1000)),
      fadeMilliseconds: Math.max(0, Math.round(plan.fade_seconds * 1000))
    });
    state.aacExportStatus = `Exported AAC: ${result?.path || "complete"}`;
  } catch (error) {
    state.aacExportStatus = error?.message || "AAC export failed.";
    throw error;
  } finally {
    state.aacExportInProgress = false;
    playbackApp.ui.renderAll();
  }
}

function clearNativeStatePoll() {
  if (!nativeStatePollTimer) {
    return;
  }

  window.clearTimeout(nativeStatePollTimer);
  nativeStatePollTimer = 0;
}

function clearPlaybackRuntimeState() {
  clearNativeStatePoll();
}

async function stopAllOutput({ declick = true, keepNativeOutput = false } = {}) {
  if (declick) await fadeActiveOutput();
  if (nativePlaybackInitialized) {
    try {
      if (keepNativeOutput) await window.spcBoyWK.nativePlaybackUnload();
      else await window.spcBoyWK.nativePlaybackStop();
    } catch {
      // A stopped or not-yet-primed native session is already safe to replace.
    }
  }
}

function updateTimingSummary() {
  const track = activeTrackInfo();
  const totalSeconds = currentTotalSeconds(track);
  state.totalSeconds = totalSeconds;
  refs.songLengthLabel.textContent = formatTime(totalSeconds);
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
    refs.uiItemSpacingInput.value = String(state.uiItemSpacingRem);
  }
  refs.spcForceLengthCheckbox.checked = state.longPlayEnabled;
  refs.queuedSkipsCheckbox.checked = state.queuedSkipsEnabled;
  refs.spcFadeCheckbox.checked = state.fadeEnabled;
  if (!shouldPreserveFieldValue(refs.sidebarFontSizeInput)) {
    refs.sidebarFontSizeInput.value = String(state.uiFontSizePt);
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
  if (!("mediaSession" in navigator)) {
    return;
  }

  bindMediaSessionHandlers();

  const track = activeTrackInfo();
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

function updatePlaybackReadout() {
  refs.elapsedLabel.textContent = formatTime(state.elapsedSeconds);
  refs.songLengthLabel.textContent = formatTime(state.totalSeconds);
  const playlistTotalSeconds = state.playlist.reduce((sum, entry) => sum + currentOutputBasePlaybackSeconds(entry), 0);
  refs.playlistTotalLabel.textContent = formatTime(playlistTotalSeconds);
  const currentValue = Math.min(state.elapsedSeconds, state.totalSeconds || 1);
  refs.progressSlider.value = String(currentValue);
  const percent = state.totalSeconds > 0 ? (currentValue / state.totalSeconds) * 100 : 0;
  refs.progressSliderShell.style.setProperty("--progress-percent", `${Math.max(0, Math.min(percent, 100))}%`);
  refs.playButton.querySelector("use")?.setAttribute("href", state.isPlaying ? "#icon-pause" : "#icon-play");
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
  if (snapshot.transport_state === "ended") {
    void finalizePlaybackEnded();
    return;
  }
}

async function setPlaybackPowerSaveBlocker(enabled) {
  try {
    await window.spcBoyWK.setPlaybackPowerSaveBlocker(enabled);
  } catch {
    // Power-save blocker is best-effort support around playback.
  }
}

async function ensureNativePlaybackInitialized() {
  if (nativePlaybackInitialized) {
    return;
  }

  await window.spcBoyWK.nativePlaybackInit();
  await window.spcBoyWK.nativePlaybackAudioConfig(
    state.appVolume,
    state.equalizerEnabled,
    state.equalizerBandGains
  );
  nativePlaybackInitialized = true;
}

function applyNativePlaybackSnapshot(track, snapshot, generation, { allowNativeGenerationChange = false } = {}) {
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
  const elapsedSeconds = clampPosition((Number(snapshot?.position_ms) || 0) / 1000, totalSeconds);
  const transportState = snapshot?.transport_state || "stopped";

  state.nativePlayback = {
    transportState,
    outputState: snapshot?.output_state || "idle",
    generation: observedNativeGeneration,
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

  state.totalSeconds = totalSeconds;
  state.elapsedSeconds = elapsedSeconds;
  state.isPlaying = transportState === "playing";

  if (transportState === "ended") {
    state.isPlaying = false;
    state.elapsedSeconds = totalSeconds;
  }

  updatePlaybackReadout();
  updateNativeDiagnostics();
  return true;
}

async function readNativePlaybackState(track, generation) {
  const snapshot = await window.spcBoyWK.nativePlaybackState();
  const applied = applyNativePlaybackSnapshot(track, snapshot, generation);
  if (!applied) {
    return { ...snapshot, stale_generation: true };
  }
  return snapshot;
}

function scheduleNativePlaybackStatePoll(track, generation) {
  clearNativeStatePoll();
  if (generation !== playbackGeneration || !state.currentTrackId) {
    return;
  }

  nativeStatePollTimer = window.setTimeout(async () => {
    nativeStatePollTimer = 0;
    if (generation !== playbackGeneration || !state.currentTrackId) {
      return;
    }

    try {
      const snapshot = await readNativePlaybackState(track, generation);
      if (generation !== playbackGeneration) {
        return;
      }

      if (snapshot?.stale_generation) {
        return;
      }

      if (snapshot?.transport_state === "playing") {
        scheduleNativePlaybackStatePoll(track, generation);
        return;
      }

      if (snapshot?.transport_state === "ended") {
        void finalizePlaybackEnded();
        return;
      }

      if (snapshot?.track_loaded) {
        scheduleNativePlaybackStatePoll(track, generation);
      }
    } catch (error) {
      if (generation === playbackGeneration) {
        state.isPlaying = false;
        resetNativePlaybackSnapshot();
        updatePlaybackReadout();
        updateNativeDiagnostics();
      }
    }
  }, NATIVE_STATE_POLL_MS);
}

async function finalizePlaybackEnded() {
  if (finalizePlaybackPromise) {
    return finalizePlaybackPromise;
  }

  finalizePlaybackPromise = (async () => {
    const finalizationGeneration = playbackGeneration;
    const completedTrackId = state.currentTrackId;
    const completedQueuedSkip = queuedSkipRequest;
    let completionTargetId = null;
    if (!completedQueuedSkip) {
      completionTargetId = await window.spcBoyWK.playbackQueueTransition({
        state: {
          currentTrackId: completedTrackId,
          selectedTrackId: state.selectedTrackId,
          pendingTrackId: null
        },
        playlistIds: state.playlist.map((track) => track.id),
        intent: { kind: "completion", repeatMode: state.repeatMode }
      });
    }
    if (finalizationGeneration !== playbackGeneration
        || state.currentTrackId !== completedTrackId) {
      return;
    }
    clearNativeStatePoll();
    state.isPlaying = false;
    state.elapsedSeconds = state.totalSeconds;
    updatePlaybackReadout();
    updateNativeDiagnostics();

    queuedSkipRequest = null;
    clearQueuedSkipTimer();
    await stopPlaybackState({ declick: false, keepNativeOutput: Boolean(completionTargetId || completedQueuedSkip) });

    // stopPlaybackState intentionally advances the generation once to retire
    // the completed native session. A newer user request advances it again;
    // only the expected single retirement may continue into queue advance.
    if (playbackGeneration !== finalizationGeneration + 1 || state.currentTrackId) {
      return;
    }

    if (completedQueuedSkip) {
      await advanceToAdjacent(completedQueuedSkip.delta);
    } else if (completionTargetId) {
      await playTrack(completionTargetId, 0);
    }
  })();

  try {
    await finalizePlaybackPromise;
  } finally {
    finalizePlaybackPromise = null;
  }
}

async function stopPlaybackState({ declick = true, keepNativeOutput = false } = {}) {
  clearNativeStatePoll();
  playbackGeneration += 1;
  clearPlaybackRuntimeState();
  await stopAllOutput({ declick, keepNativeOutput });
  // The core owns every output path; release an archive materialization only
  // after the bridge has stopped or unloaded it.
  try { await window.spcBoyWK.releaseMaterializedTrack?.(); } catch {}

  await setPlaybackPowerSaveBlocker(false);
  state.currentTrackId = null;
  state.currentTrackInfo = null;
  playbackWindow = null;
  state.isPlaying = false;
  state.elapsedSeconds = 0;
  state.totalSeconds = targetPlaybackSeconds();
  resetNativePlaybackSnapshot();
  updatePlaybackReadout();
  updateNativeDiagnostics();
  playbackApp.ui.refreshPlaylistPlaybackState();
}

async function cancelQueuedSkip({ restoreOutput = false } = {}) {
  const hadQueuedSkip = Boolean(queuedSkipRequest);
  queuedSkipRequest = null;
  clearQueuedSkipTimer();
  if (restoreOutput && hadQueuedSkip && nativePlaybackInitialized && state.nativePlayback.trackLoaded) {
    await window.spcBoyWK.nativePlaybackRampGain(1, TRANSPORT_DECLICK_MS);
  }
}

async function playTrackNow(trackId, startSeconds = 0, playbackOptions = null) {
  let track = state.playlist.find((entry) => entry.id === trackId);
  if (!track) {
    return;
  }

  const generation = ++playbackGeneration;
  const timingPlan = await resolveTimingPlan(track, { force: true });
  if (generation !== playbackGeneration) {
    return;
  }
  // Native-state broadcasts can arrive while the native playback request is in flight.
  // Keep this request's offset immutable so a prior track cannot leak its elapsed position.
  let requestedStartSeconds = Math.max(0, Math.min(startSeconds, currentTotalSeconds(track)));
  const fadeNowSeconds = Math.max(0, Number(playbackOptions?.fadeNowSeconds) || 0);
  const normalBaseSeconds = currentOutputBasePlaybackSeconds(track);
  let playbackTotalSeconds = fadeNowSeconds > 0
    ? requestedStartSeconds + fadeNowSeconds
    : currentTotalSeconds(track);
  let playbackBaseSeconds = fadeNowSeconds > 0
    ? Math.max(0.001, requestedStartSeconds)
    : normalBaseSeconds;
  playbackWindow = fadeNowSeconds > 0
    ? { trackId: track.id, totalSeconds: playbackTotalSeconds, fadeSeconds: fadeNowSeconds }
    : null;
  clearPlaybackRuntimeState();
  resetNativePlaybackSnapshot();
  await stopAllOutput({ keepNativeOutput: true });

  state.currentTrackId = track.id;
  state.selectedTrackId = track.id;
  state.currentTrackInfo = track;
  state.totalSeconds = playbackTotalSeconds;
  state.elapsedSeconds = requestedStartSeconds;

  if (state.elapsedSeconds >= state.totalSeconds) {
    state.isPlaying = false;
    playbackApp.ui.refreshPlaylistPlaybackState();
    return;
  }

  playbackApp.ui.refreshPlaylistPlaybackState();

  try {
    await setPlaybackPowerSaveBlocker(true);
    state.totalSeconds = playbackTotalSeconds;
    state.elapsedSeconds = requestedStartSeconds;
    updatePlaybackReadout();
    if (state.elapsedSeconds >= state.totalSeconds) {
      await setPlaybackPowerSaveBlocker(false);
      state.isPlaying = false;
      resetNativePlaybackSnapshot();
      playbackApp.ui.refreshPlaylistPlaybackState();
      return;
    }
    await ensureNativePlaybackInitialized();
    const snapshot = await window.spcBoyWK.nativePlaybackStart({
      path: track.path,
      archivePath: track.archivePath || null,
      archiveEntry: track.archiveEntry || null,
      trackIndex: track.trackIndex || 0,
      startMilliseconds: Math.round(requestedStartSeconds * 1000),
      playMilliseconds: Math.round((fadeNowSeconds > 0
        ? playbackBaseSeconds
        : (timingPlan.is_long_play ? playbackBaseSeconds : 0)) * 1000),
      fadeMilliseconds: Math.round((fadeNowSeconds > 0 ? fadeNowSeconds : currentFadeSeconds(track)) * 1000),
      tempo: playbackSpeedForTrack(track),
      longPlayEnabled: timingPlan.is_long_play,
      timedOverride: fadeNowSeconds > 0,
      unknownDurationMilliseconds: Math.round(state.unknownDurationSeconds * 1000)
    });
    if (generation !== playbackGeneration) {
      return;
    }

    await setPlaybackPowerSaveBlocker(true);
    applyNativePlaybackSnapshot(track, snapshot, generation);
    // Position and reached-end state are supplied on demand by the native
    // bridge. Keep the active generation polling so the transport readout
    // advances and the next playlist item can begin at track end.
    scheduleNativePlaybackStatePoll(track, generation);
    playbackApp.ui.refreshPlaylistPlaybackState();
  } catch (error) {
    if (generation !== playbackGeneration) {
      return;
    }

    await setPlaybackPowerSaveBlocker(false);
    state.isPlaying = false;
    resetNativePlaybackSnapshot();
    try { await window.spcBoyWK.nativePlaybackClose(); } catch {}
    nativePlaybackInitialized = false;
    updatePlaybackReadout();
    updateNativeDiagnostics();
    playbackApp.ui.refreshPlaylistPlaybackState();
    throw error;
  }
}

function playTrack(trackId, startSeconds = 0, preserveQueuedSkip = false, playbackOptions = null) {
  if (!preserveQueuedSkip) {
    queuedSkipRequest = null;
    clearQueuedSkipTimer();
  }
  return playTrackNow(trackId, startSeconds, playbackOptions);
}

async function advanceToAdjacent(delta) {
  if (state.playlist.length === 0) {
    return;
  }

  try {
    const playlistIDs = state.playlist.map((track) => track.id);
    const nextID = await window.spcBoyWK.playbackQueueTransition({
      state: {
        currentTrackId: state.currentTrackId,
        selectedTrackId: state.selectedTrackId,
        pendingTrackId: null
      },
      playlistIds: playlistIDs,
      intent: {
        kind: "adjacent",
        direction: delta < 0 ? "previous" : "next",
        wraps: true
      }
    });
    if (!nextID) return;
    await playTrack(nextID, 0);
  } catch (error) {
    console.error(error);
  }
}

function playAdjacent(delta) {
  return playAdjacentNow(delta).catch((error) => {
    console.error("[SPCBoy] adjacent playback failed", error);
  });
}

async function playAdjacentNow(delta) {
  if (!state.currentTrackId) {
    await advanceToAdjacent(delta);
    return;
  }

  if (queuedSkipRequest) {
    const request = queuedSkipRequest;
    queuedSkipRequest = null;
    clearQueuedSkipTimer();
    void (async () => {
      await fadeActiveOutput(TRANSPORT_DECLICK_MS);
      await stopPlaybackState({ declick: false });
      advanceToAdjacent(delta || request.delta);
    })().catch((error) => console.error(error));
    return;
  }

  const track = currentTrack();
  const fadeSeconds = currentFadeSeconds(track);
  const fadeDurationMs = await window.spcBoyWK.playbackFadeDuration(
    state.queuedSkipsEnabled,
    state.isPlaying,
    Boolean(track),
    state.elapsedSeconds,
    currentOutputBasePlaybackSeconds(track),
    fadeSeconds,
    currentTotalSeconds(track)
  );
  if (!fadeDurationMs) {
    await advanceToAdjacent(delta);
    return;
  }

  queuedSkipRequest = {
    delta,
    generation: playbackGeneration,
    nativeGeneration: Number(state.nativePlayback.generation) || 0
  };
  fadeActiveOutput(fadeDurationMs).catch((error) => {
    console.error(error);
  });
  queuedSkipTimer = window.setTimeout(() => {
    void (async () => {
      const request = queuedSkipRequest;
      if (!request || request.generation !== playbackGeneration) return;
      const snapshot = await window.spcBoyWK.nativePlaybackState();
      if (request.nativeGeneration > 0
          && Number(snapshot?.generation) !== request.nativeGeneration) {
        await cancelQueuedSkip({ restoreOutput: true });
        return;
      }
      queuedSkipTimer = 0;
      // Route timer completion through the same single-flight finalizer as a
      // natural end, so an end event arriving on the same callback cannot
      // advance the playlist twice.
      await finalizePlaybackEnded();
    })().catch((error) => console.error("[SPCBoy] faded skip failed", error));
  }, fadeDurationMs);
}

async function togglePlayback() {
  const track = activeTrackInfo();
  if (!track) {
    return;
  }

  if (!state.currentTrackId || state.currentTrackId !== track.id) {
    await playTrack(track.id, 0);
    return;
  }

  if (state.isPlaying) {
    if (queuedSkipRequest) {
      queuedSkipRequest = null;
      clearQueuedSkipTimer();
    }
    playbackGeneration += 1;
    clearPlaybackRuntimeState();
    try {
      await fadeActiveOutput(TRANSPORT_DECLICK_MS);
      const snapshot = await window.spcBoyWK.nativePlaybackPause();
      await setPlaybackPowerSaveBlocker(false);
      applyNativePlaybackSnapshot(track, snapshot, playbackGeneration);
      updatePlaybackReadout();
      return;
    } catch (error) {
      throw error;
    }
  }

  if (nativePlaybackInitialized && state.nativePlayback.trackLoaded) {
    const generation = ++playbackGeneration;
    clearPlaybackRuntimeState();
    try {
      await setPlaybackPowerSaveBlocker(true);
      const snapshot = await window.spcBoyWK.nativePlaybackResume();
      if (generation !== playbackGeneration) {
        return;
      }
      applyNativePlaybackSnapshot(track, snapshot, generation);
      scheduleNativePlaybackStatePoll(track, generation);
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

  state.elapsedSeconds = Math.max(0, Math.min(seconds, state.totalSeconds));
  updatePlaybackReadout();

  if (state.currentTrackId === track.id) {
    if (nativePlaybackInitialized && state.nativePlayback.trackLoaded) {
      const generation = playbackGeneration;
      await cancelQueuedSkip({ restoreOutput: true });
      clearPlaybackRuntimeState();
      try {
        const snapshot = await window.spcBoyWK.nativePlaybackSeek(
          Math.round(state.elapsedSeconds * 1000)
        );
        if (generation !== playbackGeneration) {
          return;
        }
        applyNativePlaybackSnapshot(track, snapshot, generation);
        scheduleNativePlaybackStatePoll(track, generation);
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
  const track = currentTrack();
  if (!track || state.currentTrackId !== track.id) {
    updateTimingSummary();
    updatePlaybackReadout();
    return;
  }

  timingPlans.delete(track.id);
  const plan = await resolveTimingPlan(track, { force: true });
  if (!nativePlaybackInitialized || !state.nativePlayback.trackLoaded) {
    state.totalSeconds = currentTotalSeconds(track);
    updateTimingSummary();
    updatePlaybackReadout();
    return;
  }

  const snapshot = await window.spcBoyWK.nativePlaybackReconfigure({
    longPlayEnabled: plan.is_long_play,
    manualPlayMilliseconds: Math.max(1, Math.round(plan.pre_fade_seconds * 1000)),
    fadeMilliseconds: Math.max(0, Math.round(plan.fade_seconds * 1000)),
    unknownDurationMilliseconds: Math.max(1, Math.round(state.unknownDurationSeconds * 1000)),
    tempo: playbackSpeedForTrack(track)
  });
  applyNativePlaybackSnapshot(track, snapshot, playbackGeneration, { allowNativeGenerationChange: true });
  state.totalSeconds = effectiveTotalSeconds(track);
  state.elapsedSeconds = Math.max(0, Math.min(state.elapsedSeconds, state.totalSeconds));
  updateTimingSummary();
  updatePlaybackReadout();
}

async function refreshPlaybackForSpeedChange(backendId) {
  const track = activeTrackInfo();
  const activeBackend = playbackBackends.forPath(track?.archiveEntry || track?.path)?.id;
  if (activeBackend !== backendId) return;
  await refreshPlaybackForTimingChange();
}

playbackApp.playback = {
  updateTimingSummary,
  updatePlaybackReadout,
  updateNativeDiagnostics,
  handleNativePlaybackState,
  stopPlaybackState,
  playTrack,
  finalizePlaybackEnded,
  playAdjacent,
  togglePlayback,
  restartAt,
  refreshPlaybackForTimingChange,
  refreshPlaybackForSpeedChange,
  chooseAACExportDirectory,
  exportTrackAsAAC,
  cancelQueuedSkip,
  setAudioSettings
};
})();
