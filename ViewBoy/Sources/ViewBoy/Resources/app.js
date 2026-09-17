(() => {
const app = window.SPCBoyApp;
const { state, refs } = app;

let resizingSidebar = false;
let resizePointerId = null;
refs.sidebarResizeHandle?.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  resizingSidebar = true;
  resizePointerId = event.pointerId;
  refs.sidebarResizeHandle.setPointerCapture?.(event.pointerId);
  document.body.classList.add("is-sidebar-resizing");
});

function updateSidebarResize(event) {
  if (!resizingSidebar || (resizePointerId !== null && event.pointerId !== resizePointerId)) return;
  const bounds = refs.workspace?.getBoundingClientRect?.();
  if (!bounds?.width) return;
  const nextPercent = ((event.clientX - bounds.left) / bounds.width) * 100;
  state.sidebarWidthPercent = app.normalizeSidebarWidth(nextPercent);
  document.documentElement.style.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
  refs.sidebarWidthInput && (refs.sidebarWidthInput.value = String(state.sidebarWidthPercent));
  refs.sidebarResizeHandle?.setAttribute("aria-valuenow", String(Math.round(state.sidebarWidthPercent)));
}

function finishSidebarResize(event) {
  if (!resizingSidebar || (resizePointerId !== null && event.pointerId !== resizePointerId)) return;
  resizingSidebar = false;
  refs.sidebarResizeHandle?.releasePointerCapture?.(resizePointerId);
  resizePointerId = null;
  document.body.classList.remove("is-sidebar-resizing");
  app.persistSettings();
}

// Keep tracking the active pointer outside the narrow separator. WKWebView can
// otherwise stop delivering movement when the pointer crosses the scroll view.
document.addEventListener("pointermove", updateSidebarResize);
document.addEventListener("pointerup", finishSidebarResize);
document.addEventListener("pointercancel", finishSidebarResize);
refs.sidebarResizeHandle?.addEventListener("keydown", (event) => {
  if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
  event.preventDefault();
  const next = event.key === "ArrowLeft"
    ? state.sidebarWidthPercent - 1
    : event.key === "ArrowRight"
      ? state.sidebarWidthPercent + 1
      : event.key === "Home" ? 12 : 50;
  state.sidebarWidthPercent = app.normalizeSidebarWidth(next);
  document.documentElement.style.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
  refs.sidebarResizeHandle?.setAttribute("aria-valuenow", String(Math.round(state.sidebarWidthPercent)));
  app.persistSettings();
});

refs.playButton.addEventListener("click", () => {
  app.playback.togglePlayback().catch((error) => {
    console.error(error);
  });
});

refs.longPlayButton.addEventListener("click", () => {
  app.ui.setSpcForceManualTime(!state.longPlayEnabled);
});

refs.repeatButton.addEventListener("click", () => {
  app.ui.cycleRepeatMode();
});

refs.previousButton.addEventListener("click", () => {
  app.playback.playAdjacent(-1);
});

refs.databaseCollapseAllButton.addEventListener("click", () => {
  app.ui.setAllSidebarNodesCollapsed(true).catch((error) => console.error(error));
});

refs.databaseExpandAllButton.addEventListener("click", () => {
  app.ui.setAllSidebarNodesCollapsed(false).catch((error) => console.error(error));
});

refs.nextButton.addEventListener("click", () => {
  app.playback.playAdjacent(1);
});

refs.equalizerToolbarButton.addEventListener("click", () => {
  app.ui.setEqualizerEnabled(!state.equalizerEnabled);
});

refs.progressSlider.addEventListener("input", (event) => {
  const nextValue = Number(event.target.value);
  state.elapsedSeconds = nextValue;
  app.playback.setPlaybackClockPosition?.(nextValue);
  app.playback.updatePlaybackReadout();
});

refs.progressSlider.addEventListener("change", (event) => {
  const nextValue = Number(event.target.value);
  app.playback.restartAt(nextValue).catch((error) => {
    console.error(error);
  });
});

refs.spcForceLengthCheckbox.addEventListener("change", (event) => {
  app.ui.setSpcForceManualTime(event.target.checked);
});

