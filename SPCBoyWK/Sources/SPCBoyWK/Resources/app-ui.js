(() => {
const uiApp = window.SPCBoyApp;
const { state, refs, persistSettings, loadSettings, targetPlaybackSeconds, COLUMN_DEFS } = uiApp;
const { sidebarView, searchRecords, filterSearchRecords } = window.SPCBoyDatabaseView;
const { valueForColumn, sortValue } = window.SPCBoyPlaylistTable;
const catalogTrackMapper = window.SPCBoyCatalogTrackMapper.create({ state, formatTime: uiApp.formatTime });
const expandedFolders = new Set();
let metadataRefreshFrame = 0;
const metadataRefreshTrackIds = new Set();
let collapsedDatabaseConsoles = new Set();
const playlistColumns = window.SPCBoyPlaylistColumns.create({
  state,
  refs,
  COLUMN_DEFS,
  persistSettings,
  normalizeColumnOrder: uiApp.normalizeColumnOrder,
  valueForColumn,
  sortValue,
  getPlaylistRows: () => playlistRows.rows(),
  onRenderPlaylist: (options) => renderPlaylist(options)
});
const playlistRows = window.SPCBoyPlaylistRows.create({
  state,
  refs,
  columns: playlistColumns,
  valueForColumn,
  persistSettings,
  isFavoritePresentation,
  toggleFavorites,
  renderSidebar,
  showContextMenu,
  playVisibleTrack,
  exportTrackAsAAC: (track) => uiApp.playback.exportTrackAsAAC(track),
  updateTimingSummary: () => uiApp.playback.updateTimingSummary(),
  scheduleSelectionIndicators,
  onRenderPlaylist: (options) => renderPlaylist(options)
});
const playlistSelectionActions = window.SPCBoyPlaylistSelectionActions.create({
  state,
  refs,
  persistSettings,
  selectPlaylistTrack,
  refreshPlaylistPlaybackState,
  renderPlaylist,
  playlistRows,
  updateTimingSummary: () => uiApp.playback.updateTimingSummary(),
  getSelectedTrack: () => uiApp.selectedTrack(),
  playVisibleTrack
});
const playbackSettingsActions = window.SPCBoyPlaybackSettingsActions.create({
  state,
  persistSettings,
  renderAll: () => renderAll(),
  refreshPlaybackForTimingChange: () => uiApp.playback.refreshPlaybackForTimingChange(),
  normalizeLongPlayTime: uiApp.normalizeLongPlayTime,
  normalizeFadeTime: uiApp.normalizeFadeTime,
  normalizePlayTime: uiApp.normalizePlayTime,
  parseDurationSeconds: uiApp.parseDurationSeconds
});
const audioSettingsActions = window.SPCBoyAudioSettingsActions.create({
  state,
  persistSettings,
  nativePlaybackAudioConfig: (...args) => window.spcBoyWK?.nativePlaybackAudioConfig?.(...args),
  setAudioSettings: (settings) => uiApp.playback.setAudioSettings?.(settings),
  normalizeEqualizerGain: uiApp.normalizeEqualizerGain,
  normalizeAppVolume: uiApp.normalizeAppVolume,
  renderAll: () => renderAll()
});
const playbackSpeedActions = window.SPCBoyPlaybackSpeedActions.create({
  state,
  refs,
  persistSettings,
  parsePlaybackSpeed: uiApp.parsePlaybackSpeed,
  formatPlaybackSpeed: uiApp.formatPlaybackSpeed,
  refreshPlaybackForSpeedChange: (backendId) => uiApp.playback.refreshPlaybackForSpeedChange(backendId),
  renderAll: () => renderAll()
});
const appearanceActions = window.SPCBoyAppearanceActions.create({
  state,
  persistSettings,
  broadcastAppearanceSettings: () => broadcastAppearanceSettings(),
  renderAll: () => renderAll(),
  renderPlaylist: () => renderPlaylist(),
  renderSidebar: () => renderSidebar(),
  invalidateDatabaseSidebar: () => databaseSidebarView.invalidate(),
  normalizeItemSpacing: uiApp.normalizeItemSpacing,
  normalizeFontSize: uiApp.normalizeFontSize,
  normalizeSidebarWidth: uiApp.normalizeSidebarWidth,
  normalizeFontColor: uiApp.normalizeFontColor,
  normalizeAccentColor: uiApp.normalizeAccentColor,
  normalizeAnimationMilliseconds: uiApp.normalizeAnimationMilliseconds,
  parseNumericInput: uiApp.parseNumericInput,
  setAnimation: (key, value, normalize) => window.SPCBoyOptionsController.setAnimation(state, normalize, key, value),
  setWindowLevel: (key, enabled) => window.SPCBoyOptionsController.setWindowLevel(state, key, enabled)
});
const archiveCacheActions = window.SPCBoyArchiveCacheActions.create({
  state,
  persistSettings,
  configureArchiveCache: (settings) => window.spcBoyWK?.configureArchiveCache?.(settings),
  normalizeArchiveCacheLimit: uiApp.normalizeArchiveCacheLimit,
  renderAll: () => renderAll()
});
const routingActions = window.SPCBoyRoutingActions.create({
  state,
  persistSettings,
  candidatesForPath: (filePath) => window.SPCBoyPlaybackBackends?.candidatesForPath?.(filePath) || [],
  setRoutingPreferences: (preferences) => window.spcBoyWK?.setRoutingPreferences?.(preferences),
  renderAll: () => renderAll()
});
const favoriteActions = window.SPCBoyFavoriteActions.create({
  state,
  listFavorites: (sortOrder) => window.spcBoyWK.favoritesList(sortOrder),
  toggleFavoriteTracks: (tracks, sortOrder) => window.spcBoyWK.favoritesToggle(tracks, sortOrder),
  renderSidebar: () => renderSidebar(),
  renderPlaylist: () => renderPlaylist(),
  isSidebarFocused: () => refs.treeRoot.contains(document.activeElement),
  visibleDatabaseGames: () => visibleDatabaseGames(),
  databaseGameKey: (game) => databaseGameKey(game),
  databaseConsoleName: (game) => databaseConsoleName(game),
  databaseGameTracks: (games) => window.spcBoyWK.databaseGameTracks(games),
  databaseRowsToPlaylistTracks: catalogTrackMapper.databaseRowsToPlaylistTracks
});
const playlistMutationActions = window.SPCBoyPlaylistMutationActions.create({
  state,
  persistSettings,
  renderTree: () => renderTree(),
  syncTreeSelection: () => syncTreeSelection(),
  renderPlaylist: () => renderPlaylist(),
  updateTimingSummary: () => uiApp.playback.updateTimingSummary()
});
const navigationActions = window.SPCBoyNavigationActions.create({
  state,
  refs,
  currentSidebarView: () => currentSidebarView(),
  visibleBrowserNodes: () => visibleBrowserNodes(),
  selectBrowserNode: (node, options) => selectBrowserNode(node, options),
  selectPlaylistTrack: (trackId, options) => selectPlaylistTrack(trackId, options),
  updateTimingSummary: () => uiApp.playback.updateTimingSummary()
});
const appearanceView = window.SPCBoyAppearanceView.create({
  state,
  refs,
  escapeHtml,
  onSetRoutingPreference: (extension, backendId) => setRoutingPreference(extension, backendId)
});
const sidebarTree = window.SPCBoySidebarTree.create({
  state,
  refs,
  expandedFolders,
  currentSidebarView,
  escapeHtml,
  resetSidebarContent,
  scheduleSelectionIndicators,
  selectBrowserNode,
  handleBrowserPrimaryClick,
  handleBrowserGesture,
  showSidebarContextMenu,
  moveBrowserSelection,
  setSelectedBrowserButton: (button) => { selectedBrowserButton = button; }
});
const databaseSidebarView = window.SPCBoyDatabaseSidebar.create({
  state,
  refs,
  sidebarNaturalCollator: new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }),
  collapsedDatabaseConsoles,
  databaseGameKey,
  databaseConsoleName,
  escapeHtml,
  persistSettings,
  resetSidebarContent,
  positionSelectionIndicator,
  scheduleSelectionIndicators,
  applySharedDatabaseGroupAction,
  reportDatabaseSidebarError,
  showContextMenu,
  loadDatabaseGame,
  databaseLoadedSelectionID,
  playVisibleTrack,
  activateDatabaseSelection,
  appendPlaylistTracks,
  databaseRowsToPlaylistTracks: catalogTrackMapper.databaseRowsToPlaylistTracks
});
const browserActions = window.SPCBoyBrowserActions.create({
  state,
  refs,
  expandedFolders,
  persistSettings,
  databaseRowsToPlaylistTracks: catalogTrackMapper.databaseRowsToPlaylistTracks,
  applyFolderSelection,
  playVisibleTrack,
  renderTree,
  syncTreeSelection,
  filteredTree,
  findBrowserNode,
  appendPlaylistTracks
});
const catalogActions = window.SPCBoyCatalogActions.create({
  state,
  refs,
  sidebarView,
  searchRecords,
  filterSearchRecords,
  resolveSidebarState: (...args) => window.spcBoyWK.resolveSidebarState(...args),
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
  databaseRowsToPlaylistTracks: catalogTrackMapper.databaseRowsToPlaylistTracks,
  databaseLoadedSelectionID,
  playVisibleTrack,
  reportDatabaseSidebarError,
  playback: uiApp.playback
});

