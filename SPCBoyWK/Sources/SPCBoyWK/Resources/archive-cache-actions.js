(() => {
function create({
  state,
  persistSettings,
  configureArchiveCache,
  normalizeArchiveCacheLimit,
  renderAll
}) {
  async function applyArchiveCacheSettings() {
    const settings = {
      enabled: state.archiveCacheEnabled,
      limitBytes: state.archiveCacheLimitBytes
    };
    persistSettings();
    const configured = await configureArchiveCache?.(settings);
    if (configured?.summary) {
      state.archiveCacheSummary = { ...configured.summary, enabled: configured.enabled, limitBytes: configured.limitBytes };
    }
    renderAll();
  }

  function setArchiveCacheEnabled(enabled) {
    state.archiveCacheEnabled = Boolean(enabled);
    applyArchiveCacheSettings().catch((error) => {
      console.error("[SPCBoy] archive cache setting update failed", error);
    });
    renderAll();
  }

  function setArchiveCacheLimit(value) {
    state.archiveCacheLimitBytes = normalizeArchiveCacheLimit(value);
    applyArchiveCacheSettings().catch((error) => {
      console.error("[SPCBoy] archive cache limit update failed", error);
    });
    renderAll();
  }

  return Object.freeze({ applyArchiveCacheSettings, setArchiveCacheEnabled, setArchiveCacheLimit });
}

window.SPCBoyArchiveCacheActions = Object.freeze({ create });
})();
