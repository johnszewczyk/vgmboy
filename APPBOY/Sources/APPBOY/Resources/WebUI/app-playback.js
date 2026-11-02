(() => {
  const app = window.APPBOYApp;
  const { state, refs } = app;

  function findTrackInAnyTab(trackId) {
    if (!trackId) return null;
    for (const tracks of state.tabTracks.values()) {
      const match = tracks.find((t) => t.id === trackId);
      if (match) return match;
    }
    return null;
  }

  function updateProgressVisuals() {
    const pb = state.playback;
    const activeSelected = app.activeTracks().find((t) => t.id === app.activeTab()?.selectedTrackId);
    const fallbackDuration = pb.transportState === "stopped"
      ? app.effectiveTrackDuration(pb.trackMeta || activeSelected)
      : 0;
    const duration = Math.max(0, Number(pb.durationSeconds) || fallbackDuration || 0);
    const elapsed = pb.transportState === "stopped"
      ? 0
      : Math.min(duration || 0, Math.max(0, Number(pb.elapsedSeconds) || 0));
    const pct = duration > 0 ? Math.min(100, (elapsed / duration) * 100) : 0;

    document.documentElement.style.setProperty("--progress-percent", `${pct.toFixed(2)}%`);

    refs.elapsedLabel.textContent = app.formatTime(elapsed);
    refs.songLengthLabel.textContent = app.formatTime(duration);

    const playlistTotal = app.activeTracks().reduce(
      (sum, t) => sum + app.effectiveTrackDuration(t),
      0
    );
    refs.playlistTotalLabel.textContent = app.formatTime(playlistTotal);
  }

  function renderTransportChrome() {
    const pb = state.playback;
    const p = state.preferences;
    const isPlaying = pb.transportState === "playing";

    refs.playBtn.classList.toggle("sb-is-playing", isPlaying);
    refs.playBtn.setAttribute("aria-pressed", isPlaying ? "true" : "false");

    const repeatActive = p.repeatMode !== "off";
    refs.repeatBtn.setAttribute("aria-pressed", repeatActive ? "true" : "false");
    const repeatLabel = p.repeatMode === "one"
      ? "Repeat track"
      : p.repeatMode === "all"
        ? "Repeat playlist"
        : "Repeat off";
    refs.repeatBtn.setAttribute("title", repeatLabel);
    refs.repeatBtn.setAttribute("aria-label", repeatLabel);

    const eqActive = Boolean(p.equalizerEnabled);
    refs.eqBtn?.setAttribute("aria-pressed", eqActive ? "true" : "false");
    refs.eqBtn?.setAttribute("title", eqActive ? "Disable Equalizer" : "Enable Equalizer");

    const longPlayActive = Boolean(p.longPlayEnabled);
    refs.longPlayBtn.setAttribute("aria-pressed", longPlayActive ? "true" : "false");
    refs.longPlayBtn.setAttribute(
      "title",
      longPlayActive ? `Long Play (${app.formatTime(p.manualPlayTimeSeconds)})` : "Toggle Long Play"
    );

    const speedRatio = app.formatSpeedRatio(p.playbackSpeedRate || 1.25);
    refs.speedBtn.setAttribute("aria-pressed", p.playbackSpeedEnabled ? "true" : "false");
    refs.speedBtn.setAttribute(
      "title",
      p.playbackSpeedEnabled ? `Playback speed ${speedRatio}` : "Playback speed disabled"
    );

    const pctVol = Math.round((Number(p.appVolume ?? 1) || 0) * 100);
    refs.volumeInput.value = String(pctVol);
    refs.volumeOutput.textContent = `${pctVol}%`;
    refs.volumeBtn.setAttribute("title", `Volume ${pctVol}%`);
    refs.volumeBtn.setAttribute("aria-label", `Volume ${pctVol}%`);

    const meta = pb.trackMeta || findTrackInAnyTab(pb.trackId);
    if (refs.currentTrackTitle) {
      if (meta && pb.transportState !== "stopped") {
        refs.currentTrackTitle.textContent = meta.title;
        refs.currentTrackTitle.hidden = false;
      } else {
        refs.currentTrackTitle.textContent = "";
        refs.currentTrackTitle.hidden = true;
      }
    }

    const st = pb.transportState || "ready";
    refs.statusStateWrap.dataset.state = st === "playing" ? "playing" : st === "error" ? "error" : "ready";
    refs.statusLabel.textContent = st === "stopped" ? "READY" : st.toUpperCase();

    updateProgressVisuals();
  }

  async function startTrack(track, tabId) {
    if (!track) return;
    const tab = state.tabs.find((t) => t.id === (tabId || state.activeTabId)) || app.activeTab();
    if (tab) {
      tab.selectedTrackId = track.id;
      state.playback.queueTabId = tab.id;
      app.scheduleWorkspaceSave();
    }
    state.playback.trackId = track.id;
    state.playback.trackMeta = track;

    if (!window.appBoy?.playbackStart) {
      state.playback.transportState = "playing";
      state.playback.elapsedSeconds = 0;
      state.playback.durationSeconds = app.effectiveTrackDuration(track) || 30;
      renderTransportChrome();
      app.ui?.renderPlaylistRows();
      return;
    }

    try {
      const snap = await window.appBoy.playbackStart({ trackId: track.id });
      applyNativeState(snap);
      app.ui?.renderPlaylistRows();
    } catch (err) {
      app.showErrorToast(err?.message || "Playback failed to start.");
    }
  }

  async function togglePlayback() {
    const pb = state.playback;
    if (pb.transportState === "playing") {
      if (window.appBoy?.playbackPause) {
        const snap = await window.appBoy.playbackPause(pb.generation);
        applyNativeState(snap);
      } else {
        pb.transportState = "paused";
        renderTransportChrome();
      }
      return;
    }

    if (pb.transportState === "paused" && pb.trackId) {
      if (window.appBoy?.playbackResume) {
        const snap = await window.appBoy.playbackResume(pb.generation);
        applyNativeState(snap);
      } else {
        pb.transportState = "playing";
        renderTransportChrome();
      }
      return;
    }

    const tracks = app.activeTracks();
    const tab = app.activeTab();
    const chosen = tracks.find((t) => t.id === tab?.selectedTrackId)
      || tracks.find((t) => t.id === pb.trackId)
      || tracks[0];
    if (chosen) {
      await startTrack(chosen, tab?.id);
    }
  }

  async function stopPlayback() {
    const pb = state.playback;
    if (window.appBoy?.playbackStop) {
      const snap = await window.appBoy.playbackStop(pb.generation);
      applyNativeState(snap);
    } else {
      pb.transportState = "stopped";
      pb.elapsedSeconds = 0;
      renderTransportChrome();
    }
    app.ui?.renderPlaylistRows();
  }

  async function playAdjacent(delta, { fromNaturalEnd = false } = {}) {
    const queueTabId = state.playback.queueTabId || state.activeTabId;
    const tracks = state.tabTracks.get(queueTabId) || app.activeTracks();
    if (!tracks.length) return;

    const repeatMode = state.preferences.repeatMode || "off";
    const currentId = state.playback.trackId || app.activeTab()?.selectedTrackId;
    const currentIndex = tracks.findIndex((t) => t.id === currentId);

    if (fromNaturalEnd && repeatMode === "one" && currentIndex >= 0) {
      await startTrack(tracks[currentIndex], queueTabId);
      return;
    }

    let nextIndex = currentIndex >= 0 ? currentIndex + delta : 0;
    if (nextIndex >= tracks.length) {
      if (repeatMode === "all" || !fromNaturalEnd) {
        nextIndex = 0;
      } else {
        await stopPlayback();
        return;
      }
    } else if (nextIndex < 0) {
      nextIndex = tracks.length - 1;
    }

    await startTrack(tracks[nextIndex], queueTabId);
  }

  async function seekTo(seconds) {
    const pb = state.playback;
    pb.elapsedSeconds = Math.max(0, Number(seconds) || 0);
    updateProgressVisuals();
    if (window.appBoy?.playbackSeek && pb.trackId) {
      const snap = await window.appBoy.playbackSeek(pb.elapsedSeconds, pb.generation);
      applyNativeState(snap);
    }
  }

  function cycleRepeatMode() {
    const order = ["off", "all", "one"];
    const idx = order.indexOf(state.preferences.repeatMode || "off");
    const next = order[(idx + 1) % order.length];
    app.queueSettingsPatch({ repeatMode: next });
    renderTransportChrome();
  }

  function toggleEqualizer() {
    const next = !state.preferences.equalizerEnabled;
    const bands = (state.preferences.equalizerBandsDB || []).slice();
    app.queueSettingsPatch({ equalizerEnabled: next });
    window.appBoy?.playbackSetEqualizer?.(next, bands).catch(() => {});
    renderTransportChrome();
  }

  function setEqualizerBand(index, gainDB) {
    const clamped = Math.round(Math.min(12, Math.max(-12, Number(gainDB) || 0)) * 2) / 2;
    const bands = Array.isArray(state.preferences.equalizerBandsDB)
      ? state.preferences.equalizerBandsDB.slice()
      : Array(10).fill(0);
    while (bands.length < 10) bands.push(0);
    bands[index] = clamped;
    app.queueSettingsPatch({ equalizerBandsDB: bands });
    window.appBoy?.playbackSetEqualizer?.(Boolean(state.preferences.equalizerEnabled), bands).catch(() => {});
    renderTransportChrome();
  }

  function resetEqualizer() {
    const zeroBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    app.queueSettingsPatch({ equalizerBandsDB: zeroBands });
    window.appBoy?.playbackSetEqualizer?.(Boolean(state.preferences.equalizerEnabled), zeroBands).catch(() => {});
    renderTransportChrome();
  }

  function toggleLongPlay() {
    const next = !state.preferences.longPlayEnabled;
    app.queueSettingsPatch({ longPlayEnabled: next });
    if (state.playback.trackMeta) {
      state.playback.durationSeconds = next
        ? Number(state.preferences.manualPlayTimeSeconds || 180)
        : Number(state.playback.trackMeta.durationSeconds || state.playback.durationSeconds);
    }
    app.ui?.renderPlaylistRows();
    renderTransportChrome();
  }

  function setPlaybackSpeed(enabled, rate) {
    const cleanRate = app.parseSpeedInput(String(rate ?? 1.25), 1.25);
    app.queueSettingsPatch({
      playbackSpeedEnabled: Boolean(enabled),
      playbackSpeedRate: cleanRate
    });
    const activeRate = enabled ? cleanRate : 1.0;
    window.appBoy?.playbackSetRate?.(activeRate).catch(() => {});
    renderTransportChrome();
  }

  function togglePlaybackSpeed() {
    const next = !state.preferences.playbackSpeedEnabled;
    setPlaybackSpeed(next, state.preferences.playbackSpeedRate || 1.25);
  }

  function setAppVolume(normalizedVolume) {
    const detents = Number(window.appBoy?.volumeDetentCount) || 20;
    const clamped = Math.round(Math.min(1, Math.max(0, normalizedVolume)) * detents) / detents;
    app.queueSettingsPatch({ appVolume: clamped });
    window.appBoy?.playbackSetVolume?.(clamped).catch(() => {});
    renderTransportChrome();
  }

  function applyNativeState(snap) {
    if (!snap || typeof snap !== "object") return;
    if (typeof snap.generation === "number" && snap.generation < state.playback.generation) {
      return;
    }
    state.playback.generation = snap.generation ?? state.playback.generation;
    if (snap.trackId !== undefined) {
      state.playback.trackId = snap.trackId;
      const found = findTrackInAnyTab(snap.trackId);
      if (found) state.playback.trackMeta = found;
    }
    state.playback.transportState = snap.transportState || state.playback.transportState;
    if (typeof snap.elapsedSeconds === "number") {
      state.playback.elapsedSeconds = snap.elapsedSeconds;
    }
    if (typeof snap.durationSeconds === "number" && snap.durationSeconds > 0) {
      state.playback.durationSeconds = snap.durationSeconds;
    }
    if (typeof snap.playbackRate === "number") {
      state.playback.playbackRate = snap.playbackRate;
    }
    if (snap.errorMessage) {
      app.showErrorToast(snap.errorMessage);
    }
    renderTransportChrome();
    if (state.optionsOpen && state.optionsTab === "diagnostics") {
      void app.refreshDiagnostics();
    }
  }

  function handleNaturalEnd(payload) {
    if (!payload || payload.generation !== state.playback.generation) return;
    void playAdjacent(1, { fromNaturalEnd: true });
  }

  function handleRemoteCommand(payload) {
    if (!payload?.command) return;
    switch (payload.command) {
      case "play":
        if (state.playback.transportState !== "playing") void togglePlayback();
        break;
      case "pause":
        if (state.playback.transportState === "playing") void togglePlayback();
        break;
      case "playPause":
      case "togglePlayPause":
        void togglePlayback();
        break;
      case "next":
        void playAdjacent(1);
        break;
      case "previous":
        void playAdjacent(-1);
        break;
      case "stop":
        void stopPlayback();
        break;
      case "seek":
        if (typeof payload.positionTime === "number") void seekTo(payload.positionTime);
        break;
      default:
        break;
    }
  }

  app.playback = {
    startTrack,
    togglePlayback,
    stopPlayback,
    playAdjacent,
    seekTo,
    cycleRepeatMode,
    toggleEqualizer,
    setEqualizerBand,
    resetEqualizer,
    toggleLongPlay,
    setPlaybackSpeed,
    togglePlaybackSpeed,
    setAppVolume,
    renderTransportChrome,
    updateProgressVisuals,
    applyNativeState,
    handleNaturalEnd,
    handleRemoteCommand
  };
})();
