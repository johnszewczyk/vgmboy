(() => {
function create({
  state,
  persistSettings,
  renderAll,
  refreshPlaybackForTimingChange,
  normalizeLongPlayTime,
  normalizeFadeTime,
  normalizePlayTime,
  parseDurationSeconds
}) {
  function refreshTiming() {
    refreshPlaybackForTimingChange().catch((error) => {
      console.error(error);
    });
  }

  function setPlayTime(nextSeconds) {
    state.manualPlayTimeSeconds = normalizeLongPlayTime(nextSeconds);
    persistSettings();
    renderAll();
    refreshTiming();
  }

  function setSpcForceManualTime(nextEnabled) {
    state.longPlayEnabled = Boolean(nextEnabled);
    persistSettings();
    renderAll();
    refreshTiming();
  }

  function cycleRepeatMode() {
    const modes = ["off", "all", "one"];
    state.repeatMode = modes[(modes.indexOf(state.repeatMode) + 1) % modes.length];
    persistSettings();
    renderAll();
  }

  function setSpcFadeTime(nextSeconds) {
    state.spcFadeSeconds = normalizeFadeTime(nextSeconds);
    persistSettings();
    renderAll();
    refreshTiming();
  }

  function setSpcFadeEnabled(nextEnabled) {
    state.fadeEnabled = Boolean(nextEnabled);
    persistSettings();
    renderAll();
    refreshTiming();
  }

  function setQueuedSkipsEnabled(nextEnabled) {
    state.queuedSkipsEnabled = Boolean(nextEnabled);
    persistSettings();
    renderAll();
  }

  function commitSpcLengthInput(rawValue) {
    const parsedSeconds = parseDurationSeconds(rawValue);
    state.manualPlayTimeSeconds = normalizeLongPlayTime(parsedSeconds ?? state.manualPlayTimeSeconds);
    persistSettings();
    refreshTiming();
  }

  function commitUnknownDurationInput(rawValue) {
    const parsedSeconds = parseDurationSeconds(rawValue);
    state.unknownDurationSeconds = normalizePlayTime(parsedSeconds ?? state.unknownDurationSeconds);
    persistSettings();
    refreshTiming();
  }

  function commitSpcFadeInput(rawValue) {
    const parsedSeconds = parseDurationSeconds(rawValue);
    state.spcFadeSeconds = normalizeFadeTime(parsedSeconds ?? state.spcFadeSeconds);
    persistSettings();
    refreshTiming();
  }

  return Object.freeze({
    commitSpcFadeInput,
    commitSpcLengthInput,
    commitUnknownDurationInput,
    cycleRepeatMode,
    setPlayTime,
    setQueuedSkipsEnabled,
    setSpcFadeEnabled,
    setSpcFadeTime,
    setSpcForceManualTime
  });
}

window.SPCBoyPlaybackSettingsActions = Object.freeze({ create });
})();
