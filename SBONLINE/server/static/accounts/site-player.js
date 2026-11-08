(() => {
  const dock = document.querySelector("#site-player");
  const audio = document.querySelector("#spcboy-audio");
  if (!dock || !audio) return;
  audio.playbackRate = 1;

  const title = document.querySelector("#spcboy-current-title");
  const album = document.querySelector("#spcboy-current-album");
  const currentSeparator = document.querySelector("#spcboy-current-separator");
  const playbackClock = document.querySelector("#spcboy-playback-clock");
  const statusReadout = document.querySelector("#spcboy-player-status");
  const statusText = document.querySelector("#spcboy-player-status-text");
  const reloadButton = document.querySelector("#spcboy-reload");
  const playButton = document.querySelector("#spcboy-play");
  const stopButton = document.querySelector("#spcboy-stop");
  const previousButton = document.querySelector("#spcboy-previous");
  const nextButton = document.querySelector("#spcboy-next");
  const longPlayToggle = document.querySelector("#spcboy-long-play");
  const longPlayDurationInput = document.querySelector("#spcboy-long-play-duration");
  const longPlayError = document.querySelector("#spcboy-long-play-error");
  const spcFadeSecondsInput = document.querySelector("#spcboy-spc-fade-seconds");
  const spcFadeError = document.querySelector("#spcboy-spc-fade-error");
  const fadedSkipToggle = document.querySelector("#spcboy-faded-skip");
  const speedInput = document.querySelector("#spcboy-speed");
  const speedEnabledToggle = document.querySelector("#spcboy-speed-enabled");
  const speedError = document.querySelector("#spcboy-speed-error");
  const equalizerToggle = document.querySelector("#spcboy-equalizer-enabled");
  const equalizerBandInputs = [...document.querySelectorAll("[data-equalizer-band]")];
  const equalizerResetButton = document.querySelector("#spcboy-equalizer-reset");
  const equalizerError = document.querySelector("#spcboy-equalizer-error");
  const equalizerPresetApplyButtons = [...document.querySelectorAll("[data-equalizer-preset-apply]")];
  const equalizerPresetSaveButtons = [...document.querySelectorAll("[data-equalizer-preset-save]")];
  const equalizerPresetStatus = document.querySelector("#spcboy-equalizer-preset-status");
  const settingsPageButtons = [...document.querySelectorAll("[data-settings-page-target]")];
  const settingsPages = [...document.querySelectorAll("[data-settings-page]")];
  const mobileSettingsButtons = [...document.querySelectorAll("[data-mobile-settings-page]")];
  const settingsTabList = document.querySelector('[role="tablist"][aria-label="Navigation and options"]');
  const settingsTabIndicator = settingsTabList?.querySelector(".spcboy-settings-tab-indicator");
  const state = document.querySelector("#spcboy-player-state");
  const queueToggle = document.querySelector("#site-player-queue-toggle");
  const settingsToggle = document.querySelector("#spcboy-settings-toggle");
  const volumeInput = document.querySelector("#site-player-volume");
  const volumeValue = document.querySelector("#site-player-volume-value");
  const queueCount = document.querySelector("#site-player-queue-count");
  const queuePanel = document.querySelector("#site-player-queue-panel");
  const queueClose = document.querySelector("#site-player-queue-close");
  const settingsPanel = document.querySelector("#spcboy-settings-panel");
  const drawerNavigation = document.querySelector("#drawer-navigation");
  const drawerOptions = document.querySelector("#drawer-options");
  const settingsClose = document.querySelector("#spcboy-settings-close");
  const playerDrawerScrim = document.querySelector("#site-player-drawer-scrim");
  const transport = document.querySelector("#spcboy-transport");
  const transportSlot = document.querySelector("#site-player-transport-slot");
  const actionsSlot = document.querySelector("#site-player-actions-slot");
  const queueList = document.querySelector("#site-player-queue");
  const queueColumns = document.querySelector("#site-player-queue-columns");
  const queueEmpty = document.querySelector("#site-player-queue-empty");
  const queueCurrent = document.querySelector("#site-player-queue-current");
  const queueCurrentTitle = document.querySelector("#site-player-queue-current-title");
  const queueCurrentGame = document.querySelector("#site-player-queue-current-game");
  const configuredSessionLimitSeconds = Number(dock.dataset.sessionLimitSeconds);
  const playbackSessionLimitSeconds = Number.isSafeInteger(configuredSessionLimitSeconds)
    && configuredSessionLimitSeconds > 0
    && configuredSessionLimitSeconds <= 1440 * 60
    ? configuredSessionLimitSeconds
    : 120 * 60;
  function playbackSessionLimitLabel() {
    const minutes = Math.ceil(playbackSessionLimitSeconds / 60);
    if (minutes % 60 === 0) {
      const hours = minutes / 60;
      return `${hours} ${hours === 1 ? "hour" : "hours"}`;
    }
    return `${minutes} minutes`;
  }
  const playbackExpiredAnnouncement = `Playback stopped because this page has been open for ${playbackSessionLimitLabel()}. Reload to continue.`;
  const storage = {
    get(key, fallback) {
      return window.SBOProfileStorage?.get("player", key, fallback) ?? fallback;
    },
    set(key, value) {
      window.SBOProfileStorage?.set("player", key, value);
    },
    remove(key) {
      window.SBOProfileStorage?.remove("player", key);
    },
  };
  storage.remove("encodedFileSpeedFraction");
  storage.remove("encodedFileSpeedEnabled");
  const maximumLongPlaySeconds = 86400;
  const equalizerFrequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  function parseSpeedFraction(value) {
    const match = String(value).trim().match(/^(\d{1,7})\s*\/\s*(\d{1,7})$/);
    if (!match) return null;
    const numerator = Number(match[1]);
    const denominator = Number(match[2]);
    if (!Number.isSafeInteger(numerator) || !Number.isSafeInteger(denominator) || numerator < 1 || denominator < 1) return null;
    const ticks = numerator * 64 / denominator;
    if (!Number.isInteger(ticks) || ticks < 32 || ticks > 128) return null;
    const divisor = (left, right) => right ? divisor(right, left % right) : left;
    const common = divisor(numerator, denominator);
    return { rate: numerator / denominator, fraction: `${numerator / common}/${denominator / common}` };
  }
  function fractionForRate(rate) {
    const ticks = Math.round(rate * 64);
    if (ticks < 32 || ticks > 128 || Math.abs(ticks / 64 - rate) > 1e-9) return null;
    const divisor = (left, right) => right ? divisor(right, left % right) : left;
    const common = divisor(ticks, 64);
    return `${ticks / common}/${64 / common}`;
  }
  const savedFraction = parseSpeedFraction(storage.get("playbackRateFraction", ""));
  const legacyRate = Number(storage.get("playbackRate", 1));
  let playbackRateFraction = savedFraction?.fraction || fractionForRate(legacyRate) || "1/1";
  let playbackRate = parseSpeedFraction(playbackRateFraction).rate;
  const savedPlaybackSpeedEnabled = storage.get("playbackSpeedEnabled", null);
  let playbackSpeedEnabled = typeof savedPlaybackSpeedEnabled === "boolean"
    ? savedPlaybackSpeedEnabled
    : playbackRate !== 1;
  const savedLongPlaySeconds = storage.get("longPlayDurationSeconds", null);
  const legacyMinutes = storage.get("longPlayMinutes", null);
  const legacySeconds = Number(storage.get("longPlaySeconds", 0));
  let longPlaySeconds = Number.isInteger(savedLongPlaySeconds) && savedLongPlaySeconds >= 0 && savedLongPlaySeconds <= maximumLongPlaySeconds
    ? savedLongPlaySeconds
    : Number.isInteger(legacyMinutes) && legacyMinutes > 0 ? Math.min(1800,legacyMinutes*60)
      : legacySeconds > 0 ? Math.min(1800,legacySeconds) : 180;
  let longPlayEnabled = Boolean(storage.get("longPlayEnabled", legacySeconds > 0));
  function parseLongPlayDuration(value) {
    const parts = String(value).trim().split(':');
    if (parts.length > 3 || parts.some(part => !/^\d+$/.test(part))) return null;
    if (parts.slice(1).some(part => Number(part) > 59)) return null;
    const seconds = parts.reduce((total,part) => total*60+Number(part),0);
    return Number.isSafeInteger(seconds) && seconds >= 0 && seconds <= maximumLongPlaySeconds ? seconds : null;
  }
  let spcFadeSeconds = Number(storage.get("spcFadeSeconds", 5));
  if (!Number.isInteger(spcFadeSeconds) || spcFadeSeconds < 0 || spcFadeSeconds > 30) spcFadeSeconds = 5;
  let fadedSkipsEnabled = Boolean(storage.get("fadedSkipsEnabled", false));
  const storedVolumeStep = Number(storage.get("volumeStep", 20));
  let volumeStep = Number.isInteger(storedVolumeStep) && storedVolumeStep >= 0 && storedVolumeStep <= 20
    ? storedVolumeStep
    : 20;
  let equalizerEnabled = Boolean(storage.get("equalizerEnabled", false));
  const storedEqualizerGains = storage.get("equalizerBandGains", []);
  let equalizerBandGains = equalizerFrequencies.map((_, index) => {
    const value = Number(Array.isArray(storedEqualizerGains) ? storedEqualizerGains[index] : 0);
    return Number.isFinite(value) ? Math.max(-12, Math.min(12, Math.round(value * 2) / 2)) : 0;
  });
  function normalizeEqualizerGains(values) {
    if (!Array.isArray(values) || values.length !== equalizerFrequencies.length) return null;
    return equalizerFrequencies.map((_, index) => {
      const value = Number(values[index]);
      return Number.isFinite(value) ? Math.max(-12, Math.min(12, Math.round(value * 2) / 2)) : 0;
    });
  }
  const storedEqualizerPresets = storage.get("equalizerPresets", []);
  let equalizerPresets = Array.from({ length: 3 }, (_, index) => {
    const item = Array.isArray(storedEqualizerPresets) ? storedEqualizerPresets[index] : null;
    const gains = normalizeEqualizerGains(item?.gains);
    return gains ? { name: `Preset ${index + 1}`, gains } : null;
  });
  let audioContext = null;
  let equalizerSource = null;
  let equalizerFilters = [];
  let equalizerOutput = null;
  let transportFadeOutput = null;
  let transportFadeEnvelope = { startGain: 1, targetGain: 1, startTime: 0, endTime: 0 };
  let equalizerGraphReady = false;
  let equalizerGraphFailed = false;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  function applyVolumeStep() {
    const percent = volumeStep * 5;
    volumeInput.value = String(volumeStep);
    volumeInput.closest(".spcboy-equalizer-slider")?.style.setProperty("--range-percent", `${percent}%`);
    volumeInput.setAttribute("aria-valuetext", `${percent} percent`);
    volumeValue.value = String(percent);
    volumeValue.textContent = String(percent);
  }
  function formatEqualizerGain(value) {
    const rounded = Math.round(value * 2) / 2;
    return `${rounded > 0 ? "+" : ""}${rounded.toFixed(1)}`;
  }
  function updateEqualizerToggle(enabled) {
    equalizerToggle.setAttribute("aria-checked", String(enabled));
    equalizerToggle.textContent = enabled ? "Yes" : "No";
    equalizerToggle.classList.toggle("is-enabled", enabled);
  }
  function syncEqualizerControls() {
    updateEqualizerToggle(equalizerEnabled);
    equalizerBandInputs.forEach((input, index) => {
      const gain = equalizerBandGains[index] || 0;
      input.value = String(gain);
      const slider = input.closest(".spcboy-equalizer-slider");
      if (slider) {
        const minimum = Number(input.min || 0);
        const maximum = Number(input.max || 100);
        const percent = maximum > minimum ? ((gain - minimum) / (maximum - minimum)) * 100 : 0;
        slider.style.setProperty("--range-percent", `${Math.max(0, Math.min(100, percent))}%`);
      }
      const output = document.querySelector(`[data-equalizer-value="${index}"]`);
      if (output) output.textContent = formatEqualizerGain(gain);
    });
    if (!AudioContextClass || equalizerGraphFailed) {
      if (!equalizerGraphFailed) equalizerError.textContent = "Equalizer is not supported by this browser.";
      equalizerToggle.disabled = true;
      equalizerBandInputs.forEach((input) => { input.disabled = true; });
      equalizerResetButton.disabled = true;
    }
  }
  function syncEqualizerPresetControls() {
    equalizerPresetApplyButtons.forEach((button) => {
      const index = Number(button.dataset.equalizerPresetApply);
      const saved = Boolean(equalizerPresets[index]);
      button.disabled = !saved || !AudioContextClass || equalizerGraphFailed;
      button.setAttribute("aria-label", `${button.textContent.trim()}${saved ? ", saved" : ", empty"}`);
      const state = document.querySelector(`[data-equalizer-preset-state="${index}"]`);
      if (state) state.textContent = saved ? "Saved" : "Empty";
    });
    equalizerPresetSaveButtons.forEach((button) => { button.disabled = !AudioContextClass || equalizerGraphFailed; });
  }
  function updateEqualizerGraph() {
    if (!equalizerGraphReady) return;
    const activeGains = equalizerEnabled ? equalizerBandGains : equalizerBandGains.map(() => 0);
    activeGains.forEach((gain, index) => {
      const parameter = equalizerFilters[index]?.gain;
      if (!parameter) return;
      parameter.setTargetAtTime(gain, audioContext.currentTime, 0.035);
    });
    // Reserve headroom for positive EQ boosts before the browser sends audio to output.
    const headroomDb = equalizerEnabled ? -Math.max(0, ...equalizerBandGains) : 0;
    equalizerOutput.gain.setTargetAtTime((volumeStep / 20) * 10 ** (headroomDb / 20), audioContext.currentTime, 0.035);
  }
  function ensureEqualizerGraph() {
    if (equalizerGraphReady) return true;
    if (equalizerGraphFailed || !AudioContextClass) return false;
    try {
      audioContext = new AudioContextClass();
      equalizerSource = audioContext.createMediaElementSource(audio);
      equalizerFilters = equalizerFrequencies.map((frequency) => {
        const filter = audioContext.createBiquadFilter();
        filter.type = "peaking";
        filter.frequency.value = Math.min(frequency, audioContext.sampleRate / 2 - 1);
        filter.Q.value = Math.SQRT2;
        return filter;
      });
      equalizerOutput = audioContext.createGain();
      transportFadeOutput = audioContext.createGain();
      transportFadeOutput.gain.value = 1;
      equalizerFilters.forEach((filter, index) => {
        if (index === 0) equalizerSource.connect(filter);
        else equalizerFilters[index - 1].connect(filter);
      });
      equalizerFilters.at(-1).connect(equalizerOutput);
      equalizerOutput.connect(transportFadeOutput);
      transportFadeOutput.connect(audioContext.destination);
      equalizerGraphReady = true;
      updateEqualizerGraph();
      return true;
    } catch {
      // If graph setup fails after creating the media source, keep direct output connected.
      try {
        equalizerSource?.disconnect();
        equalizerSource?.connect(audioContext.destination);
      } catch { /* Keep the browser's native player path available when possible. */ }
      equalizerGraphFailed = true;
      equalizerEnabled = false;
      fadedSkipsEnabled = false;
      storage.set("equalizerEnabled", false);
      storage.set("fadedSkipsEnabled", false);
      equalizerError.textContent = "Equalizer setup failed; playback will continue without it.";
      syncEqualizerControls();
      syncEqualizerPresetControls();
      updateFadedSkipToggle();
      return false;
    }
  }
  function currentTransportFadeGain(now = audioContext?.currentTime || 0) {
    const { startGain, targetGain, startTime, endTime } = transportFadeEnvelope;
    if (endTime <= startTime || now >= endTime) return targetGain;
    if (now <= startTime) return startGain;
    const progress = (now - startTime) / (endTime - startTime);
    return startGain + (targetGain - startGain) * progress;
  }
  function rampTransportFade(targetGain, durationSeconds) {
    if (!ensureEqualizerGraph() || !transportFadeOutput || audioContext.state !== "running") return false;
    const now = audioContext.currentTime;
    const startGain = currentTransportFadeGain(now);
    const endTime = now + Math.max(0, durationSeconds);
    const parameter = transportFadeOutput.gain;
    parameter.cancelScheduledValues(now);
    parameter.setValueAtTime(startGain, now);
    if (endTime > now) parameter.linearRampToValueAtTime(targetGain, endTime);
    else parameter.setValueAtTime(targetGain, now);
    transportFadeEnvelope = { startGain, targetGain, startTime: now, endTime };
    return true;
  }
  function restoreTransportFade() {
    if (!audioContext || !transportFadeOutput) {
      transportFadeEnvelope = { startGain: 1, targetGain: 1, startTime: 0, endTime: 0 };
      return;
    }
    const now = audioContext.currentTime;
    const parameter = transportFadeOutput.gain;
    parameter.cancelScheduledValues(now);
    parameter.setValueAtTime(1, now);
    transportFadeEnvelope = { startGain: 1, targetGain: 1, startTime: now, endTime: now };
  }
  async function startAudioPlayback() {
    if (playbackSessionExpired() || !currentTrack) return false;
    playbackWanted = true;
    cancelStreamRecovery();
    // A failed media resource cannot be retried with play() alone.
    if (!aacTransport?.supported) {
      playbackWanted = false;
      setPlayerStatus("AAC streaming requires an up-to-date browser.");
      return false;
    }
    if (streamNeedsRetry || aacTransport.interrupted || audio.error || audio.ended) {
      streamOffsetSeconds = audio.ended && !streamNeedsRetry ? 0 : sourcePositionSeconds();
      setAudioSource(audioURL(currentTrack, streamOffsetSeconds));
    }
    const clientVolume = AudioContextClass && !equalizerGraphFailed;
    if ((equalizerEnabled || clientVolume) && !ensureEqualizerGraph()) {
      equalizerEnabled = false;
      syncEqualizerControls();
      if (clientVolume) {
        // If browser processing could not initialize, use encoded volume.
        streamOffsetSeconds = sourcePositionSeconds();
        setAudioSource(audioURL(currentTrack, streamOffsetSeconds));
      }
    }
    const source = audio.src;
    try {
      // Start both within the click gesture; resume() can remain pending in WebKit.
      const resume = audioContext && audioContext.state !== "running" ? audioContext.resume() : Promise.resolve();
      await Promise.all([audio.play(), resume]);
      return true;
    } catch (error) {
      // Track switches and Stop legitimately abort an outstanding play request.
      if (source === audio.src && error.name !== "AbortError") {
        playbackWanted = false;
        cancelStreamRecovery();
        setPlayerStatus(error.name === "NotAllowedError" ? "Press Play to resume audio." : `Audio could not start (${error.name || "unknown"}). Press Play to retry.`);
        updateControls();
      }
      return false;
    }
  }
  function positionSettingsTabIndicator() {
    if (!settingsTabList || !settingsTabIndicator) return;
    const selectedTab = settingsPageButtons.find((button) => button.getAttribute("aria-selected") === "true" && button.getClientRects().length);
    if (!selectedTab) return;
    const navBounds = settingsTabList.getBoundingClientRect();
    const tabBounds = selectedTab.getBoundingClientRect();
    settingsTabIndicator.style.width = `${tabBounds.width}px`;
    settingsTabIndicator.style.transform = `translate3d(${tabBounds.left - navBounds.left + settingsTabList.scrollLeft}px,0,0)`;
  }
  function syncMobileSettingsTabState(mode) {
    const activeMode = mode || (document.querySelector("#drawer-navigation")?.hidden ? "options" : "navigation");
    const selectedPage = settingsPageButtons.find((button) => button.getAttribute("aria-selected") === "true")?.dataset.settingsPageTarget;
    const selectedTab = activeMode === "navigation" ? "navigation" : selectedPage;
    mobileSettingsButtons.forEach((button) => {
      const selected = button.dataset.mobileSettingsPage === selectedTab;
      button.setAttribute("aria-selected", String(selected));
      button.tabIndex = selected ? 0 : -1;
    });
  }
  function selectSettingsPage(pageName, { focus = false } = {}) {
    if (pageName === "playlist") pageName = "interface";
    const validPage = settingsPages.some((page) => page.dataset.settingsPage === pageName);
    if (!validPage) return;
    settingsPageButtons.forEach((button) => {
      const selected = button.dataset.settingsPageTarget === pageName;
      button.setAttribute("aria-selected", String(selected));
      button.tabIndex = selected ? 0 : -1;
    });
    syncSettingsPageVisibility(pageName);
    syncMobileSettingsTabState();
    storage.set("optionsPage", pageName);
    requestAnimationFrame(positionSettingsTabIndicator);
    if (focus) settingsPageButtons.find((button) => button.dataset.settingsPageTarget === pageName)?.focus();
  }
  function syncSettingsPageVisibility(selectedPage = "playback") {
    settingsPages.forEach((page) => {
      page.hidden = page.dataset.settingsPage !== selectedPage;
    });
  }
  function saveEqualizerGains() {
    storage.set("equalizerBandGains", equalizerBandGains);
    syncEqualizerControls();
    updateEqualizerGraph();
  }
  async function setEqualizerEnabled(enabled) {
    if (enabled) {
      if (!ensureEqualizerGraph()) {
        equalizerEnabled = false;
        updateEqualizerToggle(false);
        syncOnlineControls();
        return false;
      }
      try {
        if (audioContext.state !== "running") await audioContext.resume();
      } catch {
        equalizerEnabled = false;
        updateEqualizerToggle(false);
        storage.set("equalizerEnabled", false);
        updateEqualizerGraph();
        equalizerError.textContent = "Tap again to enable audio processing in this browser.";
        syncOnlineControls();
        return false;
      }
      equalizerError.textContent = "";
    }
    equalizerEnabled = enabled;
    updateEqualizerToggle(enabled);
    storage.set("equalizerEnabled", enabled);
    updateEqualizerGraph();
    syncOnlineControls();
    return true;
  }
  function updateLongPlayToggle() {
    const duration = longPlaySeconds === 0 ? "Unlimited" : formatPlaybackTime(longPlaySeconds);
    longPlayToggle.setAttribute("aria-checked", String(longPlayEnabled));
    longPlayToggle.setAttribute("aria-label", `Long Play · ${longPlayEnabled ? "Yes" : "No"} · ${duration}`);
    longPlayToggle.title = `Long Play · ${duration}`;
    longPlayToggle.classList.toggle("is-enabled", longPlayEnabled);
    longPlayToggle.textContent = longPlayEnabled ? "Yes" : "No";
    longPlayDurationInput.value = formatPlaybackTime(longPlaySeconds);

  }
  function updateBooleanSettingsToggle(toggle, enabled, label) {
    toggle.setAttribute("aria-checked", String(enabled));
    toggle.setAttribute("aria-label", `${label} · ${enabled ? "Yes" : "No"}`);
    toggle.title = `${label} · ${enabled ? "Yes" : "No"}`;
    toggle.classList.toggle("is-enabled", enabled);
    toggle.textContent = enabled ? "Yes" : "No";
  }
  function updateFadedSkipToggle() {
    updateBooleanSettingsToggle(fadedSkipToggle, fadedSkipsEnabled, "Faded Skip");
    if (!AudioContextClass || equalizerGraphFailed) {
      fadedSkipToggle.disabled = true;
      fadedSkipToggle.title = "Faded Skip requires working browser audio processing.";
    }
  }
  function updateSpeedEnabledToggle() {
    updateBooleanSettingsToggle(speedEnabledToggle, playbackSpeedEnabled, "Native format speed");
  }
  updateLongPlayToggle();
  syncEqualizerControls();
  syncEqualizerPresetControls();
  selectSettingsPage(storage.get("optionsPage", "playback"));
  if (spcFadeSecondsInput) spcFadeSecondsInput.value = String(spcFadeSeconds);
  updateFadedSkipToggle();
  speedInput.value = playbackRateFraction;
  updateSpeedEnabledToggle();

  let currentTrack = null;
  let currentPlaybackId = null;
  let streamDurationSeconds = 0;
  let announcedPlaybackId = null;
  let streamOffsetSeconds = 0;
  let library = [];
  let libraryById = new Map();
  let libraryNavigator = null;
  let libraryNavigationPending = false;
  let queue = [];
  let nowPlayingPlaylist = false;
  let playlistHistory = [];
  let nowPlayingTimer = null;
  let statusTimer = null;
  let expiryPollTimer = null;
  let volumeRestartTimer = null;
  let queuedSkipRequest = null;
  let queuedSkipTimer = null;
  let queuedSkipGeneration = 0;
  const transportDeclickSeconds = 0.01;
  let panelReturnFocus = settingsToggle;
  let playerPanelCloseTimer = null;
  let playbackExpired = false;
  let playbackNeedsLogin = false;
  const playbackExpiredMessage = "Stopped · reload page to play";
  const playbackDeadline = Date.now() + playbackSessionLimitSeconds * 1000;
  let streamNeedsRetry = false;
  let playbackWanted = false;
  let changingAudioSource = false;
  let streamRecoveryTimer = null;
  let streamRecoveryAttempts = 0;
  let healthyPlaybackSince = 0;
  function cancelStreamRecovery(reset = false) {
    window.clearTimeout(streamRecoveryTimer);
    streamRecoveryTimer = null;
    if (reset) streamRecoveryAttempts = 0;
  }
  function pausePlayback() {
    clearFadedSkip();
    playbackWanted = false;
    cancelStreamRecovery(true);
    audio.pause();
  }
  function recoverStream(error = {}) {
    streamNeedsRetry = true;
    healthyPlaybackSince = 0;
    if (error.status === 401 || error.status === 403) playbackNeedsLogin = true;
    if (error.status === 410) { stopPlaybackSession(); return; }
    const terminal = playbackNeedsLogin || [400,404,415,429].includes(error.status);
    if (!playbackWanted || terminal || playbackSessionExpired() || (streamRecoveryAttempts >= 3 && streamRecoveryTimer === null)) {
      pausePlayback();
      if (error.status === 429) showStreamQuotaMessage();
      else setPlayerStatus(playbackNeedsLogin ? "Sign in to resume audio." : "Audio interrupted · press Play to resume.");
      updateControls(); savePlayback();
      return;
    }
    if (streamRecoveryTimer !== null) return;
    if (navigator.onLine === false) {
      setPlayerStatus("Offline · waiting for connection…", { busy: true });
      return;
    }
    const playbackId = currentPlaybackId;
    const delay = 1000 * 2 ** streamRecoveryAttempts++;
    setPlayerStatus("Connection interrupted · reconnecting…", { busy: true });
    streamRecoveryTimer = window.setTimeout(() => {
      streamRecoveryTimer = null;
      if (!playbackWanted || playbackId !== currentPlaybackId || playbackSessionExpired()) return;
      startAudioPlayback();
    }, delay);
  }
  const aacTransport = window.SBAACStream?.attach(audio, handleStreamFailure, (seconds) => {
    if (currentTrack && !longPlayEnabled && Number.isFinite(seconds) && seconds > 0) {
      // The response header reports the track endpoint in source time. Keep
      // it out of the catalog object so playlist labels stay canonical.
      streamDurationSeconds = seconds;
      updatePlaybackClock();
    }
  });
  function setAudioSource(url) {
    changingAudioSource = true;
    streamNeedsRetry = false;
    aacTransport?.load(url);
  }
  function handleStreamFailure(error) {
    recoverStream(error);
  }
  window.addEventListener("online", () => {
    if (playbackWanted && streamNeedsRetry) recoverStream();
  });
  const mobileControlsQuery = window.matchMedia("(max-width: 780px)");
  const canPlayFromCurrentPage = () => document.body.classList.contains("has-site-player");
  const transportHome = transport.parentNode;
  const transportHomeNextSibling = transport.nextSibling;
  const actionsHome = actionsSlot.parentNode;
  const actionsHomeNextSibling = actionsSlot.nextSibling;

  function playbackSessionExpired() {
    if (!playbackExpired && Date.now() >= playbackDeadline) stopPlaybackSession();
    return playbackExpired;
  }

  function setPlayerStatus(message = "", { busy = false, timeout = 0, announcement = message } = {}) {
    if (playbackExpired && message !== playbackExpiredMessage) return;
    window.clearTimeout(statusTimer);
    statusTimer = null;
    const text = String(message || "");
    const desktopDock = document.body.classList.contains("spcboy-body") && window.matchMedia("(min-width: 781px)").matches;
    const idleText = !currentTrack ? "Ready" : audio.paused || audio.ended ? "Paused" : "Playing";
    const isBusy = Boolean(text && busy);
    state.textContent = String(announcement || "");
    statusText.textContent = text || idleText;
    statusReadout.hidden = !text && !desktopDock;
    statusReadout.classList.toggle("has-message", Boolean(text));
    statusReadout.classList.toggle("is-busy", isBusy);
    statusReadout.setAttribute("aria-busy", String(isBusy));
    playButton.classList.toggle("is-buffering", isBusy);
    playButton.setAttribute("aria-busy", String(isBusy));
    if (text && timeout > 0) {
      statusTimer = window.setTimeout(() => {
        if (statusText.textContent === text) setPlayerStatus("");
      }, timeout);
    }
  }

  function createPlaybackId() {
    if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }

  function normalizeTrack(track) {
    if (!track || typeof track.id !== "string" || !track.id) return null;
    const known = libraryById.get(track.id);
    return {
      ...(known || {}),
      ...track,
      title: String(track.title || known?.title || track.id),
      game: String(track.game || known?.game || ""),
      artist: String(track.artist || known?.artist || ""),
      console: String(track.console || known?.console || ""),
      durationSeconds: Number(known?.durationSeconds ?? track.durationSeconds ?? 0),
    };
  }

  function renderCurrentTrack(track) {
    title.textContent = track?.title || "";
    const albumName = String(track?.game || "");
    const albumId = albumIdForTrack(track);
    album.textContent = albumName;
    album.hidden = !albumName;
    currentSeparator.hidden = !albumName;
    if (albumId) {
      const albumURL = new URL(dock.dataset.libraryUrl, window.location.href);
      albumURL.searchParams.set("openAlbum", albumId);
      album.href = albumURL.pathname + albumURL.search;
      album.dataset.albumId = albumId;
    } else {
      album.removeAttribute("href");
      delete album.dataset.albumId;
    }
  }

  function albumIdForTrack(track) {
    if (typeof track?.albumId === "string" && /^[0-9a-f]{32}$/.test(track.albumId)) return track.albumId;
    return String(track?.albumPlaylistUrl || "").match(/\/spcboy\/album\/([0-9a-f]{32})\.json(?:$|\?)/)?.[1] || "";
  }

  // The profile stores playback metadata only, never stream URLs or tokens.
  function savedTrack(track) {
    if (!track || typeof track.id !== "string" || !/^[a-zA-Z0-9_-]{1,200}$/.test(track.id)) return null;
    return { id: track.id, title: String(track.title || "").slice(0,500),
      game: String(track.game || "").slice(0,500), console: String(track.console || "").slice(0,200),
      artworkUrl: String(track.artworkUrl || "").slice(0,2048),
      albumId: albumIdForTrack(track),
      durationSeconds: Math.max(0, Math.min(86400, Number(track.durationSeconds) || 0)) };
  }
  let lastPlaybackSaveAt = 0;
  let lastPlaybackSignature = "";
  function savePlayback(force = false) {
    if (!currentTrack) return;
    const saved = {
      track: savedTrack(currentTrack), queue: queue.slice(0,500).map(savedTrack).filter(Boolean),
      history: playlistHistory.slice(-500).map(savedTrack).filter(Boolean), playlist: nowPlayingPlaylist,
      position: sourcePositionSeconds(),
      playing: !audio.paused && !audio.ended, savedAt: Date.now()
    };
    const signature = JSON.stringify({
      track: saved.track, queue: saved.queue.map(track => track.id),
      history: saved.history.map(track => track.id), playlist: saved.playlist, playing: saved.playing,
    });
    const now = Date.now();
    if (!force && signature === lastPlaybackSignature && now - lastPlaybackSaveAt < 15000) return;
    lastPlaybackSignature = signature;
    lastPlaybackSaveAt = now;
    window.SBOProfileStorage?.set("playback", "session", saved);
  }
  function restorePlayback() {
    const saved = window.SBOProfileStorage?.get("playback", "session", null);
    if (!saved || !savedTrack(saved.track)) return;
    currentTrack = savedTrack(saved.track);
    currentPlaybackId = createPlaybackId();
    queue = (Array.isArray(saved.queue) ? saved.queue : []).slice(0,500).map(savedTrack).filter(Boolean);
    playlistHistory = (Array.isArray(saved.history) ? saved.history : []).slice(-500).map(savedTrack).filter(Boolean);
    nowPlayingPlaylist = Boolean(saved.playlist);
    streamOffsetSeconds = Math.max(0, Math.min(Number(saved.position) || 0, effectiveDuration() - .1));
    renderCurrentTrack(currentTrack);
    lastPlaybackSignature = JSON.stringify({
      track: saved.track, queue: queue.map(track => track.id), history: playlistHistory.map(track => track.id),
      playlist: nowPlayingPlaylist, playing: Boolean(saved.playing),
    });
    lastPlaybackSaveAt = Date.now();
    // Construct a new authorized URL using this document's token after login/reload.
    setAudioSource(audioURL(currentTrack, streamOffsetSeconds));
    renderQueue(); updateControls();
    setPlayerStatus("Restored · press Play to resume");
    if (saved.playing) startAudioPlayback();
  }

  function effectiveDuration(track = currentTrack) {
    // This is playback timing for the dock clock and seek bounds. Playlist
    // length labels use the catalog's durationSeconds field directly.
    if (longPlayEnabled) return longPlaySeconds || Infinity;
    if (track === currentTrack && streamDurationSeconds > 0) {
      return streamDurationSeconds;
    }
    return Number(track?.durationSeconds) || 0;
  }

  function fadedSkipDurationSeconds() {
    if (!fadedSkipsEnabled
        || !currentTrack
        || !playbackWanted
        || audio.paused
        || audio.ended
        || audio.error
        || streamNeedsRetry
        || spcFadeSeconds <= 0
        || !ensureEqualizerGraph()
        || equalizerGraphFailed) return 0;
    const totalSeconds = effectiveDuration();
    if (!(totalSeconds > 0) && totalSeconds !== Infinity) return 0;
    const elapsedSeconds = sourcePositionSeconds();
    const preFadeSeconds = totalSeconds === Infinity ? Infinity : Math.max(0, totalSeconds - spcFadeSeconds);
    if (elapsedSeconds >= preFadeSeconds) return 0;
    const remainingWallSeconds = totalSeconds === Infinity
      ? Infinity
      : Math.max(0, (totalSeconds - elapsedSeconds) / effectivePlaybackRate());
    return Math.min(spcFadeSeconds, remainingWallSeconds);
  }

  function clearFadedSkip({ restoreOutput = true } = {}) {
    if (queuedSkipTimer !== null) window.clearTimeout(queuedSkipTimer);
    queuedSkipTimer = null;
    queuedSkipRequest = null;
    queuedSkipGeneration += 1;
    if (restoreOutput) restoreTransportFade();
  }

  function formatPlaybackTime(seconds) {
    if (seconds === Infinity) return "∞";
    const wholeSeconds = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = Math.floor(wholeSeconds / 3600);
    const minutes = Math.floor((wholeSeconds % 3600) / 60);
    const remainder = wholeSeconds % 60;
    return hours
      ? `${hours}:${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`
      : `${minutes}:${String(remainder).padStart(2, "0")}`;
  }

  function updatePlaybackClock() {
    if (!currentTrack) {
      playbackClock.hidden = true;
      playbackClock.textContent = "";
      return;
    }
    const trackDuration = effectiveDuration(currentTrack);
    const mediaTime = Number.isFinite(audio.currentTime) ? audio.currentTime : 0;
    const elapsed = Math.min(trackDuration || Infinity, streamOffsetSeconds + mediaTime * nativeFormatPlaybackRate());
    const playlistDuration = trackDuration + queue.reduce(
      (total, queuedTrack) => total + effectiveDuration(queuedTrack),
      0,
    );
    const elapsedText = formatPlaybackTime(elapsed);
    const trackText = formatPlaybackTime(trackDuration);
    const playlistText = formatPlaybackTime(playlistDuration);
    playbackClock.textContent = `${elapsedText} / ${trackText} / ${playlistText}`;
    playbackClock.setAttribute(
      "aria-label",
      `${elapsedText} elapsed / ${trackText} track length / ${playlistText} current track and Up Next`,
    );
    playbackClock.hidden = false;
  }

  function audioURL(track, startSeconds = 0) {
    const base = dock.dataset.audioUrl.replace("TRACK_ID", encodeURIComponent(track.id));
    const params = new URLSearchParams({ playback: currentPlaybackId, pageLoad: dock.dataset.pageLoadToken });
    params.set("format", "aac");
    const startMs = Math.max(0, Math.floor(startSeconds * 1000));
    if (startMs) params.set("start", String(startMs));
    const [speedNumerator, speedDenominator] = playbackSpeedEnabled ? playbackRateFraction.split("/") : ["1", "1"];
    params.set("speedNumerator", speedNumerator);
    params.set("speedDenominator", speedDenominator);
    params.set("fade", String(spcFadeSeconds));
    if (longPlayEnabled) params.set("longPlay", String(longPlaySeconds));
    if (volumeStep < 20 && (!AudioContextClass || equalizerGraphFailed)) params.set("volume", String(volumeStep));
    return `${base}?${params}`;
  }

  function nativeFormatPlaybackRate() {
    return playbackSpeedEnabled ? playbackRate : 1;
  }

  function effectivePlaybackRate() {
    return nativeFormatPlaybackRate();
  }

  function sourcePositionSeconds() {
    return Math.max(0, streamOffsetSeconds + (Number(audio.currentTime) || 0) * nativeFormatPlaybackRate());
  }

  function updateControls() {
    if (stopButton) stopButton.disabled = !currentTrack || playbackSessionExpired();
    syncOnlineControls();
    const playing = Boolean(currentTrack && !audio.paused && !audio.ended && !audio.error);
    playButton.disabled = !playbackSessionExpired() && !currentTrack;
    playButton.setAttribute("aria-label", playbackExpired ? "Reload player" : playing ? "Pause" : "Play");
    playButton.title = playbackExpired ? "Reload player to start a new session" : playing ? "Pause" : "Play";
    playButton.classList.toggle("is-expired", playbackExpired);
    if (reloadButton) {
      reloadButton.hidden = !playbackExpired && !playbackNeedsLogin;
      reloadButton.textContent = playbackNeedsLogin ? "Sign in" : "Reload player";
    }
    playButton.classList.toggle("is-playing", playing);
    playButton.classList.toggle("sb-is-playing", playing);
    const canNavigate = nowPlayingPlaylist
      ? queue.length > 0
      : Boolean(libraryNavigator) || library.length > 1;
    const canGoBack = nowPlayingPlaylist ? playlistHistory.length > 0 : canNavigate;
    previousButton.disabled = playbackExpired || !currentTrack || !canGoBack || libraryNavigationPending;
    nextButton.disabled = playbackExpired || (!queue.length && (nowPlayingPlaylist || !currentTrack || !canNavigate)) || libraryNavigationPending;
    updatePlaybackClock();
  }

  function emitTrack() {
    syncMediaSession();
    savePlayback();
    window.dispatchEvent(new CustomEvent("siteplayer:track", {
      detail: { track: currentTrack, playbackId: currentPlaybackId, playing: Boolean(currentTrack && !audio.paused && !audio.ended && !audio.error) },
    }));
  }

  function syncMediaPosition() {
    if (!navigator.mediaSession?.setPositionState || !currentTrack) return;
    const duration = effectiveDuration();
    try {
      if (!Number.isFinite(duration) || duration <= 0) navigator.mediaSession.setPositionState();
      else navigator.mediaSession.setPositionState({duration, playbackRate: effectivePlaybackRate(),
        position: Math.min(duration, sourcePositionSeconds())});
    } catch { /* Platform support varies. */ }
  }
  function syncMediaSession() {
    if (!navigator.mediaSession) return;
    if (currentTrack && window.MediaMetadata) {
      const artwork = typeof currentTrack.artworkUrl === "string" && currentTrack.artworkUrl
        ? [{src: new URL(currentTrack.artworkUrl, document.baseURI).href, sizes: "240x240", type: "image/webp"}]
        : [];
      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentTrack.title, artist: currentTrack.artist || "", album: currentTrack.game || "", artwork
      });
    }
    navigator.mediaSession.playbackState = !currentTrack ? "none" : audio.paused || audio.ended ? "paused" : "playing";
    syncMediaPosition();
  }
  if (navigator.mediaSession) {
    const seek = seconds => {
      if (!currentTrack || playbackSessionExpired()) return;
      const duration = effectiveDuration();
      const offset = Math.max(0,Math.min(seconds,Number.isFinite(duration) ? Math.max(0,duration-.1) : seconds));
      if (!Number.isFinite(offset)) return;
      const resume = playbackWanted;
      cancelStreamRecovery(true);
      streamOffsetSeconds = offset;
      setAudioSource(audioURL(currentTrack,offset));
      if (resume) startAudioPlayback();
      syncMediaPosition(); savePlayback();
    };
    const actions = {
      play: () => startAudioPlayback(), pause: () => pausePlayback(),
      previoustrack: () => moveTrack(-1), nexttrack: () => moveTrack(1),
      seekto: event => seek(event.seekTime),
      seekbackward: event => seek(sourcePositionSeconds() - (event.seekOffset || 10)),
      seekforward: event => seek(sourcePositionSeconds() + (event.seekOffset || 10)),
    };
    for (const [action,handler] of Object.entries(actions)) {
      try { navigator.mediaSession.setActionHandler(action,handler); } catch { /* Unsupported action. */ }
    }
  }
  function renderQueue() {
    const playlistCount = queue.length + (currentTrack ? 1 : 0);
    queueCount.textContent = String(playlistCount);
    queueToggle.setAttribute("aria-label", `Queue, ${playlistCount} ${playlistCount === 1 ? "track" : "tracks"}`);
    queueCurrent.hidden = !currentTrack;
    queueCurrentTitle.textContent = currentTrack?.title || "";
    queueCurrentGame.textContent = currentTrack?.game || "";
    queueList.replaceChildren();
    queue.forEach((track, index) => {
      const row = document.createElement("li");
      const play = document.createElement("button");
      play.type = "button";
      play.className = "site-player-queue-track";
      play.setAttribute("aria-label", `Play ${track.title}${track.game ? `, ${track.game}` : ""}`);
      const cells = [
        ["site-player-queue-number", String(index + 1).padStart(2, "0")],
        ["site-player-queue-title", track.title],
        ["site-player-queue-game", track.game || "—"],
        ["site-player-queue-artist", track.artist || "—"],
        ["site-player-queue-system", track.console || "—"],
        ["site-player-queue-length", formatPlaybackTime(track.durationSeconds)],
      ];
      for (const [className, value] of cells) {
        const cell = document.createElement("span");
        cell.className = className;
        cell.textContent = value;
        play.append(cell);
      }
      play.title = `${track.title}${track.game ? ` · ${track.game}` : ""}`;
      play.addEventListener("click", () => {
        queue.splice(index, 1);
        if (nowPlayingPlaylist && currentTrack) playlistHistory.push(currentTrack);
        renderQueue();
        updateControls();
        playTrack(track, { toggle: false });
      });
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "site-player-queue-remove";
      remove.textContent = "×";
      remove.setAttribute("aria-label", `Remove ${track.title} from queue`);
      remove.addEventListener("click", () => {
        queue.splice(index, 1);
        renderQueue();
        updateControls();
      });
      row.append(play, remove);
      queueList.append(row);
    });
    queueColumns.hidden = queue.length === 0;
    queueEmpty.hidden = queue.length > 0;
    updatePlaybackClock();
  }

  function stopPlaybackSession() {
    if (playbackExpired) return;
    playbackExpired = true;
    window.clearInterval(nowPlayingTimer);
    window.clearInterval(expiryPollTimer);
    window.clearTimeout(statusTimer);
    window.clearTimeout(volumeRestartTimer);
    nowPlayingTimer = null;
    pausePlayback();
    aacTransport?.cancel();
    audio.removeAttribute("src");
    audio.load();
    queue = [];
    nowPlayingPlaylist = false;
    playlistHistory = [];
    renderQueue();
    window.clearTimeout(playerPanelCloseTimer);
    queueToggle.setAttribute("aria-expanded", "false");
    queuePanel.hidden = true;
    queuePanel.classList.remove("is-open");
    settingsToggle.setAttribute("aria-expanded", "false");
    settingsPanel.hidden = true;
    settingsPanel.inert = true;
    queuePanel.inert = true;
    setPlayerBackgroundInert(false);
    settingsPanel.classList.remove("is-open");
    playerDrawerScrim.hidden = true;
    playerDrawerScrim.classList.remove("is-open");
    clearNowPlaying();
    setPlayerStatus(playbackExpiredMessage, { announcement: playbackExpiredAnnouncement });
    updateControls();
    emitTrack();
  }

  function syncOnlineControls() {
    document.querySelectorAll(".sbonline-context").forEach((element) => { element.hidden = !document.body.classList.contains("spcboy-body"); });
    for (const [command, active] of [["equalizer", equalizerEnabled], ["long-play", longPlayEnabled], ["playback-speed", playbackSpeedEnabled]]) {
      const button = document.querySelector(`[data-sbonline-command="${command}"]`);
      button?.setAttribute("aria-pressed", String(active));
      if (command === "playback-speed" && button) {
        const label = `Native format speed ${playbackRateFraction}× ${active ? "enabled" : "disabled"}`;
        button.setAttribute("aria-label", label);
        button.title = label;
      }
    }
    const input = document.querySelector("#sbonline-volume-input");
    if (input) input.value = String(volumeStep);
    const output = document.querySelector("#sbonline-volume-value");
    if (output) output.textContent = String(volumeStep * 5);
    document.querySelector('[data-sbonline-command="volume"]')?.setAttribute("aria-label", `Volume ${volumeStep * 5}%`);
  }
  document.addEventListener("click", (event) => {
    const command = event.target.closest("[data-sbonline-command]")?.dataset.sbonlineCommand;
    if (command === "equalizer") equalizerToggle.click();
    if (command === "long-play") longPlayToggle.click();
    if (command === "playback-speed") speedEnabledToggle.click();
    const panel = document.querySelector("#sbonline-volume-panel");
    const button = document.querySelector('[data-sbonline-command="volume"]');
    if (panel && command === "volume") panel.hidden = !panel.hidden;
    else if (panel && !event.target.closest(".sbonline-volume")) panel.hidden = true;
    button?.setAttribute("aria-expanded", String(panel && !panel.hidden));
    syncOnlineControls();
  });
  document.addEventListener("input", (event) => {
    if (event.target.id === "sbonline-volume-input") {
      volumeInput.value = event.target.value;
      volumeInput.dispatchEvent(new Event("input", { bubbles: true }));
    }
    syncOnlineControls();
  });
  document.addEventListener("change", syncOnlineControls);
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    const panel = document.querySelector("#sbonline-volume-panel");
    if (panel && !panel.hidden) {
      panel.hidden = true;
      const button = document.querySelector('[data-sbonline-command="volume"]');
      button?.setAttribute("aria-expanded", "false");
      button?.focus();
    }
  });

  function moveTransportForViewport() {
    const toolbar = document.querySelector("#sbonline-transport-toolbar");
    if (toolbar && !mobileControlsQuery.matches) {
      toolbar.prepend(transport);
    } else if (mobileControlsQuery.matches || document.body.classList.contains("spcboy-body")) {
      transportSlot.append(transport);
    } else {
      transportHome.insertBefore(transport, transportHomeNextSibling);
    }
    actionsHome.insertBefore(actionsSlot, actionsHomeNextSibling);
    syncOnlineControls();
  }
  moveTransportForViewport();
  mobileControlsQuery.addEventListener?.("change", moveTransportForViewport);
  window.addEventListener("resize", moveTransportForViewport);

  function setPlayerBackgroundInert(inert) {
    document.querySelectorAll('main.page-shell, .topbar').forEach(element => { element.inert = inert; });
  }
  settingsPanel.inert = true;
  queuePanel.inert = true;
  function closePlayerPanels({ focus = false, immediate = false } = {}) {
    window.clearTimeout(playerPanelCloseTimer);
    queueToggle.setAttribute("aria-expanded", "false");
    queuePanel.classList.remove("is-open");
    settingsToggle.setAttribute("aria-expanded", "false");
    settingsPanel.classList.remove("is-open");
    settingsPanel.inert = true;
    queuePanel.inert = true;
    setPlayerBackgroundInert(false);
    const hidePanels = () => {
      queuePanel.hidden = true;
      settingsPanel.hidden = true;
      playerDrawerScrim.hidden = true;
    };
    if (immediate) hidePanels();
    else playerPanelCloseTimer = window.setTimeout(hidePanels, window.SBInterface?.duration() ?? 200);
    playerDrawerScrim.classList.remove("is-open");
    if (focus) panelReturnFocus?.focus();
  }

  function openQueue() {
    closePlayerPanels({ immediate: true });
    panelReturnFocus = document.activeElement;
    queueToggle.setAttribute("aria-expanded", "true");
    queuePanel.hidden = false;
    queuePanel.inert = false;
    setPlayerBackgroundInert(true);
    playerDrawerScrim.hidden = false;
    requestAnimationFrame(() => {
      queuePanel.classList.add("is-open");
      playerDrawerScrim.classList.add("is-open");
      queueClose.focus();
    });
  }

  function selectDrawerMode(mode) {
    drawerNavigation.hidden = mode !== "navigation";
    drawerOptions.hidden = mode !== "options";
    syncMobileSettingsTabState(mode);
    if (mode === 'options') requestAnimationFrame(positionSettingsTabIndicator);
    else if (settingsTabIndicator) settingsTabIndicator.style.width = "0px";
  }
  function activateMobileSettingsTab(button, focus = false) {
    const target = button.dataset.mobileSettingsPage;
    if (target === "navigation") {
      selectDrawerMode("navigation");
      if (focus) button.focus();
      return;
    }
    selectDrawerMode("options");
    selectSettingsPage(target, { focus });
  }
  const mobileNavigationButton = mobileSettingsButtons.find((button) => button.dataset.mobileSettingsPage === "navigation");
  mobileNavigationButton?.addEventListener("click", () => activateMobileSettingsTab(mobileNavigationButton));
  settingsPanel.querySelector(".spcboy-mobile-settings-nav")?.addEventListener("keydown", (event) => {
    const direction = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
    const visibleTabs = mobileSettingsButtons.filter((button) => button.getClientRects().length > 0);
    const current = visibleTabs.indexOf(event.target.closest("[data-mobile-settings-page]"));
    if (!visibleTabs.length || (!direction && event.key !== "Home" && event.key !== "End")) return;
    event.preventDefault();
    const next = event.key === "Home" ? 0
      : event.key === "End" ? visibleTabs.length - 1
        : (current + direction + visibleTabs.length) % visibleTabs.length;
    activateMobileSettingsTab(visibleTabs[next], true);
  });

  function openSettings(returnFocus = settingsToggle) {
    closePlayerPanels({ immediate: true });
    selectDrawerMode(mobileControlsQuery.matches ? "options" : "navigation");
    panelReturnFocus = returnFocus;
    settingsToggle.setAttribute("aria-expanded", "true");
    settingsPanel.hidden = false;
    settingsPanel.inert = false;
    setPlayerBackgroundInert(true);
    playerDrawerScrim.hidden = false;
    requestAnimationFrame(() => {
      settingsPanel.classList.add("is-open");
      playerDrawerScrim.classList.add("is-open");
      if (!drawerOptions.hidden) positionSettingsTabIndicator();
      settingsClose.focus();
    });
  }

  window.setTimeout(
    stopPlaybackSession,
    Math.max(0, playbackDeadline - Date.now()),
  );
  expiryPollTimer = window.setInterval(playbackSessionExpired, 15_000);
  document.addEventListener("visibilitychange", playbackSessionExpired);
  window.addEventListener("pageshow", playbackSessionExpired);
  document.addEventListener("site:close-player-overlays", () => closePlayerPanels());

  function csrfToken() {
    return dock.querySelector('input[name="csrfmiddlewaretoken"]')?.value || "";
  }

  function nowPlayingPayload(status) {
    const playbackId = status === "stopped" ? announcedPlaybackId || currentPlaybackId : currentPlaybackId;
    if (!currentTrack || !playbackId) return null;
    return { status, playbackId, trackId: currentTrack.id };
  }

  function updateNowPlaying() {
    if (audio.paused || audio.ended) return;
    const payload = nowPlayingPayload("playing");
    if (!payload) return;
    fetch(dock.dataset.nowPlayingUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRFToken": csrfToken() },
      body: JSON.stringify(payload),
    }).then((response) => {
      if (response.ok && payload.playbackId === currentPlaybackId) {
        announcedPlaybackId = payload.playbackId;
        document.dispatchEvent(new Event("siteplayer:presence"));
      }
    }).catch(() => {});
  }

  function clearNowPlaying() {
    const payload = nowPlayingPayload("stopped");
    if (!payload) return;
    fetch(dock.dataset.nowPlayingUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRFToken": csrfToken() },
      body: JSON.stringify(payload),
      keepalive: true,
    }).then(response => { if (response.ok) document.dispatchEvent(new Event("siteplayer:presence")); }).catch(() => {});
    if (payload.playbackId === announcedPlaybackId) announcedPlaybackId = null;
  }

  async function hasReachedStreamQuota() {
    try {
      const response = await fetch(dock.dataset.streamQuotaUrl, {
        credentials: "same-origin",
        cache: "no-store",
        headers: { Accept: "application/json" },
      });
      if (response.redirected || response.status === 401 || response.status === 403) {
        playbackNeedsLogin = true;
        return false;
      }
      if (!response.ok) return false;
      const quota = await response.json();
      return Number(quota.remaining) <= 0;
    } catch {
      return false;
    }
  }

  function showStreamQuotaMessage() {
    pausePlayback();
    setPlayerStatus("Monthly 10 GB audio limit reached · resets on the 1st (UTC).");
  }

  async function playTrack(rawTrack, options = {}) {
    if (playbackSessionExpired()) return false;
    window.clearTimeout(volumeRestartTimer);
    volumeRestartTimer = null;
    const track = normalizeTrack(rawTrack);
    if (!track) return false;
    if (queuedSkipRequest) {
      const request = queuedSkipRequest;
      clearFadedSkip({ restoreOutput: false });
      return finishFadedSkip(request, {
        declick: true,
        targetTrack: track,
        targetOptions: options,
      });
    }
    if (track.id !== currentTrack?.id && !options.bypassFadedSkip) {
      const fadeSeconds = fadedSkipDurationSeconds();
      if (fadeSeconds > 0) {
        const request = {
          generation: ++queuedSkipGeneration,
          playbackId: currentPlaybackId,
          targetTrack: track,
          targetOptions: options,
          historyRecorded: Boolean(
            nowPlayingPlaylist && playlistHistory.at(-1)?.id === currentTrack?.id,
          ),
        };
        if (rampTransportFade(0, fadeSeconds)) {
          queuedSkipRequest = request;
          queuedSkipTimer = window.setTimeout(() => {
            if (queuedSkipRequest !== request || request.generation !== queuedSkipGeneration) return;
            queuedSkipRequest = null;
            queuedSkipTimer = null;
            queuedSkipGeneration += 1;
            void finishFadedSkip(request).catch((error) => {
              console.error("[SPCBOY] faded track transition failed", error);
              if (request.playbackId === currentPlaybackId) restoreTransportFade();
            });
          }, Math.max(1, Math.ceil(fadeSeconds * 1000)));
          return true;
        }
      }
    }
    return playTrackNow(track, options);
  }

  async function playTrackNow(rawTrack, options = {}) {
    if (playbackSessionExpired()) return false;
    window.clearTimeout(volumeRestartTimer);
    volumeRestartTimer = null;
    const track = normalizeTrack(rawTrack);
    if (!track) return false;
    if (currentTrack?.id === track.id) {
      if (options.toggle) {
        if (streamRecoveryTimer !== null) {
          pausePlayback(); setPlayerStatus("");
        } else if (streamNeedsRetry || audio.paused || audio.error || audio.ended) {
          setPlayerStatus("Preparing audio…", { busy: true });
          await startAudioPlayback();
        } else {
          pausePlayback();
          setPlayerStatus("");
        }
      } else if (streamNeedsRetry || audio.paused || audio.error || audio.ended) {
        setPlayerStatus("Preparing audio…", { busy: true });
        await startAudioPlayback();
      }
      updateControls();
      emitTrack();
      return true;
    }

    pausePlayback();
    currentTrack = track;
    currentPlaybackId = createPlaybackId();
    streamDurationSeconds = 0;
    streamOffsetSeconds = 0;
    renderCurrentTrack(track);
    renderQueue();
    setPlayerStatus(options.autoplay === false ? "" : "Preparing audio…", { busy: options.autoplay !== false });
    setAudioSource(audioURL(track));
    updateControls();
    emitTrack();
    if (options.autoplay === false) return true;
    await startAudioPlayback();
    updateControls();
    emitTrack();
    return true;
  }

  function enqueue(rawTrack) {
    if (playbackSessionExpired()) return;
    const track = normalizeTrack(rawTrack);
    if (!track) return;
    nowPlayingPlaylist = true;
    if (!currentTrack) {
      playTrack(track);
      return;
    }
    queue.push(track);
    renderQueue();
    updateControls();
    setPlayerStatus("");
    state.textContent = `Queued · ${queue.length} up next`;
  }

  async function playNextFromQueue({ bypassFadedSkip = false, alreadyRecordedPlaybackId = null } = {}) {
    if (playbackSessionExpired()) return false;
    if (!queue.length) return false;
    const next = queue.shift();
    if (nowPlayingPlaylist && currentTrack) {
      const alreadyRecorded = alreadyRecordedPlaybackId === currentPlaybackId
        || (queuedSkipRequest?.playbackId === currentPlaybackId && queuedSkipRequest.historyRecorded);
      if (!alreadyRecorded) playlistHistory.push(currentTrack);
    }
    renderQueue();
    return playTrack(next, { toggle: false, bypassFadedSkip });
  }

  async function playNow(rawTrack) {
    if (playbackSessionExpired()) return false;
    const track = normalizeTrack(rawTrack);
    if (!track) return false;
    nowPlayingPlaylist = true;
    queue = [];
    playlistHistory = [];
    renderQueue();
    updateControls();
    return playTrack(track, { toggle: false });
  }

  async function playPlaylist(rawTracks, options = {}) {
    if (playbackSessionExpired()) return false;
    const seen = new Set();
    const playlist = [];
    for (const rawTrack of Array.isArray(rawTracks) ? rawTracks : []) {
      const track = normalizeTrack(rawTrack);
      if (!track || seen.has(track.id)) continue;
      seen.add(track.id);
      playlist.push(track);
    }
    if (options.shuffle) {
      for (let index = playlist.length - 1; index > 0; index -= 1) {
        const swapIndex = Math.floor(Math.random() * (index + 1));
        [playlist[index], playlist[swapIndex]] = [playlist[swapIndex], playlist[index]];
      }
    }
    const startIndex = Math.max(0, playlist.findIndex((track) => track.id === options.startTrackId));
    const first = playlist[startIndex];
    if (!first) return false;
    queue = [
      ...playlist.slice(startIndex + 1),
      ...playlist.slice(0, startIndex),
    ];
    nowPlayingPlaylist = true;
    playlistHistory = [];
    renderQueue();
    updateControls();
    return playTrack(first, { toggle: Boolean(options.toggle) });
  }

  async function finishFadedSkip(request, {
    declick = false,
    step = null,
    targetTrack = null,
    targetOptions = null,
  } = {}) {
    if (declick) {
      if (rampTransportFade(0, transportDeclickSeconds)) {
        await new Promise((resolve) => window.setTimeout(resolve, transportDeclickSeconds * 1000));
      } else {
        restoreTransportFade();
      }
    }
    if (request.playbackId !== currentPlaybackId) return;
    try {
      if (step !== null) {
        await moveTrackNow(step, {
          bypassFadedSkip: true,
          alreadyRecordedPlaybackId: request.historyRecorded ? request.playbackId : null,
        });
      } else {
        await playTrackNow(targetTrack || request.targetTrack, targetOptions || request.targetOptions || {});
      }
    } finally {
      if (request.playbackId === currentPlaybackId) restoreTransportFade();
    }
  }

  async function moveTrack(step) {
    if (queuedSkipRequest) {
      const request = queuedSkipRequest;
      clearFadedSkip({ restoreOutput: false });
      return finishFadedSkip(request, { declick: true, step });
    }
    return moveTrackNow(step);
  }

  async function moveTrackNow(step, { bypassFadedSkip = false, alreadyRecordedPlaybackId = null } = {}) {
    if (playbackSessionExpired()) return;
    if (nowPlayingPlaylist) {
      if (step > 0) {
        if (queue.length) await playNextFromQueue({ bypassFadedSkip, alreadyRecordedPlaybackId });
        else setPlayerStatus("Playlist complete.");
        return;
      }
      if (playlistHistory.length) {
        const previous = playlistHistory.pop();
        if (currentTrack) queue.unshift(currentTrack);
        renderQueue();
        updateControls();
        await playTrack(previous, { toggle: false, bypassFadedSkip });
      }
      return;
    }
    if (step > 0 && queue.length) {
      await playNextFromQueue({ bypassFadedSkip, alreadyRecordedPlaybackId });
      return;
    }
    if (!currentTrack) return;
    if (libraryNavigator) {
      if (libraryNavigationPending) return;
      libraryNavigationPending = true;
      setPlayerStatus(step > 0 ? "Preparing next track…" : "Preparing previous track…", { busy: true });
      updateControls();
      try {
        const next = await libraryNavigator(currentTrack, step);
        if (next) await playTrack(next, { toggle: false, bypassFadedSkip });
        else setPlayerStatus("No adjacent track is available.", { timeout: 4000 });
      } catch {
        setPlayerStatus("Could not load the adjacent track. Try again.", { timeout: 5000 });
      } finally {
        libraryNavigationPending = false;
        updateControls();
      }
      return;
    }
    if (library.length < 2) return;
    const index = library.findIndex((track) => track.id === currentTrack.id);
    if (index < 0) {
      if (step > 0) await playTrack(library[0], { bypassFadedSkip });
      return;
    }
    const next = (index + step + library.length) % library.length;
    await playTrack(library[next], { bypassFadedSkip });
  }

  playButton.addEventListener("click", () => {
    if (playbackSessionExpired()) {
      window.location.reload();
      return;
    }
    if (!currentTrack) return;
    if (streamRecoveryTimer !== null) {
      pausePlayback(); setPlayerStatus("");
    } else if (streamNeedsRetry || audio.paused || audio.error || audio.ended) {
      setPlayerStatus("Preparing audio…", { busy: true });
      startAudioPlayback();
    }
    else {
      pausePlayback();
      setPlayerStatus("");
    }
  });
  reloadButton?.addEventListener("click", () => {
    savePlayback();
    if (playbackNeedsLogin) window.location.assign(`/login/?next=${encodeURIComponent(window.location.pathname + window.location.search)}`);
    else window.location.reload();
  });
  stopButton?.addEventListener("click", () => {
    if (!currentTrack || playbackSessionExpired()) return;
    pausePlayback();
    streamOffsetSeconds = 0;
    setAudioSource(audioURL(currentTrack, 0));
    clearNowPlaying();
    setPlayerStatus("Stopped");
    savePlayback();
    updateControls();
    emitTrack();
  });
  previousButton.addEventListener("click", () => moveTrack(-1));
  nextButton.addEventListener("click", () => moveTrack(1));
  async function restartCurrentStream(sourcePosition = null) {
    if (playbackSessionExpired() || !currentTrack) return;
    clearFadedSkip();
    const resume = !audio.paused && !audio.ended;
    const target = Math.min(sourcePosition ?? sourcePositionSeconds(), Math.max(0, effectiveDuration() - 1));
    streamOffsetSeconds = target;
    streamDurationSeconds = 0;
    audio.pause();
    setAudioSource(audioURL(currentTrack, target));
    if (resume) setPlayerStatus("Preparing audio…", { busy: true });
    else setPlayerStatus("");
    updateControls();
    syncMediaSession();
    savePlayback();
    if (resume) {
      startAudioPlayback();
    }
  }
  longPlayToggle.addEventListener("click", async () => {
    if (playbackSessionExpired()) return;
    longPlayEnabled = !longPlayEnabled;
    updateLongPlayToggle();
    storage.set("longPlayEnabled", longPlayEnabled);
    await restartCurrentStream();
  });
  function commitLongPlayDuration() {
    const selected = parseLongPlayDuration(longPlayDurationInput.value);
    if (selected === null) {
      longPlayDurationInput.setAttribute("aria-invalid", "true");
      longPlayError.textContent = "Enter seconds, M:SS, or H:MM:SS (up to 24 hours). Zero means unlimited.";
      return false;
    }
    const changed = selected !== longPlaySeconds;
    longPlaySeconds = selected;
    longPlayDurationInput.removeAttribute("aria-invalid");
    longPlayError.textContent = "";
    storage.set("longPlayDurationSeconds", longPlaySeconds);
    updateLongPlayToggle();
    if (changed && longPlayEnabled) restartCurrentStream();
    return true;
  }
  longPlayDurationInput.addEventListener("change", commitLongPlayDuration);
  longPlayDurationInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    commitLongPlayDuration();
    longPlayDurationInput.blur();
  });
  function commitSpcFadeSeconds() {
    const selected = Number(spcFadeSecondsInput.value);
    if (!Number.isInteger(selected) || selected < 0 || selected > 30) {
      spcFadeSecondsInput.setAttribute("aria-invalid", "true");
      spcFadeError.textContent = "Choose a whole number from 0 to 30 seconds.";
      return false;
    }
    const changed = selected !== spcFadeSeconds;
    spcFadeSeconds = selected;
    spcFadeSecondsInput.removeAttribute("aria-invalid");
    spcFadeError.textContent = "";
    spcFadeSecondsInput.value = String(spcFadeSeconds);
    storage.set("spcFadeSeconds", spcFadeSeconds);
    if (changed && currentTrack) restartCurrentStream();
    return true;
  }
  spcFadeSecondsInput.addEventListener("change", commitSpcFadeSeconds);
  spcFadeSecondsInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    commitSpcFadeSeconds();
    spcFadeSecondsInput.blur();
  });
  fadedSkipToggle?.addEventListener("click", () => {
    if (fadedSkipToggle.disabled) return;
    fadedSkipsEnabled = !fadedSkipsEnabled;
    storage.set("fadedSkipsEnabled", fadedSkipsEnabled);
    if (!fadedSkipsEnabled) clearFadedSkip();
    updateFadedSkipToggle();
  });
  speedEnabledToggle.addEventListener("click", () => {
    const sourcePosition = sourcePositionSeconds();
    playbackSpeedEnabled = !playbackSpeedEnabled;
    storage.set("playbackSpeedEnabled", playbackSpeedEnabled);
    updateSpeedEnabledToggle();
    restartCurrentStream(sourcePosition);
    syncOnlineControls();
  });
  function commitPlaybackRate() {
    const selected = parseSpeedFraction(speedInput.value);
    if (!selected) {
      speedInput.setAttribute("aria-invalid", "true");
      speedInput.title = "Enter a fraction from 1/2 to 2 in 1/64 increments, such as 33/32 or 15/16.";
      speedError.textContent = "Use a fraction from 1/2 to 2 in 1/64 increments, such as 33/32 or 15/16.";
      return false;
    }
    const sourcePosition = sourcePositionSeconds();
    const wasEnabled = playbackSpeedEnabled;
    playbackRate = selected.rate;
    playbackRateFraction = selected.fraction;
    speedInput.value = playbackRateFraction;
    speedInput.removeAttribute("aria-invalid");
    speedInput.title = "Native format speed as a fraction. Use 1/64 increments from 1/2 to 2.";
    speedError.textContent = "";
    storage.set("playbackRateFraction", playbackRateFraction);
    storage.set("playbackRate", playbackRate);
    if (wasEnabled) restartCurrentStream(sourcePosition);
    syncOnlineControls();
    return true;
  }
  speedInput.addEventListener("change", commitPlaybackRate);
  speedInput.addEventListener("input", () => {
    if (parseSpeedFraction(speedInput.value)) {
      speedInput.removeAttribute("aria-invalid");
      speedError.textContent = "";
    }
  });
  speedInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      commitPlaybackRate();
      speedInput.blur();
    }
  });
  settingsPageButtons.forEach((button) => {
    button.addEventListener("click", () => {
      if (button.closest(".spcboy-mobile-settings-nav")) selectDrawerMode("options");
      selectSettingsPage(button.dataset.settingsPageTarget);
    });
  });
  settingsTabList?.addEventListener("scroll", positionSettingsTabIndicator, { passive: true });
  window.addEventListener("resize", () => {
    const selectedPage = settingsPageButtons.find((button) => button.getAttribute("aria-selected") === "true")?.dataset.settingsPageTarget || "playback";
    syncSettingsPageVisibility(selectedPage);
    positionSettingsTabIndicator();
  });
  const audioProcessingGestureSelector = [
    "#spcboy-play", "#spcboy-next", "#spcboy-previous", "#spcboy-gallery-play",
    "#spcboy-faded-skip", "#spcboy-equalizer-enabled", "#site-player-volume",
    ".spcboy-track", ".spcboy-media-card", "[data-site-play-track]", "[data-site-play-album-url]",
  ].join(",");
  function prepareAudioGraphFromGesture(event) {
    const target = event.target instanceof Element ? event.target : event.target?.parentElement;
    if (!equalizerEnabled && !fadedSkipsEnabled && !target?.closest(audioProcessingGestureSelector)) return;
    if (!ensureEqualizerGraph() || audioContext.state === "running") return;
    try { audioContext.resume().catch(() => {}); } catch { /* The next playback gesture can retry the suspended context. */ }
  }
  document.addEventListener("pointerdown", prepareAudioGraphFromGesture, true);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") prepareAudioGraphFromGesture(event);
  }, true);
  equalizerToggle.addEventListener("click", () => setEqualizerEnabled(equalizerToggle.getAttribute("aria-checked") !== "true"));
  equalizerBandInputs.forEach((input) => {
    input.addEventListener("input", () => {
      const index = Number(input.dataset.equalizerBand);
      if (!Number.isInteger(index) || index < 0 || index >= equalizerBandGains.length) return;
      equalizerBandGains[index] = Math.max(-12, Math.min(12, Math.round(Number(input.value) * 2) / 2));
      saveEqualizerGains();
    });
  });
  equalizerResetButton.addEventListener("click", () => {
    equalizerBandGains = equalizerBandGains.map(() => 0);
    saveEqualizerGains();
  });
  equalizerPresetApplyButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const index = Number(button.dataset.equalizerPresetApply);
      const preset = equalizerPresets[index];
      if (!preset) return;
      equalizerBandGains = [...preset.gains];
      saveEqualizerGains();
      const enabled = equalizerEnabled || await setEqualizerEnabled(true);
      equalizerPresetStatus.textContent = enabled
        ? `${preset.name} applied.`
        : `${preset.name} loaded, but audio processing could not be enabled.`;
    });
  });
  equalizerPresetSaveButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const index = Number(button.dataset.equalizerPresetSave);
      if (!Number.isInteger(index) || index < 0 || index >= equalizerPresets.length) return;
      equalizerPresets[index] = { name: `Preset ${index + 1}`, gains: [...equalizerBandGains] };
      storage.set("equalizerPresets", equalizerPresets);
      syncEqualizerPresetControls();
      equalizerPresetStatus.textContent = `Preset ${index + 1} saved.`;
    });
  });
  queueToggle.addEventListener("click", () => {
    const open = queueToggle.getAttribute("aria-expanded") !== "true";
    if (open) openQueue();
    else closePlayerPanels({ focus: true });
  });
  settingsToggle.addEventListener("click", () => {
    const open = settingsToggle.getAttribute("aria-expanded") !== "true";
    if (open) openSettings(settingsToggle);
    else closePlayerPanels();
  });
  volumeInput.addEventListener("input", () => {
    volumeStep = Math.max(0, Math.min(20, Math.round(Number(volumeInput.value))));
    storage.set("volumeStep", volumeStep);
    applyVolumeStep();
    window.clearTimeout(volumeRestartTimer);
    if (ensureEqualizerGraph()) {
      updateEqualizerGraph();
      if (audioContext.state !== "running") {
        audioContext.resume().catch(() => { setPlayerStatus("Press Play to resume audio processing."); });
      }
    } else if (currentTrack) {
      // Legacy browsers without Web Audio retain the server-volume fallback.
      volumeRestartTimer = window.setTimeout(() => restartCurrentStream(), 350);
    }
  });
  settingsClose.addEventListener("click", () => closePlayerPanels({ focus: true }));
  queueClose.addEventListener("click", () => closePlayerPanels({ focus: true }));
  playerDrawerScrim.addEventListener("click", () => closePlayerPanels({ focus: true }));
  document.addEventListener("pointerdown", (event) => {
    if (
      dock.contains(event.target)
      || settingsPanel.contains(event.target)
      || queuePanel.contains(event.target)
      || transportSlot.contains(event.target)
      || actionsSlot.contains(event.target)
      || event.target === playerDrawerScrim
    ) return;
    if (!queuePanel.hidden || !settingsPanel.hidden) closePlayerPanels();
  });
  document.addEventListener("keydown", (event) => {
    const activeDialog = !queuePanel.hidden
      ? queuePanel
      : (!settingsPanel.hidden && !settingsPanel.inert ? settingsPanel : null);
    if (event.key === "Tab" && activeDialog) {
      const focusable = [...activeDialog.querySelectorAll('a[href], button:not(:disabled), input:not(:disabled), [tabindex]:not([tabindex="-1"])')]
        .filter((element) => !element.hidden && element.getClientRects().length > 0);
      const first = focusable[0];
      const last = focusable.at(-1);
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    }
    if (event.key !== "Escape") return;
    const queueWasOpen = !queuePanel.hidden;
    const settingsWereOpen = !settingsPanel.hidden;
    if (!queueWasOpen && !settingsWereOpen) return;
    closePlayerPanels({ focus: queueWasOpen || settingsWereOpen });
  });
  document.addEventListener("site:close-player-overlays", () => closePlayerPanels());
  document.addEventListener("site:pageleave", () => {
    transportSlot.append(transport);
    actionsHome.insertBefore(actionsSlot, actionsHomeNextSibling);
  });
  document.addEventListener("site:navigated", () => {
    moveTransportForViewport();
    closePlayerPanels();
  });
  applyVolumeStep();
  document.querySelector("#site-player-clear-queue").addEventListener("click", () => {
    queue = [];
    renderQueue();
    updateControls();
  });

  let lastPlaybackSave = 0;
  audio.addEventListener("timeupdate", () => {
    updateControls();
    syncMediaPosition();
    if (!audio.paused && !audio.ended && !audio.error && healthyPlaybackSince && Date.now() - healthyPlaybackSince > 30000) streamRecoveryAttempts = 0;
    if (Date.now() - lastPlaybackSave > 2000) { savePlayback(); lastPlaybackSave = Date.now(); }
  });
  audio.addEventListener("playing", () => {
    changingAudioSource = false;
    healthyPlaybackSince = Date.now();
    if (playbackSessionExpired()) {
      stopPlaybackSession();
      return;
    }
    setPlayerStatus("", { announcement: "Playback started" });
    updateControls();
    updateNowPlaying();
    emitTrack();
    window.clearInterval(nowPlayingTimer);
    nowPlayingTimer = window.setInterval(updateNowPlaying, 20_000);
  });
  audio.addEventListener("pause", () => {
    // Device interruptions cancel intent; source replacement emits its own pause.
    if (!changingAudioSource && !audio.ended && !audio.error) {
      clearFadedSkip();
      playbackWanted = false;
      cancelStreamRecovery();
    }
    syncMediaSession();
    updateControls();
    emitTrack();
    window.clearInterval(nowPlayingTimer);
    nowPlayingTimer = null;
    clearNowPlaying();
  });
  audio.addEventListener("waiting", () => {
    if (currentTrack && !audio.paused) setPlayerStatus("Buffering audio…", { busy: true });
  });
  audio.addEventListener("stalled", () => {
    if (currentTrack && !audio.paused) setPlayerStatus("Buffering audio…", { busy: true });
  });
  audio.addEventListener("ended", async () => {
    const source = audio.src;
    const expectedDuration = effectiveDuration();
    if (expectedDuration > 0 && sourcePositionSeconds() < expectedDuration - 1) {
      const quotaReached = await hasReachedStreamQuota();
      if (source !== audio.src || !audio.ended) return;
      if (quotaReached) showStreamQuotaMessage();
      else recoverStream();
      updateControls();
      return;
    }
    moveTrack(1);
  });
  audio.addEventListener("error", async () => {
    const failedPlaybackId = currentPlaybackId;
    const failedSource = audio.src;
    const stillFailed = () => failedPlaybackId === currentPlaybackId && failedSource === audio.src && audio.error;
    if (currentTrack && await hasReachedStreamQuota()) {
      if (stillFailed()) showStreamQuotaMessage();
    } else if (currentTrack && stillFailed()) {
      recoverStream({status: audio.error.code === 3 || audio.error.code === 4 ? 415 : 0});
    }
    updateControls();
  });
  window.addEventListener("pagehide", () => {
    savePlayback(true);
    playbackWanted = false;
    cancelStreamRecovery();
    window.clearInterval(nowPlayingTimer);
    const payload = nowPlayingPayload("stopped");
    if (!payload || !navigator.sendBeacon) return;
    const form = new URLSearchParams({ ...payload, csrfmiddlewaretoken: csrfToken() });
    navigator.sendBeacon(dock.dataset.nowPlayingUrl, form);
  });
  document.addEventListener("site:pageleave", () => savePlayback(true));

  function trackFromControl(control) {
    return {
      id: control.dataset.trackId,
      title: control.dataset.trackTitle,
      game: control.dataset.trackGame,
      console: control.dataset.trackConsole,
      durationSeconds: control.dataset.trackDuration,
    };
  }

  async function playAlbumFromControl(control) {
    if (control.getAttribute("aria-busy") === "true") return;
    control.setAttribute("aria-busy", "true");
    setPlayerStatus("Preparing album…", { busy: true });
    try {
      const response = await fetch(control.dataset.sitePlayAlbumUrl, {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) throw new Error(`Album request returned ${response.status}.`);
      const payload = await response.json();
      if (!Array.isArray(payload.tracks) || !payload.tracks.length) throw new Error("Album playlist is empty.");
      await playPlaylist(payload.tracks, { startTrackId: control.dataset.trackId });
    } catch {
      setPlayerStatus("Album playlist could not be loaded. Try again.");
    } finally {
      control.removeAttribute("aria-busy");
    }
  }

  document.addEventListener("click", (event) => {
    if (!canPlayFromCurrentPage()) return;
    const albumButton = event.target.closest("[data-site-play-album-url]");
    if (albumButton) {
      const modifiedLink = albumButton instanceof HTMLAnchorElement
        && (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey);
      if (modifiedLink) return;
      event.preventDefault();
      playAlbumFromControl(albumButton);
      return;
    }
    const queueButton = event.target.closest("[data-site-queue-track]");
    if (queueButton) {
      event.preventDefault();
      enqueue({
        id: queueButton.dataset.trackId,
        title: queueButton.dataset.trackTitle,
        game: queueButton.dataset.trackGame,
        console: queueButton.dataset.trackConsole,
        durationSeconds: queueButton.dataset.trackDuration,
      });
      return;
    }
    const playButton = event.target.closest("button[data-site-play-track]");
    if (playButton) {
      event.preventDefault();
      playNow(trackFromControl(playButton));
      return;
    }
    const playLink = event.target.closest("a[data-site-play-track]");
    if (!playLink || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    playNow(trackFromControl(playLink));
  });

  function applyTrack(track, options = {}) {
    return playTrack(track, options);
  }

  window.SitePlayer = {
    play: applyTrack,
    playNow,
    enqueue,
    playPlaylist,
    setStatus(message, options = {}) { setPlayerStatus(message, options); },
    setLibrary(tracks) {
      const prior = libraryById;
      library = Array.isArray(tracks) ? tracks.map((track) => {
        if (!track || typeof track.id !== "string" || !track.id) return null;
        const known = prior.get(track.id);
        return {
          ...(known || {}),
          ...track,
          title: String(track.title || known?.title || track.id),
          game: String(track.game || known?.game || ""),
          console: String(track.console || known?.console || ""),
          durationSeconds: Number(known?.durationSeconds ?? track.durationSeconds ?? 0),
        };
      }).filter(Boolean) : [];
      libraryById = new Map(library.map((track) => [track.id, track]));
      if (currentTrack) {
        currentTrack = normalizeTrack(currentTrack);
        queue = queue.map((track) => normalizeTrack(track)).filter(Boolean);
        playlistHistory = playlistHistory.map((track) => normalizeTrack(track)).filter(Boolean);
        renderCurrentTrack(currentTrack);
        syncMediaSession();
        savePlayback(true);
      }
      updateControls();
    },
    setLibraryNavigator(provider) { libraryNavigator = typeof provider === "function" ? provider : null; updateControls(); },
    getDuration(track) { return effectiveDuration(track); },
    getCurrentTrack() { return currentTrack; },
    isPlaying() { return Boolean(currentTrack && !audio.paused && !audio.ended && !audio.error); },
    getQueue() { return [...queue]; },
  };
  window.SitePlayer.setLibraryNavigator(async (track, step) => {
    const url = new URL(dock.dataset.navigationUrl, window.location.href);
    url.searchParams.set("trackId", track.id);
    url.searchParams.set("step", String(step));
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error(`Track navigation returned ${response.status}.`);
    const payload = await response.json();
    return payload.track && typeof payload.track.id === "string" ? payload.track : null;
  });
  renderQueue();
  setPlayerStatus("");
  updateControls();
  restorePlayback();
})();
