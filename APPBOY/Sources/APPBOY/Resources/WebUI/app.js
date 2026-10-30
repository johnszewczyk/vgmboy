(() => {
  const app = window.APPBOYApp;
  const { state, refs } = app;

  // Selector target attachment on pointer/tap
  document.addEventListener("pointerdown", (ev) => {
    if (state.volumePopoverOpen && !refs.volumeWrap?.contains(ev.target)) {
      app.ui.setVolumePopoverOpen(false);
    }
    const target = ev.target.closest("[data-selector-target]");
    if (target && !state.optionsOpen) {
      app.ui.moveSelectionIndicator(target);
    }
  });

  window.addEventListener("resize", () => {
    app.ui.refreshIndicatorPosition();
  });

  if (typeof ResizeObserver === "function") {
    const ro = new ResizeObserver(() => {
      app.ui.refreshIndicatorPosition();
    });
    for (const sel of [".app-shell", ".sb-titlebar", "#mobile-mode-bar", ".workspace", ".transport-deck"]) {
      const el = document.querySelector(sel);
      if (el) ro.observe(el);
    }
  }

  // Mobile mode bar
  refs.mobileModeBar.querySelectorAll("[data-mobile-target]").forEach((btn) => {
    btn.addEventListener("click", () => {
      app.ui.setMobilePane(btn.dataset.mobileTarget);
    });
  });

  // Split-view library shortcuts
  refs.splitGalleryBtn?.addEventListener("click", () => {
    state.contentMode = state.contentMode === "gallery" ? "playlist" : "gallery";
    if (state.contentMode === "gallery") app.ui.renderGallery();
    app.ui.renderAll();
  });

  refs.splitFavoritesBtn?.addEventListener("click", () => {
    void app.ui.openFavoritesTab();
  });

  refs.splitRecentBtn?.addEventListener("click", () => {
    void app.ui.openRecentTab();
  });

  refs.foldToggleBtn?.addEventListener("click", () => {
    app.ui.toggleAllConsoleGroups();
  });

  refs.searchInput?.addEventListener("input", (ev) => {
    state.searchQuery = ev.target.value || "";
    app.ui.renderLibraryTree();
    if (state.contentMode === "gallery") {
      app.ui.renderGallery();
    }
  });

  // Tabs & column sort
  refs.newTabBtn?.addEventListener("click", () => {
    app.ui.createNewTab();
  });
  refs.sortTitleBtn?.addEventListener("click", () => app.ui.toggleSort("title"));
  refs.sortAlbumBtn?.addEventListener("click", () => app.ui.toggleSort("album"));
  refs.sortTimeBtn?.addEventListener("click", () => app.ui.toggleSort("time"));

  // Transport controls
  refs.playBtn?.addEventListener("click", () => {
    void app.playback.togglePlayback();
  });
  refs.stopBtn?.addEventListener("click", () => {
    void app.playback.stopPlayback();
  });
  refs.prevBtn?.addEventListener("click", () => {
    void app.playback.playAdjacent(-1);
  });
  refs.nextBtn?.addEventListener("click", () => {
    void app.playback.playAdjacent(1);
  });
  refs.repeatBtn?.addEventListener("click", () => {
    app.playback.cycleRepeatMode();
  });
  refs.longPlayBtn?.addEventListener("click", () => {
    app.playback.toggleLongPlay();
  });
  refs.speedBtn?.addEventListener("click", () => {
    app.playback.togglePlaybackSpeed();
  });
  refs.volumeBtn?.addEventListener("click", () => {
    app.ui.setVolumePopoverOpen(!state.volumePopoverOpen);
  });
  refs.volumeInput?.addEventListener("input", (ev) => {
    app.playback.setAppVolume(Number(ev.target.value) / 100);
  });

  // Scrubber
  refs.progressSlider?.addEventListener("pointerdown", () => {
    state.playback.scrubbing = true;
  });
  refs.progressSlider?.addEventListener("input", (ev) => {
    state.playback.scrubbing = true;
    state.playback.elapsedSeconds = Number(ev.target.value) || 0;
    app.playback.updateProgressVisuals();
  });
  refs.progressSlider?.addEventListener("change", (ev) => {
    state.playback.scrubbing = false;
    void app.playback.seekTo(Number(ev.target.value) || 0);
  });

  // Options Drawer
  refs.optionsBtn?.addEventListener("click", () => {
    app.ui.setOptionsOpen(!state.optionsOpen);
  });
  refs.optionsCloseBtn?.addEventListener("click", () => {
    app.ui.setOptionsOpen(false);
  });
  refs.optionsOverlay?.addEventListener("click", (ev) => {
    if (ev.target === refs.optionsOverlay) {
      app.ui.setOptionsOpen(false);
    }
  });
  document.querySelectorAll("[data-options-tab]").forEach((btn) => {
    btn.addEventListener("click", () => {
      app.ui.setOptionsSection(btn.dataset.optionsTab);
    });
  });

  // Theme Presets & Options Bindings
  document.querySelectorAll("[data-theme-preset]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const preset = app.THEME_PRESETS[btn.dataset.themePreset];
      if (preset) app.queueSettingsPatch(preset);
    });
  });

  refs.optAccentColor?.addEventListener("change", (ev) => app.queueSettingsPatch({ accentColor: ev.target.value }));
  refs.optChromePrimary?.addEventListener("change", (ev) => app.queueSettingsPatch({ uiChromePrimaryColor: ev.target.value }));
  refs.optChromePane?.addEventListener("change", (ev) => app.queueSettingsPatch({ uiChromePaneColor: ev.target.value }));
  refs.optSelectionAnimEnabled?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ selectionAnimationEnabled: ev.target.checked });
    app.ui.refreshIndicatorPosition();
  });
  refs.optSelectionAnimMs?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ selectionAnimationMilliseconds: Number(ev.target.value) || 0 });
  });
  refs.optLinkMode?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ playlistLinkMode: ev.target.checked });
  });
  refs.optSidebarCounts?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ sidebarTrackCounts: ev.target.checked });
    app.ui.renderLibraryTree();
  });
  refs.optFavSort?.addEventListener("change", async (ev) => {
    app.queueSettingsPatch({ favoriteSortOrder: ev.target.value });
    await app.flushSettings();
    if (app.activeTab()?.sourceKind === "favorites" && window.appBoy?.favoritesList) {
      state.tabTracks.set(app.activeTab().id, await window.appBoy.favoritesList());
      app.ui.renderPlaylistRows();
    }
  });

  refs.optChromeFontPt?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ uiChromeFontSizePt: Number(ev.target.value) || 11 });
  });
  refs.optContentFontPt?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ contentFontSizePt: Number(ev.target.value) || 11.5 });
  });
  refs.optSidebarTextColor?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ sidebarTextColor: ev.target.value });
  });
  refs.optChromeMono?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ uiChromeMonospace: ev.target.checked });
  });
  refs.optContentMono?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ contentMonospace: ev.target.checked });
  });

  refs.optGalleryFit?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ galleryFitMode: ev.target.value });
  });
  refs.optGalleryScale?.addEventListener("input", (ev) => {
    app.queueSettingsPatch({ galleryFrameScale: Number(ev.target.value) || 1 });
  });
  refs.optGalleryGap?.addEventListener("input", (ev) => {
    app.queueSettingsPatch({ galleryGapRem: Number(ev.target.value) || 0 });
  });
  refs.optGalleryRadius?.addEventListener("input", (ev) => {
    app.queueSettingsPatch({ galleryRadiusRem: Number(ev.target.value) || 0 });
  });

  refs.optSpeedEnabled?.addEventListener("change", (ev) => {
    const enabled = ev.target.checked;
    app.queueSettingsPatch({ playbackSpeedEnabled: enabled });
    const rate = enabled ? Number(state.preferences.playbackSpeedRate || 1.25) : 1.0;
    window.appBoy?.playbackSetRate?.(rate).catch(() => {});
    app.playback.renderTransportChrome();
  });
  refs.optSpeedRate?.addEventListener("change", (ev) => {
    const rate = Math.min(2.0, Math.max(0.5, Number(ev.target.value) || 1.25));
    app.queueSettingsPatch({ playbackSpeedRate: rate });
    if (state.preferences.playbackSpeedEnabled) {
      window.appBoy?.playbackSetRate?.(rate).catch(() => {});
    }
    app.playback.renderTransportChrome();
  });
  refs.optLongPlayEnabled?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ longPlayEnabled: ev.target.checked });
    app.playback.renderTransportChrome();
  });
  refs.optManualDuration?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ manualPlayTimeSeconds: Math.max(15, Number(ev.target.value) || 180) });
  });

  refs.optRemoteURL?.addEventListener("change", (ev) => {
    app.queueSettingsPatch({ remoteCatalogURL: ev.target.value.trim() });
  });
  refs.optReloadCatalogBtn?.addEventListener("click", async () => {
    refs.optSourceStatus.textContent = "Reloading…";
    await app.flushSettings();
    if (!window.appBoy?.reloadCatalog) {
      refs.optSourceStatus.textContent = "Native bridge unavailable.";
      return;
    }
    try {
      const res = await window.appBoy.reloadCatalog();
      if (res?.catalog) state.catalog = res.catalog;
      if (Array.isArray(res?.favoriteTrackIds)) state.favoriteIds = new Set(res.favoriteTrackIds);
      state.expandedConsoleIds = new Set((state.catalog.consoles || []).slice(0, 2).map((c) => c.id));
      refs.optSourceStatus.textContent = `Loaded ${state.catalog.trackCount} tracks.`;
      app.ui.renderAll();
    } catch (err) {
      refs.optSourceStatus.textContent = err?.message || "Catalog reload failed.";
      app.showErrorToast(err?.message || "Catalog reload failed.");
    }
  });

  // Hardware keyboard support (iPad Magic Keyboard)
  window.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape") {
      if (state.volumePopoverOpen) {
        ev.preventDefault();
        app.ui.setVolumePopoverOpen(false);
        return;
      }
      if (state.optionsOpen) {
        ev.preventDefault();
        app.ui.setOptionsOpen(false);
      }
      return;
    }
    const tag = ev.target?.tagName;
    if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") return;
    if (ev.metaKey && ev.key === ",") {
      ev.preventDefault();
      app.ui.setOptionsOpen(!state.optionsOpen);
      return;
    }
    if (ev.key === " " && !state.optionsOpen) {
      ev.preventDefault();
      void app.playback.togglePlayback();
    }
  });

  window.addEventListener("pagehide", () => {
    void app.flushPendingState();
  });

  function applyDeepLink(payload) {
    const action = payload?.action;
    const target = payload?.target;
    if (action === "view") {
      if (target === "options") {
        app.ui.setOptionsOpen(true);
      } else {
        app.ui.setOptionsOpen(false);
        app.ui.setMobilePane(target);
      }
    } else if (action === "play") {
      app.ui.setOptionsOpen(false);
      if (target) {
        const track = app.activeTracks().find((t) => t.id === target);
        if (track) {
          void app.playback.startTrack(track, app.activeTab()?.id);
          return;
        }
      }
      void app.playback.togglePlayback();
    } else if (action === "transport" && target) {
      app.playback.handleRemoteCommand({ command: target });
    }
  }

  // Native Bridge Subscriptions
  const pendingDeepLinks = [];
  let bootstrapDone = false;

  if (window.appBoy) {
    window.appBoy.onNativePlaybackState?.((snap) => {
      app.playback.applyNativeState(snap);
      app.ui.renderPlaylistRows();
    });
    window.appBoy.onNativePlaybackEnded?.((payload) => {
      app.playback.handleNaturalEnd(payload);
    });
    window.appBoy.onRemoteCommand?.((payload) => {
      app.playback.handleRemoteCommand(payload);
    });
    window.appBoy.onDeepLink?.((payload) => {
      if (!bootstrapDone) {
        pendingDeepLinks.push(payload);
      } else {
        applyDeepLink(payload);
      }
    });
  }

  async function bootstrap() {
    if (!window.appBoy?.bootstrap) {
      app.ui.renderAll();
      return;
    }
    try {
      const payload = await window.appBoy.bootstrap();
      if (payload?.preferences) {
        Object.assign(state.preferences, payload.preferences);
      }
      if (payload?.catalog) {
        state.catalog = payload.catalog;
      }
      if (Array.isArray(payload?.favoriteTrackIds)) {
        state.favoriteIds = new Set(payload.favoriteTrackIds);
      }
      state.expandedConsoleIds = new Set((state.catalog.consoles || []).slice(0, 2).map((c) => c.id));

      const ws = payload?.workspace;
      const initialTabTracks = payload?.initialTabTracks || {};
      if (ws && Array.isArray(ws.tabs) && ws.tabs.length > 0) {
        state.tabs = ws.tabs.map((t) => ({
          id: t.id,
          title: t.title,
          consoleName: t.consoleName || "",
          sourceKind: t.sourceKind || "album",
          sourceId: t.sourceId || null,
          selectedTrackId: t.selectedTrackId || null
        }));
        state.activeTabId = ws.activeTabId || state.tabs[0].id;
        for (const tab of state.tabs) {
          state.tabTracks.set(tab.id, initialTabTracks[tab.id] || []);
        }
        const active = app.activeTab();
        if (active?.sourceKind === "album" && active.sourceId) {
          state.selectedAlbumId = active.sourceId;
        }
      }
      if (Array.isArray(payload?.initialDeepLinks)) {
        pendingDeepLinks.push(...payload.initialDeepLinks);
      }
      app.ui.renderAll();
    } catch (err) {
      app.showErrorToast(err?.message || "APPBOY bootstrap failed.");
      app.ui.renderAll();
    } finally {
      bootstrapDone = true;
      while (pendingDeepLinks.length > 0) {
        applyDeepLink(pendingDeepLinks.shift());
      }
    }
  }

  void bootstrap();
})();