function syncCollapsedConsolePersistence() {
  state.collapsedConsoleNames = [...collapsedDatabaseConsoles];
  persistSettings();
}

function currentSidebarView() {
  return state.sidebarView;
}

function rebuildDatabaseGameSearchIndex(games = state.databaseGames) {
  return catalogActions.rebuildDatabaseGameSearchIndex(games);
}

function localDatabaseSearch(query) {
  return catalogActions.localDatabaseSearch(query);
}

async function syncSidebarView() {
  return catalogActions.syncSidebarView();
}

function isFavoritePresentation(track) {
  return favoriteActions.isFavoritePresentation(track);
}

async function refreshFavorites() {
  return favoriteActions.refreshFavorites();
}

async function toggleFavorites(tracks) {
  return favoriteActions.toggleFavorites(tracks);
}

function playVisibleTrack(trackId, startSeconds = 0) {
  return uiApp.playback.playTrack(trackId, startSeconds, false, { replaceQueue: true });
}
let selectedBrowserButton = null;
let selectionIndicatorFrame = 0;

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  }[character]));
}

function ensureSidebarSelectionIndicator() {
  let indicator = refs.treeRoot.querySelector(".list-selection-indicator");
  if (indicator) return indicator;
  indicator = document.createElement("div");
  indicator.className = "list-selection-indicator";
  indicator.setAttribute("aria-hidden", "true");
  refs.treeRoot.prepend(indicator);
  return indicator;
}

function resetSidebarContent() {
  // Keep the single selection surface alive across sidebar renders. Recreating
  // it on every click resets its transform, producing both flicker and stale
  // looking bars instead of one continuous 100 ms movement.
  databaseSidebarView.invalidate();
  const indicator = ensureSidebarSelectionIndicator();
  refs.treeRoot.replaceChildren(indicator);
  return indicator;
}

