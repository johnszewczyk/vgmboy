(() => {
function create({
  state,
  refs,
  persistSettings,
  parsePlaybackSpeed,
  formatPlaybackSpeed,
  refreshPlaybackForSpeedChange,
  renderAll
}) {
  function commitPlaybackSpeedInput(backendId, rawValue) {
    const speedKey = backendId === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
    const enabledKey = backendId === "libvgm" ? "libvgmPlaybackSpeedEnabled" : "playbackSpeedEnabled";
    const input = backendId === "libvgm" ? refs.libvgmPlaybackSpeedInput : refs.playbackSpeedInput;
    const parsedSpeed = parsePlaybackSpeed(rawValue);
    if (!parsedSpeed) {
      input.value = formatPlaybackSpeed(state[speedKey]);
      return;
    }
    if (parsedSpeed.numerator === state[speedKey].numerator && parsedSpeed.denominator === state[speedKey].denominator) {
      input.value = formatPlaybackSpeed(parsedSpeed);
      return;
    }
    state[speedKey] = parsedSpeed;
    persistSettings();
    if (state[enabledKey]) refreshPlaybackForSpeedChange(backendId).catch((error) => console.error(error));
    renderAll();
  }

  function setPlaybackSpeedEnabled(backendId, enabled) {
    const enabledKey = backendId === "libvgm" ? "libvgmPlaybackSpeedEnabled" : "playbackSpeedEnabled";
    state[enabledKey] = Boolean(enabled);
    persistSettings();
    refreshPlaybackForSpeedChange(backendId).catch((error) => console.error(error));
    renderAll();
  }

  return Object.freeze({ commitPlaybackSpeedInput, setPlaybackSpeedEnabled });
}

window.SPCBoyPlaybackSpeedActions = Object.freeze({ create });
})();