refs.spcLengthInput.addEventListener("change", (event) => {
  app.ui.commitSpcLengthInput(event.target.value);
});

refs.spcLengthInput.addEventListener("input", (event) => {
  app.ui.commitSpcLengthInput(event.target.value);
});

refs.spcLengthInput.addEventListener("blur", (event) => {
  app.ui.commitSpcLengthInput(event.target.value);
});

refs.spcUnknownDurationInput.addEventListener("change", (event) => {
  app.ui.commitUnknownDurationInput(event.target.value);
});

refs.spcUnknownDurationInput.addEventListener("input", (event) => {
  app.ui.commitUnknownDurationInput(event.target.value);
});

refs.spcUnknownDurationInput.addEventListener("blur", (event) => {
  app.ui.commitUnknownDurationInput(event.target.value);
});

refs.spcFadeInput.addEventListener("change", (event) => {
  app.ui.commitSpcFadeInput(event.target.value);
});

refs.spcFadeCheckbox.addEventListener("change", (event) => {
  app.ui.setSpcFadeEnabled(event.target.checked);
});

refs.queuedSkipsCheckbox.addEventListener("change", (event) => {
  app.ui.setQueuedSkipsEnabled(event.target.checked);
});

refs.spcFadeInput.addEventListener("input", (event) => {
  app.ui.commitSpcFadeInput(event.target.value);
});

refs.spcFadeInput.addEventListener("blur", (event) => {
  app.ui.commitSpcFadeInput(event.target.value);
});

refs.playbackSpeedInput.addEventListener("change", (event) => {
  app.ui.commitPlaybackSpeedInput("libgme", event.target.value);
});

refs.playbackSpeedInput.addEventListener("blur", (event) => {
  app.ui.commitPlaybackSpeedInput("libgme", event.target.value);
});

refs.playbackSpeedEnabledCheckbox.addEventListener("change", (event) => {
  app.ui.setPlaybackSpeedEnabled("libgme", event.target.checked);
});

refs.libvgmPlaybackSpeedInput.addEventListener("change", (event) => app.ui.commitPlaybackSpeedInput("libvgm", event.target.value));
refs.libvgmPlaybackSpeedInput.addEventListener("blur", (event) => app.ui.commitPlaybackSpeedInput("libvgm", event.target.value));
refs.libvgmPlaybackSpeedEnabledCheckbox.addEventListener("change", (event) => app.ui.setPlaybackSpeedEnabled("libvgm", event.target.checked));

refs.equalizerEnabledCheckbox.addEventListener("change", (event) => {
  app.ui.setEqualizerEnabled(event.target.checked);
});
refs.equalizerBandInputs.forEach((input, index) => {
  input.addEventListener("input", (event) => app.ui.setEqualizerBandGain(index, event.target.value));
});
refs.equalizerResetButton.addEventListener("click", () => app.ui.resetEqualizer());
refs.appVolumeInput.addEventListener("input", (event) => app.ui.setAppVolume(event.target.value));
refs.monoEnabledCheckbox.addEventListener("change", (event) => app.ui.setMonoEnabled(event.target.checked));

refs.uiItemSpacingInput.addEventListener("change", (event) => {
  app.ui.setUiItemSpacing(event.target.value);
});

refs.uiItemSpacingInput.addEventListener("input", (event) => {
  app.ui.setUiItemSpacing(event.target.value);
});

refs.uiItemSpacingInput.addEventListener("blur", (event) => {
  app.ui.setUiItemSpacing(event.target.value);
});

refs.sidebarFontSizeInput.addEventListener("change", (event) => {
  app.ui.commitSidebarFontSizeInput(event.target.value);
});

refs.sidebarFontSizeInput.addEventListener("input", (event) => {
  app.ui.commitSidebarFontSizeInput(event.target.value);
});

refs.sidebarFontSizeInput.addEventListener("blur", (event) => {
  app.ui.commitSidebarFontSizeInput(event.target.value);
});

refs.sidebarTextColorInput.addEventListener("change", (event) => {
  app.ui.setSidebarTextColor(event.target.value);
});
refs.sidebarTextColorInput.addEventListener("blur", (event) => {
  app.ui.setSidebarTextColor(event.target.value);
});

