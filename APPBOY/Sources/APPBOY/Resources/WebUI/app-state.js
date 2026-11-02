(() => {
  const THEME_PRESETS = {
    "sb2-cyan": {
      accentColor: "#38aaff",
      uiChromePrimaryColor: "#111419",
      uiChromePaneColor: "#090b0f",
      sidebarTextColor: "#b6b7dc"
    },
    "amber-crt": {
      accentColor: "#ffb443",
      uiChromePrimaryColor: "#16120d",
      uiChromePaneColor: "#0c0906",
      sidebarTextColor: "#ebd2ad"
    },
    "gb-matrix": {
      accentColor: "#8bd450",
      uiChromePrimaryColor: "#101711",
      uiChromePaneColor: "#080d09",
      sidebarTextColor: "#c5dec0"
    },
    "synth-violet": {
      accentColor: "#bb9af7",
      uiChromePrimaryColor: "#14121d",
      uiChromePaneColor: "#0a0911",
      sidebarTextColor: "#cfc8eb"
    }
  };

  function gcd(a, b) {
    let x = Math.abs(Math.trunc(a));
    let y = Math.abs(Math.trunc(b));
    while (y !== 0) {
      const r = x % y;
      x = y;
      y = r;
    }
    return x || 1;
  }

  function quantizeSpeedRate(rawRate) {
    const clamped = Math.min(2.0, Math.max(0.5, Number.isFinite(rawRate) ? rawRate : 1.25));
    const steps32 = Math.min(64, Math.max(16, Math.round(clamped * 32)));
    const divisor = gcd(steps32, 32);
    return {
      numerator: steps32 / divisor,
      denominator: 32 / divisor,
      rate: steps32 / 32
    };
  }

  function parseSpeedInput(rawText, fallbackRate = 1.25) {
    const cleaned = String(rawText ?? "").trim().replace(/[×xX]$/u, "").trim();
    if (!cleaned) return quantizeSpeedRate(fallbackRate).rate;
    if (cleaned.includes("/")) {
      const parts = cleaned.split("/");
      if (parts.length === 2) {
        const num = Number(parts[0].trim());
        const den = Number(parts[1].trim());
        if (Number.isFinite(num) && Number.isFinite(den) && den > 0) {
          return quantizeSpeedRate(num / den).rate;
        }
      }
      return quantizeSpeedRate(fallbackRate).rate;
    }
    const parsed = Number(cleaned);
    if (!Number.isFinite(parsed)) return quantizeSpeedRate(fallbackRate).rate;
    return quantizeSpeedRate(parsed).rate;
  }

  function formatSpeedRatio(rate) {
    const q = quantizeSpeedRate(Number(rate) || 1.0);
    return `${q.numerator}/${q.denominator}`;
  }

  const state = {
    mobilePane: "library",
    contentMode: "playlist",
    optionsOpen: false,
    optionsTab: "interface",
    volumePopoverOpen: false,
    searchQuery: "",
    expandedConsoleIds: new Set(),
    catalog: {
      sourceLabel: "Starter Catalog",
      databasePath: "",
      schemaVersion: 0,
      consoleCount: 0,
      albumCount: 0,
      trackCount: 0,
      artworkCount: 0,
      consoles: []
    },
    favoriteIds: new Set(),
    tabs: [],
    activeTabId: "",
    tabTracks: new Map(),
    sortColumn: null,
    sortDirection: "asc",
    selectedAlbumId: null,
    diagnostics: null,
    preferences: {
      accentColor: "#38aaff",
      uiChromePrimaryColor: "#111419",
      uiChromeSecondaryColor: "#141820",
      uiChromePaneColor: "#090b0f",
      sidebarTextColor: "#b6b7dc",
      uiChromeFontSizePt: 11,
      contentFontSizePt: 11.5,
      uiChromeMonospace: true,
      contentMonospace: true,
      selectionAnimationEnabled: true,
      selectionAnimationMilliseconds: 180,
      playlistLinkMode: true,
      sidebarTrackCounts: true,
      favoriteSortOrder: "historical",
      galleryFitMode: "crop",
      galleryFrameScale: 1.0,
      galleryGapRem: 0.35,
      galleryRadiusRem: 0.2,
      repeatMode: "off",
      equalizerEnabled: false,
      equalizerBandsDB: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      monoEnabled: false,
      fadeOutEnabled: true,
      fadeOutSeconds: 5,
      longPlayEnabled: false,
      manualPlayTimeSeconds: 180,
      playbackSpeedEnabled: false,
      playbackSpeedRate: 1.25,
      appVolume: 1.0,
      remoteCatalogURL: ""
    },
    playback: {
      generation: 0,
      trackId: null,
      trackMeta: null,
      queueTabId: null,
      transportState: "stopped",
      elapsedSeconds: 0,
      durationSeconds: 0,
      playbackRate: 1.0
    }
  };

  const refs = {
    indicator: document.getElementById("sb2-selection-indicator"),
    consoleLabel: document.getElementById("sb2-console-label"),
    albumLabel: document.getElementById("sb2-album-label"),
    searchInput: document.getElementById("sidebar-search-input"),
    viewToggleBtn: document.getElementById("sidebar-view-toggle-button"),
    galleryBtn: document.getElementById("sidebar-gallery-button"),
    recentBtn: document.getElementById("sidebar-history-button"),
    favoritesBtn: document.getElementById("sidebar-favorites-button"),
    foldToggleBtn: document.getElementById("sidebar-fold-toggle-button"),
    foldIconUse: document.getElementById("sidebar-fold-icon-use"),
    treeRoot: document.getElementById("tree-root"),
    contentPane: document.getElementById("content-pane"),
    tabsToolbar: document.getElementById("playlist-tabs-toolbar"),
    tabsContainer: document.getElementById("playlist-tabs"),
    newTabBtn: document.getElementById("new-tab-button"),
    playlistView: document.getElementById("playlist-view"),
    playlistBody: document.getElementById("playlist-body-wrap"),
    sortTitleBtn: document.getElementById("sort-title-button"),
    sortAlbumBtn: document.getElementById("sort-album-button"),
    sortTimeBtn: document.getElementById("sort-time-button"),
    galleryView: document.getElementById("gallery-view"),
    galleryGrid: document.getElementById("gallery-grid"),
    prevBtn: document.getElementById("previous-button"),
    stopBtn: document.getElementById("stop-button"),
    playBtn: document.getElementById("play-button"),
    nextBtn: document.getElementById("next-button"),
    repeatBtn: document.getElementById("repeat-button"),
    eqBtn: document.getElementById("equalizer-toolbar-button"),
    longPlayBtn: document.getElementById("long-play-button"),
    speedBtn: document.getElementById("playback-speed-button"),
    volumeWrap: document.getElementById("toolbar-volume-control"),
    volumeBtn: document.getElementById("toolbar-volume-button"),
    volumePopover: document.getElementById("toolbar-volume-popover"),
    volumeInput: document.getElementById("toolbar-volume-input"),
    volumeOutput: document.getElementById("toolbar-volume-value"),
    optionsBtn: document.getElementById("options-toolbar-button"),
    sidebarStats: document.getElementById("sidebar-stats"),
    statusStateWrap: document.getElementById("status-state-wrap"),
    statusLabel: document.getElementById("sb2-app-status-label"),
    currentTrackTitle: document.getElementById("sb2-current-track-title"),
    elapsedLabel: document.getElementById("elapsed-label"),
    songLengthLabel: document.getElementById("song-length-label"),
    playlistTotalLabel: document.getElementById("playlist-total-label"),
    errorToast: document.getElementById("playback-error-toast"),
    optionsOverlay: document.getElementById("options-overlay"),
    optionsCloseBtn: document.getElementById("options-close-button"),
    optAccentColor: document.getElementById("opt-accent-color"),
    optChromePrimary: document.getElementById("opt-chrome-primary"),
    optChromePane: document.getElementById("opt-chrome-pane"),
    optSelectionAnimEnabled: document.getElementById("opt-selection-anim-enabled"),
    optSelectionAnimMs: document.getElementById("opt-selection-anim-ms"),
    optLinkMode: document.getElementById("opt-link-mode"),
    optSidebarCounts: document.getElementById("opt-sidebar-counts"),
    optFavSort: document.getElementById("opt-fav-sort"),
    optChromeFontPt: document.getElementById("opt-chrome-font-pt"),
    optContentFontPt: document.getElementById("opt-content-font-pt"),
    optSidebarTextColor: document.getElementById("opt-sidebar-text-color"),
    optChromeMono: document.getElementById("opt-chrome-mono"),
    optContentMono: document.getElementById("opt-content-mono"),
    optGalleryFit: document.getElementById("opt-gallery-fit"),
    optGalleryScale: document.getElementById("opt-gallery-scale"),
    optGalleryScaleOut: document.getElementById("opt-gallery-scale-out"),
    optGalleryGap: document.getElementById("opt-gallery-gap"),
    optGalleryGapOut: document.getElementById("opt-gallery-gap-out"),
    optGalleryRadius: document.getElementById("opt-gallery-radius"),
    optGalleryRadiusOut: document.getElementById("opt-gallery-radius-out"),
    optEqEnabled: document.getElementById("opt-eq-enabled"),
    optEqResetBtn: document.getElementById("opt-eq-reset-button"),
    optEqBandsWrap: document.getElementById("equalizer-bands"),
    optMonoEnabled: document.getElementById("opt-mono-enabled"),
    optAppVolume: document.getElementById("opt-app-volume"),
    optAppVolumeValue: document.getElementById("opt-app-volume-value"),
    optSpeedEnabled: document.getElementById("opt-speed-enabled"),
    optSpeedRate: document.getElementById("opt-speed-rate"),
    optLongPlayEnabled: document.getElementById("opt-long-play-enabled"),
    optManualDuration: document.getElementById("opt-manual-duration"),
    optFadeEnabled: document.getElementById("opt-fade-enabled"),
    optFadeDuration: document.getElementById("opt-fade-duration"),
    optSourceLabel: document.getElementById("opt-source-label"),
    optDbSummary: document.getElementById("opt-db-summary"),
    optRemoteURL: document.getElementById("opt-remote-url"),
    optReloadCatalogBtn: document.getElementById("opt-reload-catalog-button"),
    optSourceStatus: document.getElementById("opt-source-status"),
    diagRefreshBtn: document.getElementById("diag-refresh-button"),
    diagBackend: document.getElementById("diag-backend"),
    diagTransport: document.getElementById("diag-transport"),
    diagSampleRate: document.getElementById("diag-sample-rate"),
    diagBuffers: document.getElementById("diag-buffers"),
    diagFrames: document.getElementById("diag-frames"),
    diagTempo: document.getElementById("diag-tempo"),
    diagEq: document.getElementById("diag-eq"),
    diagContainer: document.getElementById("diag-container"),
    diagPosition: document.getElementById("diag-position")
  };

  let pendingSettingsPatch = {};
  let settingsTimer = null;
  let workspaceTimer = null;
  let toastTimer = null;

  function formatTime(seconds) {
    const safe = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
    const hrs = Math.floor(safe / 3600);
    const mins = Math.floor((safe % 3600) / 60);
    const secs = safe % 60;
    if (hrs > 0) {
      return `${hrs}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
    }
    return `${mins}:${String(secs).padStart(2, "0")}`;
  }

  function parseDurationInput(rawText, minSec, maxSec, fallbackSec) {
    const text = String(rawText ?? "").trim();
    if (!text) return fallbackSec;
    let total = NaN;
    if (text.includes(":")) {
      const parts = text.split(":").map((part) => Number(part.trim()));
      if (parts.every((n) => Number.isFinite(n) && n >= 0)) {
        if (parts.length === 2) {
          total = parts[0] * 60 + parts[1];
        } else if (parts.length === 3) {
          total = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
      }
    } else {
      total = Number(text);
    }
    if (!Number.isFinite(total)) return fallbackSec;
    return Math.min(maxSec, Math.max(minSec, Math.round(total)));
  }

  function effectiveTrackDuration(track) {
    if (!track) return 0;
    if (state.preferences.longPlayEnabled) {
      return Math.max(15, Number(state.preferences.manualPlayTimeSeconds) || 180);
    }
    return Math.max(0, Number(track.durationSeconds) || 0);
  }

  function formatGainDB(gain) {
    const num = Number.isFinite(gain) ? Math.round(gain * 2) / 2 : 0;
    const sign = num > 0 ? "+" : "";
    return `${sign}${num.toFixed(1)} dB`;
  }

  function setRangeSliderPercent(inputEl, pct) {
    window.VGMRangeControls?.setPercent(inputEl, pct);
  }

  function showErrorToast(message) {
    if (!refs.errorToast) return;
    refs.errorToast.textContent = String(message || "Operation failed.");
    refs.errorToast.classList.remove("is-hidden");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      refs.errorToast.classList.add("is-hidden");
    }, 4200);
  }

  function applyPreferencesToDOM() {
    const p = state.preferences;
    const root = document.documentElement.style;
    root.setProperty("--accent", p.accentColor || "#38aaff");
    root.setProperty("--bg-chrome", p.uiChromePrimaryColor || "#111419");
    root.setProperty("--bg-pane", p.uiChromePaneColor || "#090b0f");
    root.setProperty("--text", p.sidebarTextColor || "#b6b7dc");
    root.setProperty("--ui-font-size-pt", String(p.uiChromeFontSizePt || 11));
    root.setProperty("--content-font-size-pt", String(p.contentFontSizePt || 11.5));
    root.setProperty(
      "--chrome-font-family",
      p.uiChromeMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)"
    );
    root.setProperty(
      "--content-font-family",
      p.contentMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)"
    );
    const ms = p.selectionAnimationEnabled ? Number(p.selectionAnimationMilliseconds || 0) : 0;
    root.setProperty("--selection-animation-duration", `${ms}ms`);
    document.body.dataset.sbMotion = p.selectionAnimationEnabled && ms > 0 ? "on" : "off";

    root.setProperty("--sb-gallery-scale", String(p.galleryFrameScale || 1));
    root.setProperty("--sb-gallery-gap", `${Number(p.galleryGapRem || 0)}rem`);
    root.setProperty("--sb-gallery-radius", `${Number(p.galleryRadiusRem || 0)}rem`);
    refs.galleryGrid?.classList.toggle("is-pad-to-square", p.galleryFitMode === "pad");
  }

  function syncOptionsInputsFromState() {
    const p = state.preferences;
    const c = state.catalog;
    if (refs.optAccentColor && document.activeElement !== refs.optAccentColor) refs.optAccentColor.value = p.accentColor;
    if (refs.optChromePrimary && document.activeElement !== refs.optChromePrimary) refs.optChromePrimary.value = p.uiChromePrimaryColor;
    if (refs.optChromePane && document.activeElement !== refs.optChromePane) refs.optChromePane.value = p.uiChromePaneColor;
    if (refs.optSelectionAnimEnabled) refs.optSelectionAnimEnabled.checked = Boolean(p.selectionAnimationEnabled);
    if (refs.optSelectionAnimMs && document.activeElement !== refs.optSelectionAnimMs) refs.optSelectionAnimMs.value = String(p.selectionAnimationMilliseconds);
    if (refs.optLinkMode) refs.optLinkMode.checked = Boolean(p.playlistLinkMode);
    if (refs.optSidebarCounts) refs.optSidebarCounts.checked = Boolean(p.sidebarTrackCounts);
    if (refs.optFavSort) refs.optFavSort.value = p.favoriteSortOrder || "historical";

    if (refs.optChromeFontPt && document.activeElement !== refs.optChromeFontPt) refs.optChromeFontPt.value = String(p.uiChromeFontSizePt);
    if (refs.optContentFontPt && document.activeElement !== refs.optContentFontPt) refs.optContentFontPt.value = String(p.contentFontSizePt);
    if (refs.optSidebarTextColor && document.activeElement !== refs.optSidebarTextColor) refs.optSidebarTextColor.value = p.sidebarTextColor;
    if (refs.optChromeMono) refs.optChromeMono.checked = Boolean(p.uiChromeMonospace);
    if (refs.optContentMono) refs.optContentMono.checked = Boolean(p.contentMonospace);

    if (refs.optGalleryFit) refs.optGalleryFit.value = p.galleryFitMode || "crop";
    if (refs.optGalleryScale) refs.optGalleryScale.value = String(p.galleryFrameScale);
    if (refs.optGalleryScaleOut) refs.optGalleryScaleOut.textContent = `${Number(p.galleryFrameScale).toFixed(2)}×`;
    if (refs.optGalleryGap) refs.optGalleryGap.value = String(p.galleryGapRem);
    if (refs.optGalleryGapOut) refs.optGalleryGapOut.textContent = `${Number(p.galleryGapRem).toFixed(2)}rem`;
    if (refs.optGalleryRadius) refs.optGalleryRadius.value = String(p.galleryRadiusRem);
    if (refs.optGalleryRadiusOut) refs.optGalleryRadiusOut.textContent = `${Number(p.galleryRadiusRem).toFixed(2)}rem`;

    // Audio: 10-Band Equalizer + Mono + Volume
    if (refs.optEqEnabled) refs.optEqEnabled.checked = Boolean(p.equalizerEnabled);
    refs.optEqBandsWrap?.classList.toggle("is-bypassed", !p.equalizerEnabled);
    const bands = Array.isArray(p.equalizerBandsDB) ? p.equalizerBandsDB : [];
    document.querySelectorAll("[data-equalizer-band]").forEach((input) => {
      const idx = Number(input.dataset.equalizerBand);
      const gain = Number.isFinite(bands[idx]) ? Math.min(12, Math.max(-12, Number(bands[idx]))) : 0;
      if (document.activeElement !== input) {
        input.value = String(gain);
      }
      setRangeSliderPercent(input, ((gain + 12) / 24) * 100);
      const out = document.querySelector(`[data-equalizer-value="${idx}"]`);
      if (out) out.textContent = formatGainDB(gain);
    });

    if (refs.optMonoEnabled) refs.optMonoEnabled.checked = Boolean(p.monoEnabled);
    const vol = Math.min(1, Math.max(0, Number(p.appVolume ?? 1)));
    if (refs.optAppVolume) {
      if (document.activeElement !== refs.optAppVolume) refs.optAppVolume.value = String(vol);
      setRangeSliderPercent(refs.optAppVolume, vol * 100);
    }
    if (refs.optAppVolumeValue) refs.optAppVolumeValue.textContent = `${Math.round(vol * 100)}%`;

    // Playback: Long Play + Fade Out + 1/32 Speed
    if (refs.optLongPlayEnabled) refs.optLongPlayEnabled.checked = Boolean(p.longPlayEnabled);
    if (refs.optManualDuration && document.activeElement !== refs.optManualDuration) {
      refs.optManualDuration.value = formatTime(p.manualPlayTimeSeconds);
    }
    if (refs.optFadeEnabled) refs.optFadeEnabled.checked = Boolean(p.fadeOutEnabled);
    if (refs.optFadeDuration && document.activeElement !== refs.optFadeDuration) {
      refs.optFadeDuration.value = formatTime(p.fadeOutSeconds);
    }

    if (refs.optSpeedEnabled) refs.optSpeedEnabled.checked = Boolean(p.playbackSpeedEnabled);
    if (refs.optSpeedRate && document.activeElement !== refs.optSpeedRate) {
      refs.optSpeedRate.value = formatSpeedRatio(p.playbackSpeedRate || 1.25);
    }
    document.querySelectorAll("[data-speed-preset]").forEach((btn) => {
      const presetVal = Number(btn.dataset.speedPreset);
      const active = Boolean(p.playbackSpeedEnabled) && Math.abs(presetVal - Number(p.playbackSpeedRate)) < 0.01;
      btn.classList.toggle("is-selected", active);
    });

    if (refs.optSourceLabel) refs.optSourceLabel.textContent = c.sourceLabel || "Starter Catalog";
    if (refs.optDbSummary) {
      refs.optDbSummary.textContent = `${c.albumCount || 0} games · ${c.consoleCount || 0} systems · ${c.trackCount || 0} tracks`;
    }
    if (refs.optRemoteURL && document.activeElement !== refs.optRemoteURL) {
      refs.optRemoteURL.value = p.remoteCatalogURL || "";
    }
  }

  function renderDiagnostics(diag) {
    if (diag && typeof diag === "object") {
      state.diagnostics = diag;
    }
    const d = state.diagnostics;
    if (!d) return;
    if (refs.diagBackend) refs.diagBackend.textContent = d.backendName || "Idle";
    if (refs.diagTransport) refs.diagTransport.textContent = String(d.transportState || "stopped").toUpperCase();
    if (refs.diagSampleRate) {
      refs.diagSampleRate.textContent = d.sampleRateHz ? `${d.sampleRateHz} Hz` : "—";
    }
    if (refs.diagBuffers) {
      refs.diagBuffers.textContent = d.targetBuffers
        ? `${d.queuedBuffers ?? 0} / ${d.targetBuffers} queued`
        : "—";
    }
    if (refs.diagFrames) {
      refs.diagFrames.textContent = Number.isFinite(d.framesScheduled)
        ? Number(d.framesScheduled).toLocaleString()
        : "0";
    }
    if (refs.diagTempo) refs.diagTempo.textContent = d.tempoDisplay || "1/1 (1.00×)";
    if (refs.diagEq) {
      refs.diagEq.textContent = d.equalizerEnabled
        ? `Enabled (${Number(d.headroomCompensationDB || 0).toFixed(1)} dB headroom)`
        : "Bypassed";
    }
    if (refs.diagContainer) refs.diagContainer.textContent = d.containerSummary || "—";
    if (refs.diagPosition) {
      refs.diagPosition.textContent = `${formatTime(d.positionSeconds || 0)} / ${formatTime(d.durationSeconds || 0)}`;
    }
  }

  async function refreshDiagnostics() {
    if (!window.appBoy?.audioDiagnostics) return;
    try {
      const diag = await window.appBoy.audioDiagnostics();
      renderDiagnostics(diag);
    } catch {
      // Ignore transient bridge errors
    }
  }

  function queueSettingsPatch(patch) {
    Object.assign(state.preferences, patch);
    Object.assign(pendingSettingsPatch, patch);
    applyPreferencesToDOM();
    syncOptionsInputsFromState();
    clearTimeout(settingsTimer);
    settingsTimer = setTimeout(() => {
      void flushSettings();
    }, 180);
  }

  async function flushSettings() {
    clearTimeout(settingsTimer);
    settingsTimer = null;
    const patch = pendingSettingsPatch;
    if (!Object.keys(patch).length) return;
    pendingSettingsPatch = {};
    if (!window.appBoy?.settingsSave) return;
    try {
      const normalized = await window.appBoy.settingsSave(patch);
      if (normalized && typeof normalized === "object") {
        for (const [k, v] of Object.entries(normalized)) {
          if (!(k in pendingSettingsPatch)) {
            state.preferences[k] = v;
          }
        }
        applyPreferencesToDOM();
        syncOptionsInputsFromState();
      }
    } catch (err) {
      showErrorToast(err?.message || "Failed saving settings.");
    }
  }

  function buildWorkspacePayload() {
    return {
      activeTabId: state.activeTabId,
      tabs: state.tabs.map((tab) => ({
        id: tab.id,
        title: tab.title,
        consoleName: tab.consoleName || "",
        sourceKind: tab.sourceKind || "album",
        sourceId: tab.sourceId || null,
        trackIds: (state.tabTracks.get(tab.id) || []).map((t) => t.id),
        selectedTrackId: tab.selectedTrackId || null
      }))
    };
  }

  function scheduleWorkspaceSave() {
    clearTimeout(workspaceTimer);
    workspaceTimer = setTimeout(() => {
      void flushWorkspace();
    }, 350);
  }

  async function flushWorkspace() {
    clearTimeout(workspaceTimer);
    workspaceTimer = null;
    if (!state.tabs.length || !window.appBoy?.workspaceSave) return;
    try {
      await window.appBoy.workspaceSave(buildWorkspacePayload());
    } catch (err) {
      console.error("[SPCBoy] workspace save error", err);
    }
  }

  async function flushPendingState() {
    await flushSettings();
    await flushWorkspace();
  }

  function activeTab() {
    return state.tabs.find((t) => t.id === state.activeTabId) || state.tabs[0] || null;
  }

  function activeTracks() {
    const tab = activeTab();
    return tab ? state.tabTracks.get(tab.id) || [] : [];
  }

  window.APPBOYApp = {
    THEME_PRESETS,
    state,
    refs,
    formatTime,
    parseDurationInput,
    parseSpeedInput,
    formatSpeedRatio,
    effectiveTrackDuration,
    formatGainDB,
    setRangeSliderPercent,
    showErrorToast,
    applyPreferencesToDOM,
    syncOptionsInputsFromState,
    renderDiagnostics,
    refreshDiagnostics,
    queueSettingsPatch,
    flushSettings,
    scheduleWorkspaceSave,
    flushWorkspace,
    flushPendingState,
    activeTab,
    activeTracks
  };

  window.APPBOY = {
    flushPendingState
  };
})();
