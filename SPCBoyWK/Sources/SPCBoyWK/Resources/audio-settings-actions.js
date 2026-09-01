(() => {
function create({
  state,
  persistSettings,
  nativePlaybackAudioConfig,
  setAudioSettings,
  normalizeEqualizerGain,
  normalizeAppVolume,
  renderAll
}) {
  function audioSettingsPayload() {
    return {
      equalizerEnabled: state.equalizerEnabled,
      equalizerBandGains: [...state.equalizerBandGains],
      appVolume: state.appVolume,
      monoEnabled: state.monoEnabled
    };
  }

  function broadcastAudioSettings() {
    const settings = audioSettingsPayload();
    const nativeRequest = nativePlaybackAudioConfig?.(
      state.appVolume,
      state.equalizerEnabled,
      state.equalizerBandGains,
      state.monoEnabled
    );
    nativeRequest?.catch?.(() => {});
    setAudioSettings?.(settings);
  }

  function setEqualizerEnabled(enabled) {
    state.equalizerEnabled = Boolean(enabled);
    persistSettings();
    broadcastAudioSettings();
    renderAll();
  }

  function setEqualizerBandGain(index, gain) {
    if (!state.equalizerBandGains[index]) state.equalizerBandGains[index] = 0;
    state.equalizerBandGains[index] = normalizeEqualizerGain(gain);
    persistSettings();
    broadcastAudioSettings();
    renderAll();
  }

  function resetEqualizer() {
    state.equalizerBandGains = state.equalizerBandGains.map(() => 0);
    persistSettings();
    broadcastAudioSettings();
    renderAll();
  }

  function setAppVolume(volume) {
    state.appVolume = normalizeAppVolume(volume);
    persistSettings();
    broadcastAudioSettings();
    renderAll();
  }

  function setMonoEnabled(enabled) {
    state.monoEnabled = Boolean(enabled);
    persistSettings();
    broadcastAudioSettings();
    renderAll();
  }

  function adjustAppVolume(delta) {
    setAppVolume(state.appVolume + Number(delta || 0));
  }

  return Object.freeze({
    adjustAppVolume,
    audioSettingsPayload,
    broadcastAudioSettings,
    resetEqualizer,
    setAppVolume,
    setEqualizerBandGain,
    setEqualizerEnabled,
    setMonoEnabled
  });
}

window.SPCBoyAudioSettingsActions = Object.freeze({ create });
})();