refs.sidebarPathCountsCheckbox.addEventListener("change", (event) => {
  app.ui.setSidebarPathCounts(event.target.checked);
});
refs.applicationMonospaceCheckbox.addEventListener("change", (event) => {
  app.ui.setApplicationMonospace(event.target.checked);
});
refs.aacExportChooseButton.addEventListener("click", () => {
  app.playback.chooseAACExportDirectory().catch((error) => console.error("[SPCBoy] AAC export folder failed", error));
});
refs.aacExportCancelButton?.addEventListener("click", () => {
  app.playback.cancelAACExport().catch((error) => console.error("[SPCBoy] AAC cancellation failed", error));
});
refs.playlistHeaderBoldCheckbox.addEventListener("change", (event) => {
  app.ui.setPlaylistHeaderBold(event.target.checked);
});

refs.columnAutoSizeCheckbox.addEventListener("change", (event) => {
  app.ui.setColumnAutoSize(event.target.checked);
});

refs.autoResizeAnimationInput.addEventListener("change", (event) => {
  app.ui.setAnimationTiming("autoResizeAnimationMilliseconds", event.target.value);
});
refs.autoResizeAnimationEnabledCheckbox.addEventListener("change", (event) => {
  app.ui.setAnimationEnabled("autoResizeAnimationEnabled", event.target.checked);
});
refs.selectionAnimationInput.addEventListener("change", (event) => {
  app.ui.setAnimationTiming("selectionAnimationMilliseconds", event.target.value);
});
refs.selectionAnimationEnabledCheckbox.addEventListener("change", (event) => {
  app.ui.setAnimationEnabled("selectionAnimationEnabled", event.target.checked);
});
refs.mainWindowAlwaysOnTopCheckbox.addEventListener("change", (event) => {
  app.ui.setWindowAlwaysOnTop("mainWindowAlwaysOnTop", event.target.checked);
});
refs.settingsWindowAlwaysOnTopCheckbox.addEventListener("change", (event) => {
  app.ui.setWindowAlwaysOnTop("settingsWindowAlwaysOnTop", event.target.checked);
});

refs.sidebarWidthInput.addEventListener("change", (event) => {
  app.ui.commitSidebarWidthInput(event.target.value);
});

refs.sidebarWidthInput.addEventListener("input", (event) => {
  app.ui.commitSidebarWidthInput(event.target.value);
});

refs.sidebarWidthInput.addEventListener("blur", (event) => {
  app.ui.commitSidebarWidthInput(event.target.value);
});

refs.accentColorInput.addEventListener("change", (event) => {
  app.ui.setAccentColor(event.target.value);
});
refs.accentColorInput.addEventListener("blur", (event) => {
  app.ui.setAccentColor(event.target.value);
});

if (window.spcBoyWK?.onAppearanceSettingsChanged) {
  window.spcBoyWK.onAppearanceSettingsChanged((settings) => {
    app.ui.applyAppearanceSettings(settings);
  });
}

