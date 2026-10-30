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

  const state = {
    mobilePane: "library",
    contentMode: "playlist",
    optionsOpen: false,
    optionsTab: "interface",
    volumePopoverOpen: false,
    searchQuery: "",
    expandedConsoleIds: new Set(),
    catalog: {
      sourceLabel: "Built-in VGM",
      consoleCount: 0,
      albumCount: 0,
      trackCount: 0,
      consoles: []
    },
    favoriteIds: new Set(),
    tabs: [],
    activeTabId: "",
    tabTracks: new Map(),
    sortColumn: null,
    sortDirection: "asc",
    selectedAlbumId: null,
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
      playbackRate: 1.0,
      scrubbing: false
    }
  };

  const refs = {
    indicator: document.getElementById("sb2-selection-indicator"),
    consoleLabel: document.getElementById("sb2-console-label"),
    albumLabel: document.getElementById("sb2-album-label"),
    sourceChip: document.getElementById("sb2-source-chip"),
    mobileModeBar: document.getElementById("mobile-mode-bar"),
    searchInput: document.getElementById("sidebar-search-input"),
    splitGalleryBtn: document.getElementById("split-gallery-button"),
    splitRecentBtn: document.getElementById("split-recent-button"),
    splitFavoritesBtn: document.getElementById("split-favorites-button"),
    foldToggleBtn: document.getElementById("sidebar-fold-toggle-button"),
    foldIconUse: document.getElementById("sidebar-fold-icon-use"),
    treeRoot: document.getElementById("tree-root"),
    tabsContainer: document.getElementById("playlist-tabs"),
    newTabBtn: document.getElementById("new-tab-button"),
    playlistView: document.getElementById("playlist-view"),
    playlistBody: document.getElementById("playlist-body-wrap"),
    sortTitleBtn: document.getElementById("sort-title-button"),
    sortAlbumBtn: document.getElementById("sort-album-button"),
    sortTimeBtn: document.getElementById("sort-time-button"),
    galleryView: document.getElementById("gallery-view"),
    galleryGrid: document.getElementById("gallery-grid"),
    nowPlayingTitle: document.getElementById("now-playing-title"),
    nowPlayingMeta: document.getElementById("now-playing-meta"),
    speedBadge: document.getElementById("speed-readout-badge"),
    repeatBadge: document.getElementById("repeat-readout-badge"),
    progressSlider: document.getElementById("progress-slider"),
    progressShell: document.getElementById("progress-slider-shell"),
    prevBtn: document.getElementById("previous-button"),
    stopBtn: document.getElementById("stop-button"),
    playBtn: document.getElementById("play-button"),
    nextBtn: document.getElementById("next-button"),
    repeatBtn: document.getElementById("repeat-button"),
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
    optSpeedEnabled: document.getElementById("opt-speed-enabled"),
    optSpeedRate: document.getElementById("opt-speed-rate"),
    optLongPlayEnabled: document.getElementById("opt-long-play-enabled"),
    optManualDuration: document.getElementById("opt-manual-duration"),
    optSourceLabel: document.getElementById("opt-source-label"),
    optRemoteURL: document.getElementById("opt-remote-url"),
    optReloadCatalogBtn: document.getElementById("opt-reload-catalog-button"),
    optSourceStatus: document.getElementById("opt-source-status")
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
    if (document.activeElement !== refs.optAccentColor) refs.optAccentColor.value = p.accentColor;
    if (document.activeElement !== refs.optChromePrimary) refs.optChromePrimary.value = p.uiChromePrimaryColor;
    if (document.activeElement !== refs.optChromePane) refs.optChromePane.value = p.uiChromePaneColor;
    refs.optSelectionAnimEnabled.checked = Boolean(p.selectionAnimationEnabled);
    if (document.activeElement !== refs.optSelectionAnimMs) refs.optSelectionAnimMs.value = String(p.selectionAnimationMilliseconds);
    refs.optLinkMode.checked = Boolean(p.playlistLinkMode);
    refs.optSidebarCounts.checked = Boolean(p.sidebarTrackCounts);
    refs.optFavSort.value = p.favoriteSortOrder || "historical";

    if (document.activeElement !== refs.optChromeFontPt) refs.optChromeFontPt.value = String(p.uiChromeFontSizePt);
    if (document.activeElement !== refs.optContentFontPt) refs.optContentFontPt.value = String(p.contentFontSizePt);
    if (document.activeElement !== refs.optSidebarTextColor) refs.optSidebarTextColor.value = p.sidebarTextColor;
    refs.optChromeMono.checked = Boolean(p.uiChromeMonospace);
    refs.optContentMono.checked = Boolean(p.contentMonospace);

    refs.optGalleryFit.value = p.galleryFitMode || "crop";
    refs.optGalleryScale.value = String(p.galleryFrameScale);
    refs.optGalleryScaleOut.textContent = `${Number(p.galleryFrameScale).toFixed(2)}×`;
    refs.optGalleryGap.value = String(p.galleryGapRem);
    refs.optGalleryGapOut.textContent = `${Number(p.galleryGapRem).toFixed(2)}rem`;
    refs.optGalleryRadius.value = String(p.galleryRadiusRem);
    refs.optGalleryRadiusOut.textContent = `${Number(p.galleryRadiusRem).toFixed(2)}rem`;

    refs.optSpeedEnabled.checked = Boolean(p.playbackSpeedEnabled);
    if (document.activeElement !== refs.optSpeedRate) refs.optSpeedRate.value = String(p.playbackSpeedRate);
    refs.optLongPlayEnabled.checked = Boolean(p.longPlayEnabled);
    if (document.activeElement !== refs.optManualDuration) refs.optManualDuration.value = String(p.manualPlayTimeSeconds);

    refs.optSourceLabel.textContent = state.catalog.sourceLabel || "Built-in VGM";
    if (document.activeElement !== refs.optRemoteURL) refs.optRemoteURL.value = p.remoteCatalogURL || "";
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
      console.error("[APPBOY] workspace save error", err);
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
    showErrorToast,
    applyPreferencesToDOM,
    syncOptionsInputsFromState,
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
