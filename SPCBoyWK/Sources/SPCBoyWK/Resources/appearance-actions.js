(() => {
function create({
  state,
  persistSettings,
  broadcastAppearanceSettings,
  renderAll,
  renderPlaylist,
  renderSidebar,
  invalidateDatabaseSidebar,
  normalizeItemSpacing,
  normalizeFontSize,
  normalizeSidebarWidth,
  normalizeFontColor,
  normalizeAccentColor,
  normalizeAnimationMilliseconds,
  parseNumericInput,
  setAnimation,
  setWindowLevel
}) {
  function setUiItemSpacing(nextSpacingRem) {
    state.uiItemSpacingRem = normalizeItemSpacing(nextSpacingRem);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setFontSize(nextSize) {
    const size = normalizeFontSize(nextSize);
    state.uiFontSizePt = size;
    state.sidebarFontSizePt = size;
    state.playlistFontSizePt = size;
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setSidebarWidth(nextWidth) {
    state.sidebarWidthPercent = normalizeSidebarWidth(nextWidth);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function commitFontSizeInput(rawValue) {
    const parsedValue = parseNumericInput(rawValue);
    setFontSize(parsedValue ?? state.uiFontSizePt);
  }

  function commitSidebarFontSizeInput(rawValue) {
    const parsedValue = parseNumericInput(rawValue);
    setFontSize(parsedValue ?? state.uiFontSizePt);
  }

  function setSidebarTextColor(color) {
    const normalized = normalizeFontColor(color);
    state.sidebarTextColor = normalized;
    state.playlistTextColor = normalized;
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setSidebarMonospace(enabled) {
    state.sidebarMonospace = Boolean(enabled);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setSidebarPathCounts(enabled) {
    state.sidebarPathCounts = Boolean(enabled);
    persistSettings();
    broadcastAppearanceSettings();
    invalidateDatabaseSidebar();
    renderSidebar();
  }

  function commitPlaylistFontSizeInput(rawValue) {
    const parsedValue = parseNumericInput(rawValue);
    state.playlistFontSizePt = normalizeFontSize(parsedValue ?? state.playlistFontSizePt);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setPlaylistTextColor(color) {
    state.playlistTextColor = normalizeFontColor(color);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setPlaylistMonospace(enabled) {
    state.playlistMonospace = Boolean(enabled);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setApplicationMonospace(enabled) {
    const value = Boolean(enabled);
    state.applicationMonospace = value;
    state.sidebarMonospace = value;
    state.playlistMonospace = value;
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setPlaylistHeaderBold(enabled) {
    state.playlistHeaderBold = Boolean(enabled);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function setColumnAutoSize(enabled) {
    state.columnAutoSize = Boolean(enabled);
    persistSettings();
    renderPlaylist();
  }

  function setAnimationTiming(key, value) {
    setAnimation(key, value, normalizeAnimationMilliseconds);
    persistSettings();
    renderAll();
  }

  function setAnimationEnabled(key, enabled) {
    state[key] = Boolean(enabled);
    persistSettings();
    renderAll();
  }

  function setWindowAlwaysOnTop(key, enabled) {
    setWindowLevel(key, enabled);
    persistSettings();
    renderAll();
  }

  function applyAppearanceSettings(settings) {
    if (settings.uiItemSpacingRem !== undefined) state.uiItemSpacingRem = normalizeItemSpacing(settings.uiItemSpacingRem);
    if (settings.sidebarWidthPercent !== undefined) state.sidebarWidthPercent = normalizeSidebarWidth(settings.sidebarWidthPercent);
    const interfaceFontSize = settings.uiFontSizePt ?? settings.sidebarFontSizePt ?? settings.playlistFontSizePt;
    if (interfaceFontSize !== undefined) {
      const size = normalizeFontSize(interfaceFontSize);
      state.uiFontSizePt = size;
      state.sidebarFontSizePt = size;
      state.playlistFontSizePt = size;
    }
    const interfaceFontColor = settings.sidebarTextColor ?? settings.playlistTextColor;
    if (interfaceFontColor !== undefined) {
      const color = normalizeFontColor(interfaceFontColor);
      state.sidebarTextColor = color;
      state.playlistTextColor = color;
    }
    const interfaceMonospace = settings.applicationMonospace ?? settings.sidebarMonospace ?? settings.playlistMonospace;
    if (interfaceMonospace !== undefined) {
      const enabled = Boolean(interfaceMonospace);
      state.applicationMonospace = enabled;
      state.sidebarMonospace = enabled;
      state.playlistMonospace = enabled;
    }
    if (settings.sidebarPathCounts !== undefined) state.sidebarPathCounts = Boolean(settings.sidebarPathCounts);
    if (settings.playlistHeaderBold !== undefined) state.playlistHeaderBold = Boolean(settings.playlistHeaderBold);
    if (settings.accentColor !== undefined) state.accentColor = normalizeAccentColor(settings.accentColor);
    persistSettings();
    renderAll();
  }

  function setAccentColor(color) {
    state.accentColor = normalizeAccentColor(color);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  function commitSidebarWidthInput(rawValue) {
    const parsedValue = parseNumericInput(rawValue);
    state.sidebarWidthPercent = normalizeSidebarWidth(parsedValue ?? state.sidebarWidthPercent);
    persistSettings();
    broadcastAppearanceSettings();
    renderAll();
  }

  return Object.freeze({
    applyAppearanceSettings,
    commitFontSizeInput,
    commitPlaylistFontSizeInput,
    commitSidebarFontSizeInput,
    commitSidebarWidthInput,
    setAccentColor,
    setAnimationEnabled,
    setAnimationTiming,
    setApplicationMonospace,
    setColumnAutoSize,
    setFontSize,
    setPlaylistHeaderBold,
    setPlaylistMonospace,
    setPlaylistTextColor,
    setSidebarMonospace,
    setSidebarPathCounts,
    setSidebarTextColor,
    setSidebarWidth,
    setUiItemSpacing,
    setWindowAlwaysOnTop
  });
}

window.SPCBoyAppearanceActions = Object.freeze({ create });
})();