function positionSelectionIndicator(container, indicator, target) {
  if (!container || !indicator || !target) {
    if (indicator) indicator.style.opacity = "0";
    return;
  }
  const containerBounds = container.getBoundingClientRect();
  const targetBounds = target.getBoundingClientRect();
  if (!targetBounds.width || !targetBounds.height) {
    indicator.style.opacity = "0";
    return;
  }
  const left = targetBounds.left - containerBounds.left + container.scrollLeft;
  const top = targetBounds.top - containerBounds.top + container.scrollTop;
  indicator.style.width = `${targetBounds.width}px`;
  indicator.style.height = `${targetBounds.height}px`;
  indicator.style.transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`;
  indicator.style.opacity = "1";
}

function syncSelectionIndicators() {
  selectionIndicatorFrame = 0;
  const sidebarTarget = refs.treeRoot.querySelector(".tree-node.is-selected, .database-game-row.is-selected, .database-console-row.is-selected");
  positionSelectionIndicator(refs.treeRoot, ensureSidebarSelectionIndicator(), sidebarTarget);
  positionSelectionIndicator(refs.playlistBodyWrap, refs.playlistSelectionIndicator, playlistRows.selectedRow());
}

function scheduleSelectionIndicators() {
  if (selectionIndicatorFrame) return;
  selectionIndicatorFrame = window.requestAnimationFrame(syncSelectionIndicators);
}

function resolveSelectedTrackId(playlist, preferredTrackId = state.lastSelectedTrackId) {
  if (!Array.isArray(playlist) || playlist.length === 0) {
    return null;
  }

  if (preferredTrackId && playlist.some((track) => track.id === preferredTrackId)) {
    return preferredTrackId;
  }

  return playlist[0].id;
}

function showStartupFailure(message) {
  refs.treeRoot.innerHTML = "";
  const empty = document.createElement("div");
  empty.className = "empty sidebar-empty";
  empty.textContent = message;
  refs.treeRoot.appendChild(empty);

  refs.playlistBody.innerHTML = "";
  const row = document.createElement("tr");
  row.innerHTML = `<td colspan="7" class="empty-row">${message}</td>`;
  refs.playlistBody.appendChild(row);
}

function scrollSelectedBrowserItemIntoView() {
  return navigationActions.scrollSelectedBrowserItemIntoView();
}

async function loadBrowserChildren(node) {
  return browserActions.loadBrowserChildren(node);
}

async function invalidatePlaylistCatalogSession() {
  await window.spcBoyWK.catalogSessionInvalidate("playlist");
}

function hideSidebarContextMenu() {
  refs.sidebarContextMenu?.classList.add("is-hidden");
  if (refs.sidebarContextMenu) refs.sidebarContextMenu.innerHTML = "";
}

function showContextMenu(event, actions) {
  const menu = refs.sidebarContextMenu;
  if (!menu) return;
  event.preventDefault();
  event.stopPropagation();
  menu.innerHTML = "";
  for (const [label, action] of actions) {
    const button = document.createElement("button");
    button.type = "button";
    button.role = "menuitem";
    button.textContent = label;
    button.addEventListener("click", () => {
      hideSidebarContextMenu();
      Promise.resolve(action()).catch((error) => console.error("[SPCBoy] sidebar context action failed", error));
    });
    menu.appendChild(button);
  }
  menu.classList.remove("is-hidden");
  const margin = 6;
  const left = Math.min(event.clientX, window.innerWidth - menu.offsetWidth - margin);
  const top = Math.min(event.clientY, window.innerHeight - menu.offsetHeight - margin);
  menu.style.left = `${Math.max(margin, left)}px`;
  menu.style.top = `${Math.max(margin, top)}px`;
}

function showSidebarContextMenu(node, event) {
  state.selectedBrowserPath = node.path;
  persistSettings();
  syncTreeSelection();
  const finderPath = node.catalogFile?.path || node.catalogFolder?.folderPath || node.path;
  showContextMenu(event, [
    ["Show in Finder", async () => window.spcBoyWK.showInFinder(finderPath)],
    ["Play Now", async () => activateBrowserNode(node)],
    ["Queue", async () => queueBrowserNode(node)]
  ]);
}

async function activateBrowserNode(node, { playNow = true } = {}) {
  return browserActions.activateBrowserNode(node, { playNow });
}

async function previewBrowserLeaf(node) {
  return browserActions.previewBrowserLeaf(node);
}

async function handleBrowserPrimaryClick(node) {
  return browserActions.handleBrowserPrimaryClick(node);
}

async function handleBrowserGesture(node, gesture, wasSelected = false) {
  return browserActions.handleBrowserGesture(node, gesture, wasSelected);
}

function selectBrowserNode(node, { focus = false, previewLeaf = true } = {}) {
  return browserActions.selectBrowserNode(node, { focus, previewLeaf });
}

function visibleBrowserNodes() {
  return browserActions.visibleBrowserNodes();
}

function moveBrowserSelection(delta) {
  return browserActions.moveBrowserSelection(delta);
}

function jumpFocusedListToEdge(toEnd, focused = document.activeElement) {
  return navigationActions.jumpFocusedListToEdge(toEnd, focused);
}

function appendPlaylistTracks(additions, selectedBrowserPath = state.selectedBrowserPath) {
  return playlistMutationActions.appendPlaylistTracks(additions, selectedBrowserPath);
}

async function queueBrowserNode(node) {
  return browserActions.queueBrowserNode(node);
}

async function toggleBrowserNode(node) {
  return browserActions.toggleBrowserNode(node);
}

document.addEventListener("pointerdown", (event) => {
  if (!refs.sidebarContextMenu?.contains(event.target)) hideSidebarContextMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") hideSidebarContextMenu();
});

function findBrowserNode(nodes, targetPath) {
  return sidebarTree.findBrowserNode(nodes, targetPath);
}

function filteredTree() {
  return sidebarTree.filteredTree();
}

function renderTree() {
  selectedBrowserButton = null;
  return sidebarTree.renderTree();
}

function databaseGameKey(game) {
  return `${game.rootId}\u0000${game.name}\u0000${game.system}`;
}

function databaseConsoleName(game) {
  return game.system || "Unknown Console";
}

let databaseGroupTransitionGeneration = 0;

function databaseGroupStateSnapshot() {
  const knownGroupNames = databaseSidebarView.consoleNames();
  return {
    expandedGroupNames: knownGroupNames.filter((name) => !collapsedDatabaseConsoles.has(name)),
    selectedGroupName: state.selectedDatabaseConsoleName || null,
    selectedGameID: state.selectedDatabaseGameKey || null,
    knownGroupNames
  };
}

async function applySharedDatabaseGroupAction(action, groupName = null, gameID = null, extra = {}) {
  const generation = ++databaseGroupTransitionGeneration;
  const next = await window.spcBoyWK.databaseGroupState(
    { ...databaseGroupStateSnapshot(), ...extra },
    action,
    groupName,
    gameID
  );
  if (generation !== databaseGroupTransitionGeneration || !next) return false;
  const expanded = new Set(Array.isArray(next.expandedGroupNames) ? next.expandedGroupNames : []);
  for (const knownName of databaseSidebarView.consoleNames()) {
    if (expanded.has(knownName)) collapsedDatabaseConsoles.delete(knownName);
    else collapsedDatabaseConsoles.add(knownName);
  }
  state.selectedDatabaseConsoleName = next.selectedGroupName || null;
  state.selectedDatabaseGameKey = next.selectedGameID || null;
  syncCollapsedConsolePersistence();
  return true;
}

function visibleDatabaseGames() {
  return Array.isArray(state.databaseSearchGames) ? state.databaseSearchGames : state.databaseGames;
}

function databaseLoadedSelectionID() {
  return state.selectedTrackId || state.playlist[0]?.id || null;
}

function renderDatabaseGames() {
  return databaseSidebarView.renderDatabaseGames();
}

async function setAllDatabaseConsolesCollapsed(collapsed) {
  await applySharedDatabaseGroupAction("allCollapsed", null, null, { collapsed });
  renderDatabaseGames();
}

async function setAllSidebarNodesCollapsed(collapsed) {
  if (currentSidebarView().contentMode === "database") {
    void setAllDatabaseConsolesCollapsed(collapsed).catch((error) => reportDatabaseSidebarError("change database console disclosure", error));
    return;
  }

  if (collapsed) {
    expandedFolders.clear();
    state.selectedBrowserPath = currentSidebarView().view === "paths"
      ? state.databaseFileTree[0]?.path || null
      : state.rootPath;
    persistSettings();
    renderTree();
    syncTreeSelection();
    return;
  }

  async function expandFolder(node) {
    if (node.kind !== "folder") return;
    expandedFolders.add(node.path);
    if (currentSidebarView().view !== "paths") await loadBrowserChildren(node);
    await Promise.all(node.children.filter((child) => child.kind === "folder").map(expandFolder));
  }
  await Promise.all(state.tree.map(expandFolder));
  renderTree();
  syncTreeSelection();
}

async function loadDatabaseGames() {
  return catalogActions.loadDatabaseGames();
}

async function loadDatabaseFiles() {
  return catalogActions.loadDatabaseFiles();
}

async function setSidebarMode(mode) {
  return catalogActions.setSidebarMode(mode);
}

async function showFavoritesPlaylist() {
  return catalogActions.showFavoritesPlaylist();
}

async function refreshDatabaseGamesForVisibleRoots() {
  return catalogActions.refreshDatabaseGamesForVisibleRoots();
}

async function updateSidebarSearch(query) {
  return catalogActions.updateSidebarSearch(query);
}

async function cycleSidebarMode() {
  return catalogActions.cycleSidebarMode();
}

async function loadDatabaseGame(game) {
  return catalogActions.loadDatabaseGame(game);
}

async function toggleSelectedFavorites() {
  return favoriteActions.toggleSelectedFavorites();
}

function reportDatabaseSidebarError(action, error) {
  const detail = String(error?.message || error || "Unknown database error");
  state.databaseSidebarError = `Could not ${action}: ${detail}`;
  console.error(`[SPCBoy] could not ${action}`, error);
  if (currentSidebarView().contentMode === "database") renderDatabaseGames();
}

function databaseRowsToPlaylistTracks(rows, games) {
  return catalogTrackMapper.databaseRowsToPlaylistTracks(rows, games);
}

async function activateDatabaseSelection() {
  return catalogActions.activateDatabaseSelection();
}

async function activateFocusedItem(focusTarget = document.activeElement) {
  const focused = focusTarget?.closest?.(".playlist-row, .tree-node, .database-game-row, .database-console-row") || document.activeElement;
  const playlistRow = focused?.closest?.(".playlist-row");
  if (playlistRow?.dataset.trackId) {
    // Enter on a playlist row activates that row. Never substitute the
    // previously selected or playing track when DOM focus has moved.
    const track = selectPlaylistTrack(playlistRow.dataset.trackId, { focus: true });
    if (!track) return false;
    await playVisibleTrack(track.id, 0);
    return true;
  }

  const browserButton = focused?.closest?.(".tree-node");
  if (browserButton?.dataset.browserPath) {
    const node = findBrowserNode(filteredTree(), browserButton.dataset.browserPath);
    if (node) {
      await activateBrowserNode(node);
      return true;
    }
  }

  const databaseGameButton = focused?.closest?.(".database-game-row");
  if (databaseGameButton?.dataset.databaseGameKey) {
    const game = visibleDatabaseGames().find((entry) => databaseGameKey(entry) === databaseGameButton.dataset.databaseGameKey);
    if (game) {
      databaseSidebarView.cancelPendingGameClick();
      state.selectedDatabaseGameKey = databaseGameButton.dataset.databaseGameKey;
      state.selectedDatabaseConsoleName = databaseConsoleName(game);
      persistSettings();
      const loaded = await loadDatabaseGame(game);
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) await playVisibleTrack(targetID, 0);
      return true;
    }
  }

  const databaseConsoleButton = focused?.closest?.(".database-console-row");
  if (databaseConsoleButton?.dataset.databaseConsoleName) {
    state.selectedDatabaseConsoleName = databaseConsoleButton.dataset.databaseConsoleName;
    await activateDatabaseSelection();
    return true;
  }

  return false;
}

function renderSidebar() {
  const view = currentSidebarView();
  const labels = { paths: "Path View", consoles: "Console View", diskPath: "Local Files" };
  const glyphs = { paths: "#icon-folder-tree", consoles: "#icon-database", diskPath: "#icon-folder-tree" };
  if (refs.sidebarViewToggleButton) {
    const title = labels[view.storedMode] || labels.consoles;
    refs.sidebarViewToggleButton.title = title;
    refs.sidebarViewToggleButton.setAttribute("aria-label", title);
    refs.sidebarViewToggleButton.querySelector("use")?.setAttribute("href", glyphs[view.storedMode] || glyphs.consoles);
  }
  if (state.databaseSidebarLoading) {
    const indicator = resetSidebarContent();
    const loading = document.createElement("div");
    loading.className = "empty sidebar-empty sidebar-loading";
    loading.textContent = "Loading catalog…";
    refs.treeRoot.appendChild(loading);
    positionSelectionIndicator(refs.treeRoot, indicator, null);
    return;
  }
  if (view.contentMode === "database") renderDatabaseGames();
  else renderTree();
}

function syncAnimatedRanges() {
  document.querySelectorAll(".animated-range").forEach((input) => {
    const minimum = Number(input.min || 0);
    const maximum = Number(input.max || 100);
    const value = Number(input.value || 0);
    const percent = maximum > minimum
      ? ((value - minimum) / (maximum - minimum)) * 100
      : 0;
    input.parentElement?.style.setProperty("--range-percent", `${Math.max(0, Math.min(100, percent))}%`);
  });
}

function syncTreeSelection() {
  if (selectedBrowserButton?.dataset.browserPath !== state.selectedBrowserPath) {
    selectedBrowserButton?.classList.remove("is-selected");
    selectedBrowserButton = state.selectedBrowserPath
      ? refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`)
      : null;
    selectedBrowserButton?.classList.add("is-selected");
  }
  scrollSelectedBrowserItemIntoView();
  scheduleSelectionIndicators();
}

