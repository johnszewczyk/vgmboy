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
  const equalizerModeButtons = [...document.querySelectorAll("[data-equalizer-mode]")];
  const equalizerMobileProfileButtons = [...document.querySelectorAll("[data-equalizer-mobile-profile]")];
  const equalizerMobileSaveButton = document.querySelector("[data-equalizer-mobile-save]");
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
    const raw = String(value).trim();
    const match = raw.match(/^(\d{1,7})\s*\/\s*(\d{1,7})$/);
    if (match) {
      const numerator = Number(match[1]);
      const denominator = Number(match[2]);
      if (!Number.isSafeInteger(numerator) || !Number.isSafeInteger(denominator) || numerator < 1 || denominator < 1) return null;
      const ticks = (numerator * 64) / denominator;
      if (!Number.isInteger(ticks) || ticks < 32 || ticks > 128) return null;
      const divisor = (left, right) => (right ? divisor(right, left % right) : left);
      const common = divisor(numerator, denominator);
      return { rate: numerator / denominator, fraction: `${numerator / common}/${denominator / common}` };
    }
    const asNum = Number(raw.replace(/[x×]$/, ""));
    if (Number.isFinite(asNum) && asNum >= 0.5 && asNum <= 2) {
      const ticks = Math.max(32, Math.min(128, Math.round(asNum * 64)));
      const divisor = (left, right) => (right ? divisor(right, left % right) : left);
      const common = divisor(ticks, 64);
      const num = ticks / common;
      const den = 64 / common;
      return { rate: num / den, fraction: `${num}/${den}` };
    }
    return null;
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
  let selectedEqualizerPresetIndex = 0;
  let audioContext = null;
  let equalizerSource = null;
  let equalizerFilters = [];
  let equalizerOutput = null;
  let transportFadeOutput = null;
  let transportFadeEnvelope = { startGain: 1, targetGain: 1, startTime: 0, endTime: 0 };
  let equalizerGraphReady = false;
  let equalizerGraphFailed = false;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  let supportsAudioVolume = null;
  function testAudioVolumeSupport() {
    if (supportsAudioVolume !== null) return supportsAudioVolume;
    try {
      if (typeof document === "undefined") {
        supportsAudioVolume = true;
        return true;
      }
      const t = document.createElement("audio");
      t.volume = 0.5;
      supportsAudioVolume = Math.abs(t.volume - 0.5) < 0.05;
    } catch {
      supportsAudioVolume = false;
    }
    return supportsAudioVolume;
  }
  function applyVolumeStep() {
    const percent = volumeStep * 5;
    if (volumeInput) {
      volumeInput.value = String(volumeStep);
      volumeInput.closest(".spcboy-equalizer-slider")?.style.setProperty("--range-percent", `${percent}%`);
      volumeInput.setAttribute("aria-valuetext", `${percent} percent`);
    }
    if (volumeValue) {
      volumeValue.value = String(percent);
      volumeValue.textContent = `${percent}%`;
    }
    try {
      if (audio) audio.volume = Math.max(0, Math.min(1, volumeStep / 20));
    } catch {}
  }
  function syncVolumeControls() {
    applyVolumeStep();
    const mobileVol = document.querySelector("#spcboy-mobile-volume");
    if (mobileVol) mobileVol.value = String(volumeStep);
    const mobileVal = document.querySelector("#spcboy-mobile-volume-value");
    if (mobileVal) mobileVal.textContent = `${volumeStep * 5}%`;
    const sbonlineVol = document.querySelector("#sbonline-volume-input");
    if (sbonlineVol) sbonlineVol.value = String(volumeStep);
    const sbonlineVal = document.querySelector("#sbonline-volume-value");
    if (sbonlineVal) sbonlineVal.textContent = String(volumeStep * 5);
    window.dispatchEvent(new CustomEvent("siteplayer:settings-changed"));
  }
  function formatEqualizerGain(value) {
    const rounded = Math.round(value * 2) / 2;
    return `${rounded > 0 ? "+" : ""}${rounded.toFixed(1)}`;
  }
  function updateEqualizerToggle(enabled) {
    if (!equalizerToggle) return;
    equalizerToggle.setAttribute("aria-checked", String(enabled));
    const desktopLabel = equalizerToggle.querySelector(".spcboy-equalizer-toggle-desktop");
    const mobileLabel = equalizerToggle.querySelector(".spcboy-equalizer-toggle-mobile");
    if (desktopLabel) desktopLabel.textContent = enabled ? "Yes" : "No";
    if (mobileLabel) mobileLabel.textContent = `Equalizer ${enabled ? "ON" : "OFF"}`;
    equalizerToggle.classList.toggle("is-enabled", enabled);
    if (typeof syncEqualizerPresetControls === "function") syncEqualizerPresetControls();
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
  }
  function syncEqualizerPresetControls() {
    equalizerPresetApplyButtons.forEach((button) => {
      const index = Number(button.dataset.equalizerPresetApply);
      const saved = Boolean(equalizerPresets[index]);
      button.disabled = !saved;
      button.setAttribute("aria-label", `${button.textContent.trim()}${saved ? ", saved" : ", empty"}`);
      const state = document.querySelector(`[data-equalizer-preset-state="${index}"]`);
      if (state) state.textContent = saved ? "Saved" : "Empty";
    });
    equalizerPresetSaveButtons.forEach((button) => { button.disabled = false; });
    equalizerModeButtons.forEach((button) => {
      const mode = button.dataset.equalizerMode;
      const isOff = mode === "off";
      const isActive = isOff ? !equalizerEnabled : (equalizerEnabled && Number(mode) === selectedEqualizerPresetIndex);
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-pressed", String(isActive));
      button.disabled = false;
    });
    equalizerMobileProfileButtons.forEach((button) => {
      const index = Number(button.dataset.equalizerMobileProfile);
      const saved = Boolean(equalizerPresets[index]);
      const selected = equalizerEnabled && index === selectedEqualizerPresetIndex;
      button.classList.toggle("is-selected", selected);
      button.setAttribute("aria-pressed", String(selected));
      button.setAttribute("aria-label", `Preset ${index + 1}, ${saved ? "saved" : "empty"}${selected ? ", active" : ""}`);
      const state = document.querySelector(`[data-equalizer-mobile-state="${index}"]`);
      if (state) state.textContent = saved ? "Saved" : "Empty";
    });
    if (equalizerMobileSaveButton) {
      equalizerMobileSaveButton.disabled = false;
      equalizerMobileSaveButton.textContent = `Save to Preset ${selectedEqualizerPresetIndex + 1}`;
    }
  }
  function supportsClientAudioGraph() {
    if (!AudioContextClass || equalizerGraphFailed) return false;
    if (typeof window !== "undefined") {
      if (!window.MediaSource && Boolean(window.ManagedMediaSource)) return false;
      if (typeof navigator !== "undefined" && (/iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1))) {
        return false;
      }
    }
    if (typeof document !== "undefined" && typeof testAudioVolumeSupport === "function" && !testAudioVolumeSupport()) {
      return false;
    }
    return true;
  }
  function updateEqualizerGraph() {
    if (!equalizerGraphReady) return;
    const immediate = arguments[0]?.immediate === true;
    const smoothing = immediate ? 0.001 : 0.035;
    const now = audioContext.currentTime;
    const activeGains = equalizerEnabled ? equalizerBandGains : equalizerBandGains.map(() => 0);
    activeGains.forEach((gain, index) => {
      const parameter = equalizerFilters[index]?.gain;
      if (!parameter) return;
      parameter.cancelScheduledValues?.(now);
      parameter.setTargetAtTime(gain, now, smoothing);
    });
    // Baseline output level is unattenuated; live Web Audio EQ keeps playback continuous.
    equalizerOutput.gain.cancelScheduledValues?.(now);
    equalizerOutput.gain.setTargetAtTime(volumeStep / 20, now, smoothing);
  }
  function ensureEqualizerGraph() {
    if (equalizerGraphReady) return true;
    const clientGraphAllowed = typeof supportsClientAudioGraph === "function"
      ? supportsClientAudioGraph()
      : Boolean(AudioContextClass && !equalizerGraphFailed);
    if (equalizerGraphFailed || !clientGraphAllowed) return false;
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
      updateEqualizerGraph({ immediate: true });
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
    const clientVolume = typeof supportsClientAudioGraph === "function"
      ? supportsClientAudioGraph()
      : Boolean(AudioContextClass && !equalizerGraphFailed);
    if (clientVolume && (equalizerEnabled || clientVolume) && !ensureEqualizerGraph()) {
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
      // Do not block audio.play() on resume() in WebKit when async chains lose user activation.
      if (audioContext && audioContext.state !== "running") {
        const resumeResult = audioContext.resume();
        if (resumeResult && typeof resumeResult.catch === "function") resumeResult.catch(() => {});
      }
      await audio.play();
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
    if (equalizerEnabled && typeof ensureEqualizerGraph === "function") ensureEqualizerGraph();
    updateEqualizerGraph();
    window.dispatchEvent(new CustomEvent("siteplayer:settings-changed", { detail: { equalizerBandGains } }));
  }
  async function setEqualizerEnabled(enabled) {
    equalizerEnabled = Boolean(enabled);
    updateEqualizerToggle(equalizerEnabled);
    storage.set("equalizerEnabled", equalizerEnabled);
    if (equalizerError) equalizerError.textContent = "";
    const graphReady = ensureEqualizerGraph();
    updateEqualizerGraph();
    syncEqualizerControls();
    syncOnlineControls();
    if (graphReady) {
      if (audioContext && audioContext.state !== "running") {
        audioContext.resume().catch(() => {});
      }
    } else if (currentTrack) {
      // Legacy fallback when Web Audio graph cannot be initialized.
      restartCurrentStream(sourcePositionSeconds());
    }
    window.dispatchEvent(new CustomEvent("siteplayer:settings-changed", { detail: { equalizerEnabled } }));
    return true;
  }
  function updateLongPlayToggle() {
    if (!longPlayToggle) return;
    const duration = longPlaySeconds === 0 ? "Unlimited" : formatPlaybackTime(longPlaySeconds);
    longPlayToggle.setAttribute("aria-checked", String(longPlayEnabled));
    longPlayToggle.setAttribute("aria-label", `Long Play · ${longPlayEnabled ? "Yes" : "No"} · ${duration}`);
    longPlayToggle.title = `Long Play · ${duration}`;
    longPlayToggle.classList.toggle("is-enabled", longPlayEnabled);
    longPlayToggle.textContent = longPlayEnabled ? "Yes" : "No";
    if (longPlayDurationInput) longPlayDurationInput.value = formatPlaybackTime(longPlaySeconds);
  }
  function updateBooleanSettingsToggle(toggle, enabled, label) {
    if (!toggle) return;
    toggle.setAttribute("aria-checked", String(enabled));
    toggle.setAttribute("aria-label", `${label} · ${enabled ? "Yes" : "No"}`);
    toggle.title = `${label} · ${enabled ? "Yes" : "No"}`;
    toggle.classList.toggle("is-enabled", enabled);
    toggle.textContent = enabled ? "Yes" : "No";
  }
  function updateFadedSkipToggle() {
    updateBooleanSettingsToggle(fadedSkipToggle, fadedSkipsEnabled, "Faded Skip");
    if (!supportsClientAudioGraph()) {
      fadedSkipToggle.disabled = true;
      fadedSkipToggle.title = "Faded Skip requires working browser audio processing.";
    }
  }
  function updateSpeedEnabledToggle() {
    updateBooleanSettingsToggle(speedEnabledToggle, playbackSpeedEnabled, "Slow Play");
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
  let eqRestartTimer = null;
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
    const usesClientAudioGraph = typeof supportsClientAudioGraph === "function"
      ? supportsClientAudioGraph()
      : Boolean(AudioContextClass && !equalizerGraphFailed);
    if (!usesClientAudioGraph && equalizerEnabled && equalizerBandGains.some((g) => g !== 0)) {
      params.set("eq", equalizerBandGains.map((g) => (Math.round(g * 2) / 2).toFixed(1)).join(","));
    }
    if (volumeStep < 20 && !usesClientAudioGraph) params.set("volume", String(volumeStep));
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
      ? queue.length > 0 || playlistHistory.length > 0
      : Boolean(libraryNavigator) || library.length > 1;
    const canGoBack = Boolean(currentTrack);
    previousButton.disabled = playbackExpired || !currentTrack || libraryNavigationPending;
    nextButton.disabled = playbackExpired || (!canNavigate && !currentTrack) || libraryNavigationPending;
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
  function seekToTrackOffset(seconds) {
    if (!currentTrack || playbackSessionExpired()) return;
    const duration = effectiveDuration();
    const offset = Math.max(0, Math.min(seconds, Number.isFinite(duration) ? Math.max(0, duration - .1) : seconds));
    if (!Number.isFinite(offset)) return;
    const resume = playbackWanted;
    cancelStreamRecovery(true);
    streamOffsetSeconds = offset;
    setAudioSource(audioURL(currentTrack, offset));
    if (resume) startAudioPlayback();
    syncMediaPosition();
    savePlayback();
  }
  if (navigator.mediaSession) {
    const actions = {
      play: () => startAudioPlayback(), pause: () => pausePlayback(),
      previoustrack: () => moveTrack(-1), nexttrack: () => moveTrack(1),
      seekto: event => seekToTrackOffset(event.seekTime),
      seekbackward: event => seekToTrackOffset(sourcePositionSeconds() - (event.seekOffset || 10)),
      seekforward: event => seekToTrackOffset(sourcePositionSeconds() + (event.seekOffset || 10)),
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
        const label = `Slow Play ${playbackRateFraction}× ${active ? "enabled" : "disabled"}`;
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
    clearFadedSkip({ restoreOutput: true });
    restoreTransportFade();
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
    let startIndex = 0;
    if (options.startTrackId) {
      const idx = playlist.findIndex((track) => track.id === options.startTrackId);
      if (idx >= 0) {
        startIndex = idx;
      } else {
        const targetTrack = normalizeTrack(options.startTrack) || normalizeTrack(libraryById.get(options.startTrackId));
        if (!targetTrack) return false;
        playlist.splice(0, playlist.length, targetTrack);
        startIndex = 0;
      }
    } else if (Number.isInteger(options.startIndex) && options.startIndex >= 0 && options.startIndex < playlist.length) {
      startIndex = options.startIndex;
    }
    const first = playlist[startIndex];
    if (!first) return false;
    queue = playlist.slice(startIndex + 1);
    playlistHistory = playlist.slice(0, startIndex);
    nowPlayingPlaylist = true;
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
      restoreTransportFade();
    }
  }

  async function moveTrack(step, { completeQueuedTarget = false } = {}) {
    if (queuedSkipRequest) {
      const request = queuedSkipRequest;
      clearFadedSkip({ restoreOutput: false });
      return finishFadedSkip(request, completeQueuedTarget ? { declick: true } : { declick: true, step });
    }
    return moveTrackNow(step);
  }

  async function moveTrackNow(step, { bypassFadedSkip = false, alreadyRecordedPlaybackId = null } = {}) {
    if (playbackSessionExpired() || !currentTrack) return;
    if (step < 0) {
      if (sourcePositionSeconds() > 2.5) {
        seekToTrackOffset(0);
        return;
      }
      if (nowPlayingPlaylist) {
        if (playlistHistory.length) {
          const previous = playlistHistory.pop();
          if (currentTrack) queue.unshift(currentTrack);
          renderQueue();
          updateControls();
          await playTrack(previous, { toggle: false, bypassFadedSkip });
          return;
        }
        if (queue.length) {
          const last = queue.pop();
          if (currentTrack) queue.unshift(currentTrack);
          renderQueue();
          updateControls();
          await playTrack(last, { toggle: false, bypassFadedSkip });
          return;
        }
        seekToTrackOffset(0);
        return;
      }
      if (libraryNavigator) {
        if (libraryNavigationPending) return;
        libraryNavigationPending = true;
        setPlayerStatus("Preparing previous track…", { busy: true });
        updateControls();
        try {
          const prev = await libraryNavigator(currentTrack, -1);
          if (prev) await playTrack(prev, { toggle: false, bypassFadedSkip });
          else seekToTrackOffset(0);
        } catch {
          seekToTrackOffset(0);
        } finally {
          libraryNavigationPending = false;
          updateControls();
        }
        return;
      }
      if (library.length > 1) {
        const index = library.findIndex((track) => track.id === currentTrack.id);
        const prev = index < 0 ? library.length - 1 : (index - 1 + library.length) % library.length;
        await playTrack(library[prev], { bypassFadedSkip });
        return;
      }
      seekToTrackOffset(0);
      return;
    }
    // step > 0 (NEXT)
    if (nowPlayingPlaylist) {
      if (queue.length) {
        await playNextFromQueue({ bypassFadedSkip, alreadyRecordedPlaybackId });
        return;
      }
      if (playlistHistory.length) {
        const allTracks = [...playlistHistory, currentTrack];
        playlistHistory = [];
        const first = allTracks[0];
        queue = allTracks.slice(1);
        renderQueue();
        updateControls();
        await playTrack(first, { toggle: false, bypassFadedSkip });
        return;
      }
      seekToTrackOffset(0);
      return;
    }
    if (queue.length) {
      await playNextFromQueue({ bypassFadedSkip, alreadyRecordedPlaybackId });
      return;
    }
    if (libraryNavigator) {
      if (libraryNavigationPending) return;
      libraryNavigationPending = true;
      setPlayerStatus("Preparing next track…", { busy: true });
      updateControls();
      try {
        const next = await libraryNavigator(currentTrack, 1);
        if (next) await playTrack(next, { toggle: false, bypassFadedSkip });
        else seekToTrackOffset(0);
      } catch {
        seekToTrackOffset(0);
      } finally {
        libraryNavigationPending = false;
        updateControls();
      }
      return;
    }
    if (library.length > 1) {
      const index = library.findIndex((track) => track.id === currentTrack.id);
      const next = index < 0 ? 0 : (index + 1) % library.length;
      await playTrack(library[next], { bypassFadedSkip });
      return;
    }
    seekToTrackOffset(0);
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
    speedInput.title = "Slow Play speed as a fraction. Use 1/64 increments from 1/2 to 2.";
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
    "#spcboy-faded-skip", "#spcboy-equalizer-enabled", "[data-equalizer-mode]", "[data-equalizer-band]",
    "[data-equalizer-preset-apply]", "[data-equalizer-mobile-profile]", "#spcboy-equalizer-reset",
    "[data-equalizer-mobile-save]", "#site-player-volume",
    ".spcboy-track", ".spcboy-media-card", "[data-site-play-track]", "[data-site-play-album-url]",
    "#spcboy-mobile-play", "#spcboy-mobile-next", "#spcboy-mobile-previous",
    "#spcboy-mobile-dock-play", ".spcboy-mobile-dock", "#spcboy-mobile-equalizer",
    "#spcboy-mobile-volume", "#spcboy-mobile-reset-flat", "[data-mobile-eq-band]",
    "[data-mobile-eq-mode]", "#spcboy-mobile-save-preset", "#spcboy-mobile-shuffle-favs",
    "#spcboy-mobile-detail-play", ".spcboy-mobile-track", ".spcboy-mobile-track-row",
    ".spcboy-mobile-detail-track-row", ".spcboy-mobile-album-card",
  ].join(",");
  function prepareAudioGraphFromGesture(event) {
    if (!supportsClientAudioGraph()) return;
    const target = event.target instanceof Element ? event.target : event.target?.parentElement;
    const matchesGesture = Boolean(target?.closest(audioProcessingGestureSelector));
    if (!equalizerEnabled && !fadedSkipsEnabled && !matchesGesture) return;
    if (!ensureEqualizerGraph() || audioContext.state === "running") return;
    try { audioContext.resume().catch(() => {}); } catch { /* The next playback gesture can retry the suspended context. */ }
  }
  document.addEventListener("pointerdown", prepareAudioGraphFromGesture, true);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") prepareAudioGraphFromGesture(event);
  }, true);
  let equalizerFaderAnimationId = null;
  function cancelEqualizerFaderAnimation() {
    if (equalizerFaderAnimationId !== null) {
      cancelAnimationFrame(equalizerFaderAnimationId);
      equalizerFaderAnimationId = null;
    }
  }
  function animateEqualizerBandSliders(targetGains, onComplete) {
    cancelEqualizerFaderAnimation();
    const duration = window.SBInterface?.duration?.() ?? 200;
    if (!equalizerBandInputs.length || duration <= 0) {
      if (typeof onComplete === "function") onComplete();
      return;
    }
    const startGains = equalizerBandInputs.map((input) => Number(input.value) || 0);
    const startTime = performance.now();
    const step = (now) => {
      const progress = Math.min(1, (now - startTime) / duration);
      const eased = 1 - Math.pow(1 - progress, 3);
      equalizerBandInputs.forEach((input, index) => {
        const start = startGains[index];
        const target = targetGains[index] ?? 0;
        const current = start + (target - start) * eased;
        input.value = current.toFixed(1);
        const output = document.querySelector(`[data-equalizer-value="${index}"]`);
        if (output) output.textContent = formatEqualizerGain(current);
      });
      if (progress < 1) {
        equalizerFaderAnimationId = requestAnimationFrame(step);
      } else {
        equalizerFaderAnimationId = null;
        if (typeof onComplete === "function") onComplete();
      }
    };
    equalizerFaderAnimationId = requestAnimationFrame(step);
  }
  equalizerToggle.addEventListener("click", () => setEqualizerEnabled(equalizerToggle.getAttribute("aria-checked") !== "true"));
  equalizerModeButtons.filter((button) => button.dataset.equalizerMode === "off").forEach((button) => {
    button.addEventListener("click", async () => {
      cancelEqualizerFaderAnimation();
      await setEqualizerEnabled(false);
      if (equalizerPresetStatus) equalizerPresetStatus.textContent = "Equalizer OFF.";
    });
  });
  equalizerBandInputs.forEach((input) => {
    input.addEventListener("input", () => {
      cancelEqualizerFaderAnimation();
      const index = Number(input.dataset.equalizerBand);
      if (!Number.isInteger(index) || index < 0 || index >= equalizerBandGains.length) return;
      equalizerBandGains[index] = Math.max(-12, Math.min(12, Math.round(Number(input.value) * 2) / 2));
      const wasDisabled = !equalizerEnabled;
      if (!equalizerEnabled) setEqualizerEnabled(true);
      const graphReady = ensureEqualizerGraph();
      if (equalizerEnabled && graphReady && audioContext?.state !== "running") {
        audioContext?.resume().catch(() => {});
      }
      saveEqualizerGains();
      if (!graphReady && equalizerEnabled && !wasDisabled && currentTrack) {
        window.clearTimeout(eqRestartTimer);
        eqRestartTimer = window.setTimeout(() => restartCurrentStream(sourcePositionSeconds()), 250);
      }
    });
  });
  equalizerResetButton.addEventListener("click", () => {
    const flatGains = equalizerBandGains.map(() => 0);
    animateEqualizerBandSliders(flatGains, () => {
      equalizerBandGains = flatGains;
      const graphReady = ensureEqualizerGraph();
      if (equalizerEnabled && graphReady && audioContext?.state !== "running") {
        audioContext?.resume().catch(() => {});
      }
      saveEqualizerGains();
      if (equalizerPresetStatus) equalizerPresetStatus.textContent = "Equalizer reset to Flat.";
      if (!graphReady && equalizerEnabled && currentTrack) {
        restartCurrentStream(sourcePositionSeconds());
      }
    });
  });
  async function applyEqualizerPreset(index) {
    if (!Number.isInteger(index) || index < 0 || index >= equalizerPresets.length) return;
    if (typeof selectedEqualizerPresetIndex !== "undefined") selectedEqualizerPresetIndex = index;
    const preset = equalizerPresets[index];
    equalizerBandGains = preset?.gains ? [...preset.gains] : equalizerFrequencies.map(() => 0);
    const wasEnabled = equalizerEnabled;
    saveEqualizerGains();
    const enabled = wasEnabled ? true : await setEqualizerEnabled(true);
    if (wasEnabled && !(typeof ensureEqualizerGraph === "function" && ensureEqualizerGraph()) && typeof currentTrack !== "undefined" && currentTrack && typeof restartCurrentStream === "function") {
      if (typeof window !== "undefined") window.clearTimeout?.(typeof eqRestartTimer !== "undefined" ? eqRestartTimer : 0);
      restartCurrentStream(sourcePositionSeconds());
    }
    syncEqualizerPresetControls();
    if (equalizerPresetStatus) {
      equalizerPresetStatus.textContent = enabled
        ? (preset?.gains ? `${preset?.name || `Preset ${index + 1}`} applied.` : `Preset ${index + 1} (Flat) active.`)
        : `${preset?.name || `Preset ${index + 1}`} loaded, but audio processing could not be enabled.`;
    }
    if (typeof window !== "undefined" && typeof window.dispatchEvent === "function") {
      window.dispatchEvent(new CustomEvent("siteplayer:settings-changed"));
    }
  }
  function saveEqualizerPreset(index) {
    if (!Number.isInteger(index) || index < 0 || index >= equalizerPresets.length) return;
    equalizerPresets[index] = { name: `Preset ${index + 1}`, gains: [...equalizerBandGains] };
    storage.set("equalizerPresets", equalizerPresets);
    syncEqualizerPresetControls();
    if (equalizerPresetStatus) {
      equalizerPresetStatus.textContent = `Preset ${index + 1} saved.`;
    }
    if (typeof window !== "undefined" && typeof window.dispatchEvent === "function") {
      window.dispatchEvent(new CustomEvent("siteplayer:settings-changed"));
    }
  }
  equalizerPresetApplyButtons.forEach((button) => {
    button.addEventListener("click", () => applyEqualizerPreset(Number(button.dataset.equalizerPresetApply)));
  });
  equalizerPresetSaveButtons.forEach((button) => {
    button.addEventListener("click", () => saveEqualizerPreset(Number(button.dataset.equalizerPresetSave)));
  });
  if (typeof equalizerMobileProfileButtons !== "undefined" && Array.isArray(equalizerMobileProfileButtons)) {
    equalizerMobileProfileButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const index = Number(button.dataset.equalizerMobileProfile);
        if (!Number.isInteger(index) || index < 0 || index >= equalizerPresets.length) return;
        selectedEqualizerPresetIndex = index;
        const preset = equalizerPresets[index];
        const targetGains = preset?.gains ? [...preset.gains] : equalizerFrequencies.map(() => 0);
        if (typeof animateEqualizerBandSliders === "function") {
          animateEqualizerBandSliders(targetGains, () => applyEqualizerPreset(index));
        } else {
          applyEqualizerPreset(index);
        }
      });
    });
  }
  if (typeof equalizerMobileSaveButton !== "undefined" && equalizerMobileSaveButton) {
    equalizerMobileSaveButton.addEventListener("click", () => saveEqualizerPreset(selectedEqualizerPresetIndex));
  }
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
    if (typeof syncVolumeControls === "function") syncVolumeControls();
    window.clearTimeout(volumeRestartTimer);
    if (ensureEqualizerGraph()) {
      updateEqualizerGraph();
      if (audioContext && audioContext.state !== "running") {
        audioContext.resume().catch(() => { setPlayerStatus("Press Play to resume audio processing."); });
      }
    } else if (currentTrack) {
      // Legacy browsers without Web Audio retain the server-volume fallback.
      volumeRestartTimer = window.setTimeout(() => restartCurrentStream(sourcePositionSeconds()), 350);
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
    const streamEndedCleanly = typeof aacTransport !== "undefined" && Boolean(aacTransport?.streamEnded);
    if (!streamEndedCleanly && expectedDuration > 0 && sourcePositionSeconds() < expectedDuration - 1) {
      const quotaReached = await hasReachedStreamQuota();
      if (source !== audio.src || !audio.ended) return;
      if (quotaReached) showStreamQuotaMessage();
      else recoverStream();
      updateControls();
      return;
    }
    moveTrack(1, { completeQueuedTarget: true });
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
    togglePlayback() { playButton.click(); },
    previous() { return moveTrack(-1); },
    next() { return moveTrack(1); },
    seekTo(seconds) { seekToTrackOffset(Number(seconds) || 0); },
    getVolume() { return volumeStep; },
    setVolume(step) {
      const num = Math.max(0, Math.min(20, Math.round(Number(step) || 0)));
      volumeStep = num;
      storage.set("volumeStep", volumeStep);
      if (volumeInput) volumeInput.value = String(num);
      applyVolumeStep();
      syncVolumeControls();
      window.clearTimeout(volumeRestartTimer);
      if (ensureEqualizerGraph()) {
        updateEqualizerGraph();
        if (audioContext && audioContext.state !== "running") {
          audioContext.resume().catch(() => {});
        }
      } else if (currentTrack) {
        volumeRestartTimer = window.setTimeout(() => restartCurrentStream(sourcePositionSeconds()), 350);
      }
    },
    getEqualizerPresets() {
      return equalizerPresets.map((preset, index) => ({
        index,
        name: preset?.name || `Preset ${index + 1}`,
        gains: Array.isArray(preset?.gains) ? [...preset.gains] : equalizerFrequencies.map(() => 0),
        saved: Boolean(preset?.gains),
      }));
    },
    applyEqualizerPreset(index) {
      return applyEqualizerPreset(Number(index) || 0);
    },
    saveEqualizerPreset(index) {
      return saveEqualizerPreset(Number(index) || 0);
    },
    getSelectedEqualizerPresetIndex() {
      return selectedEqualizerPresetIndex;
    },
    isEqualizerEnabled() { return equalizerEnabled; },
    setEqualizerEnabled(enabled) { return setEqualizerEnabled(Boolean(enabled)); },
    getEqualizerBands() { return [...equalizerBandGains]; },
    getEqualizerFrequencies() { return [...equalizerFrequencies]; },
    setEqualizerBandGain(index, gain) {
      if (!Number.isInteger(index) || index < 0 || index >= equalizerBandGains.length) return;
      const rounded = Math.max(-12, Math.min(12, Math.round(Number(gain) * 2) / 2));
      equalizerBandGains[index] = rounded;
      if (equalizerBandInputs[index]) equalizerBandInputs[index].value = String(rounded);
      const graphReady = ensureEqualizerGraph();
      if (equalizerEnabled && graphReady && audioContext && audioContext.state !== "running") {
        audioContext.resume().catch(() => {});
      }
      saveEqualizerGains();
      if (!graphReady && equalizerEnabled && currentTrack) {
        window.clearTimeout(eqRestartTimer);
        eqRestartTimer = window.setTimeout(() => {
          restartCurrentStream(sourcePositionSeconds());
        }, 250);
      }
    },
    resetEqualizer() {
      equalizerBandGains = equalizerFrequencies.map(() => 0);
      equalizerBandInputs.forEach(input => { input.value = "0"; });
      const graphReady = ensureEqualizerGraph();
      saveEqualizerGains();
      if (!graphReady && equalizerEnabled && currentTrack) {
        restartCurrentStream(sourcePositionSeconds());
      }
    },
    getFadedSkips() { return { enabled: fadedSkipsEnabled, seconds: spcFadeSeconds }; },
    setFadedSkips(enabled, seconds) {
      let changed = false;
      if (typeof enabled === "boolean" && enabled !== fadedSkipsEnabled) {
        fadedSkipsEnabled = enabled;
        storage.set("fadedSkipsEnabled", enabled);
        if (!fadedSkipsEnabled) clearFadedSkip();
        updateFadedSkipToggle();
        changed = true;
      }
      if (typeof seconds === "number" || typeof seconds === "string") {
        const num = Math.max(0, Math.min(30, Math.round(Number(seconds) || 0)));
        if (num !== spcFadeSeconds) {
          spcFadeSeconds = num;
          if (spcFadeSecondsInput) spcFadeSecondsInput.value = String(spcFadeSeconds);
          storage.set("spcFadeSeconds", spcFadeSeconds);
          changed = true;
        }
      }
      if (changed) {
        window.dispatchEvent(new CustomEvent("siteplayer:settings-changed", { detail: { fadedSkipsEnabled, spcFadeSeconds } }));
      }
    },
    getPlaybackSpeed() { return { enabled: playbackSpeedEnabled, fraction: playbackRateFraction, rate: playbackRate }; },
    setPlaybackSpeed(enabled, fraction) {
      let changed = false;
      let rateChanged = false;
      if (typeof enabled === "boolean" && enabled !== playbackSpeedEnabled) {
        playbackSpeedEnabled = enabled;
        storage.set("playbackSpeedEnabled", enabled);
        updateSpeedEnabledToggle();
        changed = true;
      }
      if (typeof fraction === "string" && fraction.trim()) {
        const parsed = parseSpeedFraction(fraction);
        if (parsed && (parsed.rate !== playbackRate || parsed.fraction !== playbackRateFraction)) {
          playbackRateFraction = parsed.fraction;
          playbackRate = parsed.rate;
          if (speedInput) speedInput.value = parsed.fraction;
          storage.set("playbackRateFraction", parsed.fraction);
          storage.set("playbackRate", parsed.rate);
          changed = true;
          rateChanged = true;
        }
      }
      if (changed) {
        if (currentTrack) {
          restartCurrentStream(sourcePositionSeconds());
        }
        syncOnlineControls();
        window.dispatchEvent(new CustomEvent("siteplayer:settings-changed", { detail: { playbackSpeedEnabled, playbackRateFraction } }));
      }
    },
    getLongPlay() { return { enabled: longPlayEnabled, seconds: longPlaySeconds }; },
    setLongPlay(enabled, seconds) {
      let changed = false;
      if (typeof enabled === "boolean" && enabled !== longPlayEnabled) {
        longPlayEnabled = enabled;
        storage.set("longPlayEnabled", enabled);
        updateLongPlayToggle();
        changed = true;
      }
      if (typeof seconds === "string" && seconds.trim()) {
        const parsed = parseLongPlayDuration(seconds);
        if (parsed !== null) seconds = parsed;
      }
      if (Number.isInteger(seconds) && seconds !== longPlaySeconds) {
        longPlaySeconds = Math.max(0, Math.min(maximumLongPlaySeconds, seconds));
        if (longPlayDurationInput) longPlayDurationInput.value = formatPlaybackTime(longPlaySeconds);
        storage.set("longPlayDurationSeconds", longPlaySeconds);
        changed = true;
      }
      if (changed) {
        if (currentTrack) {
          restartCurrentStream(sourcePositionSeconds());
        }
        syncOnlineControls();
        window.dispatchEvent(new CustomEvent("siteplayer:settings-changed", { detail: { longPlayEnabled, longPlaySeconds } }));
      }
    },
    formatPlaybackTime,
    parseLongPlayDuration,
    parseSpeedFraction,
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