if (window.spcBoyWK?.onFrontendSettingsChanged) {
  window.spcBoyWK.onFrontendSettingsChanged((settings) => {
    const wasEnabled = state.localBrowserEnabled;
    const previousRootPath = state.rootPath;
    const previousFavoriteSortOrder = state.favoriteSortOrder;
    const previousTiming = {
      manualPlayTimeSeconds: state.manualPlayTimeSeconds,
      unknownDurationSeconds: state.unknownDurationSeconds,
      longPlayEnabled: state.longPlayEnabled,
      fadeEnabled: state.fadeEnabled,
      spcFadeSeconds: state.spcFadeSeconds
    };
    if (settings.manualPlayTimeSeconds !== undefined) state.manualPlayTimeSeconds = app.normalizeLongPlayTime(settings.manualPlayTimeSeconds);
    if (settings.unknownDurationSeconds !== undefined) state.unknownDurationSeconds = app.normalizePlayTime(settings.unknownDurationSeconds);
    if (settings.longPlayEnabled !== undefined) state.longPlayEnabled = Boolean(settings.longPlayEnabled);
    if (settings.fadeEnabled !== undefined) state.fadeEnabled = Boolean(settings.fadeEnabled);
    if (settings.spcFadeSeconds !== undefined) state.spcFadeSeconds = app.normalizeFadeTime(settings.spcFadeSeconds);
    const timingChanged = previousTiming.manualPlayTimeSeconds !== state.manualPlayTimeSeconds
      || previousTiming.unknownDurationSeconds !== state.unknownDurationSeconds
      || previousTiming.longPlayEnabled !== state.longPlayEnabled
      || previousTiming.fadeEnabled !== state.fadeEnabled
      || previousTiming.spcFadeSeconds !== state.spcFadeSeconds;
    state.rootPath = settings.rootPath || state.rootPath;
    state.localBrowserEnabled = Boolean(settings.localBrowserEnabled && state.rootPath);
    state.favoriteSortOrder = settings.favoriteSortOrder === "alphabetical" ? "alphabetical" : "historical";
    if (settings.autoResizeAnimationMilliseconds !== undefined) {
      state.autoResizeAnimationMilliseconds = app.normalizeAnimationMilliseconds(settings.autoResizeAnimationMilliseconds);
    }
    if (settings.autoResizeAnimationEnabled !== undefined) state.autoResizeAnimationEnabled = settings.autoResizeAnimationEnabled !== false;
    if (settings.selectionAnimationMilliseconds !== undefined) {
      state.selectionAnimationMilliseconds = app.normalizeAnimationMilliseconds(settings.selectionAnimationMilliseconds);
    }
    if (settings.selectionAnimationEnabled !== undefined) state.selectionAnimationEnabled = settings.selectionAnimationEnabled !== false;
    if (settings.mainWindowAlwaysOnTop !== undefined) state.mainWindowAlwaysOnTop = Boolean(settings.mainWindowAlwaysOnTop);
    if (settings.settingsWindowAlwaysOnTop !== undefined) state.settingsWindowAlwaysOnTop = Boolean(settings.settingsWindowAlwaysOnTop);
    if (!window.spcBoyWK.isOptionsWindow && state.localBrowserEnabled && (!wasEnabled || previousRootPath !== state.rootPath || state.sidebarMode !== "diskPath")) {
      window.spcBoyWK.refreshTree(state.rootPath, state.selectedFolderPath || state.rootPath)
        .then((snapshot) => {
          Object.assign(state, snapshot);
          state.sidebarMode = "diskPath";
          app.ui.renderAll();
        })
        .catch((error) => console.error("[SPCBoy] local settings sync failed", error));
    } else if (!window.spcBoyWK.isOptionsWindow && wasEnabled && !state.localBrowserEnabled) {
      state.sidebarMode = "consoles";
      app.ui.setSidebarMode("consoles").catch((error) => console.error(error));
    } else {
      app.ui.renderAll();
    }
    if (!window.spcBoyWK.isOptionsWindow && timingChanged) {
      app.playback.refreshPlaybackForTimingChange().catch((error) => console.error("[SPCBoy] playback timing sync failed", error));
    }
    if (previousFavoriteSortOrder !== state.favoriteSortOrder) {
      app.ui.refreshFavorites().then(() => app.ui.renderAll()).catch(() => {});
    }
  });
}

if (window.spcBoyWK?.onRoutingPreferencesChanged) {
  window.spcBoyWK.onRoutingPreferencesChanged((preferences) => {
    app.ui.applyRoutingPreferences(preferences);
  });
}

if (window.spcBoyWK?.onCatalogReloaded) {
  window.spcBoyWK.onCatalogReloaded((location) => {
    app.ui.handleCatalogReloaded(location).catch((error) => console.error("[SPCBoy] catalog reload refresh failed", error));
  });
}

refs.optionsCloseButton.addEventListener("click", () => {
  app.ui.setOptionsOpen(false);
});

refs.optionsThemeTab.addEventListener("click", () => {
  state.optionsSection = "theme";
  app.ui.renderAll();
});

refs.optionsWindowsTab.addEventListener("click", () => {
  state.optionsSection = "windows";
  app.ui.renderAll();
});