function allColumns() {
  return playlistColumns.allColumns();
}

function orderedColumns() {
  return playlistColumns.orderedColumns();
}

function sortPlaylist() {
  return playlistColumns.sortPlaylist();
}

function autoSizeColumns() {
  return playlistColumns.autoSizeColumns();
}

function autoSizeColumn(columnId) {
  return playlistColumns.autoSizeColumn(columnId);
}

function renderPlaylistHeader() {
  return playlistColumns.renderHeader();
}

function playlistAutoSizeSignature() {
  return playlistColumns.autoSizeSignature();
}

function syncPlaylistColumnWidths() {
  return playlistColumns.syncWidths();
}

function renderPlaylistCell(track, column, rowIndex) {
  return playlistRows.renderPlaylistCell(track, column, rowIndex);
}

function selectPlaylistTrack(trackId, options = {}) {
  return playlistRows.selectPlaylistTrack(trackId, options);
}

function refreshPlaylistPlaybackState() {
  return playlistRows.refreshPlaylistPlaybackState();
}

function refreshPlaylistRow(trackId) {
  return playlistRows.refreshPlaylistRow(trackId);
}

function playlistSortDependsOnMetadata() {
  return playlistRows.playlistSortDependsOnMetadata();
}

function renderPlaylist({ sort = true } = {}) {
  return playlistRows.renderPlaylist({ sort });
}

