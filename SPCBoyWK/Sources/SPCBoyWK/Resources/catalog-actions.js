(() => {
function create({
  state,
  refs,
  sidebarView,
  searchRecords,
  filterSearchRecords,
  resolveSidebarState,
  persistSettings,
  invalidatePlaylistCatalogSession,
  renderAll,
  renderSidebar,
  renderPlaylist,
  syncTreeSelection,
  refreshFavorites,
  resolveSelectedTrackId,
  targetPlaybackSeconds,
  databaseGameKey,
  databaseConsoleName,
  databaseRowsToPlaylistTracks,
  databaseLoadedSelectionID,
  playVisibleTrack,
  reportDatabaseSidebarError,
  playback
}) {
  let databaseGameSearchRecords = [];

  function rebuildDatabaseGameSearchIndex(games = state.databaseGames) {
    databaseGameSearchRecords = searchRecords(games);
  }

  function localDatabaseSearch(query) {
    return filterSearchRecords(databaseGameSearchRecords, query, state.databaseGames);
  }

  async function syncSidebarView() {
    state.sidebarView = Object.freeze(await resolveSidebarState(state.sidebarMode, state.sidebarQuery));
    return state.sidebarView;
  }

  async function loadDatabaseGames() {
    state.databaseSidebarLoading = true;
    state.databaseSidebarError = "";
    renderAll();
    try {
      await refreshDatabaseGamesForVisibleRoots();
    } finally {
      state.databaseSidebarLoading = false;
      renderAll();
    }
  }

  async function loadDatabaseFiles() {
    state.databaseSidebarLoading = true;
    state.databaseSidebarError = "";
    renderAll();
    try {
      const fileTree = await window.spcBoyWK.databaseFileTree();
      if (fileTree?.stale === true) return false;
      state.databaseFileTree = fileTree;
      // The tree is the complete database projection. This array is retained
      // only as the loaded sentinel for the existing mode-switch lifecycle.
      state.databaseFiles = state.databaseFileTree;
      state.databaseSidebarError = "";
      return true;
    } catch (error) {
      reportDatabaseSidebarError("read the catalog paths", error);
      throw error;
    } finally {
      state.databaseSidebarLoading = false;
      renderAll();
    }
  }

  async function setSidebarMode(mode) {
    if (!["paths", "consoles", "diskPath"].includes(mode)) return;
    if (state.localBrowserEnabled && mode !== "diskPath") return;
    await invalidatePlaylistCatalogSession();
    state.sidebarMode = mode;
    state.sidebarQuery = "";
    await syncSidebarView();
    refs.sidebarSearchInput.value = "";
    state.databaseSearchGames = null;
    if (mode === "paths" && !state.databaseFiles.length) await loadDatabaseFiles();
    if (mode === "consoles" && !state.databaseGames.length) await loadDatabaseGames();
    persistSettings();
    renderAll();
    syncTreeSelection();
  }

  async function showFavoritesPlaylist() {
    await refreshFavorites();
    await invalidatePlaylistCatalogSession();
    state.playlist = [...state.favorites];
    state.selectedTrackId = state.playlist[0]?.id || null;
    state.selectedTrackIds = state.selectedTrackId ? [state.selectedTrackId] : [];
    state.lastSelectedTrackId = state.selectedTrackId;
    persistSettings();
    renderPlaylist();
    renderSidebar();
  }

  async function refreshDatabaseGamesForVisibleRoots() {
    const previousSelection = state.selectedDatabaseGameKey;
    try {
      const games = await window.spcBoyWK.databaseGames();
      if (games?.stale === true) return false;
      state.databaseGames = games;
      rebuildDatabaseGameSearchIndex(state.databaseGames);
    } catch (error) {
      reportDatabaseSidebarError("read the database sidebar", error);
      throw error;
    }
    state.databaseSidebarError = "";
    state.databaseSearchGames = null;
    if (previousSelection && !state.databaseGames.some((game) => databaseGameKey(game) === previousSelection)) {
      state.selectedDatabaseGameKey = null;
      state.playlist = [];
      state.selectedTrackId = null;
      state.lastSelectedTrackId = null;
      persistSettings();
    }
    return true;
  }

  async function updateSidebarSearch(query) {
    state.sidebarQuery = String(query || "");
    state.databaseSidebarError = "";
    state.databaseSearchGames = state.sidebarQuery.trim()
      ? localDatabaseSearch(state.sidebarQuery)
      : null;
    // Search is a view-policy projection, not a catalog read. Keeping this
    // synchronous removes the bridge round-trip and debounce from every keypress
    // while preserving CatalogBrowserCore's query semantics locally.
    state.sidebarView = Object.freeze(sidebarView(state.sidebarMode, state.sidebarQuery));
    renderSidebar();
  }

  const SIDEBAR_VIEW_CYCLE = ["consoles", "paths"];

  async function cycleSidebarMode() {
    if (state.localBrowserEnabled) return;
    const current = state.sidebarView.storedMode;
    const currentIndex = SIDEBAR_VIEW_CYCLE.indexOf(current);
    const next = SIDEBAR_VIEW_CYCLE[(currentIndex + 1 + SIDEBAR_VIEW_CYCLE.length) % SIDEBAR_VIEW_CYCLE.length];
    await setSidebarMode(next);
  }

  async function loadDatabaseGamesIntoPlaylist(games) {
    await invalidatePlaylistCatalogSession();
    const rows = await window.spcBoyWK.databaseGameTracks(games);
    if (rows?.stale === true) return false;
    state.databaseSidebarError = "";
    state.selectedDatabaseGameKey = games.length === 1 ? databaseGameKey(games[0]) : null;
    state.playlist = databaseRowsToPlaylistTracks(rows, games);
    // Sidebar selection is a preview operation. It must not replace the
    // playback queue or clear the active track; explicit Play/Enter adopts this
    // visible playlist through playTrack({ replaceQueue: true }).
    state.selectedTrackId = resolveSelectedTrackId(state.playlist);
    state.selectedTrackIds = state.selectedTrackId ? [state.selectedTrackId] : [];
    state.lastSelectedTrackId = state.selectedTrackId;
    persistSettings();
    // Database rows already contain their catalog metadata. Keep playlist
    // hydration independent from the 21k-entry sidebar redraw; rebuilding the
    // sidebar here made a small indexed query wait on every database row DOM
    // update before the playlist could paint.
    renderPlaylist();
    playback.updateTimingSummary();
    playback.updatePlaybackReadout();
    playback.updateNativeDiagnostics();
    return true;
  }

  async function loadDatabaseGame(game) {
    return loadDatabaseGamesIntoPlaylist([game]);
  }

  async function activateDatabaseSelection() {
    const gamesForView = Array.isArray(state.databaseSearchGames) ? state.databaseSearchGames : state.databaseGames;
    const selectedGame = gamesForView.find((entry) => databaseGameKey(entry) === state.selectedDatabaseGameKey);
    if (selectedGame) {
      const loaded = await loadDatabaseGame(selectedGame);
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) await playVisibleTrack(targetID, 0);
      return;
    }
    if (state.selectedDatabaseConsoleName) {
      const games = gamesForView.filter((game) => databaseConsoleName(game) === state.selectedDatabaseConsoleName);
      if (games.length) {
        const loaded = await loadDatabaseGamesIntoPlaylist(games);
        const targetID = loaded ? databaseLoadedSelectionID() : null;
        if (targetID) await playVisibleTrack(targetID, 0);
        return;
      }
    }
  }

  return Object.freeze({
    activateDatabaseSelection,
    cycleSidebarMode,
    loadDatabaseFiles,
    loadDatabaseGame,
    loadDatabaseGames,
    localDatabaseSearch,
    rebuildDatabaseGameSearchIndex,
    refreshDatabaseGamesForVisibleRoots,
    setSidebarMode,
    showFavoritesPlaylist,
    syncSidebarView,
    updateSidebarSearch
  });
}

window.SPCBoyCatalogActions = Object.freeze({ create });
})();