refs.optionsDatabaseTab.addEventListener("click", () => {
  state.optionsSection = "database";
  app.ui.refreshDatabaseLocation().catch((error) => console.error(error));
  app.ui.refreshArchiveCacheSummary().catch((error) => console.error(error));
  app.ui.renderAll();
});

refs.libraryDatabaseReloadButton.addEventListener("click", () => {
  app.ui.reloadDatabaseLibrary().catch((error) => {
    state.databaseLocationStatus = `Library reload failed • ${error.message}`;
    app.ui.renderAll();
  });
});

refs.libraryDatabaseBrowseButton.addEventListener("click", () => {
  app.ui.chooseDatabaseLocation().catch((error) => {
    state.databaseLocationStatus = `Database not selected • ${error.message}`;
    app.ui.renderAll();
  });
});

refs.libraryDatabaseShowButton.addEventListener("click", () => {
  const path = state.databaseLocation?.path;
  if (path) window.spcBoyWK?.showInFinder?.(path).catch?.((error) => console.error(error));
});

refs.libraryDatabaseDefaultButton.addEventListener("click", () => {
  app.ui.useDefaultDatabaseLocation().catch((error) => {
    state.databaseLocationStatus = `Could not select default database • ${error.message}`;
    app.ui.renderAll();
  });
});

refs.localBrowserBrowseButton.addEventListener("click", () => {
  window.spcBoyWK.chooseRootFolder()
    .then((snapshot) => {
      if (!snapshot) return;
      state.localBrowserEnabled = true;
      app.ui.applyLibrarySnapshot(snapshot);
    })
    .catch((error) => console.error("[SPCBoy] local folder selection failed", error));
});

refs.localBrowserEnabledCheckbox.addEventListener("change", (event) => {
  const enabled = event.target.checked;
  if (enabled && !state.rootPath) {
    refs.localBrowserBrowseButton.click();
    event.target.checked = false;
    return;
  }
  state.localBrowserEnabled = enabled;
  if (enabled) {
    state.sidebarMode = "diskPath";
    window.spcBoyWK.refreshTree(state.rootPath, state.selectedFolderPath || state.rootPath)
      .then((snapshot) => app.ui.applyLibrarySnapshot(snapshot))
      .catch((error) => console.error("[SPCBoy] local browser activation failed", error));
  } else {
    state.sidebarMode = "consoles";
    app.ui.setSidebarMode("consoles").catch((error) => console.error(error));
  }
  app.persistSettings();
  app.ui.renderAll();
});

refs.favoriteHistoricalSortCheckbox.addEventListener("change", (event) => {
  state.favoriteSortOrder = event.target.checked ? "historical" : "alphabetical";
  app.persistSettings();
  app.ui.refreshFavorites()
    .then(() => app.ui.renderAll())
    .catch((error) => console.error("[SPCBoy] favorites order failed", error));
});

refs.optionsRoutingTab.addEventListener("click", () => {
  state.optionsSection = "routing";
  app.ui.renderAll();
});

refs.optionsPlaybackTab.addEventListener("click", () => {
  state.optionsSection = "playback";
  app.ui.renderAll();
});

refs.optionsDiagnosticsTab.addEventListener("click", () => {
  state.optionsSection = "diagnostics";
  app.ui.renderAll();
});

refs.optionsAudioTab.addEventListener("click", () => {
  state.optionsSection = "audio";
  app.ui.renderAll();
});

refs.libraryClearCacheButton.addEventListener("click", () => {
  app.ui.clearLibraryArchiveCache().catch((error) => console.error(error));
});

refs.libraryShowCacheButton.addEventListener("click", () => {
  app.ui.showLibraryArchiveCacheInFinder().catch((error) => console.error(error));
});

refs.libraryCacheBrowseButton?.addEventListener("click", () => {
  if (state.archiveCacheLocation) window.spcBoyWK?.showInFinder?.(state.archiveCacheLocation);
});

refs.libraryCacheDefaultButton?.addEventListener("click", () => {
  app.ui.refreshArchiveCacheSummary().catch((error) => console.error(error));
});