function scheduleMetadataRefresh(trackId) {
  if (trackId) metadataRefreshTrackIds.add(trackId);
  if (metadataRefreshFrame) {
    return;
  }

  metadataRefreshFrame = window.requestAnimationFrame(() => {
    metadataRefreshFrame = 0;
    const trackIds = [...metadataRefreshTrackIds];
    metadataRefreshTrackIds.clear();
    const mustReorder = playlistSortDependsOnMetadata();
    if (mustReorder || trackIds.some((id) => !refreshPlaylistRow(id))) {
      renderPlaylist();
    } else if (!playlistColumns.isResizing() && state.columnAutoSize && trackIds.length) {
      playlistColumns.markAutoSized();
      autoSizeColumns();
      renderPlaylistHeader();
      syncPlaylistColumnWidths();
    }
    uiApp.playback.updateTimingSummary();
  });
}

function applyUISettings() {
  return appearanceView.applyUISettings();
}

function appearanceSettings() {
  return appearanceView.appearanceSettings();
}

function broadcastAppearanceSettings() {
  window.spcBoyWK?.setAppearanceSettings?.(appearanceSettings());
}

function formatArchiveCacheSummary(summary) {
  return appearanceView.formatArchiveCacheSummary(summary);
}

function renderRoutingConflicts() {
  return appearanceView.renderRoutingConflicts();
}

function setRoutingPreference(extension, backendId) {
  return routingActions.setRoutingPreference(extension, backendId);
}

function applyRoutingPreferences(preferences) {
  return routingActions.applyRoutingPreferences(preferences);
}

