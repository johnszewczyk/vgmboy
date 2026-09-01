(() => {
function create({
  state,
  persistSettings,
  candidatesForPath,
  setRoutingPreferences,
  renderAll
}) {
  function setRoutingPreference(extension, backendId) {
    const candidates = candidatesForPath(`route${extension}`) || [];
    if (!candidates.some((backend) => backend.id === backendId)) return;
    const nextPreferences = { ...state.routingPreferences };
    if (backendId === candidates[0]?.id) delete nextPreferences[extension];
    else nextPreferences[extension] = backendId;
    state.routingPreferences = nextPreferences;
    persistSettings();
    setRoutingPreferences(nextPreferences).then((normalizedPreferences) => {
      state.routingPreferences = { ...normalizedPreferences };
      persistSettings();
      renderAll();
    }).catch((error) => console.error("[SPCBoy] routing preference update failed", error));
    renderAll();
  }

  function applyRoutingPreferences(preferences) {
    state.routingPreferences = preferences && typeof preferences === "object" ? { ...preferences } : {};
    persistSettings();
    renderAll();
  }

  return Object.freeze({ applyRoutingPreferences, setRoutingPreference });
}

window.SPCBoyRoutingActions = Object.freeze({ create });
})();
