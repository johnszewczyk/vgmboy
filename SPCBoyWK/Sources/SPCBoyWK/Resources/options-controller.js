(() => {
  function applyManifest(manifest) {
    const sectionOrder = Array.isArray(manifest?.appSections) ? manifest.appSections : [];
    const navGroup = document.querySelector("#options-native-heading")?.parentElement;
    if (!navGroup || sectionOrder.length === 0) throw new Error("Native options manifest is unavailable.");
    for (const section of sectionOrder) {
      const button = document.querySelector(`[data-app-option-section="${CSS.escape(section)}"]`);
      if (!button) throw new Error(`Missing app options section: ${section}`);
      navGroup.appendChild(button);
    }
  }

  function setAnimation(state, normalize, key, value) {
    state[key] = normalize(value);
  }

  function setWindowLevel(state, key, enabled) {
    state[key] = Boolean(enabled);
  }

  window.SPCBoyOptionsController = Object.freeze({ applyManifest, setAnimation, setWindowLevel });
})();