function renderAll() {
  applyUISettings();
  refs.optionsOverlay.classList.toggle("is-hidden", !state.optionsOpen);
  refs.optionsOverlay.setAttribute("aria-hidden", state.optionsOpen ? "false" : "true");
  const databaseSelected = state.optionsSection === "database";
  const routingSelected = state.optionsSection === "routing";
  const playbackSelected = state.optionsSection === "playback";
  const diagnosticsSelected = state.optionsSection === "diagnostics";
  const audioSelected = state.optionsSection === "audio";
  const themeSelected = state.optionsSection === "theme";
  const windowsSelected = state.optionsSection === "windows";
  refs.optionsDatabaseTab.classList.toggle("is-selected", databaseSelected);
  refs.optionsRoutingTab.classList.toggle("is-selected", routingSelected);
  refs.optionsPlaybackTab.classList.toggle("is-selected", playbackSelected);
  refs.optionsDiagnosticsTab.classList.toggle("is-selected", diagnosticsSelected);
  refs.optionsAudioTab.classList.toggle("is-selected", audioSelected);
  refs.optionsThemeTab.classList.toggle("is-selected", themeSelected);
  refs.optionsWindowsTab.classList.toggle("is-selected", windowsSelected);
  refs.optionsThemeSection.classList.toggle("is-hidden", !themeSelected);
  refs.optionsWindowsSection.classList.toggle("is-hidden", !windowsSelected);
  refs.optionsDatabaseSection.classList.toggle("is-hidden", !databaseSelected);
  refs.optionsRoutingSection.classList.toggle("is-hidden", !routingSelected);
  refs.optionsPlaybackSection.classList.toggle("is-hidden", !playbackSelected);
  refs.optionsDiagnosticsSection.classList.toggle("is-hidden", !diagnosticsSelected);
  refs.optionsAudioSection.classList.toggle("is-hidden", !audioSelected);
  renderRoutingConflicts();
  if (document.activeElement !== refs.sidebarFontSizeInput) refs.sidebarFontSizeInput.value = String(state.uiFontSizePt);
  if (document.activeElement !== refs.sidebarTextColorInput) refs.sidebarTextColorInput.value = state.sidebarTextColor;
  refs.sidebarPathCountsCheckbox.checked = state.sidebarPathCounts;
  if (document.activeElement !== refs.accentColorInput) refs.accentColorInput.value = state.accentColor;
  refs.applicationMonospaceCheckbox.checked = state.applicationMonospace;
  if (refs.aacExportDirectoryPath) refs.aacExportDirectoryPath.value = state.aacExportDirectory || "";
  if (refs.aacExportStatus) refs.aacExportStatus.textContent = state.aacExportStatus || "";
  if (refs.aacExportCancelButton) refs.aacExportCancelButton.disabled = !state.aacExportInProgress;
  refs.playlistHeaderBoldCheckbox.checked = state.playlistHeaderBold;
  if (document.activeElement !== refs.spcUnknownDurationInput) refs.spcUnknownDurationInput.value = uiApp.formatTime(state.unknownDurationSeconds);
  refs.columnAutoSizeCheckbox.checked = state.columnAutoSize;
  refs.autoResizeAnimationEnabledCheckbox.checked = state.autoResizeAnimationEnabled;
  refs.autoResizeAnimationInput.value = String(state.autoResizeAnimationMilliseconds);
  refs.autoResizeAnimationInput.disabled = !state.autoResizeAnimationEnabled;
  refs.selectionAnimationEnabledCheckbox.checked = state.selectionAnimationEnabled;
  refs.selectionAnimationInput.value = String(state.selectionAnimationMilliseconds);
  refs.selectionAnimationInput.disabled = !state.selectionAnimationEnabled;
  refs.mainWindowAlwaysOnTopCheckbox.checked = state.mainWindowAlwaysOnTop;
  refs.settingsWindowAlwaysOnTopCheckbox.checked = state.settingsWindowAlwaysOnTop;
  refs.archiveCacheEnabledCheckbox.checked = state.archiveCacheEnabled;
  refs.archiveCacheLimitSelect.value = String(state.archiveCacheLimitBytes);
  refs.archiveCacheLimitSelect.disabled = !state.archiveCacheEnabled;
  refs.localBrowserEnabledCheckbox.checked = state.localBrowserEnabled;
  refs.localBrowserPath.value = state.rootPath || "";
  refs.favoriteHistoricalSortCheckbox.checked = state.favoriteSortOrder === "historical";
  [refs.libraryDatabaseBrowseButton, refs.libraryDatabaseShowButton, refs.libraryDatabaseDefaultButton, refs.libraryDatabaseReloadButton]
    .forEach((control) => { control.disabled = state.localBrowserEnabled; });
  refs.playbackSpeedEnabledCheckbox.checked = state.playbackSpeedEnabled;
  if (document.activeElement !== refs.playbackSpeedInput) refs.playbackSpeedInput.value = uiApp.formatPlaybackSpeed(state.playbackSpeed);
  refs.libvgmPlaybackSpeedEnabledCheckbox.checked = state.libvgmPlaybackSpeedEnabled;
  if (document.activeElement !== refs.libvgmPlaybackSpeedInput) refs.libvgmPlaybackSpeedInput.value = uiApp.formatPlaybackSpeed(state.libvgmPlaybackSpeed);
  refs.longPlayButton.classList.toggle("is-selected", state.longPlayEnabled);
  refs.longPlayButton.setAttribute("aria-pressed", state.longPlayEnabled ? "true" : "false");
  refs.longPlayButton.title = state.longPlayEnabled ? "Long Play enabled" : "Long Play disabled";
  refs.longPlayButton.setAttribute("aria-label", refs.longPlayButton.title);
  const repeatTitles = { off: "Repeat off", all: "Repeat all", one: "Repeat one" };
  refs.repeatButton.dataset.repeatMode = state.repeatMode;
  refs.repeatButton.classList.toggle("is-selected", state.repeatMode !== "off");
  refs.repeatButton.setAttribute("aria-pressed", state.repeatMode === "off" ? "false" : "true");
  refs.repeatButton.title = repeatTitles[state.repeatMode];
  refs.repeatButton.setAttribute("aria-label", repeatTitles[state.repeatMode]);
  const databasePath = state.databaseLocation?.path || "";
  const archiveCachePath = state.archiveCacheLocation || "";
  refs.libraryDatabasePath.value = databasePath;
  refs.libraryDatabasePath.title = databasePath;
  if (refs.libraryCachePath) {
    refs.libraryCachePath.value = archiveCachePath;
    refs.libraryCachePath.title = archiveCachePath;
  }
  refs.libraryDatabaseLocationStatus.textContent = state.databaseLocationStatus || "SPCBoy reads this schema-23 catalog. ScanSong owns scan paths, scanning, link checks, and cleanup.";
  refs.libraryDatabaseReloadButton.disabled = Boolean(state.databaseLocation?.requiresRestart);
  refs.libraryClearCacheButton.disabled = false;
  refs.databaseCacheSummary.textContent = state.archiveCacheSummary ? formatArchiveCacheSummary(state.archiveCacheSummary) : "—";
  refs.equalizerEnabledCheckbox.checked = state.equalizerEnabled;
  refs.equalizerToolbarButton.classList.toggle("is-selected", state.equalizerEnabled);
  refs.equalizerToolbarButton.setAttribute("aria-pressed", state.equalizerEnabled ? "true" : "false");
  refs.equalizerToolbarButton.title = state.equalizerEnabled ? "Disable Equalizer" : "Enable Equalizer";
  refs.equalizerToolbarButton.setAttribute("aria-label", refs.equalizerToolbarButton.title);
  refs.appVolumeInput.value = String(state.appVolume);
  refs.appVolumeValue.textContent = `${Math.round(state.appVolume * 100)}%`;
  refs.monoEnabledCheckbox.checked = state.monoEnabled;
  refs.equalizerBandInputs.forEach((input, index) => {
    input.value = String(state.equalizerBandGains[index] || 0);
    refs.equalizerBandValues[index].textContent = `${(state.equalizerBandGains[index] || 0) >= 0 ? "+" : ""}${(state.equalizerBandGains[index] || 0).toFixed(1)} dB`;
  });
  syncAnimatedRanges();
  renderSidebar();
  renderPlaylistHeader();
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
  uiApp.playback.updateNativeDiagnostics();
}

function scrollSelectedTrackIntoView() {
  return playlistSelectionActions.scrollSelectedTrackIntoView();
}

function moveSelection(delta, { range = false, extend = false } = {}) {
  return playlistSelectionActions.moveSelection(delta, { range, extend });
}

function selectAllPlaylistTracks() {
  return playlistSelectionActions.selectAllPlaylistTracks();
}

function playSelectedTrack() {
  return playlistSelectionActions.playSelectedTrack();
}

function setPlayTime(nextSeconds) {
  return playbackSettingsActions.setPlayTime(nextSeconds);
}

function setSpcForceManualTime(nextEnabled) {
  return playbackSettingsActions.setSpcForceManualTime(nextEnabled);
}

function cycleRepeatMode() {
  return playbackSettingsActions.cycleRepeatMode();
}

function setSpcFadeTime(nextSeconds) {
  return playbackSettingsActions.setSpcFadeTime(nextSeconds);
}