refs.archiveCacheEnabledCheckbox.addEventListener("change", (event) => {
  app.ui.setArchiveCacheEnabled(event.target.checked);
});

refs.archiveCacheLimitSelect.addEventListener("change", (event) => {
  app.ui.setArchiveCacheLimit(event.target.value);
});

refs.optionsOverlay.addEventListener("click", (event) => {
  if (event.target === refs.optionsOverlay) {
    app.ui.setOptionsOpen(false);
  }
});

let dragDepth = 0;

function droppedPath(event) {
  const file = [...(event.dataTransfer?.files || [])][0];
  return file?.path || null;
}

function hasDroppedFiles(event) {
  return Array.from(event.dataTransfer?.types || []).includes("Files");
}

document.addEventListener("dragenter", (event) => {
  if (!hasDroppedFiles(event)) return;
  event.preventDefault();
  dragDepth += 1;
  document.body.classList.add("is-file-drag-over");
});

document.addEventListener("dragleave", (event) => {
  if (!hasDroppedFiles(event)) return;
  event.preventDefault();
  dragDepth = Math.max(0, dragDepth - 1);
  if (!dragDepth) document.body.classList.remove("is-file-drag-over");
});

document.addEventListener("dragover", (event) => {
  if (!hasDroppedFiles(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = "copy";
});

document.addEventListener("drop", (event) => {
  if (!hasDroppedFiles(event)) return;
  event.preventDefault();
  dragDepth = 0;
  document.body.classList.remove("is-file-drag-over");
  const inputPath = droppedPath(event);
  if (!inputPath) return;
  window.spcBoyWK.openPath(inputPath)
    .then((snapshot) => app.ui.applyLibrarySnapshot(snapshot))
    .catch((error) => console.error("[SPCBoy] dropped path failed", error));
});

refs.sidebarSearchInput.addEventListener("input", (event) => {
  app.ui.updateSidebarSearch(event.target.value).catch((error) => console.error("[SPCBoy] sidebar search failed", error));
});

refs.sidebarViewToggleButton?.addEventListener("click", () => {
  app.ui.cycleSidebarMode().catch((error) => console.error("[SPCBoy] sidebar view switch failed", error));
});

if (window.spcBoyWK?.onTransportShortcut) {
  window.spcBoyWK.onTransportShortcut((action) => {
    if (action === "settings") {
      window.spcBoyWK.openOptionsWindow().catch((error) => console.error(error));
      return;
    }

    if (action === "toggle") {
      app.playback.togglePlayback().catch((error) => {
        console.error(error);
      });
      return;
    }

    if (action === "previous") {
      app.playback.playAdjacent(-1);
      return;
    }

    if (action === "next") {
      app.playback.playAdjacent(1);
    }
  });
}

if (window.spcBoyWK?.onLibrarySnapshot) {
  window.spcBoyWK.onLibrarySnapshot((snapshot) => {
    if (!snapshot) {
      return;
    }

    app.ui.applyLibrarySnapshot(snapshot);
  });
}

if (window.spcBoyWK?.onLibraryCommand) {
  window.spcBoyWK.onLibraryCommand((command) => {
    if (command?.type === "sidebar-view") {
      app.ui.setSidebarMode(command.view).catch((error) => console.error("[SPCBoy] sidebar view switch failed", error));
      return;
    }
    if (command?.type !== "open-root") {
      return;
    }

    app.ui.openLibraryRoot().catch((error) => {
      console.error(error);
    });
  });
}

if (window.spcBoyWK?.onNativePlaybackState) {
  window.spcBoyWK.onNativePlaybackState((snapshot) => {
    app.playback.handleNativePlaybackState(snapshot);
  });
}

if (window.spcBoyWK?.onNativePlaybackEnded) {
  window.spcBoyWK.onNativePlaybackEnded((snapshot) => {
    app.playback.handleNativePlaybackEnded(snapshot);
  });
}

if (window.spcBoyWK?.onNativeAACExport) {
  window.spcBoyWK.onNativeAACExport((event) => {
    app.playback.handleAACExportEvent(event);
  });
}

window.addEventListener("keydown", (event) => {
  const target = event.target;
  const isRangeInput = target instanceof HTMLInputElement && target.type === "range";
  if (!event.metaKey && !event.ctrlKey && !event.altKey && (event.key === "-" || event.key === "=" || event.key === "Subtract" || event.key === "Equal") && (!target || !target.isContentEditable) && (!target.tagName || target.tagName !== "TEXTAREA") && (!target.tagName || target.tagName !== "INPUT" || isRangeInput)) {
    event.preventDefault();
    app.ui.adjustAppVolume(event.key === "-" || event.key === "Subtract" ? -0.05 : 0.05);
    return;
  }
  const isTextEntry = target instanceof HTMLElement && (
    (target.tagName === "INPUT" && target.type !== "range") ||
    target.tagName === "TEXTAREA" ||
    target.isContentEditable
  );

  if (isTextEntry) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "a") {
      if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement) {
        target.select();
        event.preventDefault();
      }
      return;
    }

    if (event.key === "Enter") {
      const input = target;
      input.blur();
      event.preventDefault();
      return;
    }

    if (event.key === "Escape" && state.optionsOpen) {
      event.preventDefault();
      app.ui.setOptionsOpen(false);
    }
    return;
  }

  if (event.metaKey && event.shiftKey && !event.ctrlKey && !event.altKey && event.key.toLowerCase() === "d" && !state.optionsOpen) {
    event.preventDefault();
    app.ui.showFavoritesPlaylist().catch((error) => console.error("[SPCBoy] favorites playlist failed", error));
    return;
  }

  if (event.metaKey && !event.shiftKey && !event.ctrlKey && !event.altKey && event.key.toLowerCase() === "d" && !state.optionsOpen) {
    event.preventDefault();
    app.ui.toggleSelectedFavorites().catch((error) => console.error("[SPCBoy] favorite toggle failed", error));
    return;
  }

  if ((event.metaKey || event.ctrlKey) && !event.altKey && event.key.toLowerCase() === "a" && !state.optionsOpen && refs.playlistBody.contains(event.target)) {
    event.preventDefault();
    app.ui.selectAllPlaylistTracks();
    return;
  }

  if (event.key === "F7") {
    event.preventDefault();
    app.playback.playAdjacent(-1);
    return;
  }

  if (event.key === "F8") {
    event.preventDefault();
    app.playback.togglePlayback().catch((error) => {
      console.error(error);
    });
    return;
  }

  if (event.key === "F9") {
    event.preventDefault();
    app.playback.playAdjacent(1);
    return;
  }

  if (event.metaKey && !event.ctrlKey && !event.altKey && !state.optionsOpen && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
    if (app.ui.jumpFocusedListToEdge(event.key === "ArrowDown", event.target)) {
      event.preventDefault();
      return;
    }
  }

  if (event.key === "ArrowDown" && !state.optionsOpen) {
    event.preventDefault();
    app.ui.moveSelection(1, { range: event.shiftKey, extend: event.metaKey || event.ctrlKey });
    return;
  }

  if (event.key === "ArrowUp" && !state.optionsOpen) {
    event.preventDefault();
    app.ui.moveSelection(-1, { range: event.shiftKey, extend: event.metaKey || event.ctrlKey });
    return;
  }

  if (event.key === "Enter" && !state.optionsOpen) {
    event.preventDefault();
    app.ui.activateFocusedItem(event.target).then((handled) => {
      if (handled) return;
      if (state.sidebarView.contentMode === "database") {
        app.ui.activateDatabaseSelection();
        return;
      }
      app.ui.playSelectedTrack();
    }).catch((error) => console.error("[SPCBoy] Enter activation failed", error));
    return;
  }

  if (event.key === "Escape" && state.optionsOpen) {
    event.preventDefault();
    app.ui.setOptionsOpen(false);
  }
});

app.ui.bootstrap().catch((error) => {
  console.error(error);
});

window.addEventListener("focus", () => {
  if (window.spcBoyWK?.isOptionsWindow) return;
  app.ui.refreshFavorites()
    .then(() => {
      app.ui.renderSidebar();
      app.ui.renderPlaylist();
    })
    .catch((error) => console.error("[SPCBoy] Favorites refresh failed", error));
});
})();
