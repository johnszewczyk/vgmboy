/* Keep online player preferences in the signed-in member profile. */
(() => {
  if (window.SBOProfileStorage) return;
  const dock = document.querySelector("#site-player");
  const bootstrap = document.querySelector("#spcboy-profile-preferences");
  const endpoint = document.currentScript?.dataset.preferencesUrl;
  if (!dock || !bootstrap || !endpoint) return;

  const userId = dock.dataset.userId;
  const userPrefix = `spcboy:${userId}:`;
  const scopes = new Set(["player", "interface", "library", "playback"]);
  const preferenceKeys = Object.create(null);
  try {
    const parsed = JSON.parse(bootstrap.textContent || "{}");
    for (const scope of scopes) {
      if (parsed?.[scope] && typeof parsed[scope] === "object" && !Array.isArray(parsed[scope])) {
        preferenceKeys[scope] = { ...parsed[scope] };
      } else preferenceKeys[scope] = {};
    }
  } catch {
    for (const scope of scopes) preferenceKeys[scope] = {};
  }

  const playerKeys = new Set([
    "playbackRateFraction", "playbackRate", "playbackSpeedEnabled", "longPlayDurationSeconds",
    "longPlayMinutes", "longPlaySeconds", "longPlayEnabled", "spcFadeSeconds", "fadedSkipsEnabled",
    "volumeStep", "equalizerEnabled", "equalizerBandGains", "equalizerPresets", "optionsPage",
  ]);
  const legacyImports = Object.create(null);
  const pendingUpdates = Object.create(null);
  const pendingRemovals = Object.create(null);
  let saveTimer = 0;
  let requestPending = false;
  let importNeeded = false;
  let cleanupNeeded = false;
  let retryDelay = 1000;
  let resolveReady;
  let readyResolved = false;
  const ready = new Promise(resolve => { resolveReady = resolve; });
  const csrfToken = () => document.querySelector("#site-player-csrf [name='csrfmiddlewaretoken']")?.value || "";

  function plainObject(value) {
    return value && typeof value === "object" && !Array.isArray(value);
  }
  function copy(value) {
    try { return JSON.parse(JSON.stringify(value)); } catch { return undefined; }
  }
  function addImport(scope, key, value) {
    if (!scopes.has(scope) || !key || typeof key !== "string" || value === undefined) return;
    if (Object.prototype.hasOwnProperty.call(preferenceKeys[scope], key)) return;
    preferenceKeys[scope][key] = copy(value);
    (legacyImports[scope] ||= {})[key] = copy(value);
    importNeeded = true;
  }
  function parseLegacy(raw) {
    try { return JSON.parse(raw); } catch { return undefined; }
  }
  function importLegacyValue(key, value) {
    if (key === "interface") {
      if (plainObject(value)) for (const [name, setting] of Object.entries(value)) addImport("interface", name, setting);
      return;
    }
    if (key === "playback-v1") {
      addImport("playback", "session", value);
      return;
    }
    if (key === "legacy-favorites-imported" || key === "encodedFileSpeedFraction" || key === "encodedFileSpeedEnabled") return;
    addImport(playerKeys.has(key) ? "player" : "library", key, value);
  }

  try {
    for (let index = 0; index < localStorage.length; index += 1) {
      const key = localStorage.key(index);
      if (!key) continue;
      if (key.startsWith(userPrefix)) importLegacyValue(key.slice(userPrefix.length), parseLegacy(localStorage.getItem(key)));
      else if (key === "spcboy:favorites") importLegacyValue("favorites", parseLegacy(localStorage.getItem(key)));
    }
    for (let index = 0; index < sessionStorage.length; index += 1) {
      const key = sessionStorage.key(index);
      if (key?.startsWith(userPrefix)) importLegacyValue(key.slice(userPrefix.length), parseLegacy(sessionStorage.getItem(key)));
    }
  } catch {
    // Storage can be disabled; cloud preferences and current-session controls still work.
  }

  function clearLegacyStorage() {
    try {
      for (const storage of [localStorage, sessionStorage]) {
        for (let index = storage.length - 1; index >= 0; index -= 1) {
          const key = storage.key(index);
          if (key?.startsWith(userPrefix) || (storage === localStorage && key === "spcboy:favorites")) storage.removeItem(key);
        }
      }
    } catch { /* Cloud state remains authoritative. */ }
    cleanupNeeded = false;
  }

  function hasPending() {
    return importNeeded || Object.keys(pendingUpdates).length || Object.keys(pendingRemovals).length;
  }
  function scheduleSave(delay = 250) {
    window.clearTimeout(saveTimer);
    saveTimer = window.setTimeout(flush, delay);
  }
  function mergeBack(target, source) {
    for (const [scope, values] of Object.entries(source || {})) {
      target[scope] ||= {};
      Object.assign(target[scope], values);
    }
  }
  function mergeRemovals(source) {
    for (const [scope, keys] of Object.entries(source || {})) {
      const pending = (pendingRemovals[scope] ||= []);
      for (const key of keys) if (!pending.includes(key)) pending.push(key);
    }
  }
  async function flush() {
    window.clearTimeout(saveTimer);
    saveTimer = 0;
    if (requestPending) return;
    if (!hasPending()) {
      if (cleanupNeeded) clearLegacyStorage();
      return;
    }
    const payload = {
      imports: copy(legacyImports) || {},
      updates: copy(pendingUpdates) || {},
      removals: copy(pendingRemovals) || {},
    };
    for (const scope of Object.keys(legacyImports)) delete legacyImports[scope];
    for (const scope of Object.keys(pendingUpdates)) delete pendingUpdates[scope];
    for (const scope of Object.keys(pendingRemovals)) delete pendingRemovals[scope];
    importNeeded = false;
    requestPending = true;
    const body = JSON.stringify(payload);
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        credentials: "same-origin",
        keepalive: body.length <= 60000,
        headers: { "Content-Type": "application/json", "X-CSRFToken": csrfToken(), Accept: "application/json" },
        body,
      });
      if (!response.ok) throw new Error(`Player preference save returned ${response.status}.`);
      cleanupNeeded = true;
      retryDelay = 1000;
      clearLegacyStorage();
      if (!readyResolved) { readyResolved = true; resolveReady(); }
    } catch (error) {
      mergeBack(legacyImports, payload.imports);
      mergeBack(pendingUpdates, payload.updates);
      mergeRemovals(payload.removals);
      importNeeded = Object.keys(legacyImports).length > 0;
      retryDelay = Math.min(retryDelay * 2, 30000);
      console.warn("SBO preferences could not be synced to the profile yet.", error);
    } finally {
      requestPending = false;
      if (hasPending()) scheduleSave(retryDelay);
    }
  }

  window.SBOProfileStorage = {
    get(scope, key, fallback = null) {
      const value = preferenceKeys[scope]?.[key];
      return value === undefined ? fallback : copy(value);
    },
    set(scope, key, value) {
      if (!scopes.has(scope) || !key || typeof key !== "string") return;
      const saved = copy(value);
      if (saved === undefined) return;
      preferenceKeys[scope][key] = saved;
      const pending = pendingRemovals[scope];
      if (pending) {
        const index = pending.indexOf(key);
        if (index >= 0) pending.splice(index, 1);
      }
      (pendingUpdates[scope] ||= {})[key] = saved;
      scheduleSave();
    },
    remove(scope, key) {
      if (!scopes.has(scope) || !key || typeof key !== "string") return;
      if (!Object.prototype.hasOwnProperty.call(preferenceKeys[scope], key)
        && !Object.prototype.hasOwnProperty.call(pendingUpdates[scope] || {}, key)) return;
      delete preferenceKeys[scope][key];
      delete pendingUpdates[scope]?.[key];
      (pendingRemovals[scope] ||= []).push(key);
      scheduleSave();
    },
    ready,
    flush,
  };

  cleanupNeeded = true;
  if (importNeeded) scheduleSave(0);
  else {
    clearLegacyStorage();
    readyResolved = true;
    resolveReady();
  }
  document.addEventListener("site:pageleave", () => queueMicrotask(flush));
  window.addEventListener("pagehide", () => queueMicrotask(flush));
  window.addEventListener("online", () => { if (hasPending()) scheduleSave(0); });
})();