function setSpcFadeEnabled(nextEnabled) {
  return playbackSettingsActions.setSpcFadeEnabled(nextEnabled);
}

function setQueuedSkipsEnabled(nextEnabled) {
  return playbackSettingsActions.setQueuedSkipsEnabled(nextEnabled);
}

async function applyArchiveCacheSettings() {
  return archiveCacheActions.applyArchiveCacheSettings();
}

function setArchiveCacheEnabled(enabled) {
  return archiveCacheActions.setArchiveCacheEnabled(enabled);
}

function setArchiveCacheLimit(value) {
  return archiveCacheActions.setArchiveCacheLimit(value);
}

function setEqualizerEnabled(enabled) {
  return audioSettingsActions.setEqualizerEnabled(enabled);
}

function setEqualizerBandGain(index, gain) {
  return audioSettingsActions.setEqualizerBandGain(index, gain);
}

function resetEqualizer() {
  return audioSettingsActions.resetEqualizer();
}

function setAppVolume(volume) {
  return audioSettingsActions.setAppVolume(volume);
}

function setMonoEnabled(enabled) {
  return audioSettingsActions.setMonoEnabled(enabled);
}

function adjustAppVolume(delta) {
  return audioSettingsActions.adjustAppVolume(delta);
}

function commitSpcLengthInput(rawValue) {
  return playbackSettingsActions.commitSpcLengthInput(rawValue);
}

function commitUnknownDurationInput(rawValue) {
  return playbackSettingsActions.commitUnknownDurationInput(rawValue);
}

function commitSpcFadeInput(rawValue) {
  return playbackSettingsActions.commitSpcFadeInput(rawValue);
}

function commitPlaybackSpeedInput(backendId, rawValue) {
  return playbackSpeedActions.commitPlaybackSpeedInput(backendId, rawValue);
}

function setPlaybackSpeedEnabled(backendId, enabled) {
  return playbackSpeedActions.setPlaybackSpeedEnabled(backendId, enabled);
}

function setUiItemSpacing(nextSpacingRem) {
  return appearanceActions.setUiItemSpacing(nextSpacingRem);
}

function setFontSize(nextSize) {
  return appearanceActions.setFontSize(nextSize);
}

function setSidebarWidth(nextWidth) {
  return appearanceActions.setSidebarWidth(nextWidth);
}

function commitFontSizeInput(rawValue) {
  return appearanceActions.commitFontSizeInput(rawValue);
}

function commitSidebarFontSizeInput(rawValue) {
  return appearanceActions.commitSidebarFontSizeInput(rawValue);
}

function setSidebarTextColor(color) {
  return appearanceActions.setSidebarTextColor(color);
}

function setSidebarMonospace(enabled) {
  return appearanceActions.setSidebarMonospace(enabled);
}

function setSidebarPathCounts(enabled) {
  return appearanceActions.setSidebarPathCounts(enabled);
}

function commitPlaylistFontSizeInput(rawValue) {
  return appearanceActions.commitPlaylistFontSizeInput(rawValue);
}

function setPlaylistTextColor(color) {
  return appearanceActions.setPlaylistTextColor(color);
}

function setPlaylistMonospace(enabled) {
  return appearanceActions.setPlaylistMonospace(enabled);
}

function setApplicationMonospace(enabled) {
  return appearanceActions.setApplicationMonospace(enabled);
}

function setPlaylistHeaderBold(enabled) {
  return appearanceActions.setPlaylistHeaderBold(enabled);
}

function setColumnAutoSize(enabled) {
  return appearanceActions.setColumnAutoSize(enabled);
}

function setAnimationTiming(key, value) {
  return appearanceActions.setAnimationTiming(key, value);
}

function setAnimationEnabled(key, enabled) {
  return appearanceActions.setAnimationEnabled(key, enabled);
}

function setWindowAlwaysOnTop(key, enabled) {
  return appearanceActions.setWindowAlwaysOnTop(key, enabled);
}

function applyAppearanceSettings(settings) {
  return appearanceActions.applyAppearanceSettings(settings);
}

function setAccentColor(color) {
  return appearanceActions.setAccentColor(color);
}

function commitSidebarWidthInput(rawValue) {
  return appearanceActions.commitSidebarWidthInput(rawValue);
}

function setOptionsOpen(nextOpen) {
  if (nextOpen && !window.spcBoyWK?.isOptionsWindow) {
    window.spcBoyWK.openOptionsWindow().catch((error) => console.error("[SPCBoy] open options failed", error));
    return;
  }
  if (!nextOpen && window.spcBoyWK?.isOptionsWindow) {
    window.spcBoyWK.closeOptionsWindow();
    return;
  }
  state.optionsOpen = nextOpen;
  if (nextOpen) {
    state.optionsSection = "database";
    uiApp.ui.refreshDatabaseLocation().catch((error) => console.error("[SPCBoy] database location refresh failed", error));
    uiApp.ui.refreshArchiveCacheSummary().catch((error) => console.error("[SPCBoy] archive cache refresh failed", error));
  }
  renderAll();
}


async function bootstrap() {
  // Load persisted appearance before the first Options-window paint. The
  // window is native-sized and immediately visible; deferring this until
  // after catalog/cache requests produces a distracting default-style flash.
  window.SPCBoyOptionsController.applyManifest(await window.spcBoyWK.frontendOptionsManifest());
  await loadSettings();
  await syncSidebarView();
  if (!window.spcBoyWK?.isOptionsWindow) await refreshFavorites();
  if (window.spcBoyWK?.isOptionsWindow) {
    document.body.classList.add("options-window");
    state.optionsOpen = true;
    // Paint the native Settings window before any catalog/cache request can
    // delay or reject. The controls remain usable while those values load.
    renderAll();
  }
  if (!window.spcBoyWK?.bootstrap || !window.spcBoyWK?.refreshTree) {
    const message = "SPCBoy WK native bridge is unavailable. File loading is unavailable.";
    showStartupFailure(message);
    throw new Error(message);
  }

  collapsedDatabaseConsoles.clear();
  state.collapsedConsoleNames.forEach((name) => collapsedDatabaseConsoles.add(name));
  state.databaseLocation = await window.spcBoyWK?.databaseLocation?.() || null;
  state.databaseLocationStatus = state.databaseLocation?.requiresRestart
    ? "Restart SPCBoy to use the selected database."
    : "The shared ScanSong catalog is active and opened read-only.";
  await window.spcBoyWK?.configureArchiveCache?.({
    enabled: state.archiveCacheEnabled,
    limitBytes: state.archiveCacheLimitBytes
  });
  await uiApp.ui.refreshArchiveCacheSummary();
  if (window.spcBoyWK?.setRoutingPreferences) {
    state.routingPreferences = { ...(await window.spcBoyWK.setRoutingPreferences(state.routingPreferences)) };
    persistSettings();
  }
  let snapshot;
  if (window.spcBoyWK?.isOptionsWindow) {
    // Options owns settings/library controls, not the raw browser. Do not
    // enumerate the persisted JoshW root just to paint this window.
    snapshot = {
      rootPath: state.rootPath,
      tree: [],
      selectedFolderPath: state.selectedFolderPath,
      selectedBrowserPath: state.selectedBrowserPath,
      playlist: []
    };
  } else if (state.localBrowserEnabled && state.rootPath) {
    state.sidebarMode = "diskPath";
    snapshot = await window.spcBoyWK.refreshTree(state.rootPath, state.selectedFolderPath || state.rootPath);
  } else {
    snapshot = await window.spcBoyWK.bootstrap();
  }

  if (snapshot?.stale === true) return;

  Object.assign(state, snapshot);
  rebuildDatabaseGameSearchIndex(state.databaseGames);
  await uiApp.playback.stopPlaybackState();
  state.selectedTrackId = resolveSelectedTrackId(snapshot.playlist);
  state.lastSelectedTrackId = state.selectedTrackId;
  state.totalSeconds = targetPlaybackSeconds();
  persistSettings();
  if (!state.localBrowserEnabled && !window.spcBoyWK?.isOptionsWindow && window.spcBoyWK?.databaseRoots) {
    state.libraryRoots = await window.spcBoyWK.databaseRoots();
    await uiApp.ui.handleLibraryRootsChanged(state.libraryRoots);
  }
  renderAll();
  if (state.sidebarMode === "consoles") {
    const selectedGame = state.databaseGames.find((game) => databaseGameKey(game) === state.selectedDatabaseGameKey);
    if (selectedGame) {
      await loadDatabaseGame(selectedGame);
    }
  }
  syncTreeSelection();
  scrollSelectedTrackIntoView();
}

async function openLibraryRoot() {
  const snapshot = await window.spcBoyWK.chooseRootFolder();
  if (!snapshot) {
    return;
  }

  applyLibrarySnapshot(snapshot);
}

function applyLibrarySnapshot(snapshot) {
  if (snapshot?.stale === true) return;
  Object.assign(state, snapshot);
  rebuildDatabaseGameSearchIndex(state.databaseGames);
  state.localBrowserEnabled = true;
  state.sidebarMode = "diskPath";
  state.sidebarQuery = "";
  state.selectedDatabaseGameKey = null;
  refs.sidebarSearchInput.value = "";
  state.selectedTrackId = resolveSelectedTrackId(snapshot.playlist);
  state.lastSelectedTrackId = state.selectedTrackId;
  state.totalSeconds = targetPlaybackSeconds();
  persistSettings();
  renderAll();
  syncTreeSelection();
  scrollSelectedTrackIntoView();
}

function applyFolderSelection(selection) {
  const preserveBrowserFocus = document.activeElement?.classList.contains("tree-node");
  state.selectedFolderPath = selection.selectedFolderPath;
  state.playlist = selection.playlist;
  state.selectedTrackId = resolveSelectedTrackId(selection.playlist);
  state.lastSelectedTrackId = state.selectedTrackId;
  if (!state.currentTrackId) {
    state.totalSeconds = targetPlaybackSeconds();
  }
  persistSettings();
  renderTree();
  syncTreeSelection();
  if (preserveBrowserFocus && state.selectedBrowserPath) {
    refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`)?.focus();
  }
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
  scrollSelectedTrackIntoView();
}

uiApp.ui = {
  resolveSelectedTrackId,
  renderTree,
  syncTreeSelection,
  renderPlaylist,
  refreshPlaylistPlaybackState,
  renderAll,
  moveSelection,
  selectAllPlaylistTracks,
  moveBrowserSelection,
  jumpFocusedListToEdge,
  playSelectedTrack,
  setPlayTime,
  setSpcForceManualTime,
  cycleRepeatMode,
  setSpcFadeTime,
  setSpcFadeEnabled,
  setQueuedSkipsEnabled,
  setArchiveCacheEnabled,
  setArchiveCacheLimit,
  setEqualizerEnabled,
  setEqualizerBandGain,
  resetEqualizer,
  setAppVolume,
  setMonoEnabled,
  adjustAppVolume,
  commitSpcLengthInput,
  commitUnknownDurationInput,
  commitSpcFadeInput,
  commitPlaybackSpeedInput,
  setPlaybackSpeedEnabled,
  setUiItemSpacing,
  setFontSize,
  setSidebarWidth,
  setAccentColor,
  commitFontSizeInput,
  commitSidebarFontSizeInput,
  setSidebarTextColor,
  setSidebarMonospace,
  setSidebarPathCounts,
  commitPlaylistFontSizeInput,
  setPlaylistTextColor,
  setPlaylistMonospace,
  setApplicationMonospace,
  setPlaylistHeaderBold,
  setColumnAutoSize,
  setAnimationTiming,
  setAnimationEnabled,
  setWindowAlwaysOnTop,
  applyAppearanceSettings,
  applyRoutingPreferences,
  commitSidebarWidthInput,
  setOptionsOpen,
  setAllDatabaseConsolesCollapsed,
  setAllSidebarNodesCollapsed,
  refreshDatabaseGamesForVisibleRoots,
  loadDatabaseFiles,
  setSidebarMode,
  cycleSidebarMode,
  updateSidebarSearch,
  loadDatabaseGames,
  loadDatabaseGame,
  toggleSelectedFavorites,
  refreshFavorites,
  showFavoritesPlaylist,
  activateDatabaseSelection,
  activateFocusedItem,
  renderSidebar,
  syncAnimatedRanges,
  bootstrap,
  openLibraryRoot,
  applyLibrarySnapshot,
  applyFolderSelection
};
})();
