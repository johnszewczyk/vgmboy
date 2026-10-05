(() => {
const uiApp = window.SB2App;
const { state, refs, persistSettings, loadSettings, targetPlaybackSeconds, COLUMN_DEFS } = uiApp;
if (document.body.classList.contains("sb2-frontend")) {
  const searchWrap = document.querySelector(".sidebar-search-wrap");
  const searchSlot = document.querySelector(".sb-status-sidebar");
  const functionButtons = document.querySelector(".sidebar-search-actions");
  const transport = document.querySelector(".transport-toolbar .transport");
  const optionsOverlay = refs.optionsOverlay;
  const content = document.querySelector(".content");
  if (searchWrap && searchSlot) searchSlot.append(searchWrap);
  if (functionButtons && transport) transport.append(functionButtons);
  if (optionsOverlay && content) content.append(optionsOverlay);
}
const expandedFolders = new Set();
let draggedColumnId = null;
let metadataRefreshFrame = 0;
const metadataRefreshTrackIds = new Set();
let columnMenu = null;
let autoSizedPlaylistSignature = null;
let playlistRenderGeneration = 0;
let textMeasureContext = null;
let renderedDatabaseGames = null;
let databaseGameButtons = [];
let databaseEmptyState = null;
let databaseConsoleGroups = [];
let collapsedDatabaseConsoles = new Set();
let databaseRowRenderGeneration = 0;
let browserClickTimer = 0;
let databaseGameClickTimer = 0;
let databaseGameSearchRecords = [];
let columnResizePointerId = null;
const PLAYLIST_VIRTUALIZATION_THRESHOLD = 200;
const PLAYLIST_VIRTUAL_OVERSCAN = 12;
let playlistVirtualRowHeight = 28;
let playlistViewportFrame = 0;
let catalogPlaylistSortGeneration = 0;
let projectionPlaylistSortGeneration = 0;
let playlistTabsSaveTimer = 0;
let playlistTabsSaveChain = Promise.resolve();
const treeSearchText = new WeakMap();
let startupStartedAt = 0;
let startupRevealTimer = 0;
let startupElapsedTimer = 0;
let startupDismissTimer = 0;
let startupHasAppeared = false;

function makePlaylistTabID() {
  return globalThis.crypto?.randomUUID?.()
    || `playlist-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function findActivePlaylistTab() {
  return state.playlistTabs?.find((tab) => tab.id === state.activePlaylistTabId) || null;
}

function syncActivePlaylistTab() {
  const tab = findActivePlaylistTab();
  if (!tab) return null;
  tab.title = String(state.playlistTitle || "Playlist");
  tab.playlist = state.playlist;
  tab.selectedTrackId = state.selectedTrackId || null;
  tab.selectedTrackIds = [...(state.selectedTrackIds || [])];
  tab.playlistSelectionAnchorId = state.playlistSelectionAnchorId || null;
  tab.scrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  tab.catalogPlaylistColumnContentHints = state.catalogPlaylistColumnContentHints;
  tab.catalogPlaylistSortSessionId = state.catalogPlaylistSortSessionId;
  return tab;
}

function persistPlaylistTabs() {
  if (window.spcBoySB2?.isOptionsWindow || !window.spcBoySB2?.playlistTabsSave) return;
  syncActivePlaylistTab();
  window.clearTimeout(playlistTabsSaveTimer);
  playlistTabsSaveTimer = window.setTimeout(() => {
    playlistTabsSaveTimer = 0;
    const payload = {
      version: 1,
      activeID: state.activePlaylistTabId,
      tabs: (state.playlistTabs || []).map((tab) => ({
        id: tab.id,
        title: tab.title,
        playlist: tab.playlist || [],
        selectedTrackId: tab.selectedTrackId || null,
        selectedTrackIds: tab.selectedTrackIds || [],
        playlistSelectionAnchorId: tab.playlistSelectionAnchorId || null,
        scrollTop: Math.max(0, Number(tab.scrollTop) || 0)
      }))
    };
    playlistTabsSaveChain = playlistTabsSaveChain
      .catch(() => {})
      .then(() => window.spcBoySB2.playlistTabsSave(payload))
      .catch((error) => console.error("[SPCBoy] playlist tabs could not be saved", error));
  }, 500);
}

function restorePlaylistTabView(tab) {
  state.activePlaylistTabId = tab.id;
  state.playlistTitle = String(tab.title || "Playlist");
  state.playlist = Array.isArray(tab.playlist) ? [...tab.playlist] : [];
  state.selectedTrackId = tab.selectedTrackId || null;
  state.selectedTrackIds = Array.isArray(tab.selectedTrackIds) ? [...tab.selectedTrackIds] : [];
  state.playlistSelectionAnchorId = tab.playlistSelectionAnchorId || null;
  lastPlaylistSelectionID = state.selectedTrackId;
  state.catalogPlaylistColumnContentHints = tab.catalogPlaylistColumnContentHints || null;
  state.catalogPlaylistSortSessionId = tab.catalogPlaylistSortSessionId || null;
  // Column widths are shared UI state, but the content that determines an
  // automatic fit belongs to the restored tab.
  autoSizedPlaylistSignature = null;
  if (refs.playlistBodyWrap) refs.playlistBodyWrap.scrollTop = Math.max(0, Number(tab.scrollTop) || 0);
  renderPlaylistTabs();
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
}

function ensurePlaylistTab() {
  if (!Array.isArray(state.playlistTabs)) state.playlistTabs = [];
  let active = findActivePlaylistTab();
  if (active) return active;
  active = {
    id: makePlaylistTabID(),
    title: state.playlistTitle || "Playlist",
    playlist: state.playlist || [],
    selectedTrackId: state.selectedTrackId || null,
    selectedTrackIds: [...(state.selectedTrackIds || [])],
    playlistSelectionAnchorId: state.playlistSelectionAnchorId || null,
    scrollTop: Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0),
    catalogPlaylistColumnContentHints: state.catalogPlaylistColumnContentHints,
    catalogPlaylistSortSessionId: state.catalogPlaylistSortSessionId
  };
  state.playlistTabs.push(active);
  state.activePlaylistTabId = active.id;
  renderPlaylistTabs();
  return active;
}

function renderPlaylistTabs() {
  updateSB2Titlebar();
  const tabs = Array.isArray(state.playlistTabs) ? state.playlistTabs : [];
  const hasTabs = tabs.length > 1;
  refs.playlistTabsToolbar?.classList.toggle("is-hidden", !hasTabs);
  refs.playlistTabsToolbar?.closest(".content")?.classList.toggle("has-playlist-tabs", hasTabs);
  if (!refs.playlistTabs) return;
  if (tabs.length <= 1) {
    refs.playlistTabs.replaceChildren();
    return;
  }

  const remainingItems = new Map([...refs.playlistTabs.children].map((item) => [item.dataset.playlistTabId, item]));

  for (const [index, tab] of tabs.entries()) {
    const active = tab.id === state.activePlaylistTabId;
    let item = remainingItems.get(tab.id);
    if (!item) {
      item = document.createElement("div");
      item.className = "playlist-tab";
      item.dataset.playlistTabId = tab.id;
      item.addEventListener("click", (event) => {
        if (!event.target.closest(".playlist-tab-close")) activatePlaylistTab(tab.id);
      });

      const select = document.createElement("button");
      select.type = "button";
      select.className = "playlist-tab-select";
      select.setAttribute("role", "tab");
      item.appendChild(select);

      const close = document.createElement("button");
      close.type = "button";
      close.className = "playlist-tab-close";
      close.textContent = "×";
      close.addEventListener("click", (event) => {
        event.stopPropagation();
        closePlaylistTab(tab.id);
      });
      item.appendChild(close);
    }

    const select = item.querySelector(".playlist-tab-select");
    const close = item.querySelector(".playlist-tab-close");
    const title = String(tab.title || "Playlist");
    item.classList.toggle("is-active", active);
    select.classList.toggle("is-active", active);
    select.setAttribute("aria-selected", String(active));
    select.tabIndex = active ? 0 : -1;
    select.title = title;
    select.textContent = title;
    close.title = `Close ${title}`;
    close.setAttribute("aria-label", `Close ${title}`);

    remainingItems.delete(tab.id);
    const currentAtIndex = refs.playlistTabs.children[index];
    if (currentAtIndex !== item) refs.playlistTabs.insertBefore(item, currentAtIndex || null);
  }

  for (const item of remainingItems.values()) item.remove();
}

function activatePlaylistTab(tabID, { syncOutgoing = true } = {}) {
  const tab = state.playlistTabs?.find((entry) => entry.id === tabID);
  if (!tab || tab.id === state.activePlaylistTabId) return false;
  if (syncOutgoing) syncActivePlaylistTab();
  browserSelectionGeneration += 1;
  void invalidatePlaylistCatalogSession().catch((error) => console.error("[SPCBoy] playlist request invalidation failed", error));
  restorePlaylistTabView(tab);
  persistPlaylistTabs();
  return true;
}

function activatePlaylistTabAtIndex(index) {
  if (!Number.isInteger(index) || index < 0) return false;
  const tab = state.playlistTabs?.[index];
  return tab ? activatePlaylistTab(tab.id) : false;
}

function createPlaylistTab({ duplicateActive = true, title = null } = {}) {
  const source = ensurePlaylistTab();
  syncActivePlaylistTab();
  if ((state.playlistTabs?.length || 0) >= 64) {
    console.warn("[SPCBoy] playlist tab limit reached");
    return null;
  }
  const tab = {
    id: makePlaylistTabID(),
    title: String(title || (duplicateActive ? source.title : "Playlist")),
    playlist: duplicateActive ? [...source.playlist] : [],
    selectedTrackId: duplicateActive ? source.selectedTrackId : null,
    selectedTrackIds: duplicateActive ? [...source.selectedTrackIds] : [],
    playlistSelectionAnchorId: duplicateActive ? source.playlistSelectionAnchorId : null,
    scrollTop: duplicateActive ? source.scrollTop : 0,
    catalogPlaylistColumnContentHints: duplicateActive ? source.catalogPlaylistColumnContentHints : null,
    catalogPlaylistSortSessionId: duplicateActive ? source.catalogPlaylistSortSessionId : null
  };
  state.playlistTabs.push(tab);
  activatePlaylistTab(tab.id, { syncOutgoing: false });
  renderPlaylistTabs();
  persistPlaylistTabs();
  return tab;
}

function activateOrCreateProjectionTab(title) {
  if (findActivePlaylistTab()?.title === title) return true;
  const existing = state.playlistTabs?.find((tab) => tab.title === title);
  if (existing) return activatePlaylistTab(existing.id);
  return Boolean(createPlaylistTab({ duplicateActive: false, title }));
}

function closePlaylistTab(tabID = state.activePlaylistTabId) {
  const tabs = state.playlistTabs || [];
  if (tabs.length <= 1) {
    window.spcBoySB2?.closeMainWindow?.().catch((error) => console.error("[SPCBoy] close window failed", error));
    return false;
  }
  const closingIndex = tabs.findIndex((tab) => tab.id === tabID);
  if (closingIndex < 0) return false;
  const wasActive = tabs[closingIndex].id === state.activePlaylistTabId;
  if (wasActive) syncActivePlaylistTab();
  tabs.splice(closingIndex, 1);
  if (wasActive) {
    const next = tabs[Math.min(closingIndex, tabs.length - 1)];
    activatePlaylistTab(next.id, { syncOutgoing: false });
  } else {
    renderPlaylistTabs();
  }
  persistPlaylistTabs();
  return true;
}

function restorePlaylistTabs(value) {
  if (value?.version !== 1 || !Array.isArray(value.tabs) || !value.tabs.length) return false;
  const identifiers = new Set();
  const tabs = value.tabs.slice(0, 64).filter((tab) => {
    if (!tab || typeof tab.id !== "string" || !tab.id || identifiers.has(tab.id)) return false;
    identifiers.add(tab.id);
    return true;
  }).map((tab) => ({
    id: tab.id,
    title: typeof tab.title === "string" ? tab.title : "Playlist",
    playlist: Array.isArray(tab.playlist) ? tab.playlist : [],
    selectedTrackId: typeof tab.selectedTrackId === "string" ? tab.selectedTrackId : null,
    selectedTrackIds: Array.isArray(tab.selectedTrackIds) ? tab.selectedTrackIds.filter((id) => typeof id === "string") : [],
    playlistSelectionAnchorId: typeof tab.playlistSelectionAnchorId === "string" ? tab.playlistSelectionAnchorId : null,
    scrollTop: Math.max(0, Number(tab.scrollTop) || 0),
    // Catalog sort sessions are process-local; a restored catalog projection
    // can still be sorted through the shared projection-sort core.
    catalogPlaylistColumnContentHints: null,
    catalogPlaylistSortSessionId: null
  }));
  if (!tabs.length) return false;
  state.playlistTabs = tabs;
  state.activePlaylistTabId = identifiers.has(value.activeID) ? value.activeID : tabs[0].id;
  restorePlaylistTabView(findActivePlaylistTab());
  renderPlaylistTabs();
  persistPlaylistTabs();
  return true;
}

function syncCollapsedConsolePersistence() {
  state.collapsedConsoleNames = [...collapsedDatabaseConsoles];
  persistSettings();
}

function currentSidebarView() {
  return state.sidebarView;
}

function localSidebarView(mode, query) {
  const normalizedQuery = String(query || "").trim();
  const view = normalizedQuery ? "search" : mode;
  return {
    storedMode: mode,
    query: normalizedQuery,
    view,
    contentMode: mode === "paths" ? "tree" : "database",
    resultSource: mode === "paths" ? "catalog-path-index" : "catalog-console-index",
    isTemporary: view === "search"
  };
}

function rebuildDatabaseGameSearchIndex(games = state.databaseGames) {
  databaseGameSearchRecords = (Array.isArray(games) ? games : []).map((game) => ({
    game,
    // CatalogBrowserCore publishes this complete normalized search projection.
    // The WebKit list only filters it locally so typing never reopens SQLite.
    searchText: String(game.searchText || "")
  }));
}

function localDatabaseSearch(query) {
  const terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (!terms.length) return state.databaseGames;
  return databaseGameSearchRecords
    .filter(({ searchText }) => terms.every((term) => searchText.includes(term)))
    .map(({ game }) => game);
}

async function syncSidebarView() {
  state.sidebarMode = state.sidebarMode === "paths" ? "paths" : "consoles";
  state.sidebarView = Object.freeze(localSidebarView(state.sidebarMode, state.sidebarQuery));
  return state.sidebarView;
}

function applyFavoriteSnapshot(favorites) {
  state.favorites = Array.isArray(favorites) ? favorites : [];
  state.favoriteIds = state.favorites.map((track) => track.favoriteId).filter(Boolean);
}

function isFavoritePresentation(track) {
  return Boolean(track?.favoriteId) && state.favoriteIds.includes(track.favoriteId);
}

async function refreshFavorites() {
  const favorites = await window.spcBoySB2.favoritesList(state.favoriteSortOrder);
  applyFavoriteSnapshot(favorites);
  return state.favorites;
}

async function toggleFavorites(tracks) {
  applyFavoriteSnapshot(await window.spcBoySB2.favoritesToggle(tracks, state.favoriteSortOrder));
}

function playVisibleTrack(trackId, startSeconds = 0) {
  return uiApp.playback.playTrack(trackId, startSeconds, false, { replaceQueue: true });
}
let browserSelectionGeneration = 0;
let selectedBrowserButton = null;
let selectedDatabaseSidebarButton = null;
let renderedBrowserNodes = [];
let renderedBrowserNodesByPath = new Map();
let renderedBrowserNodeIndexByPath = new Map();
const playlistRowsByTrackId = new Map();
let selectedPlaylistRow = null;
let currentPlaylistRow = null;
let selectionIndicatorFrame = 0;
let lastPlaylistSelectionID = null;

function playlistUsesVirtualRows() {
  return state.playlist.length > PLAYLIST_VIRTUALIZATION_THRESHOLD;
}

function schedulePlaylistViewportRender() {
  if (!playlistUsesVirtualRows() || playlistViewportFrame) return;
  playlistViewportFrame = window.requestAnimationFrame(() => {
    playlistViewportFrame = 0;
    renderPlaylist({ sort: false, persistTab: false, preserveVirtualRows: true });
  });
}

// Measure directly after synchronous row insertion so calibration cannot move
// a scrolled viewport in a later frame, during the next pointer interaction.
function measurePlaylistRowHeight() {
  if (!playlistUsesVirtualRows()) return;
  const row = refs.playlistBody.querySelector(".playlist-row");
  const measuredHeight = row?.getBoundingClientRect?.().height || 0;
  const previousHeight = playlistVirtualRowHeight;
  if (!measuredHeight || Math.abs(measuredHeight - previousHeight) < 0.01) return;

  const scrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  const viewportHeight = Math.max(0, Number(refs.playlistBodyWrap?.clientHeight) || 0);
  const oldMaxScrollTop = Math.max(0, (refs.playlistBodyWrap?.scrollHeight || 0) - viewportHeight);
  const wasAtBottom = oldMaxScrollTop - scrollTop <= Math.max(previousHeight, 1);
  const anchorIndex = Math.floor(scrollTop / previousHeight);
  const offsetWithinAnchorRow = scrollTop - (anchorIndex * previousHeight);
  const adjustedScrollTop = wasAtBottom
    ? Math.max(0, state.playlist.length * measuredHeight - viewportHeight)
    : (anchorIndex * measuredHeight) + Math.min(offsetWithinAnchorRow, measuredHeight);

  playlistVirtualRowHeight = measuredHeight;
  renderPlaylist({
    sort: false,
    persistTab: false,
    virtualScrollTop: adjustedScrollTop,
    preserveVirtualRows: true
  });
  if (refs.playlistBodyWrap) refs.playlistBodyWrap.scrollTop = adjustedScrollTop;
  const tab = findActivePlaylistTab();
  if (tab) tab.scrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  persistPlaylistTabs();
}

function makePlaylistVirtualSpacer(height, side) {
  const row = document.createElement("tr");
  row.className = "playlist-virtual-spacer";
  row.dataset.virtualSpacer = side;
  row.setAttribute("aria-hidden", "true");
  const cell = document.createElement("td");
  cell.colSpan = Math.max(1, orderedColumns().length);
  cell.style.height = `${Math.max(0, height)}px`;
  row.appendChild(cell);
  return row;
}

function updatePlaylistVirtualSpacer(spacer, height) {
  if (!spacer) return;
  const cell = spacer.firstElementChild;
  if (cell) cell.style.height = `${Math.max(0, height)}px`;
}

function reconcilePlaylistVirtualRows(startIndex, endIndex) {
  // Keep rows in the overlapping viewport mounted so an in-flight pointer click
  // still lands on its original track while scrolling updates the virtual window.
  const body = refs.playlistBody;
  const wantedIDs = new Set(state.playlist.slice(startIndex, endIndex).map((track) => track.id));
  for (const [trackId, row] of playlistRowsByTrackId) {
    if (wantedIDs.has(trackId)) continue;
    row.remove();
    playlistRowsByTrackId.delete(trackId);
  }

  selectedPlaylistRow = null;
  currentPlaylistRow = null;
  let topSpacer = body.querySelector('.playlist-virtual-spacer[data-virtual-spacer="top"]');
  let bottomSpacer = body.querySelector('.playlist-virtual-spacer[data-virtual-spacer="bottom"]');
  if (startIndex > 0) {
    if (!topSpacer) topSpacer = makePlaylistVirtualSpacer(0, "top");
    if (body.firstElementChild !== topSpacer) body.insertBefore(topSpacer, body.firstElementChild);
    updatePlaylistVirtualSpacer(topSpacer, startIndex * playlistVirtualRowHeight);
  } else {
    topSpacer?.remove();
    topSpacer = null;
  }
  if (endIndex < state.playlist.length) {
    if (!bottomSpacer) bottomSpacer = makePlaylistVirtualSpacer(0, "bottom");
    if (!bottomSpacer.isConnected) body.appendChild(bottomSpacer);
    updatePlaylistVirtualSpacer(bottomSpacer, (state.playlist.length - endIndex) * playlistVirtualRowHeight);
  } else {
    bottomSpacer?.remove();
    bottomSpacer = null;
  }

  let cursor = topSpacer?.nextSibling || body.firstElementChild;
  for (let index = startIndex; index < endIndex; index += 1) {
    const track = state.playlist[index];
    let row = playlistRowsByTrackId.get(track.id);
    if (!row) {
      row = createPlaylistRow(track, index);
      playlistRowsByTrackId.set(track.id, row);
    } else {
      row.dataset.playlistIndex = String(index);
      updatePlaylistRowState(row, track.id);
    }
    if (row !== cursor) body.insertBefore(row, cursor && cursor !== bottomSpacer ? cursor : bottomSpacer);
    cursor = row.nextSibling;
    if (state.selectedTrackId === track.id) selectedPlaylistRow = row;
    if (state.activePlaylistTabId === state.playbackTabId && state.currentTrackId === track.id) currentPlaylistRow = row;
  }
  if (bottomSpacer && bottomSpacer !== body.lastElementChild) body.appendChild(bottomSpacer);
  schedulePlaylistSelectionIndicator();
}

refs.playlistBodyWrap?.addEventListener("scroll", schedulePlaylistViewportRender, { passive: true });
refs.playlistBodyWrap?.addEventListener("scroll", () => {
  const tab = findActivePlaylistTab();
  if (!tab) return;
  tab.scrollTop = Math.max(0, Number(refs.playlistBodyWrap.scrollTop) || 0);
  persistPlaylistTabs();
}, { passive: true });

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  }[character]));
}

function setSelectionIndicatorSolid(indicator, solid) {
  if (!indicator?.classList) return;
  if (solid) indicator.classList.add("is-solid");
  else indicator.classList.remove("is-solid");
}

function syncSelectionIndicatorStyle() {
  const solid = Boolean(state.solidSelectionBar);
  setSelectionIndicatorSolid(refs.playlistSelectionIndicator, solid);
}

function resetSidebarContent() {
  databaseRowRenderGeneration += 1;
  refs.treeRoot.replaceChildren();
  selectedBrowserButton = null;
  selectedDatabaseSidebarButton = null;
  renderedBrowserNodes = [];
  renderedBrowserNodesByPath = new Map();
  renderedBrowserNodeIndexByPath = new Map();
}

function hideSelectionIndicator(indicator) {
  if (!indicator) return;
  indicator.classList.add("is-hidden");
  indicator.style.opacity = "0";
}

function positionSelectionIndicator(container, indicator, target) {
  if (!container || !indicator || !target) return false;
  const containerBounds = container.getBoundingClientRect();
  const targetBounds = target.getBoundingClientRect();
  // A row can briefly have no layout box while a virtualized viewport is
  // rebuilding. Keep the last capsule frame until the new target is measurable.
  if (!targetBounds.width || !targetBounds.height) return false;
  const left = targetBounds.left - containerBounds.left + container.scrollLeft;
  const top = targetBounds.top - containerBounds.top + container.scrollTop;
  // Let the capsule fall one CSS pixel below the row baseline so it sits
  // between rows instead of visually stopping high against the text.
  const height = targetBounds.height + 1;
  const transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`;
  if (indicator.classList.contains("is-hidden")) {
    // First appearance after an explicit clear/source change should land at
    // the selected row. Later row-to-row changes use the CSS transform ease.
    const previousTransition = indicator.style.transition;
    indicator.style.transition = "none";
    indicator.style.width = `${targetBounds.width}px`;
    indicator.style.height = `${height}px`;
    indicator.style.transform = transform;
    indicator.style.opacity = "1";
    indicator.classList.remove("is-hidden");
    indicator.getBoundingClientRect();
    indicator.style.transition = previousTransition;
    return true;
  }
  indicator.style.width = `${targetBounds.width}px`;
  indicator.style.height = `${height}px`;
  indicator.style.transform = transform;
  return true;
}

function sidebarSelectionTarget() {
  const view = currentSidebarView();
  if (view.contentMode === "tree") {
    return state.selectedBrowserPath
      ? refs.treeRoot.querySelector(`.tree-node[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`)
      : null;
  }
  if (state.selectedDatabaseGameKey) {
    return refs.treeRoot.querySelector(`.database-game-row[data-database-game-key="${CSS.escape(state.selectedDatabaseGameKey)}"]`);
  }
  if (state.selectedDatabaseConsoleName) {
    return refs.treeRoot.querySelector(`.database-console-row[data-database-console-name="${CSS.escape(state.selectedDatabaseConsoleName)}"]`);
  }
  return null;
}

function syncSidebarSelectionRowClass(target = sidebarSelectionTarget()) {
  for (const previous of [selectedBrowserButton, selectedDatabaseSidebarButton]) {
    if (!previous || previous === target) continue;
    previous.classList.remove("is-selected");
    if (previous.hasAttribute("aria-selected")) previous.setAttribute("aria-selected", "false");
  }
  target?.classList.add("is-selected");
  selectedBrowserButton = target?.classList.contains("tree-node") ? target : null;
  selectedDatabaseSidebarButton = target?.classList.contains("database-game-row")
    || target?.classList.contains("database-console-row") ? target : null;
  return target;
}

function syncPlaylistSelectionIndicator() {
  selectionIndicatorFrame = 0;
  const hasPlaylistSelection = Boolean(state.selectedTrackId || state.selectedTrackIds?.length);
  const playlistTargetIsMounted = selectedPlaylistRow && selectedPlaylistRow.isConnected !== false;
  if (playlistTargetIsMounted) {
    positionSelectionIndicator(refs.playlistBodyWrap, refs.playlistSelectionIndicator, selectedPlaylistRow);
  } else if (!hasPlaylistSelection) {
    hideSelectionIndicator(refs.playlistSelectionIndicator);
  }
}

function schedulePlaylistSelectionIndicator() {
  if (selectionIndicatorFrame) return;
  selectionIndicatorFrame = window.requestAnimationFrame(syncPlaylistSelectionIndicator);
}

function clearPlaylistSelection() {
  // A sidebar source is a playlist preview, not a row-selection action. Keep
  // its visible list unselected so the prior source cannot leave an indicator
  // at a matching track ID or a fallback row in the replacement playlist.
  state.selectedTrackId = null;
  state.selectedTrackIds = [];
  state.playlistSelectionAnchorId = null;
  selectedPlaylistRow = null;
  lastPlaylistSelectionID = null;
  schedulePlaylistSelectionIndicator();
}

function showStartupFailure(message) {
  failStartup(message);
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

const SB2_STARTUP_STEPS = window.spcBoySB2?.startupStages || [];
const SB2_STARTUP_TIMING = window.spcBoySB2?.startupTiming || {
  revealDelayMilliseconds: 350,
  readyConfirmationMilliseconds: 650,
};

function setStartupStage(index, detail = null) {
  if (window.spcBoySB2?.isOptionsWindow) return;
  setStartupStatus("STARTING");
  const notice = document.getElementById("sb2-startup-notice");
  if (!notice) return;
  const step = Math.max(0, Math.min(SB2_STARTUP_STEPS.length - 1, Number(index) || 0));
  const message = SB2_STARTUP_STEPS[step];
  const heading = document.getElementById("sb2-startup-title");
  const description = document.getElementById("sb2-startup-detail");
  if (heading) heading.textContent = message?.heading || "Restoring SPCBOY SB2";
  if (description) description.textContent = String(detail || message?.detail || "Preparing your library and saved playlists.");
  notice.querySelectorAll("[data-sb2-startup-step]").forEach((item) => {
    const itemIndex = Number(item.dataset.sb2StartupStep);
    const state = itemIndex < step ? "done" : itemIndex === step ? "active" : "pending";
    item.dataset.state = state;
    const mark = item.querySelector(".sb2-startup-step-mark");
    if (mark) mark.textContent = state === "done" ? "✓" : String(itemIndex + 1);
  });
  notice.classList.remove("is-error", "is-ready");
  notice.setAttribute("aria-busy", "true");
  notice.querySelector("[role='progressbar']")?.setAttribute("aria-valuetext", "In progress");
}

function setStartupStatus(status) {
  const indicator = document.querySelector(".sb-status-state");
  const label = document.getElementById("sb2-app-status-label");
  if (!indicator || !label) return;
  label.textContent = status;
  indicator.dataset.startupState = status.toLowerCase();
}

function beginStartup() {
  if (window.spcBoySB2?.isOptionsWindow) return;
  startupStartedAt = performance.now();
  startupHasAppeared = false;
  window.clearTimeout(startupDismissTimer);
  document.querySelectorAll("[data-sb2-startup-step]").forEach((item) => {
    const index = Number(item.dataset.sb2StartupStep);
    const stage = SB2_STARTUP_STEPS[index];
    const label = item.querySelector(".sb2-startup-step-label");
    if (label && stage?.label) label.textContent = stage.label;
  });
  setStartupStage(0);
  const notice = document.getElementById("sb2-startup-notice");
  if (!notice) return;
  window.clearTimeout(startupRevealTimer);
  startupRevealTimer = window.setTimeout(() => {
    startupRevealTimer = 0;
    startupHasAppeared = true;
    notice.classList.remove("is-hidden");
    const elapsed = document.getElementById("sb2-startup-elapsed");
    const updateElapsed = () => {
      if (elapsed) elapsed.textContent = `Working ${Math.max(1, Math.floor((performance.now() - startupStartedAt) / 1000))}s`;
    };
    updateElapsed();
    window.clearInterval(startupElapsedTimer);
    startupElapsedTimer = window.setInterval(updateElapsed, 1000);
  }, SB2_STARTUP_TIMING.revealDelayMilliseconds);
}

function finishStartup() {
  if (window.spcBoySB2?.isOptionsWindow) return;
  setStartupStatus("READY");
  const notice = document.getElementById("sb2-startup-notice");
  if (!notice) return;
  window.clearTimeout(startupRevealTimer);
  startupRevealTimer = 0;
  window.clearInterval(startupElapsedTimer);
  startupElapsedTimer = 0;
  if (!startupHasAppeared) {
    notice.classList.add("is-hidden");
    return;
  }
  notice.querySelectorAll("[data-sb2-startup-step]").forEach((item) => {
    item.dataset.state = "done";
    const mark = item.querySelector(".sb2-startup-step-mark");
    if (mark) mark.textContent = "✓";
  });
  const heading = document.getElementById("sb2-startup-title");
  const description = document.getElementById("sb2-startup-detail");
  const elapsed = document.getElementById("sb2-startup-elapsed");
  if (heading) heading.textContent = "SPCBOY SB2 is ready";
  if (description) description.textContent = "Your library and saved playlists are ready.";
  if (elapsed) elapsed.textContent = "Ready";
  notice.classList.add("is-ready");
  notice.setAttribute("aria-busy", "false");
  notice.querySelector("[role='progressbar']")?.setAttribute("aria-valuetext", "Ready");
  window.clearTimeout(startupDismissTimer);
  startupDismissTimer = window.setTimeout(
    () => notice.classList.add("is-hidden"),
    SB2_STARTUP_TIMING.readyConfirmationMilliseconds
  );
}

function failStartup(message) {
  if (window.spcBoySB2?.isOptionsWindow) return;
  setStartupStatus("ERROR");
  const notice = document.getElementById("sb2-startup-notice");
  if (!notice) return;
  window.clearTimeout(startupRevealTimer);
  startupRevealTimer = 0;
  window.clearInterval(startupElapsedTimer);
  startupElapsedTimer = 0;
  window.clearTimeout(startupDismissTimer);
  startupHasAppeared = true;
  notice.classList.remove("is-hidden", "is-ready");
  notice.classList.add("is-error");
  notice.setAttribute("aria-busy", "false");
  notice.querySelector("[role='progressbar']")?.setAttribute("aria-valuetext", "Startup paused");
  const heading = document.getElementById("sb2-startup-title");
  const description = document.getElementById("sb2-startup-detail");
  const elapsed = document.getElementById("sb2-startup-elapsed");
  if (heading) heading.textContent = "SPCBOY SB2 could not finish starting";
  if (description) description.textContent = String(message || "The library could not be opened.");
  if (elapsed) elapsed.textContent = "Startup paused";
}

function pathToNode(nodes, targetPath, lineage = []) {
  for (const node of nodes) {
    const nextLineage = [...lineage, node.path];
    if (node.path === targetPath) {
      return nextLineage;
    }

    const nested = pathToNode(node.children, targetPath, nextLineage);
    if (nested) {
      return nested;
    }
  }

  return null;
}

function ensureExpandedToSelection(tree = state.tree, selectedPath = state.selectedBrowserPath) {
  if (!selectedPath) {
    return;
  }

  const lineage = pathToNode(tree, selectedPath) ?? [];
  // Expand ancestors only. The selected folder itself must remain foldable.
  lineage.slice(0, -1).forEach((folderPath) => expandedFolders.add(folderPath));
}

function isNodeExpanded(node) {
  // The active filesystem root is the Folder View anchor. It must remain
  // expanded so folding descendants can never make the browser disappear.
  if (node.path === state.rootPath || node.alwaysExpanded) return true;
  if (state.sidebarQuery.trim()) {
    return true;
  }

  if (!node.children.length) {
    return false;
  }

  return expandedFolders.has(node.path);
}

function scrollSelectedBrowserItemIntoView() {
  if (!state.selectedBrowserPath) return;
  const button = refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`);
  button?.scrollIntoView({ block: "nearest" });
}

async function loadBrowserChildren(node) {
  return false;
}

async function invalidatePlaylistCatalogSession() {
  await window.spcBoySB2.catalogSessionInvalidate("playlist");
}

async function loadBrowserSelection(node) {
  if (node.catalogFile) {
    return catalogPlaylistSelection(
      await window.spcBoySB2.databaseFileTracks([node.catalogFile]),
      node.catalogFile.path
    );
  }
  if (node.catalogFolder) {
    return catalogPlaylistSelection(
      await window.spcBoySB2.databaseFolderTracks([node.catalogFolder]),
      node.catalogFolder.folderPath
    );
  }
  return null;
}

function catalogPlaylistSelection(response, selectedPath) {
  if (response?.stale === true) return null;
  return {
    selectedFolderPath: selectedPath,
    selectedBrowserPath: state.selectedBrowserPath,
    playlist: databaseRowsToPlaylistTracks(response),
    columnContentHints: response?.columnContentHints,
    sortSessionId: response?.sortSessionId || null
  };
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
    ["Open in New Playlist", async () => {
      const tab = createPlaylistTab({ duplicateActive: false, title: node.name || "Playlist" });
      if (tab) await activateBrowserNode(node, { playNow: false });
    }],
    ["Show in Finder", async () => window.spcBoySB2.showInFinder(finderPath)],
    ["Play Now", async () => activateBrowserNode(node)],
    ["Queue", async () => queueBrowserNode(node)]
  ]);
}

async function activateBrowserNode(node, { playNow = true } = {}) {
  const generation = ++browserSelectionGeneration;
  try {
    state.selectedBrowserPath = node.path;
    persistSettings();
    syncTreeSelection();
    if (node.kind === "folder") {
      expandedFolders.add(node.path);
      await loadBrowserChildren(node);
    }
    const selection = await loadBrowserSelection(node);
    if (!selection
        || generation !== browserSelectionGeneration
        || state.selectedBrowserPath !== node.path) return;
    await applyFolderSelection(selection, state.activePlaylistTabId, node.name);
    const target = selection.playlist?.[0];
    if (playNow && target) await playVisibleTrack(target.id, 0);
  } catch (error) {
    console.error(error);
  }
}

async function previewBrowserLeaf(node) {
  const generation = ++browserSelectionGeneration;
  try {
    const selection = await loadBrowserSelection(node);
    if (!selection) return;
    if (generation !== browserSelectionGeneration || state.selectedBrowserPath !== node.path) return;
    await applyFolderSelection(selection, state.activePlaylistTabId, node.name);
  } catch (error) {
    console.error(error);
  }
}

async function handleBrowserPrimaryClick(node) {
  await handleBrowserGesture(node, "primaryClick", state.selectedBrowserPath === node.path);
}

async function handleBrowserGesture(node, gesture, wasSelected = false) {
  if (gesture === "disclosureClick" || (gesture === "primaryClick" && node.kind === "folder" && wasSelected)) {
    await toggleBrowserNode(node);
    return true;
  }
  if (gesture === "preview") {
    await previewBrowserLeaf(node);
    return true;
  }
  if (gesture === "activate" || gesture === "primaryClick") {
    await activateBrowserNode(node);
    return true;
  }
  return false;
}

function selectBrowserNode(node, { focus = false, previewLeaf = true } = {}) {
  lastPlaylistSelectionID = null;
  if (state.selectedBrowserPath !== node.path) {
    browserSelectionGeneration += 1;
  }
  state.selectedBrowserPath = node.path;
  persistSettings();
  syncTreeSelection();
  if (focus) refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
  if (previewLeaf && node.kind === "file") void previewBrowserLeaf(node);
}

function visibleBrowserNodes() {
  return renderedBrowserNodes;
}

function moveBrowserSelection(delta) {
  const nodes = visibleBrowserNodes();
  if (!nodes.length) return;
  const currentIndex = renderedBrowserNodeIndexByPath.get(state.selectedBrowserPath) ?? -1;
  const nextIndex = currentIndex < 0
    ? (delta >= 0 ? 0 : nodes.length - 1)
    : Math.max(0, Math.min(nodes.length - 1, currentIndex + delta));
  selectBrowserNode(nodes[nextIndex], { focus: true });
}

function jumpFocusedListToEdge(toEnd, focused = document.activeElement) {
  if (refs.treeRoot.contains(focused)) {
    if (currentSidebarView().contentMode === "tree") {
      const nodes = visibleBrowserNodes();
      if (nodes.length) selectBrowserNode(nodes[toEnd ? nodes.length - 1 : 0], { focus: true });
      return true;
    }
    const games = [...refs.treeRoot.querySelectorAll(".database-console-games:not(.is-hidden) .database-game-row")];
    const target = games[toEnd ? games.length - 1 : 0];
    target?.focus();
    return Boolean(target);
  }
  if (refs.playlistBody.contains(focused) && state.playlist.length) {
    const track = state.playlist[toEnd ? state.playlist.length - 1 : 0];
    selectPlaylistTrack(track.id, { focus: true });
    uiApp.playback.updateTimingSummary();
    return true;
  }
  return false;
}

function appendPlaylistTracks(additions, selectedBrowserPath = state.selectedBrowserPath) {
  if (!additions.length) return;
  const existingIds = new Set(state.playlist.map((track) => track.id));
  const uniqueAdditions = additions.filter((track) => !existingIds.has(track.id));
  if (!uniqueAdditions.length) return;
  state.selectedBrowserPath = selectedBrowserPath;
  state.playlist = [...state.playlist, ...uniqueAdditions];
  state.catalogPlaylistColumnContentHints = null;
  state.catalogPlaylistSortSessionId = null;
  state.selectedTrackId = uniqueAdditions[0].id;
  lastPlaylistSelectionID = state.selectedTrackId;
  persistSettings();
  renderTree();
  syncTreeSelection();
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
}

async function queueBrowserNode(node) {
  const selection = await loadBrowserSelection(node);
  if (!selection) return;
  appendPlaylistTracks(Array.isArray(selection.playlist) ? selection.playlist : [], node.path);
}

async function toggleBrowserNode(node) {
  if (node.kind !== "folder") return;
  if (node.path === state.rootPath) return;
  const expanded = expandedFolders.has(node.path);
  if (expanded) {
    expandedFolders.delete(node.path);
  } else {
    expandedFolders.add(node.path);
    await loadBrowserChildren(node);
  }
  renderTree();
  syncTreeSelection();
  refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
}

function renderTreeNode(node, container) {
  renderedBrowserNodeIndexByPath.set(node.path, renderedBrowserNodes.length);
  renderedBrowserNodes.push(node);
  renderedBrowserNodesByPath.set(node.path, node);
  const wrapper = document.createElement("div");
  wrapper.className = "tree-item";
  const button = document.createElement("button");
  const expanded = isNodeExpanded(node);
  button.dataset.browserPath = node.path;
  button.className = `tree-node${state.selectedBrowserPath === node.path ? " is-selected" : ""}`;
  if (state.selectedBrowserPath === node.path) selectedBrowserButton = button;
  button.classList.toggle("tree-file", node.kind === "file");
  button.setAttribute("aria-expanded", node.kind === "folder" ? String(expanded) : "false");
  button.innerHTML = `
    <span class="tree-disclosure">${node.kind === "folder" ? (expanded ? "▾" : "▸") : "·"}</span><span class="tree-label">${escapeHtml(node.name)}</span>
  `;
  button.addEventListener("click", (event) => {
    window.clearTimeout(browserClickTimer);
    selectBrowserNode(node, { focus: true, previewLeaf: false });
    if (event.detail > 1) return;
    browserClickTimer = window.setTimeout(() => void handleBrowserPrimaryClick(node), 220);
  });
  button.addEventListener("dblclick", (event) => {
    event.preventDefault();
    event.stopPropagation();
    window.clearTimeout(browserClickTimer);
    void handleBrowserGesture(node, "activate", true);
  });
  button.addEventListener("contextmenu", (event) => showSidebarContextMenu(node, event));
  button.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();
      moveBrowserSelection(event.key === "ArrowDown" ? 1 : -1);
      return;
    }
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    event.stopPropagation();
    if (event.key === "Enter") void handleBrowserGesture(node, "activate", true);
    else if (node.kind === "folder") void handleBrowserGesture(node, "disclosureClick", true);
  });

  wrapper.appendChild(button);

  if (node.kind === "folder" && node.children.length && expanded) {
    const group = document.createElement("div");
    group.className = "tree-group";
    node.children.forEach((child) => renderTreeNode(child, group));
    wrapper.appendChild(group);
  }

  container.appendChild(wrapper);
}

document.addEventListener("pointerdown", (event) => {
  if (!refs.sidebarContextMenu?.contains(event.target)) hideSidebarContextMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") hideSidebarContextMenu();
});

function filteredTree() {
  const terms = state.sidebarQuery.trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (!terms.length) {
    return currentSidebarView().contentMode === "tree" ? state.databaseFileTree : state.tree;
  }

  function ownSearchText(node) {
    const cached = treeSearchText.get(node);
    if (cached !== undefined) return cached;
    const searchable = `${node.name || ""} ${node.path || ""}`.toLowerCase();
    treeSearchText.set(node, searchable);
    return searchable;
  }

  function filterNode(node) {
    const matches = terms.every((term) => ownSearchText(node).includes(term));
    const children = node.children || [];
    const filteredChildren = children.length ? children.map(filterNode).filter(Boolean) : [];
    if (matches || filteredChildren.length > 0) {
      return {
        ...node,
        children: filteredChildren
      };
    }
    return null;
  }

  const sourceTree = currentSidebarView().contentMode === "tree" ? state.databaseFileTree : state.tree;
  return sourceTree.map(filterNode).filter(Boolean);
}

function renderTree() {
  renderedDatabaseGames = null;
  databaseGameButtons = [];
  databaseEmptyState = null;
  databaseConsoleGroups = [];
  selectedBrowserButton = null;
  resetSidebarContent();
  const visibleTree = filteredTree();
  if (visibleTree.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty sidebar-empty";
    empty.textContent = currentSidebarView().contentMode === "tree"
      ? "No catalog paths match this view."
      : "No database tree is available.";
    refs.treeRoot.appendChild(empty);
    syncSidebarFoldButton();
    return;
  }

  ensureExpandedToSelection(visibleTree);
  visibleTree.forEach((node) => renderTreeNode(node, refs.treeRoot));
  syncSidebarFoldButton();
}

function databaseGameKey(game) {
  return game.id;
}

function databaseConsoleName(game) {
  return typeof game.consoleGroupName === "string" ? game.consoleGroupName : "";
}

function visibleDatabaseSidebarRows() {
  return [...refs.treeRoot.querySelectorAll(
    ".database-console-row, .database-console-games:not(.is-hidden) .database-game-row"
  )];
}

function selectDatabaseSidebarRow(button, { focus = true, preview = false } = {}) {
  if (!button) return false;
  lastPlaylistSelectionID = null;
  window.clearTimeout(databaseGameClickTimer);
  databaseGameClickTimer = 0;

  const gameID = button.dataset.databaseGameKey;
  if (gameID) {
    const game = visibleDatabaseGames().find((entry) => databaseGameKey(entry) === gameID);
    if (!game) return false;
    state.selectedDatabaseGameKey = gameID;
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, gameID)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
  } else {
    const consoleName = button.dataset.databaseConsoleName;
    if (!consoleName) return false;
    state.selectedDatabaseConsoleName = consoleName;
    state.selectedDatabaseGameKey = null;
    void applySharedDatabaseGroupAction("select", consoleName)
      .catch((error) => reportDatabaseSidebarError("select the database console", error));
  }

  syncSidebarSelectionRowClass(button);
  if (focus) button.focus();
  persistSettings();

  if (gameID && preview) {
    const game = visibleDatabaseGames().find((entry) => databaseGameKey(entry) === gameID);
    if (game) {
      databaseGameClickTimer = window.setTimeout(() => {
        databaseGameClickTimer = 0;
        loadDatabaseGame(game).catch((error) => reportDatabaseSidebarError("preview the selected game", error));
      }, 220);
    }
  }
  return true;
}

function moveDatabaseSidebarSelection(currentButton, delta) {
  const rows = visibleDatabaseSidebarRows();
  if (!rows.length) return false;
  const currentIndex = rows.indexOf(currentButton);
  const nextIndex = currentIndex < 0
    ? (delta >= 0 ? 0 : rows.length - 1)
    : Math.max(0, Math.min(rows.length - 1, currentIndex + delta));
  const nextButton = rows[nextIndex];
  if (nextButton === currentButton) {
    currentButton?.focus();
    return true;
  }
  return selectDatabaseSidebarRow(nextButton, { focus: true, preview: true });
}

let databaseGroupTransitionGeneration = 0;

function databaseGroupStateSnapshot() {
  return {
    expandedGroupNames: databaseConsoleGroups
      .map(({ consoleName }) => consoleName)
      .filter((name) => !collapsedDatabaseConsoles.has(name)),
    selectedGroupName: state.selectedDatabaseConsoleName || null,
    selectedGameID: state.selectedDatabaseGameKey || null
  };
}

async function applySharedDatabaseGroupAction(action, groupName = null, gameID = null, { collapsed = false } = {}) {
  const generation = ++databaseGroupTransitionGeneration;
  const knownGroupNames = databaseConsoleGroups.map(({ consoleName }) => consoleName);
  const next = await window.spcBoySB2.databaseGroupState(
    {
      state: databaseGroupStateSnapshot(),
      action: {
        kind: action,
        groupName,
        gameId: gameID,
        collapsed,
        knownGroupNames
      }
    }
  );
  if (generation !== databaseGroupTransitionGeneration || !next) return false;
  const expanded = new Set(Array.isArray(next.expandedGroupNames) ? next.expandedGroupNames : []);
  for (const knownName of databaseConsoleGroups.map(({ consoleName }) => consoleName)) {
    if (expanded.has(knownName)) collapsedDatabaseConsoles.delete(knownName);
    else collapsedDatabaseConsoles.add(knownName);
  }
  state.selectedDatabaseConsoleName = next.selectedGroupName || null;
  state.selectedDatabaseGameKey = next.selectedGameID || null;
  syncCollapsedConsolePersistence();
  syncSidebarSelectionRowClass();
  return true;
}

function visibleDatabaseGames() {
  return Array.isArray(state.databaseSearchGames) ? state.databaseSearchGames : state.databaseGames;
}

function visibleDatabaseGameGroups() {
  const gamesByKey = new Map(visibleDatabaseGames().map((game) => [databaseGameKey(game), game]));
  return (Array.isArray(state.databaseGameGroups) ? state.databaseGameGroups : [])
    .map((group) => ({
      consoleName: String(group?.name || ""),
      gameItems: (Array.isArray(group?.gameIDs) ? group.gameIDs : [])
        .map((gameID) => gamesByKey.get(gameID))
        .filter(Boolean)
    }))
    .filter(({ consoleName, gameItems }) => consoleName && gameItems.length > 0);
}

function databaseLoadedSelectionID() {
  return state.selectedTrackId || state.playlist[0]?.id || null;
}

function makeDatabaseGameButton(game) {
  const button = document.createElement("button");
  button.type = "button";
  const isSelected = state.selectedDatabaseGameKey === databaseGameKey(game);
  button.className = `database-game-row${isSelected ? " is-selected" : ""}`;
  if (isSelected) {
    selectedDatabaseSidebarButton = button;
  }
  button.dataset.databaseGameKey = databaseGameKey(game);
  button.dataset.searchText = `${game.name} ${game.rootName || ""}`.toLowerCase();
  button.innerHTML = `<span class="database-disclosure">·</span><span class="database-game-name">${escapeHtml(game.displayName || game.name)}</span>${state.sidebarPathCounts ? `<span class="database-game-meta">${game.trackCount}</span>` : ""}`;
  button.addEventListener("click", (event) => {
    if (event.detail > 1) return;
    selectDatabaseSidebarRow(button, { focus: true, preview: true });
  });
  button.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();
      moveDatabaseSidebarSelection(button, event.key === "ArrowDown" ? 1 : -1);
      return;
    }
    if (event.key !== "Enter") return;
    event.preventDefault();
    event.stopPropagation();
    selectDatabaseSidebarRow(button, { focus: true });
    loadDatabaseGame(game).then((loaded) => {
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) return playVisibleTrack(targetID, 0);
      return undefined;
    }).catch((error) => reportDatabaseSidebarError("play the selected game", error));
  });
  button.addEventListener("dblclick", (event) => {
    event.preventDefault();
    event.stopPropagation();
    selectDatabaseSidebarRow(button, { focus: true });
    loadDatabaseGame(game).then((loaded) => {
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) return playVisibleTrack(targetID, 0);
      return undefined;
    }).catch((error) => reportDatabaseSidebarError("play the selected game", error));
  });
  button.addEventListener("contextmenu", (event) => {
    selectDatabaseSidebarRow(button, { focus: false });
    showContextMenu(event, [
      ["Open in New Playlist", async () => {
        const tab = createPlaylistTab({ duplicateActive: false, title: game.displayName || game.name });
        if (tab) await loadDatabaseGame(game);
      }],
      ["Show in Finder", async () => {
        const rows = await window.spcBoySB2.databaseGameTracks([game]);
        if (rows?.stale === true) return;
        const row = rows.rows[0];
        if (row) await window.spcBoySB2.showInFinder(row.archivePath || row.path);
      }],
      ["Play Now", async () => {
        const loaded = await loadDatabaseGame(game);
        const targetID = loaded ? databaseLoadedSelectionID() : null;
        if (targetID) await playVisibleTrack(targetID, 0);
      }],
      ["Queue", async () => {
        const rows = await window.spcBoySB2.databaseGameTracks([game]);
        if (rows?.stale === true) return;
        appendPlaylistTracks(databaseRowsToPlaylistTracks(rows, { adoptProjection: false }));
      }]
    ]);
  });
  return button;
}

function appendDatabaseGameRowsInBatches() {
  const generation = databaseRowRenderGeneration;
  const pendingRows = databaseConsoleGroups.flatMap(({ games, gameItems }) =>
    gameItems.map((game) => ({ games, game }))
  );
  let offset = 0;

  const appendBatch = () => {
    if (generation !== databaseRowRenderGeneration) return;
    const startedAt = performance.now();
    while (offset < pendingRows.length && performance.now() - startedAt < 8) {
      const { games, game } = pendingRows[offset++];
      const button = makeDatabaseGameButton(game);
      games.appendChild(button);
      databaseGameButtons.push(button);
    }
    if (offset < pendingRows.length) {
      window.requestAnimationFrame(appendBatch);
    }
  };

  window.requestAnimationFrame(appendBatch);
}

function renderDatabaseGames() {
  if (state.databaseSidebarLoading) {
    renderedDatabaseGames = null;
    resetSidebarContent();
    const loading = document.createElement("div");
    loading.className = "empty sidebar-empty sidebar-loading";
    loading.textContent = "Loading catalog…";
    refs.treeRoot.appendChild(loading);
    return;
  }
  const gamesForView = visibleDatabaseGames();
  if (renderedDatabaseGames !== gamesForView) {
    resetSidebarContent();
    databaseConsoleGroups = [];
    const groupsForView = visibleDatabaseGameGroups();
    databaseGameButtons = [];
    groupsForView.forEach(({ consoleName, gameItems }) => {
      const group = document.createElement("div");
      group.className = "database-console-group";
      const heading = document.createElement("button");
      heading.type = "button";
      heading.className = `database-console-row${state.selectedDatabaseConsoleName === consoleName && !state.selectedDatabaseGameKey ? " is-selected" : ""}`;
      if (heading.classList.contains("is-selected")) selectedDatabaseSidebarButton = heading;
      heading.dataset.databaseConsoleName = consoleName;
      heading.tabIndex = 0;
      const expanded = !collapsedDatabaseConsoles.has(consoleName);
      heading.innerHTML = `<span class="database-disclosure">${expanded ? "▾" : "▸"}</span><span class="database-console-label">${escapeHtml(consoleName)}</span>`;
      const games = document.createElement("div");
      games.className = "database-console-games";
      games.classList.toggle("is-hidden", !expanded);
      heading.addEventListener("click", async () => {
        const preserveFocus = document.activeElement === heading;
        try {
          await applySharedDatabaseGroupAction("toggle", consoleName);
          renderDatabaseGames();
          if (preserveFocus) {
            refs.treeRoot.querySelector(`[data-database-console-name="${CSS.escape(consoleName)}"]`)?.focus();
          }
        } catch (error) {
          reportDatabaseSidebarError("toggle the database console", error);
        }
      });
      heading.addEventListener("keydown", (event) => {
        if (event.key === "ArrowDown" || event.key === "ArrowUp") {
          event.preventDefault();
          event.stopPropagation();
          moveDatabaseSidebarSelection(heading, event.key === "ArrowDown" ? 1 : -1);
          return;
        }
        if (event.key === " ") {
          event.preventDefault();
          heading.click();
          return;
        }
        if (event.key === "Enter") {
          event.preventDefault();
          event.stopPropagation();
          void (async () => {
            await applySharedDatabaseGroupAction("select", consoleName);
            await activateDatabaseSelection();
          })().catch((error) => reportDatabaseSidebarError("play the selected console", error));
        }
      });
      heading.addEventListener("dblclick", (event) => {
        event.preventDefault();
        event.stopPropagation();
        void (async () => {
          await applySharedDatabaseGroupAction("select", consoleName);
          await activateDatabaseSelection();
        })().catch((error) => reportDatabaseSidebarError("play the selected console", error));
      });
      heading.addEventListener("contextmenu", (event) => {
        showContextMenu(event, [
          ["Open in New Playlist", async () => {
            const tab = createPlaylistTab({ duplicateActive: false, title: consoleName });
            if (tab) await loadDatabaseGamesIntoPlaylist(gameItems, { title: consoleName });
          }],
          ["Play Now", async () => {
            const loaded = await loadDatabaseGamesIntoPlaylist(gameItems, { title: consoleName });
            const targetID = loaded ? databaseLoadedSelectionID() : null;
            if (targetID) await playVisibleTrack(targetID, 0);
          }]
        ]);
      });
      group.append(heading, games);
      refs.treeRoot.appendChild(group);
      databaseConsoleGroups.push({ group, games, consoleName, gameItems });
    });

    databaseEmptyState = document.createElement("div");
    databaseEmptyState.className = "empty sidebar-empty";
    refs.treeRoot.appendChild(databaseEmptyState);
    renderedDatabaseGames = gamesForView;
    appendDatabaseGameRowsInBatches();
  }

  const query = state.sidebarQuery.trim();
  for (const button of databaseGameButtons) {
    button.classList.remove("is-hidden");
    button.classList.toggle("is-selected", state.selectedDatabaseGameKey === button.dataset.databaseGameKey);
  }

  for (const { group, games, consoleName } of databaseConsoleGroups) {
    if (query) {
      games.classList.remove("is-hidden");
    } else {
      games.classList.toggle("is-hidden", collapsedDatabaseConsoles.has(consoleName));
    }
    const disclosure = group.querySelector(".database-console-row .database-disclosure");
    if (disclosure) disclosure.textContent = games.classList.contains("is-hidden") ? "▸" : "▾";
  }

  databaseEmptyState.classList.toggle("is-hidden", !state.databaseSidebarError && gamesForView.length > 0);
  databaseEmptyState.textContent = state.databaseSidebarError || (state.databaseGames.length
    ? "No database games match this search."
    : "Use ScanSong to populate the selected database.");
  syncSidebarFoldButton();
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
    state.selectedBrowserPath = state.databaseFileTree[0]?.path || null;
    persistSettings();
    renderTree();
    syncTreeSelection();
    return;
  }
  const pendingFolders = [...state.databaseFileTree];
  while (pendingFolders.length > 0) {
    const node = pendingFolders.pop();
    if (node.kind !== "folder") continue;
    expandedFolders.add(node.path);
    for (const child of node.children || []) {
      if (child.kind === "folder") pendingFolders.push(child);
    }
  }
  renderTree();
  syncTreeSelection();
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
    const fileTree = await window.spcBoySB2.databaseFileTree();
    if (fileTree?.stale === true) return false;
    state.databaseFileTree = Array.isArray(fileTree) ? fileTree : [];
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
  if (!["paths", "consoles"].includes(mode)) return false;
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
  return true;
}

const SIDEBAR_VIEW_CYCLE = ["consoles", "paths"];
async function cycleSidebarMode() {
  const current = currentSidebarView().storedMode;
  const currentIndex = SIDEBAR_VIEW_CYCLE.indexOf(current);
  const next = SIDEBAR_VIEW_CYCLE[(currentIndex + 1 + SIDEBAR_VIEW_CYCLE.length) % SIDEBAR_VIEW_CYCLE.length];
  return setSidebarMode(next);
}

async function showFavoritesPlaylist() {
  await refreshFavorites();
  if (!activateOrCreateProjectionTab("Favorites")) return false;
  await invalidatePlaylistCatalogSession();
  state.playlist = [...state.favorites];
  state.playlistTitle = "Favorites";
  state.catalogPlaylistColumnContentHints = null;
  state.catalogPlaylistSortSessionId = null;
  clearPlaylistSelection();
  persistSettings();
  persistPlaylistTabs();
  renderPlaylistTabs();
  renderPlaylist();
  renderSidebar();
}

function formatHistoryTimestamp(milliseconds) {
  const date = new Date(Number(milliseconds));
  if (!Number.isFinite(date.getTime())) return "";
  const pad = (value, width = 2) => String(value).padStart(width, "0");
  return `${pad(date.getFullYear(), 4)}.${pad(date.getMonth() + 1)}.${pad(date.getDate())}-${pad(date.getHours())}.${pad(date.getMinutes())}.${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
}

function historyRecordToPlaylistTrack(record) {
  const snapshot = record?.snapshot || {};
  const identity = snapshot.identity || {};
  const sourcePath = String(identity.sourcePath || "");
  if (!sourcePath) return null;

  const archiveEntry = identity.archiveEntry || null;
  const trackIndex = Math.max(0, Number(identity.trackIndex) || 0);
  const trackCount = Math.max(1, Number(identity.trackCount) || 1);
  const filename = String(snapshot.filename || sourcePath.split(/[\\/]/).at(-1) || "Track");
  const timestampMilliseconds = Number(record.timestampMilliseconds);
  const playLengthMilliseconds = Math.max(0, Number(snapshot.playLengthMilliseconds) || 0);
  const seconds = playLengthMilliseconds / 1_000;
  return {
    id: String(record.id || `${sourcePath}|${timestampMilliseconds}`),
    path: sourcePath,
    archivePath: archiveEntry ? sourcePath : null,
    archiveEntry,
    trackIndex,
    trackCount,
    trackNumber: trackCount > 1 ? trackIndex + 1 : null,
    rootPath: sourcePath.split(/[\\/]/).slice(0, -1).join("/"),
    sourceFilename: filename,
    filename,
    displayName: String(snapshot.title || filename),
    title: String(snapshot.title || ""),
    game: String(snapshot.game || ""),
    artist: String(snapshot.author || ""),
    system: String(snapshot.system || ""),
    basePlaybackSeconds: seconds,
    lengthLabel: seconds > 0 ? uiApp.formatTime(Math.round(seconds)) : "",
    timestampMilliseconds,
    timestamp: formatHistoryTimestamp(timestampMilliseconds),
    catalogRow: false
  };
}

async function showPlaybackHistory() {
  const renderGeneration = playlistRenderGeneration;
  const records = await window.spcBoySB2.playbackHistoryList();
  if (renderGeneration !== playlistRenderGeneration) return false;
  if (!activateOrCreateProjectionTab("History")) return false;
  await invalidatePlaylistCatalogSession();
  state.playlist = (Array.isArray(records) ? records : [])
    .map(historyRecordToPlaylistTrack)
    .filter(Boolean);
  state.playlistTitle = "History";
  state.catalogPlaylistColumnContentHints = null;
  state.catalogPlaylistSortSessionId = null;
  state.playlistSortEnabled = true;
  state.sortColumn = "timestamp";
  state.sortDirection = "descending";
  clearPlaylistSelection();
  state.selectedTrackId = state.playlist[0]?.id || null;
  state.selectedTrackIds = state.selectedTrackId ? [state.selectedTrackId] : [];
  state.playlistSelectionAnchorId = state.selectedTrackId;
  persistSettings();
  persistPlaylistTabs();
  renderPlaylistTabs();
  renderPlaylist();
  renderSidebar();
  return true;
}

async function refreshDatabaseGamesForVisibleRoots() {
  const previousSelection = state.selectedDatabaseGameKey;
  try {
    const projection = await window.spcBoySB2.databaseGames();
    if (projection?.stale === true) return false;
    state.databaseGames = Array.isArray(projection?.games) ? projection.games : [];
    state.databaseGameGroups = Array.isArray(projection?.groups) ? projection.groups : [];
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
    state.catalogPlaylistColumnContentHints = null;
    state.catalogPlaylistSortSessionId = null;
    clearPlaylistSelection();
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
  state.sidebarView = Object.freeze(localSidebarView(state.sidebarMode, state.sidebarQuery));
  renderSidebar();
}

async function loadDatabaseGame(game) {
  return loadDatabaseGamesIntoPlaylist([game]);
}

async function toggleSelectedFavorites() {
  const focusedInSidebar = refs.treeRoot.contains(document.activeElement);
  if (!focusedInSidebar && state.selectedTrackIds.length) {
    const tracks = state.playlist.filter((entry) => state.selectedTrackIds.includes(entry.id));
    if (tracks.length) {
      await toggleFavorites(tracks);
      renderSidebar();
      renderPlaylist();
      return;
    }
  }
  const games = state.selectedDatabaseGameKey
    ? visibleDatabaseGames().filter((game) => databaseGameKey(game) === state.selectedDatabaseGameKey)
    : state.selectedDatabaseConsoleName
      ? visibleDatabaseGames().filter((game) => databaseConsoleName(game) === state.selectedDatabaseConsoleName)
      : [];
  if (!games.length) return;
  const rows = await window.spcBoySB2.databaseGameTracks(games);
  if (rows?.stale === true) return;
  await toggleFavorites(databaseRowsToPlaylistTracks(rows, { adoptProjection: false }));
  renderSidebar();
  renderPlaylist();
}

function reportDatabaseSidebarError(action, error) {
  const detail = String(error?.message || error || "Unknown database error");
  state.databaseSidebarError = `Could not ${action}: ${detail}`;
  console.error(`[SPCBoy] could not ${action}`, error);
  if (currentSidebarView().contentMode === "database") renderDatabaseGames();
}

function databaseRowsToPlaylistTracks(response, { adoptProjection = true } = {}) {
  const rows = response.rows;
  if (adoptProjection) {
    state.catalogPlaylistColumnContentHints = response.columnContentHints;
    state.catalogPlaylistSortSessionId = response.sortSessionId || null;
  }
  return rows.map((row, index) => ({
    id: row.playlistId,
    favoriteId: row.favoriteId || null,
    index: index + 1,
    path: row.path,
    rootPath: row.rootPath || state.rootPath,
    sourceFilename: row.filename,
    trackIndex: Number(row.trackIndex) || 0,
    trackCount: Math.max(1, Number(row.trackCount) || 1),
    archivePath: row.archivePath || null,
    archiveEntry: row.archiveEntry || null,
    modifiedAt: Number(row.modifiedAt) || 0,
    sourceSignature: row.sourceSignature || null,
    scanVersion: Number(row.scanVersion) || 0,
    // CatalogPlaylistPresentationCore supplies all visible catalog text. The
    // renderer only lays out the projection it received.
    filename: row.fileText,
    displayName: row.displayName,
    title: row.titleText,
    game: row.gameText,
    artist: row.authorText,
    system: row.systemText,
    lengthLabel: row.lengthText,
    basePlaybackSeconds: row.playLengthMs > 0 ? row.playLengthMs / 1000 : 0,
    metadataLoaded: row.metadataLoaded === true,
    catalogRow: true
  }));
}

async function loadDatabaseGamesIntoPlaylist(games, { title = null } = {}) {
  const targetTabID = state.activePlaylistTabId;
  await invalidatePlaylistCatalogSession();
  if (targetTabID !== state.activePlaylistTabId) return false;
  const rows = await window.spcBoySB2.databaseGameTracks(games);
  if (rows?.stale === true || targetTabID !== state.activePlaylistTabId) return false;
  state.databaseSidebarError = "";
  state.selectedDatabaseGameKey = games.length === 1 ? databaseGameKey(games[0]) : null;
  state.playlist = databaseRowsToPlaylistTracks(rows);
  state.playlistTitle = String(title || (games.length === 1
    ? String(games[0].displayName || games[0].name || "Playlist")
    : `${databaseConsoleName(games[0]) || "Playlist"} (${games.length})`));
  renderPlaylistTabs();
  await applyCatalogPlaylistSort();
  if (targetTabID !== state.activePlaylistTabId) return false;
  // Sidebar selection is a preview operation. It must not replace the
  // playback queue or clear the active track; explicit Play/Enter adopts this
  // visible playlist through playTrack({ replaceQueue: true }).
  clearPlaylistSelection();
  persistSettings();
  // Database rows already contain their catalog metadata. Keep playlist
  // hydration independent from the 21k-entry sidebar redraw; rebuilding the
  // sidebar here made a small indexed query wait on every database row DOM
  // update before the playlist could paint.
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
  uiApp.playback.updateNativeDiagnostics();
  return true;
}

async function activateDatabaseSelection() {
  const gamesForView = visibleDatabaseGames();
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
      const loaded = await loadDatabaseGamesIntoPlaylist(games, { title: state.selectedDatabaseConsoleName });
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) await playVisibleTrack(targetID, 0);
      return;
    }
  }
}

async function activateFocusedItem(focusTarget = document.activeElement) {
  const focused = focusTarget?.closest?.(".playlist-row, .tree-node, .database-game-row, .database-console-row") || document.activeElement;
  const playlistRow = focused?.closest?.(".playlist-row")
    || (refs.playlistBody.contains(focusTarget) && state.selectedTrackId
      ? refs.playlistBody.querySelector(`[data-track-id="${CSS.escape(state.selectedTrackId)}"]`)
      : null);
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
    const node = renderedBrowserNodesByPath.get(browserButton.dataset.browserPath);
    if (node) {
      await activateBrowserNode(node);
      return true;
    }
  }

  const databaseGameButton = focused?.closest?.(".database-game-row");
  if (databaseGameButton?.dataset.databaseGameKey) {
    const game = visibleDatabaseGames().find((entry) => databaseGameKey(entry) === databaseGameButton.dataset.databaseGameKey);
    if (game) {
      selectDatabaseSidebarRow(databaseGameButton, { focus: true });
      const loaded = await loadDatabaseGame(game);
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) await playVisibleTrack(targetID, 0);
      return true;
    }
  }

  const databaseConsoleButton = focused?.closest?.(".database-console-row");
  if (databaseConsoleButton?.dataset.databaseConsoleName) {
    selectDatabaseSidebarRow(databaseConsoleButton, { focus: true });
    await activateDatabaseSelection();
    return true;
  }

  return false;
}

function renderSidebar() {
  const view = currentSidebarView();
  const modeLabels = { consoles: "Console View", paths: "Path View" };
  const modeIcons = { consoles: "#icon-database", paths: "#icon-folder-tree" };
  if (refs.sidebarViewToggleButton) {
    refs.sidebarViewToggleButton.title = modeLabels[view.storedMode] || "Library view";
    refs.sidebarViewToggleButton.setAttribute("aria-label", modeLabels[view.storedMode] || "Library view");
    const icon = refs.sidebarViewToggleButton.querySelector("use");
    if (icon) icon.setAttribute("href", modeIcons[view.storedMode] || "#icon-sidebar-views");
  }
  if (state.databaseSidebarLoading) {
    resetSidebarContent();
    const loading = document.createElement("div");
    loading.className = "empty sidebar-empty sidebar-loading";
    loading.textContent = "Loading catalog…";
    refs.treeRoot.appendChild(loading);
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
}

function allColumns() {
  return state.columnOrder
    .map((columnId) => COLUMN_DEFS.find((column) => column.id === columnId))
    .filter(Boolean);
}

function orderedColumns() {
  return allColumns().filter((column) => state.columnVisibility[column.id]
    && !state.automaticallyHiddenColumns.has(column.id));
}

function hasMeaningfulColumnContent(value) {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 && normalized !== "—" && normalized !== "-";
}

function columnHasContent(column) {
  if (column.id === "favorite" || column.id === "index") return true;
  const sharedHint = state.catalogPlaylistColumnContentHints?.[column.id];
  if (sharedHint !== undefined) return hasMeaningfulColumnContent(sharedHint);
  const sample = state.playlist.length > 1200
    ? [...state.playlist.slice(0, 600), ...state.playlist.slice(-600)]
    : state.playlist;
  return sample.some((track, rowIndex) => hasMeaningfulColumnContent(playlistColumnValue(track, column, rowIndex)));
}

function updateAutomaticColumnVisibility() {
  if (!state.playlist.length) {
    state.automaticallyHiddenColumns = new Set();
    return;
  }
  const next = new Set();
  for (const column of allColumns()) {
    if (!state.columnVisibility[column.id] || column.id === "favorite" || column.id === "index") continue;
    if (!columnHasContent(column)) next.add(column.id);
  }
  state.automaticallyHiddenColumns = next;
}

function playlistDisplayPath(track) {
  const sourcePath = String(track.path || "");
  const rootPath = String(track.rootPath || state.rootPath || "");
  if (!sourcePath || !rootPath) return sourcePath;
  const hashIndex = sourcePath.indexOf("#");
  const physicalPath = hashIndex === -1 ? sourcePath : sourcePath.slice(0, hashIndex);
  const archiveSuffix = hashIndex === -1 ? "" : sourcePath.slice(hashIndex);
  const normalizedRoot = rootPath.replace(/[\\/]+$/, "");
  const normalizedPhysical = physicalPath.replace(/\\/g, "/");
  const normalizedRootForMatch = normalizedRoot.replace(/\\/g, "/");
  const rootPrefix = `${normalizedRootForMatch}/`;
  const rootLabel = normalizedRootForMatch.split("/").at(-1);
  const sourceForMatch = normalizedPhysical.toLocaleLowerCase();
  const rootForMatch = normalizedRootForMatch.toLocaleLowerCase();
  if (sourceForMatch === rootForMatch) return `${rootLabel}${archiveSuffix}`;
  if (sourceForMatch.startsWith(rootPrefix.toLocaleLowerCase())) return `${rootLabel}/${normalizedPhysical.slice(rootPrefix.length)}${archiveSuffix}`;
  return sourcePath;
}

function playlistColumnValue(track, column, rowIndex = null) {
  if (column.id === "index") return rowIndex === null ? "" : rowIndex + 1;
  if (column.id === "favorite") return "";
  return column.id === "path" ? playlistDisplayPath(track) : (track[column.id] ?? "");
}

function isCatalogPlaylistProjection() {
  return state.catalogPlaylistColumnContentHints !== null
    && state.playlist.length > 0
    && state.playlist.every((track) => track.catalogRow === true);
}

async function applyCatalogPlaylistSort() {
  if (!state.playlistSortEnabled
      || !isCatalogPlaylistProjection()
      || !state.catalogPlaylistSortSessionId) return false;
  const generation = ++catalogPlaylistSortGeneration;
  const originalIDs = state.playlist.map((track) => track.id);
  const orderedIDs = await window.spcBoySB2.databasePlaylistSort({
    sessionId: state.catalogPlaylistSortSessionId,
    column: state.sortColumn,
    direction: state.sortDirection,
    ids: originalIDs
  });
  if (generation !== catalogPlaylistSortGeneration
      || !Array.isArray(orderedIDs)
      || orderedIDs.length !== originalIDs.length
      || state.playlist.length !== originalIDs.length
      || state.playlist.some((track, index) => track.id !== originalIDs[index])) {
    return false;
  }
  const tracksByID = new Map(state.playlist.map((track) => [track.id, track]));
  const sorted = orderedIDs.map((id) => tracksByID.get(id));
  if (sorted.some((track) => !track)) return false;
  state.playlist = sorted;
  return true;
}

function playlistSortRecords() {
  return state.playlist.map((track, naturalOrder) => ({
    id: String(track.id),
    naturalOrder,
    fileText: String(track.filename || ""),
    titleText: String(track.title || ""),
    gameText: String(track.game || ""),
    authorText: String(track.artist || ""),
    systemText: String(track.system || ""),
    pathText: playlistDisplayPath(track),
    lengthMilliseconds: Math.max(0, Math.round((Number(track.basePlaybackSeconds) || 0) * 1000)),
    timestampMilliseconds: Number.isFinite(Number(track.timestampMilliseconds))
      ? Number(track.timestampMilliseconds)
      : null
  }));
}

async function applyProjectionPlaylistSort() {
  if (!state.playlistSortEnabled || isCatalogPlaylistProjection()) return false;
  const generation = ++projectionPlaylistSortGeneration;
  const originalIDs = state.playlist.map((track) => track.id);
  const orderedIDs = await window.spcBoySB2.playlistProjectionSort({
    records: playlistSortRecords(),
    frontendColumn: state.sortColumn,
    direction: state.sortDirection
  });
  if (generation !== projectionPlaylistSortGeneration
      || !Array.isArray(orderedIDs)
      || orderedIDs.length !== originalIDs.length
      || state.playlist.length !== originalIDs.length
      || state.playlist.some((track, index) => track.id !== originalIDs[index])) {
    return false;
  }
  const tracksByID = new Map(state.playlist.map((track) => [track.id, track]));
  const sorted = orderedIDs.map((id) => tracksByID.get(id));
  if (sorted.some((track) => !track)) return false;
  state.playlist = sorted;
  return true;
}

async function applyExplicitPlaylistSort() {
  if (state.sortColumn === "timestamp" && state.playlistTitle !== "History") return false;
  if (isCatalogPlaylistProjection()) {
    return applyCatalogPlaylistSort();
  }
  return applyProjectionPlaylistSort();
}

function closeColumnMenu() {
  columnMenu?.remove();
  columnMenu = null;
}

function showColumnMenu(event) {
  closeColumnMenu();
  columnMenu = document.createElement("div");
  columnMenu.className = "column-menu";
  columnMenu.addEventListener("click", (menuEvent) => menuEvent.stopPropagation());

  for (const column of allColumns()) {
    const label = document.createElement("label");
    label.className = "column-menu-item";
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = state.columnVisibility[column.id];
    checkbox.addEventListener("change", () => {
      state.automaticallyHiddenColumns.delete(column.id);
      state.columnVisibility[column.id] = checkbox.checked;
      if (!Object.values(state.columnVisibility).some(Boolean)) {
        state.columnVisibility[column.id] = true;
        checkbox.checked = true;
      }
      persistSettings();
      // Visibility changes must be immediate. Full content measurement belongs
      // to playlist population or an explicit header-seam auto-size action.
      autoSizedPlaylistSignature = playlistAutoSizeSignature();
      closeColumnMenu();
      renderPlaylistHeader();
      renderPlaylist();
    });
    label.append(checkbox, document.createTextNode(column.label));
    columnMenu.appendChild(label);
  }

  document.body.appendChild(columnMenu);
  document.addEventListener("click", closeColumnMenu, { once: true });
  const left = Math.min(event.clientX, window.innerWidth - columnMenu.offsetWidth - 8);
  const top = Math.min(event.clientY, window.innerHeight - columnMenu.offsetHeight - 8);
  columnMenu.style.left = `${Math.max(8, left)}px`;
  columnMenu.style.top = `${Math.max(8, top)}px`;
}

function beginColumnResize(event, columnId, header) {
  event.preventDefault();
  event.stopPropagation();
  const startX = event.clientX;
  const table = refs.playlistHeaderRow.closest("table");
  const tableWidth = table?.getBoundingClientRect().width || 0;
  const handle = event.currentTarget;
  if (!Number.isFinite(tableWidth) || tableWidth <= 0) {
    return;
  }
  const startWidth = state.columnWidths[columnId];
  const otherColumns = orderedColumns().filter((column) => column.id !== columnId);
  const minimumWidth = columnMinimumWidthPercent(columnId, tableWidth);
  const otherMinimumTotal = otherColumns.reduce(
    (sum, column) => sum + columnMinimumWidthPercent(column.id, tableWidth),
    0
  );
  const maximumWidth = Math.max(minimumWidth, Math.min(80, 100 - otherMinimumTotal));
  const pointerId = event.pointerId;
  columnResizePointerId = pointerId;
  const onMove = (moveEvent) => {
    if (moveEvent.pointerId !== pointerId) return;
    const nextWidth = Math.min(
      maximumWidth,
      Math.max(minimumWidth, Math.min(80, startWidth + ((moveEvent.clientX - startX) / tableWidth) * 100))
    );
    state.columnWidths[columnId] = nextWidth;
    header.style.width = `${nextWidth}%`;
    for (const row of playlistRowsByTrackId.values()) {
      const cell = row.querySelector(`[data-column-id="${CSS.escape(columnId)}"]`);
      if (cell) cell.style.width = `${nextWidth}%`;
    }
  };
  const finish = (finishEvent) => {
    if (finishEvent?.pointerId !== pointerId) return;
    document.removeEventListener("pointermove", onMove);
    document.removeEventListener("pointerup", onUp);
    document.removeEventListener("pointercancel", finish);
    handle?.releasePointerCapture?.(pointerId);
    columnResizePointerId = null;
    const draggedWidth = state.columnWidths[columnId];
    redistributeOtherColumnWidths(otherColumns, 100 - draggedWidth, tableWidth);
    persistSettings();
    renderPlaylistHeader();
    syncPlaylistColumnWidths();
  };
  const onUp = (upEvent) => finish(upEvent);
  handle?.setPointerCapture?.(pointerId);
  document.addEventListener("pointermove", onMove);
  document.addEventListener("pointerup", onUp);
  document.addEventListener("pointercancel", finish);
}

function columnContentWidth(columnId) {
  const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(columnId)}"]`);
  const column = COLUMN_DEFS.find((candidate) => candidate.id === columnId);
  if (!column) return 0;
  textMeasureContext ||= document.createElement("canvas").getContext("2d");
  const styleSource = header?.querySelector(".playlist-header-label") || header || refs.playlistBody;
  const style = getComputedStyle(styleSource);
  textMeasureContext.font = `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  const renderedHeader = header?.querySelector(".playlist-header-label")?.textContent?.trim() || column.label;
  const sharedHint = state.catalogPlaylistColumnContentHints?.[columnId];
  const sample = state.playlist.length > 1200
    ? [...state.playlist.slice(0, 600), ...state.playlist.slice(-600)]
    : state.playlist;
  const values = sharedHint
    ? [renderedHeader, sharedHint]
    : [renderedHeader, ...sample.map((track, rowIndex) => String(playlistColumnValue(track, column, rowIndex)))];
  return Math.max(...values.map((value) => textMeasureContext.measureText(value).width), 0) + playlistColumnHorizontalPadding();
}

function playlistColumnHorizontalPadding() {
  const perSide = Number(state.playlistColumnSizing?.horizontalPaddingPerSide);
  return (Number.isFinite(perSide) ? Math.max(0, Math.min(16, perSide)) : 4) * 2;
}

function columnHeaderContentWidth(columnId) {
  const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(columnId)}"]`);
  const column = COLUMN_DEFS.find((candidate) => candidate.id === columnId);
  if (!column) return 0;
  textMeasureContext ||= document.createElement("canvas").getContext("2d");
  const styleSource = header?.querySelector(".playlist-header-label") || header || refs.playlistBody;
  const style = getComputedStyle(styleSource);
  textMeasureContext.font = `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  const sortMarker = state.playlistSortEnabled && state.sortColumn === columnId
    ? state.sortDirection === "ascending" ? " ▲" : " ▼"
    : "";
  const label = header?.querySelector(".playlist-header-label")?.textContent?.trim() || `${column.label}${sortMarker}`;
  return textMeasureContext.measureText(label).width + playlistColumnHorizontalPadding();
}

function columnMinimumWidthPercent(columnId, tableWidth) {
  if (!Number.isFinite(tableWidth) || tableWidth <= 0) return 0;
  return Math.min(80, (columnHeaderContentWidth(columnId) / tableWidth) * 100);
}

function redistributeOtherColumnWidths(columns, targetTotal, tableWidth) {
  if (!columns.length) return;
  const minimums = columns.map((column) => columnMinimumWidthPercent(column.id, tableWidth));
  const minimumTotal = minimums.reduce((sum, width) => sum + width, 0);
  const total = Math.max(minimumTotal, targetTotal);
  const existingExtras = columns.map((column, index) => Math.max(0, state.columnWidths[column.id] - minimums[index]));
  const existingExtraTotal = existingExtras.reduce((sum, width) => sum + width, 0);
  const extraTotal = Math.max(0, total - minimumTotal);
  columns.forEach((column, index) => {
    const share = existingExtraTotal > 0
      ? existingExtras[index] / existingExtraTotal
      : 1 / columns.length;
    state.columnWidths[column.id] = minimums[index] + extraTotal * share;
  });
}

function autoSizeColumns() {
  const columns = orderedColumns();
  if (!columns.length || !state.playlist.length) return;
  const preferredWidths = columns.map((column) => columnContentWidth(column.id));
  const totalWidth = preferredWidths.reduce((sum, width) => sum + width, 0);
  if (!totalWidth) return;
  const table = refs.playlistHeaderTable;
  const availableWidth = refs.playlistScrollWrap?.clientWidth || table.clientWidth || totalWidth;
  const width = `${Math.max(availableWidth, totalWidth)}px`;
  [refs.playlistHeaderTable, refs.playlistBodyTable].forEach((playlistTable) => {
    playlistTable.style.width = width;
    playlistTable.style.minWidth = `${availableWidth}px`;
  });
  columns.forEach((column, index) => {
    state.columnWidths[column.id] = (preferredWidths[index] / totalWidth) * 100;
  });
  persistSettings();
}

function autoSizeColumn(columnId) {
  if (!state.playlist.length || !state.columnVisibility[columnId]) return;
  const columns = orderedColumns();
  const tableWidth = refs.playlistHeaderRow.closest("table").getBoundingClientRect().width;
  const nextWidth = Math.max(
    columnMinimumWidthPercent(columnId, tableWidth),
    Math.min(80, (columnContentWidth(columnId) / tableWidth) * 100)
  );
  const previousWidth = state.columnWidths[columnId];
  const otherColumns = columns.filter((column) => column.id !== columnId);
  const targetOtherTotal = 100 - nextWidth;
  state.columnWidths[columnId] = nextWidth;
  redistributeOtherColumnWidths(otherColumns, targetOtherTotal, tableWidth);
  if (!Number.isFinite(previousWidth)) state.columnWidths[columnId] = nextWidth;
  persistSettings();
  renderPlaylistHeader();
  syncPlaylistColumnWidths();
}

function renderPlaylistHeader() {
  updateAutomaticColumnVisibility();
  refs.playlistHeaderRow.innerHTML = "";

  for (const column of orderedColumns()) {
    const canSortColumn = column.sortable !== false
      && (column.id !== "timestamp" || state.playlistTitle === "History");
    const th = document.createElement("th");
    th.dataset.columnId = column.id;
    th.draggable = true;
    th.className = column.className || "";
    state.columnWidths[column.id] = Math.max(
      Number(state.columnWidths[column.id]) || 0,
      columnMinimumWidthPercent(column.id, refs.playlistHeaderTable?.getBoundingClientRect().width || 0)
    );
    th.style.width = `${state.columnWidths[column.id]}%`;
    th.title = canSortColumn ? `Sort by ${column.label}` : (column.id === "index" ? "Line number" : column.label);

    const label = document.createElement("span");
    label.className = "playlist-header-label toolbar-control";
    label.textContent = column.label;
    if (state.playlistSortEnabled && state.sortColumn === column.id) {
      label.textContent += state.sortDirection === "ascending" ? " ▲" : " ▼";
    }
    th.appendChild(label);

    const resizeHandle = document.createElement("span");
    resizeHandle.className = "column-resize-handle";
    resizeHandle.addEventListener("pointerdown", (event) => beginColumnResize(event, column.id, th));
    resizeHandle.addEventListener("dblclick", (event) => {
      event.preventDefault();
      event.stopPropagation();
      autoSizeColumn(column.id);
    });
    th.appendChild(resizeHandle);

    if (canSortColumn) th.addEventListener("click", async (event) => {
      if (event.target === resizeHandle || columnResizePointerId !== null) return;
      if (state.playlistSortEnabled && state.sortColumn === column.id) {
        state.sortDirection = state.sortDirection === "ascending" ? "descending" : "ascending";
      } else {
        state.playlistSortEnabled = true;
        state.sortColumn = column.id;
        state.sortDirection = "ascending";
      }
      persistSettings();
      await applyExplicitPlaylistSort();
      renderPlaylistHeader();
      renderPlaylist({ sort: false });
    });

    th.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      showColumnMenu(event);
    });

    th.addEventListener("dragstart", (event) => {
      draggedColumnId = column.id;
      th.classList.add("is-dragging");
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("text/plain", column.id);
    });

    th.addEventListener("dragend", () => {
      draggedColumnId = null;
      refs.playlistHeaderRow.querySelectorAll("th").forEach((cell) => {
        cell.classList.remove("is-dragging", "is-drop-target");
      });
    });

    th.addEventListener("dragover", (event) => {
      if (!draggedColumnId || draggedColumnId === column.id) {
        return;
      }

      event.preventDefault();
      th.classList.add("is-drop-target");
    });

    th.addEventListener("dragleave", () => {
      th.classList.remove("is-drop-target");
    });

    th.addEventListener("drop", (event) => {
      if (!draggedColumnId || draggedColumnId === column.id) {
        return;
      }

      event.preventDefault();
      const nextOrder = [...state.columnOrder];
      const fromIndex = nextOrder.indexOf(draggedColumnId);
      const toIndex = nextOrder.indexOf(column.id);
      if (fromIndex < 0 || toIndex < 0) {
        return;
      }

      const [moved] = nextOrder.splice(fromIndex, 1);
      nextOrder.splice(toIndex, 0, moved);
      state.columnOrder = nextOrder;
      persistSettings();
      renderPlaylistHeader();
      renderPlaylist();
    });

    refs.playlistHeaderRow.appendChild(th);
  }
}

function renderPlaylistCell(track, column, rowIndex) {
  const td = document.createElement("td");
  td.className = column.className || "";
  td.dataset.columnId = column.id;
  td.style.width = `${state.columnWidths[column.id]}%`;
  if (column.id === "favorite") {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "favorite-toggle";
    const favorite = isFavoritePresentation(track);
    button.title = favorite ? "Remove from Favorites" : "Add to Favorites";
    button.setAttribute("aria-label", button.title);
    button.setAttribute("aria-pressed", favorite ? "true" : "false");
    button.classList.toggle("is-favorite", favorite);
    button.innerHTML = `<svg class="ui-icon" aria-hidden="true"><use href="#icon-star"></use></svg>`;
    button.addEventListener("click", async (event) => {
      event.preventDefault();
      event.stopPropagation();
      await toggleFavorites([track]);
      renderSidebar();
      renderPlaylist();
    });
    td.appendChild(button);
  } else {
    td.textContent = String(playlistColumnValue(track, column, rowIndex));
  }
  return td;
}

function playlistAutoSizeSignature() {
  const columns = orderedColumns();
  const firstID = state.playlist[0]?.id || "";
  const lastID = state.playlist.at(-1)?.id || "";
  return `${columns.map((column) => column.id).join("\u0001")}\u0002${state.playlist.length}\u0002${firstID}\u0002${lastID}`;
}

function updatePlaylistRowState(row, trackId) {
  if (!row) return;
  row.classList.toggle("is-selected", state.selectedTrackIds.includes(trackId));
  row.classList.toggle("is-current", state.activePlaylistTabId === state.playbackTabId && state.currentTrackId === trackId);
}

function selectPlaylistTrack(trackId, { focus = false, extend = false, range = false } = {}) {
  const track = state.playlist.find((entry) => entry.id === trackId);
  if (!track) return null;

  const selection = window.SB2PlaylistController.reduceSelection({
    playlist: state.playlist,
    selectedIds: state.selectedTrackIds,
    anchorId: state.playlistSelectionAnchorId
  }, trackId, { extend, range });
  if (!selection) return null;
  state.selectedTrackIds = selection.selectedIds;
  state.selectedTrackId = selection.primaryId;
  state.playlistSelectionAnchorId = selection.anchorId;
  lastPlaylistSelectionID = selection.primaryId;
  // Playlist selection belongs to playlist-tab state. Saving all frontend
  // settings here broadcasts a settings refresh, whose renderAll() rebuilds
  // this table while a pointer click is still being dispatched.
  persistPlaylistTabs();

  if (focus && playlistUsesVirtualRows() && !playlistRowsByTrackId.has(track.id)) {
    const trackIndex = state.playlist.findIndex((entry) => entry.id === track.id);
    refs.playlistBodyWrap.scrollTop = Math.max(
      0,
      trackIndex * playlistVirtualRowHeight - (refs.playlistBodyWrap.clientHeight / 2)
    );
    renderPlaylist({ sort: false });
  }

  for (const [id, row] of playlistRowsByTrackId) updatePlaylistRowState(row, id);
  const primaryRow = selection.primaryId ? playlistRowsByTrackId.get(selection.primaryId) || null : null;
  const clickedRow = playlistRowsByTrackId.get(track.id) || null;
  selectedPlaylistRow = primaryRow;
  schedulePlaylistSelectionIndicator();
  if (focus) clickedRow?.focus({ preventScroll: true });
  return track;
}

function refreshPlaylistPlaybackState() {
  for (const [id, row] of playlistRowsByTrackId) updatePlaylistRowState(row, id);

  currentPlaylistRow?.classList.remove("is-current");
  const nextCurrentRow = state.activePlaylistTabId === state.playbackTabId && state.currentTrackId
    ? playlistRowsByTrackId.get(state.currentTrackId) || null
    : null;
  nextCurrentRow?.classList.add("is-current");
  currentPlaylistRow = nextCurrentRow;
}

function refreshPlaylistRow(trackId) {
  const track = state.playlist.find((entry) => entry.id === trackId);
  const rowIndex = state.playlist.findIndex((entry) => entry.id === trackId);
  const row = playlistRowsByTrackId.get(trackId);
  if (!track || !row) return false;

  row.setAttribute("aria-label", `${track.title || track.filename || "Track"}`);
  for (const column of orderedColumns()) {
    const cell = row.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
    if (!cell) return false;
    if (column.id === "favorite") {
      const button = cell.querySelector("button");
      if (button) {
        const favorite = isFavoritePresentation(track);
        button.classList.toggle("is-favorite", favorite);
        button.title = favorite ? "Remove from Favorites" : "Add to Favorites";
        button.setAttribute("aria-label", button.title);
        button.setAttribute("aria-pressed", favorite ? "true" : "false");
      }
    } else {
      cell.textContent = String(playlistColumnValue(track, column, rowIndex));
    }
    cell.style.width = `${state.columnWidths[column.id]}%`;
  }
  updatePlaylistRowState(row, trackId);
  return true;
}

function refreshPlaylistFavoriteRows() {
  const tracksByID = new Map(state.playlist.map((track) => [track.id, track]));
  for (const [trackId, row] of playlistRowsByTrackId) {
    const track = tracksByID.get(trackId);
    const button = row.querySelector('[data-column-id="favorite"] button');
    if (!track || !button) continue;
    const favorite = isFavoritePresentation(track);
    button.classList.toggle("is-favorite", favorite);
    button.title = favorite ? "Remove from Favorites" : "Add to Favorites";
    button.setAttribute("aria-label", button.title);
    button.setAttribute("aria-pressed", favorite ? "true" : "false");
  }
}

function playlistSortDependsOnMetadata() {
  return !isCatalogPlaylistProjection()
    && state.playlistSortEnabled
    && ["title", "game", "artist", "system", "lengthLabel"].includes(state.sortColumn);
}

function syncPlaylistColumnWidths() {
  for (const column of orderedColumns()) {
    const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
    if (header) header.style.width = `${state.columnWidths[column.id]}%`;
  }
  for (const row of playlistRowsByTrackId.values()) {
    for (const column of orderedColumns()) {
      const cell = row.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
      if (cell) cell.style.width = `${state.columnWidths[column.id]}%`;
    }
  }
}

function createPlaylistRow(track, rowIndex) {
  const row = document.createElement("tr");
  row.dataset.trackId = track.id;
  row.dataset.playlistIndex = String(rowIndex);
  row.tabIndex = 0;
  row.setAttribute("aria-label", `${track.title || track.filename || "Track"}`);
  const isCurrent = state.activePlaylistTabId === state.playbackTabId && state.currentTrackId === track.id;
  row.className = `playlist-row${state.selectedTrackIds.includes(track.id) ? " is-selected" : ""}${isCurrent ? " is-current" : ""}`;

  for (const column of orderedColumns()) {
    row.appendChild(renderPlaylistCell(track, column, rowIndex));
  }

  row.addEventListener("mousedown", (event) => {
    if (event.button !== 0) return;
    // Pointer selection stays focus-neutral because WebKit can scroll a row
    // during focus; keyboard navigation focuses explicitly with preventScroll.
    event.preventDefault();
  });

  row.addEventListener("click", (event) => {
    if (!row.isConnected || row.dataset.trackId !== track.id) return;
    const selectedTrack = selectPlaylistTrack(track.id, {
      extend: event.metaKey || event.ctrlKey,
      range: event.shiftKey
    });
    if (!selectedTrack) return;
    uiApp.playback.updateTimingSummary();
  });

  row.addEventListener("dblclick", () => {
    if (!row.isConnected || row.dataset.trackId !== track.id) return;
    playVisibleTrack(track.id, 0).catch((error) => {
      console.error(error);
    });
  });

  row.addEventListener("contextmenu", (event) => {
    showContextMenu(event, [["Export AAC", async () => {
      await uiApp.playback.exportTrackAsAAC(track);
    }]]);
  });

  row.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    if (!row.isConnected || row.dataset.trackId !== track.id) return;
    if (event.target !== row && event.target?.closest?.("button, input, select, a, [contenteditable=true]")) return;
    event.preventDefault();
    event.stopPropagation();
    // Pointer selection deliberately leaves DOM focus alone. Enter follows
    // the logical playlist selection, which may differ from an older focused row.
    const selectedTrack = uiApp.selectedTrack();
    if (!selectedTrack) return;
    playVisibleTrack(selectedTrack.id, 0).catch((error) => {
      console.error(error);
    });
  });

  return row;
}

function appendPlaylistRowsInBatches(generation, startIndex = 0, endIndex = state.playlist.length, spacers = null, { synchronous = false } = {}) {
  let rowIndex = startIndex;
  const appendBatch = () => {
    if (generation !== playlistRenderGeneration) return;
    const fragment = document.createDocumentFragment();
    if (rowIndex === startIndex && spacers?.top > 0) {
      fragment.appendChild(makePlaylistVirtualSpacer(spacers.top, "top"));
    }
    const startedAt = performance.now();
    while (rowIndex < endIndex && (synchronous || performance.now() - startedAt < 8)) {
      const track = state.playlist[rowIndex];
      const row = createPlaylistRow(track, rowIndex);
      playlistRowsByTrackId.set(track.id, row);
      if (state.selectedTrackId === track.id) selectedPlaylistRow = row;
      if (state.activePlaylistTabId === state.playbackTabId && state.currentTrackId === track.id) currentPlaylistRow = row;

      fragment.appendChild(row);
      rowIndex += 1;
    }
    refs.playlistBody.appendChild(fragment);
    if (rowIndex < endIndex) {
      window.requestAnimationFrame(appendBatch);
    } else {
      if (spacers?.bottom > 0) refs.playlistBody.appendChild(makePlaylistVirtualSpacer(spacers.bottom, "bottom"));
      schedulePlaylistSelectionIndicator();
      measurePlaylistRowHeight();
    }
  };
  if (synchronous) appendBatch();
  else window.requestAnimationFrame(appendBatch);
}

function renderPlaylist({ sort = true, persistTab = true, virtualScrollTop = null, preserveVirtualRows = false } = {}) {
  // Capture before clearing the table: WebKit clamps scrollTop to zero while
  // its tbody is empty, so reading it after replacement loses the user's row.
  const preservedScrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  if (persistTab && findActivePlaylistTab()) persistPlaylistTabs();
  updateAutomaticColumnVisibility();
  playlistRenderGeneration += 1;
  const generation = playlistRenderGeneration;
  if (!state.selectedTrackIds.length && state.selectedTrackId) {
    state.selectedTrackIds = [state.selectedTrackId];
  }
  const playlistIDs = new Set(state.playlist.map((track) => track.id));
  state.selectedTrackIds = state.selectedTrackIds.filter((id) => playlistIDs.has(id));
  if (state.selectedTrackId && (!playlistIDs.has(state.selectedTrackId) || !state.selectedTrackIds.includes(state.selectedTrackId))) {
    state.selectedTrackId = state.selectedTrackIds.at(-1) || null;
  }
  if (!state.selectedTrackId && state.selectedTrackIds.length) state.selectedTrackId = state.selectedTrackIds.at(-1) || null;
  const virtualized = playlistUsesVirtualRows();
  const preserveWindow = preserveVirtualRows && virtualized;
  if (!preserveWindow) {
    refs.playlistBody.innerHTML = "";
    playlistRowsByTrackId.clear();
    selectedPlaylistRow = null;
    currentPlaylistRow = null;
  }
  if (sort && state.playlistSortEnabled && !isCatalogPlaylistProjection()) {
    void applyProjectionPlaylistSort()
      .then((didSort) => { if (didSort) renderPlaylist({ sort: false }); })
      .catch((error) => console.error(error));
  }
  // columnContentWidth uses catalog hints or a bounded sample, so virtualized
  // playlists can still fit their columns without mounting every row.
  const playlistSignature = playlistAutoSizeSignature();
  const shouldAutoSize = columnResizePointerId === null
    && state.columnAutoSize
    && playlistSignature !== autoSizedPlaylistSignature;

  if (state.playlist.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = `<td colspan="${Math.max(1, orderedColumns().length)}" class="empty-row"></td>`;
    refs.playlistBody.appendChild(row);
    return;
  }

  if (shouldAutoSize) {
    autoSizedPlaylistSignature = playlistSignature;
    autoSizeColumns();
    syncPlaylistColumnWidths();
  }
  if (!virtualized) {
    // Small lists are cheaper to restore synchronously than to let batched
    // insertion clamp the scroller between animation frames.
    appendPlaylistRowsInBatches(generation, 0, state.playlist.length, null, { synchronous: true });
    if (refs.playlistBodyWrap) refs.playlistBodyWrap.scrollTop = preservedScrollTop;
    return;
  }

  const scrollTop = virtualScrollTop === null
    ? preservedScrollTop
    : Math.max(0, Number(virtualScrollTop) || 0);
  const viewportHeight = refs.playlistBodyWrap?.clientHeight || (playlistVirtualRowHeight * 24);
  const firstVisibleRow = Math.max(0, Math.floor(scrollTop / playlistVirtualRowHeight) - PLAYLIST_VIRTUAL_OVERSCAN);
  const lastVisibleRow = Math.min(
    state.playlist.length,
    Math.ceil((scrollTop + viewportHeight) / playlistVirtualRowHeight) + PLAYLIST_VIRTUAL_OVERSCAN
  );
  if (preserveWindow) {
    reconcilePlaylistVirtualRows(firstVisibleRow, lastVisibleRow);
    return;
  }
  appendPlaylistRowsInBatches(
    generation,
    firstVisibleRow,
    lastVisibleRow,
    {
      top: firstVisibleRow * playlistVirtualRowHeight,
      bottom: (state.playlist.length - lastVisibleRow) * playlistVirtualRowHeight
    },
    { synchronous: true }
  );
  if (refs.playlistBodyWrap) refs.playlistBodyWrap.scrollTop = scrollTop;
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
    const previousAutomaticallyHidden = [...state.automaticallyHiddenColumns].join("\u0001");
    updateAutomaticColumnVisibility();
    const automaticVisibilityChanged = previousAutomaticallyHidden
      !== [...state.automaticallyHiddenColumns].join("\u0001");
    if (mustReorder || automaticVisibilityChanged || trackIds.some((id) => !refreshPlaylistRow(id))) {
      renderPlaylist();
    } else if (columnResizePointerId === null && state.columnAutoSize && trackIds.length) {
      autoSizedPlaylistSignature = playlistAutoSizeSignature();
      autoSizeColumns();
      renderPlaylistHeader();
      syncPlaylistColumnWidths();
    }
    uiApp.playback.updateTimingSummary();
  });
}

function applyUISettings() {
  const rootStyle = document.documentElement.style;
  rootStyle.setProperty("--ui-font-size-pt", String(state.uiChromeFontSizePt ?? state.uiFontSizePt));
  rootStyle.setProperty("--app-font-family", state.uiChromeMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--sidebar-font-size-pt", String(state.sidebarFontSizePt));
  rootStyle.setProperty("--sidebar-text-color", state.sidebarTextColor);
  rootStyle.setProperty("--sidebar-font-family", state.contentMonospace || state.sidebarMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--playlist-font-size-pt", String(state.playlistFontSizePt));
  rootStyle.setProperty("--playlist-text-color", state.playlistTextColor);
  rootStyle.setProperty("--playlist-header-text-color", state.playlistHeaderTextColor);
  rootStyle.setProperty("--playlist-font-family", state.contentMonospace || state.playlistMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--playlist-header-font-weight", state.playlistHeaderBold ? "700" : "400");
  rootStyle.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
  rootStyle.setProperty("--accent", state.accentColor);
  rootStyle.setProperty("--bg-chrome", state.uiChromePrimaryColor ?? state.uiChromeColor);
  rootStyle.setProperty("--bg-panel", state.uiChromeSecondaryColor ?? "rgb(40 40 40)");
  rootStyle.setProperty("--bg-subpanel", state.uiChromeSecondaryColor ?? "rgb(40 40 40)");
  rootStyle.setProperty("--bg-sidebar", state.uiChromePaneColor ?? "rgb(20 20 20)");
  rootStyle.setProperty("--bg-hover", state.uiChromeHoverColor ?? "rgb(50 50 50)");
  rootStyle.setProperty("--line", state.uiChromeDividerColor ?? "rgb(40 40 40)");
  rootStyle.setProperty("--selection-bar-background", state.solidSelectionBar ? state.accentColor : "transparent");
  syncSelectionIndicatorStyle();
  rootStyle.setProperty("--item-spacing-rem", String(state.uiItemSpacingRem));
  rootStyle.setProperty("--column-resize-duration", `${state.autoResizeAnimationEnabled ? state.autoResizeAnimationMilliseconds : 0}ms`);
  rootStyle.setProperty("--selection-animation-duration", `${state.selectionAnimationEnabled ? state.selectionAnimationMilliseconds : 0}ms`);
  rootStyle.setProperty("--titlebar-text-color", state.titlebarTextColor);
  rootStyle.setProperty("--titlebar-font-weight", state.titlebarBold ? "700" : "400");
}

function appearanceSettings() {
  return {
    uiItemSpacingRem: state.uiItemSpacingRem,
    sidebarWidthPercent: state.sidebarWidthPercent,
    uiChromeFontSizePt: state.uiChromeFontSizePt,
    contentFontSizePt: state.sidebarFontSizePt,
    sidebarFontSizePt: state.sidebarFontSizePt,
    sidebarTextColor: state.sidebarTextColor,
    sidebarMonospace: state.sidebarMonospace,
    sidebarPathCounts: state.sidebarPathCounts,
    playlistFontSizePt: state.playlistFontSizePt,
    playlistTextColor: state.playlistTextColor,
    playlistHeaderTextColor: state.playlistHeaderTextColor,
    playlistMonospace: state.playlistMonospace,
    applicationMonospace: state.applicationMonospace,
    uiChromeMonospace: state.uiChromeMonospace,
    contentMonospace: state.contentMonospace,
    playlistHeaderBold: state.playlistHeaderBold,
    titlebarTextColor: state.titlebarTextColor,
    titlebarBold: state.titlebarBold,
    accentColor: state.accentColor,
    uiChromeColor: state.uiChromeColor,
    uiChromePrimaryColor: state.uiChromePrimaryColor,
    uiChromeSecondaryColor: state.uiChromeSecondaryColor,
    uiChromePaneColor: state.uiChromePaneColor,
    uiChromeHoverColor: state.uiChromeHoverColor,
    uiChromeDividerColor: state.uiChromeDividerColor,
    solidSelectionBar: state.solidSelectionBar
  };
}

function broadcastAppearanceSettings() {
  window.spcBoySB2?.setAppearanceSettings?.(appearanceSettings());
}

function formatArchiveCacheSummary(summary) {
  const size = `${(Number(summary?.byteCount || 0) / (1024 * 1024)).toFixed(1)} MB`;
  const limit = Number(summary?.limitBytes || state.archiveCacheLimitBytes || 0);
  const limitLabel = limit >= 1024 * 1024 * 1024
    ? `${(limit / (1024 * 1024 * 1024)).toFixed(limit % (1024 * 1024 * 1024) ? 1 : 0)} GB limit`
    : `${Math.round(limit / (1024 * 1024))} MB limit`;
  return `${size} • ${summary?.fileCount || 0} files • ${limitLabel}${summary?.partialCount ? ` • ${summary.partialCount} partial` : ""}${summary?.legacyFileCount ? ` • ${summary.legacyFileCount} legacy` : ""}`;
}

function renderRoutingConflicts() {
  const conflicts = window.SB2PlaybackBackends?.conflicts || [];
  if (!conflicts.length) {
    refs.routingConflictsList.innerHTML = '<div class="options-help-text">No overlapping decoder extensions are registered. New plugins that overlap an existing format will appear here before their routing policy is applied.</div>';
    return;
  }
  refs.routingConflictsList.innerHTML = conflicts.map(({ extension, candidates }) => {
    const candidateNames = candidates.map((backend) => escapeHtml(backend.displayName || backend.id)).join(" → ");
    const preferredBackendId = state.routingPreferences[extension] || candidates[0]?.id;
    return `<label class="routing-conflict"><span><strong>${escapeHtml(extension)}</strong><small>${candidateNames}</small></span><select class="options-input" data-routing-extension="${escapeHtml(extension)}" aria-label="Decoder for ${escapeHtml(extension)}">${candidates.map((backend) => `<option value="${escapeHtml(backend.id)}" ${backend.id === preferredBackendId ? "selected" : ""}>${escapeHtml(backend.displayName || backend.id)}</option>`).join("")}</select></label>`;
  }).join("");
  refs.routingConflictsList.querySelectorAll("[data-routing-extension]").forEach((input) => {
    input.addEventListener("change", () => setRoutingPreference(input.dataset.routingExtension, input.value));
  });
}

function setRoutingPreference(extension, backendId) {
  const candidates = window.SB2PlaybackBackends?.candidatesForPath?.(`route${extension}`) || [];
  if (!candidates.some((backend) => backend.id === backendId)) return;
  const nextPreferences = { ...state.routingPreferences };
  if (backendId === candidates[0]?.id) delete nextPreferences[extension];
  else nextPreferences[extension] = backendId;
  state.routingPreferences = nextPreferences;
  persistSettings();
  window.spcBoySB2?.setRoutingPreferences?.(nextPreferences).then((normalizedPreferences) => {
    state.routingPreferences = { ...normalizedPreferences };
    persistSettings();
    renderAll();
  }).catch((error) => console.error("[SPCBoy] routing preference update failed", error));
  renderAll();
}

function applyRoutingPreferences(preferences) {
  state.routingPreferences = preferences && typeof preferences === "object" ? { ...preferences } : {};
  persistSettings();
  renderAll();
}

function renderAll() {
  applyUISettings();
  updateSB2Titlebar();
  refs.optionsOverlay.classList.toggle("is-hidden", !state.optionsOpen);
  refs.optionsOverlay.setAttribute("aria-hidden", state.optionsOpen ? "false" : "true");
  const databaseSelected = state.optionsSection === "database";
  const routingSelected = state.optionsSection === "routing";
  const playbackSelected = state.optionsSection === "playback";
  const diagnosticsSelected = state.optionsSection === "diagnostics";
  const audioSelected = state.optionsSection === "audio";
  const themeSelected = state.optionsSection === "theme";
  const fontsSelected = state.optionsSection === "fonts";
  const windowsSelected = state.optionsSection === "windows";
  refs.optionsDatabaseTab.classList.toggle("is-selected", databaseSelected);
  refs.optionsRoutingTab.classList.toggle("is-selected", routingSelected);
  refs.optionsPlaybackTab.classList.toggle("is-selected", playbackSelected);
  refs.optionsDiagnosticsTab.classList.toggle("is-selected", diagnosticsSelected);
  refs.optionsAudioTab.classList.toggle("is-selected", audioSelected);
  refs.optionsThemeTab.classList.toggle("is-selected", themeSelected);
  refs.optionsFontsTab.classList.toggle("is-selected", fontsSelected);
  refs.optionsWindowsTab.classList.toggle("is-selected", windowsSelected);
  refs.optionsThemeSection.classList.toggle("is-hidden", !themeSelected);
  refs.optionsFontsSection.classList.toggle("is-hidden", !fontsSelected);
  refs.optionsWindowsSection.classList.toggle("is-hidden", !windowsSelected);
  refs.optionsDatabaseSection.classList.toggle("is-hidden", !databaseSelected);
  refs.optionsRoutingSection.classList.toggle("is-hidden", !routingSelected);
  refs.optionsPlaybackSection.classList.toggle("is-hidden", !playbackSelected);
  refs.optionsDiagnosticsSection.classList.toggle("is-hidden", !diagnosticsSelected);
  refs.optionsAudioSection.classList.toggle("is-hidden", !audioSelected);
  renderRoutingConflicts();
  if (refs.uiChromeFontSizeInput && document.activeElement !== refs.uiChromeFontSizeInput) refs.uiChromeFontSizeInput.value = String(state.uiChromeFontSizePt ?? state.uiFontSizePt);
  if (document.activeElement !== refs.sidebarFontSizeInput) refs.sidebarFontSizeInput.value = String(state.sidebarFontSizePt);
  if (document.activeElement !== refs.sidebarTextColorInput) refs.sidebarTextColorInput.value = state.sidebarTextColor;
  if (refs.playlistHeaderTextColorInput && document.activeElement !== refs.playlistHeaderTextColorInput) {
    refs.playlistHeaderTextColorInput.value = state.playlistHeaderTextColor;
  }
  refs.sidebarPathCountsCheckbox.checked = state.sidebarPathCounts;
  if (document.activeElement !== refs.accentColorInput) refs.accentColorInput.value = state.accentColor;
  if (refs.uiChromePrimaryColorInput && document.activeElement !== refs.uiChromePrimaryColorInput) refs.uiChromePrimaryColorInput.value = state.uiChromePrimaryColor;
  if (refs.uiChromeSecondaryColorInput && document.activeElement !== refs.uiChromeSecondaryColorInput) refs.uiChromeSecondaryColorInput.value = state.uiChromeSecondaryColor;
  if (refs.uiChromePaneColorInput && document.activeElement !== refs.uiChromePaneColorInput) refs.uiChromePaneColorInput.value = state.uiChromePaneColor;
  refs.solidSelectionBarCheckbox.checked = state.solidSelectionBar;
  if (refs.uiChromeMonospaceCheckbox) refs.uiChromeMonospaceCheckbox.checked = state.uiChromeMonospace;
  refs.applicationMonospaceCheckbox.checked = state.contentMonospace;
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
  if (document.activeElement !== refs.titlebarTextColorInput) refs.titlebarTextColorInput.value = state.titlebarTextColor;
  refs.titlebarBoldCheckbox.checked = state.titlebarBold;
  refs.mainWindowAlwaysOnTopCheckbox.checked = state.mainWindowAlwaysOnTop;
  refs.settingsWindowAlwaysOnTopCheckbox.checked = state.settingsWindowAlwaysOnTop;
  refs.archiveCacheEnabledCheckbox.checked = state.archiveCacheEnabled;
  refs.archiveCacheLimitSelect.value = String(state.archiveCacheLimitBytes);
  refs.archiveCacheLimitSelect.disabled = !state.archiveCacheEnabled;
  refs.favoriteHistoricalSortCheckbox.checked = state.favoriteSortOrder === "historical";
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
  refs.libraryDatabaseLocationStatus.textContent = state.databaseLocationStatus || "SPCBoy reads this schema-24 catalog. ScanSong owns scan paths, scanning, link checks, and cleanup.";
  refs.libraryDatabaseReloadButton.disabled = Boolean(state.databaseLocation?.requiresRestart || state.databaseReloading);
  refs.libraryDatabaseReloadButton.textContent = state.databaseReloading ? "Reloading…" : "Reload Library";
  refs.libraryDatabaseReloadButton.setAttribute("aria-busy", state.databaseReloading ? "true" : "false");
  refs.libraryClearCacheButton.disabled = false;
  refs.databaseCacheSummary.textContent = state.archiveCacheSummary ? formatArchiveCacheSummary(state.archiveCacheSummary) : "—";
  syncEqualizerControls();
  refs.appVolumeInput.value = String(state.appVolume);
  refs.appVolumeValue.textContent = `${Math.round(state.appVolume * 100)}%`;
  refs.monoEnabledCheckbox.checked = state.monoEnabled;
  syncAnimatedRanges();
  renderSidebar();
  renderPlaylistHeader();
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
  uiApp.playback.updateNativeDiagnostics();
}

function selectedTrackIndex() {
  return state.playlist.findIndex((track) => track.id === state.selectedTrackId);
}

function scrollSelectedTrackIntoView() {
  if (!state.selectedTrackId) {
    return;
  }

  const row = refs.playlistBody.querySelector(`[data-track-id="${CSS.escape(state.selectedTrackId)}"]`);
  row?.scrollIntoView({ block: "nearest" });
}

function moveSelection(delta, { range = false, extend = false } = {}) {
  if (state.playlist.length === 0) {
    return;
  }

  const currentIndex = selectedTrackIndex();
  const nextIndex = currentIndex >= 0
    ? Math.max(0, Math.min(state.playlist.length - 1, currentIndex + delta))
    : (delta >= 0 ? 0 : state.playlist.length - 1);

  // Keep DOM focus and the visual selection together. Without this, Enter
  // can be routed through an old sidebar/focused row after arrow navigation.
  selectPlaylistTrack(state.playlist[nextIndex].id, { focus: true, range, extend });
  uiApp.playback.updateTimingSummary();
  scrollSelectedTrackIntoView();
}

function selectAllPlaylistTracks() {
  if (!state.playlist.length) return;
  state.selectedTrackIds = state.playlist.map((track) => track.id);
  state.selectedTrackId = state.playlist[0].id;
  lastPlaylistSelectionID = state.selectedTrackId;
  state.playlistSelectionAnchorId = state.selectedTrackId;
  persistSettings();
  refreshPlaylistPlaybackState();
}

function playSelectedTrack() {
  // Never fall back to the current/last-playing track. Enter is a selection
  // command; a missing selection is a no-op rather than an accidental replay.
  const active = uiApp.selectedTrack();
  if (!active) {
    return;
  }

  playVisibleTrack(active.id, 0).catch((error) => {
    console.error(error);
  });
}

function isPlaylistSelectionTarget(focusTarget = document.activeElement) {
  if (refs.playlistScrollWrap?.contains(focusTarget)
      || refs.playlistBodyWrap?.contains(focusTarget)
      || refs.playlistBody?.contains(focusTarget)) return true;
  return Boolean(lastPlaylistSelectionID
    && state.selectedTrackId === lastPlaylistSelectionID
    && state.playlist.some((track) => track.id === lastPlaylistSelectionID));
}

function setPlayTime(nextSeconds) {
  const previousSeconds = state.manualPlayTimeSeconds;
  state.manualPlayTimeSeconds = uiApp.normalizeLongPlayTime(nextSeconds);
  persistSettings();
  renderAll();
  if (state.longPlayEnabled && !window.spcBoySB2?.isOptionsWindow && state.manualPlayTimeSeconds !== previousSeconds) {
    uiApp.playback.refreshPlaybackForTimingChange().catch((error) => console.error(error));
  }
}

function setSpcForceManualTime(nextEnabled) {
  const previousEnabled = state.longPlayEnabled;
  state.longPlayEnabled = Boolean(nextEnabled);
  persistSettings();
  renderAll();
  if (previousEnabled !== state.longPlayEnabled && !window.spcBoySB2?.isOptionsWindow) {
    uiApp.playback.refreshPlaybackForTimingChange().catch((error) => console.error(error));
  }
}

function cycleRepeatMode() {
  const modes = ["off", "all", "one"];
  state.repeatMode = modes[(modes.indexOf(state.repeatMode) + 1) % modes.length];
  persistSettings();
  renderAll();
}

function setSpcFadeTime(nextSeconds) {
  state.spcFadeSeconds = uiApp.normalizeFadeTime(nextSeconds);
  persistSettings();
  renderAll();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
}

function setSpcFadeEnabled(nextEnabled) {
  state.fadeEnabled = Boolean(nextEnabled);
  persistSettings();
  renderAll();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
}

function setQueuedSkipsEnabled(nextEnabled) {
  state.queuedSkipsEnabled = Boolean(nextEnabled);
  persistSettings();
  renderAll();
}

async function applyArchiveCacheSettings() {
  const settings = {
    enabled: state.archiveCacheEnabled,
    limitBytes: state.archiveCacheLimitBytes
  };
  persistSettings();
  const configured = await window.spcBoySB2?.configureArchiveCache?.(settings);
  if (configured?.summary) {
    state.archiveCacheSummary = { ...configured.summary, enabled: configured.enabled, limitBytes: configured.limitBytes };
  }
  renderAll();
}

function setArchiveCacheEnabled(enabled) {
  state.archiveCacheEnabled = Boolean(enabled);
  applyArchiveCacheSettings().catch((error) => {
    console.error("[SPCBoy] archive cache setting update failed", error);
  });
  renderAll();
}

function setArchiveCacheLimit(value) {
  state.archiveCacheLimitBytes = uiApp.normalizeArchiveCacheLimit(value);
  applyArchiveCacheSettings().catch((error) => {
    console.error("[SPCBoy] archive cache limit update failed", error);
  });
  renderAll();
}

function sendEqualizerSettings() {
  window.spcBoySB2?.nativePlaybackSetEqualizer?.({
    enabled: state.equalizerEnabled,
    bandGains: [...state.equalizerBandGains]
  }).catch?.(() => {});
}

function persistEqualizerSettings() {
  window.spcBoySB2?.frontendEqualizerSettingsSave?.({
    equalizerEnabled: state.equalizerEnabled,
    equalizerBandGains: [...state.equalizerBandGains]
  }).catch?.((error) => console.error("[SPCBoy] native equalizer settings save failed", error));
}

function syncEqualizerControls() {
  refs.equalizerEnabledCheckbox.checked = state.equalizerEnabled;
  refs.equalizerToolbarButton.classList.toggle("is-selected", state.equalizerEnabled);
  refs.equalizerToolbarButton.setAttribute("aria-pressed", state.equalizerEnabled ? "true" : "false");
  refs.equalizerToolbarButton.title = state.equalizerEnabled ? "Disable Equalizer" : "Enable Equalizer";
  refs.equalizerToolbarButton.setAttribute("aria-label", refs.equalizerToolbarButton.title);
  refs.equalizerBandInputs.forEach((input, index) => {
    input.value = String(state.equalizerBandGains[index] || 0);
    refs.equalizerBandValues[index].textContent = `${(state.equalizerBandGains[index] || 0) >= 0 ? "+" : ""}${(state.equalizerBandGains[index] || 0).toFixed(1)} dB`;
  });
}

function setEqualizerEnabled(enabled) {
  state.equalizerEnabled = Boolean(enabled);
  persistEqualizerSettings();
  sendEqualizerSettings();
  syncEqualizerControls();
}

function setEqualizerBandGain(index, gain) {
  if (!state.equalizerBandGains[index]) state.equalizerBandGains[index] = 0;
  state.equalizerBandGains[index] = uiApp.normalizeEqualizerGain(gain);
  persistEqualizerSettings();
  sendEqualizerSettings();
  syncEqualizerControls();
}

function resetEqualizer() {
  state.equalizerBandGains = state.equalizerBandGains.map(() => 0);
  persistEqualizerSettings();
  sendEqualizerSettings();
  syncEqualizerControls();
}

function setAppVolume(volume) {
  state.appVolume = uiApp.normalizeAppVolume(volume);
  persistSettings();
  window.spcBoySB2?.nativePlaybackSetVolume?.({ outputVolume: state.appVolume }).catch?.(() => {});
  renderAll();
}

function setMonoEnabled(enabled) {
  state.monoEnabled = Boolean(enabled);
  persistSettings();
  window.spcBoySB2?.nativePlaybackSetMono?.({ enabled: state.monoEnabled }).catch?.(() => {});
  renderAll();
}

function adjustAppVolume(delta) {
  setAppVolume(state.appVolume + Number(delta || 0));
}

function commitSpcLengthInput(rawValue) {
  const parsedSeconds = uiApp.parseDurationSeconds(rawValue);
  const previousSeconds = state.manualPlayTimeSeconds;
  state.manualPlayTimeSeconds = uiApp.normalizeLongPlayTime(parsedSeconds ?? state.manualPlayTimeSeconds);
  persistSettings();
  if (state.longPlayEnabled && !window.spcBoySB2?.isOptionsWindow && state.manualPlayTimeSeconds !== previousSeconds) {
    uiApp.playback.refreshPlaybackForTimingChange().catch((error) => console.error(error));
  }
}

function commitUnknownDurationInput(rawValue) {
  const parsedSeconds = uiApp.parseDurationSeconds(rawValue);
  state.unknownDurationSeconds = uiApp.normalizePlayTime(parsedSeconds ?? state.unknownDurationSeconds);
  persistSettings();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
}

function commitSpcFadeInput(rawValue) {
  const parsedSeconds = uiApp.parseDurationSeconds(rawValue);
  state.spcFadeSeconds = uiApp.normalizeFadeTime(parsedSeconds ?? state.spcFadeSeconds);
  persistSettings();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
}

function commitPlaybackSpeedInput(backendId, rawValue) {
  const speedKey = backendId === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
  const enabledKey = backendId === "libvgm" ? "libvgmPlaybackSpeedEnabled" : "playbackSpeedEnabled";
  const input = backendId === "libvgm" ? refs.libvgmPlaybackSpeedInput : refs.playbackSpeedInput;
  const parsedSpeed = uiApp.parsePlaybackSpeed(rawValue);
  if (!parsedSpeed) {
    input.value = uiApp.formatPlaybackSpeed(state[speedKey]);
    return;
  }
  if (parsedSpeed.numerator === state[speedKey].numerator && parsedSpeed.denominator === state[speedKey].denominator) {
    input.value = uiApp.formatPlaybackSpeed(parsedSpeed);
    return;
  }
  state[speedKey] = parsedSpeed;
  persistSettings();
  if (state[enabledKey]) uiApp.playback.refreshPlaybackForSpeedChange(backendId).catch((error) => console.error(error));
  renderAll();
}

function setPlaybackSpeedEnabled(backendId, enabled) {
  const enabledKey = backendId === "libvgm" ? "libvgmPlaybackSpeedEnabled" : "playbackSpeedEnabled";
  state[enabledKey] = Boolean(enabled);
  persistSettings();
  uiApp.playback.refreshPlaybackForSpeedChange(backendId).catch((error) => console.error(error));
  renderAll();
}

function setUiItemSpacing(nextSpacingRem) {
  state.uiItemSpacingRem = uiApp.normalizeItemSpacing(nextSpacingRem);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setContentFontSize(nextSize) {
  const size = uiApp.normalizeFontSize(nextSize);
  state.sidebarFontSizePt = size;
  state.playlistFontSizePt = size;
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setUIChromeFontSize(nextSize) {
  const size = uiApp.normalizeFontSize(nextSize);
  state.uiChromeFontSizePt = size;
  state.uiFontSizePt = size;
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setFontSize(nextSize) {
  setContentFontSize(nextSize);
}

function setSidebarWidth(nextWidth) {
  state.sidebarWidthPercent = uiApp.normalizeSidebarWidth(nextWidth);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function commitFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  setUIChromeFontSize(parsedValue ?? state.uiChromeFontSizePt ?? state.uiFontSizePt);
}

function commitSidebarFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  setContentFontSize(parsedValue ?? state.sidebarFontSizePt);
}

function setSidebarTextColor(color) {
  const normalized = uiApp.normalizeFontColor(color);
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
  renderedDatabaseGames = null;
  renderSidebar();
}

function commitPlaylistFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  state.playlistFontSizePt = uiApp.normalizeFontSize(parsedValue ?? state.playlistFontSizePt);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setPlaylistTextColor(color) {
  state.playlistTextColor = uiApp.normalizeFontColor(color);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setPlaylistHeaderTextColor(color) {
  state.playlistHeaderTextColor = uiApp.normalizeFontColor(color);
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
  state.contentMonospace = value;
  state.sidebarMonospace = value;
  state.playlistMonospace = value;
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setUIChromeMonospace(enabled) {
  const value = Boolean(enabled);
  state.uiChromeMonospace = value;
  state.applicationMonospace = value;
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

function setTitlebarTextColor(color) {
  state.titlebarTextColor = uiApp.normalizeFontColor(color);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setTitlebarBold(enabled) {
  state.titlebarBold = Boolean(enabled);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setColumnAutoSize(enabled) {
  state.columnAutoSize = Boolean(enabled);
  if (state.columnAutoSize) autoSizedPlaylistSignature = null;
  persistSettings();
  renderPlaylist();
}

function setAnimationTiming(key, value) {
  window.SB2OptionsController.setAnimation(state, uiApp.normalizeAnimationMilliseconds, key, value);
  persistSettings();
  renderAll();
}

function setAnimationEnabled(key, enabled) {
  state[key] = Boolean(enabled);
  persistSettings();
  renderAll();
}

function setWindowAlwaysOnTop(key, enabled) {
  window.SB2OptionsController.setWindowLevel(state, key, enabled);
  persistSettings();
  renderAll();
}

function applyAppearanceSettings(settings) {
  if (settings.uiItemSpacingRem !== undefined) state.uiItemSpacingRem = uiApp.normalizeItemSpacing(settings.uiItemSpacingRem);
  if (settings.sidebarWidthPercent !== undefined) state.sidebarWidthPercent = uiApp.normalizeSidebarWidth(settings.sidebarWidthPercent);
  const contentFontSize = settings.contentFontSizePt ?? settings.sidebarFontSizePt ?? settings.playlistFontSizePt;
  if (contentFontSize !== undefined) {
    const size = uiApp.normalizeFontSize(contentFontSize);
    state.sidebarFontSizePt = size;
    state.playlistFontSizePt = size;
  }
  const chromeFontSize = settings.uiChromeFontSizePt ?? settings.uiFontSizePt;
  if (chromeFontSize !== undefined) {
    const size = uiApp.normalizeFontSize(chromeFontSize);
    state.uiChromeFontSizePt = size;
    state.uiFontSizePt = size;
  }
  const interfaceFontColor = settings.sidebarTextColor ?? settings.playlistTextColor;
  if (interfaceFontColor !== undefined) {
    const color = uiApp.normalizeFontColor(interfaceFontColor);
    state.sidebarTextColor = color;
    state.playlistTextColor = color;
  }
  if (settings.playlistHeaderTextColor !== undefined) {
    state.playlistHeaderTextColor = uiApp.normalizeFontColor(settings.playlistHeaderTextColor);
  }
  const contentMonospace = settings.contentMonospace ?? settings.sidebarMonospace ?? settings.playlistMonospace;
  if (contentMonospace !== undefined) {
    const enabled = Boolean(contentMonospace);
    state.contentMonospace = enabled;
    state.sidebarMonospace = enabled;
    state.playlistMonospace = enabled;
  }
  const chromeMonospace = settings.uiChromeMonospace ?? settings.applicationMonospace;
  if (chromeMonospace !== undefined) {
    state.uiChromeMonospace = Boolean(chromeMonospace);
    state.applicationMonospace = Boolean(chromeMonospace);
  }
  if (settings.sidebarPathCounts !== undefined) state.sidebarPathCounts = Boolean(settings.sidebarPathCounts);
  if (settings.playlistHeaderBold !== undefined) state.playlistHeaderBold = Boolean(settings.playlistHeaderBold);
  if (settings.titlebarTextColor !== undefined) state.titlebarTextColor = uiApp.normalizeFontColor(settings.titlebarTextColor);
  if (settings.titlebarBold !== undefined) state.titlebarBold = Boolean(settings.titlebarBold);
  if (settings.accentColor !== undefined) state.accentColor = uiApp.normalizeAccentColor(settings.accentColor);
  if (settings.uiChromeColor !== undefined || settings.uiChromePrimaryColor !== undefined) {
    state.uiChromePrimaryColor = uiApp.normalizeUIColor(settings.uiChromePrimaryColor ?? settings.uiChromeColor, "rgb(30 30 30)");
    state.uiChromeColor = state.uiChromePrimaryColor;
  }
  if (settings.uiChromeSecondaryColor !== undefined || settings.uiChromeTertiaryColor !== undefined) {
    state.uiChromeSecondaryColor = uiApp.normalizeUIColor(settings.uiChromeTertiaryColor ?? settings.uiChromeSecondaryColor, "rgb(40 40 40)");
  }
  if (settings.uiChromePaneColor !== undefined || settings.uiChromeSidebarColor !== undefined) {
    state.uiChromePaneColor = uiApp.normalizeUIColor(settings.uiChromePaneColor ?? settings.uiChromeSidebarColor, "rgb(20 20 20)");
  }
  for (const [key, fallback] of Object.entries({
    uiChromeHoverColor: "rgb(50 50 50)",
    uiChromeDividerColor: "rgb(40 40 40)"
  })) {
    if (settings[key] !== undefined) state[key] = uiApp.normalizeUIColor(settings[key], fallback);
  }
  if (settings.solidSelectionBar !== undefined) state.solidSelectionBar = Boolean(settings.solidSelectionBar);
  persistSettings();
  renderAll();
}

function setAccentColor(color) {
  state.accentColor = uiApp.normalizeAccentColor(color);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setUIChromeColor(color) {
  state.uiChromePrimaryColor = uiApp.normalizeUIColor(color, "rgb(30 30 30)");
  state.uiChromeColor = state.uiChromePrimaryColor;
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setUIChromePaletteColor(role, color) {
  const key = role === "pane" ? "uiChromePaneColor" : `uiChrome${String(role || "").charAt(0).toUpperCase()}${String(role || "").slice(1)}Color`;
  const fallbacks = {
    primary: "rgb(30 30 30)", secondary: "rgb(40 40 40)", pane: "rgb(20 20 20)",
    hover: "rgb(50 50 50)", divider: "rgb(40 40 40)"
  };
  if (!Object.hasOwn(fallbacks, role)) return;
  state[key] = uiApp.normalizeUIColor(color, fallbacks[role]);
  if (role === "primary") state.uiChromeColor = state[key];
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setSolidSelectionBar(enabled) {
  state.solidSelectionBar = Boolean(enabled);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function commitSidebarWidthInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  state.sidebarWidthPercent = uiApp.normalizeSidebarWidth(parsedValue ?? state.sidebarWidthPercent);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function setOptionsOpen(nextOpen) {
  if (!nextOpen && window.spcBoySB2?.isOptionsWindow) {
    window.spcBoySB2.closeOptionsWindow();
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

function updateSB2Titlebar() {
  const track = uiApp.currentTrack() || state.currentTrackInfo || uiApp.selectedTrack();
  if (refs.sb2ConsoleLabel) refs.sb2ConsoleLabel.textContent = String(track?.system || "—").toLocaleUpperCase();
  if (refs.sb2AlbumLabel) {
    refs.sb2AlbumLabel.textContent = String(track?.game || state.playlistTitle || "NO PLAYLIST").toLocaleUpperCase();
  }
}

async function sampleSB2CPU() {
  if (!refs.sb2CPUValue || !window.spcBoySB2?.processCPUTimeMilliseconds) return;
  let previousCPU = null;
  let previousWall = null;
  const sample = async () => {
    try {
      const cpuMilliseconds = Number(await window.spcBoySB2.processCPUTimeMilliseconds());
      const wallMilliseconds = performance.now();
      if (Number.isFinite(cpuMilliseconds) && previousCPU !== null && previousWall !== null) {
        const processorCount = Math.max(1, Number(navigator.hardwareConcurrency) || 1);
        const percent = Math.max(0, Math.min(100, Math.round(
          ((cpuMilliseconds - previousCPU) / Math.max(1, wallMilliseconds - previousWall)) * 100 / processorCount
        )));
        refs.sb2CPUValue.textContent = `${String(percent).padStart(2, "0")}%`;
        refs.sb2CPUFill.style.width = `${percent}%`;
      }
      previousCPU = cpuMilliseconds;
      previousWall = wallMilliseconds;
    } catch (error) {
      console.error("[SPCBOY SB2] CPU sample failed", error);
    }
  };
  await sample();
  window.setInterval(sample, 1_000);
}

async function toggleAllSidebarNodes() {
  const allExpanded = sidebarAllGroupsExpanded();
  await setAllSidebarNodesCollapsed(allExpanded);
}

function sidebarAllGroupsExpanded() {
  if (currentSidebarView().contentMode === "database") {
    return databaseConsoleGroups.length > 0
      && databaseConsoleGroups.every(({ consoleName }) => !collapsedDatabaseConsoles.has(consoleName));
  }
  const folders = [...refs.treeRoot.querySelectorAll(".tree-node:not(.tree-file)")];
  return folders.length > 0 && folders.every((button) => button.getAttribute("aria-expanded") === "true");
}

function syncSidebarFoldButton() {
  const button = refs.databaseCollapseAllButton;
  const use = button?.querySelector("use");
  const allExpanded = sidebarAllGroupsExpanded();
  use?.setAttribute("href", allExpanded ? "#icon-list-collapse" : "#icon-list-expand");
  if (button) {
    button.title = allExpanded ? "Collapse all" : "Expand all";
    button.setAttribute("aria-label", button.title);
  }
}


async function bootstrap() {
  beginStartup();
  // Load persisted appearance before the first Options-window paint. The
  // window is native-sized and immediately visible; deferring this until
  // after catalog/cache requests produces a distracting default-style flash.
  window.SB2OptionsController.applyManifest(await window.spcBoySB2.frontendOptionsManifest());
  setStartupStage(0, "Applying saved interface settings and reopening your last session.");
  await loadSettings();
  await syncSidebarView();
  let savedPlaylistTabs = null;
  if (!window.spcBoySB2?.isOptionsWindow && window.spcBoySB2?.playlistTabsLoad) {
    try {
      savedPlaylistTabs = await window.spcBoySB2.playlistTabsLoad();
    } catch (error) {
      console.error("[SPCBoy] saved playlist tabs could not be loaded", error);
    }
  }
  if (!window.spcBoySB2?.isOptionsWindow) await refreshFavorites();
  if (window.spcBoySB2?.isOptionsWindow) {
    document.body.classList.add("options-window");
    state.optionsOpen = true;
    // Paint the native Settings window before any catalog/cache request can
    // delay or reject. The controls remain usable while those values load.
    renderAll();
  }
  if (!window.spcBoySB2?.bootstrap) {
    const message = "SPCBOY SB2 native bridge is unavailable. Database loading is unavailable.";
    showStartupFailure(message);
    throw new Error(message);
  }
  void sampleSB2CPU();

  setStartupStage(1, "Opening the shared ScanSong catalog and checking the configured library roots.");
  collapsedDatabaseConsoles = new Set(state.collapsedConsoleNames);
  state.databaseLocation = await window.spcBoySB2?.databaseLocation?.() || null;
  state.databaseLocationStatus = state.databaseLocation?.requiresRestart
    ? "Restart SPCBoy to use the selected database."
    : "The shared ScanSong catalog is active and opened read-only.";
  await window.spcBoySB2?.configureArchiveCache?.({
    enabled: state.archiveCacheEnabled,
    limitBytes: state.archiveCacheLimitBytes
  });
  await uiApp.ui.refreshArchiveCacheSummary();
  if (window.spcBoySB2?.setRoutingPreferences) {
    state.routingPreferences = { ...(await window.spcBoySB2.setRoutingPreferences(state.routingPreferences)) };
    persistSettings();
  }
  let snapshot;
  if (window.spcBoySB2?.isOptionsWindow) {
    // Options owns settings/library controls, not the raw browser. Do not
    // enumerate the persisted JoshW root just to paint this window.
    snapshot = {
      rootPath: null,
      tree: [],
      selectedFolderPath: null,
      selectedBrowserPath: null,
      playlist: []
    };
  } else {
    snapshot = await window.spcBoySB2.bootstrap();
  }

  if (snapshot?.stale === true) {
    failStartup("The library changed while SPCBOY SB2 was opening. Close and reopen the app to load the latest catalog.");
    return;
  }

  Object.assign(state, snapshot);
  state.rootPath = null;
  state.localBrowserEnabled = false;
  state.selectedFolderPath = null;
  state.selectedBrowserPath = null;
  state.sidebarMode = state.sidebarMode === "paths" ? "paths" : "consoles";
  await syncSidebarView();
  state.databaseGameGroups = [];
  rebuildDatabaseGameSearchIndex(state.databaseGames);
  await uiApp.playback.stopPlaybackState();
  state.playbackTabId = null;
  clearPlaylistSelection();
  state.totalSeconds = targetPlaybackSeconds();
  persistSettings();
  if (!window.spcBoySB2?.isOptionsWindow && window.spcBoySB2?.databaseRoots) {
    setStartupStage(2, "Indexing library sources for the sidebar and its search results.");
    state.libraryRoots = await window.spcBoySB2.databaseRoots();
    await uiApp.ui.handleLibraryRootsChanged(state.libraryRoots);
  }
  setStartupStage(3, "Reopening saved playlists and preparing playback controls.");
  const restoredPlaylistTabs = !window.spcBoySB2?.isOptionsWindow && restorePlaylistTabs(savedPlaylistTabs);
  if (!restoredPlaylistTabs && !window.spcBoySB2?.isOptionsWindow) ensurePlaylistTab();
  renderAll();
  if (!restoredPlaylistTabs && state.sidebarMode === "consoles") {
    const selectedGame = state.databaseGames.find((game) => databaseGameKey(game) === state.selectedDatabaseGameKey);
    if (selectedGame) {
      await loadDatabaseGame(selectedGame);
    }
  }
  syncTreeSelection();
  scrollSelectedTrackIntoView();
  if (!window.spcBoySB2?.isOptionsWindow) persistPlaylistTabs();
  finishStartup();
}

function selectedPathTitle(path) {
  const parts = String(path || "").split(/[\\/]/).filter(Boolean);
  return parts.at(-1) || "Playlist";
}

async function applyFolderSelection(selection, targetTabID = state.activePlaylistTabId, title = null) {
  if (targetTabID !== state.activePlaylistTabId) return false;
  const preserveBrowserFocus = document.activeElement?.classList.contains("tree-node");
  state.selectedFolderPath = selection.selectedFolderPath;
  state.playlist = selection.playlist;
  state.playlistTitle = String(title || selectedPathTitle(selection.selectedFolderPath) || "Playlist");
  state.catalogPlaylistColumnContentHints = selection.columnContentHints || null;
  state.catalogPlaylistSortSessionId = selection.sortSessionId || null;
  await applyExplicitPlaylistSort();
  if (targetTabID !== state.activePlaylistTabId) return false;
  clearPlaylistSelection();
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
  renderPlaylistTabs();
  persistPlaylistTabs();
  uiApp.playback.updateTimingSummary();
  uiApp.playback.updatePlaybackReadout();
  scrollSelectedTrackIntoView();
}

uiApp.ui = {
  renderTree,
  syncTreeSelection,
  renderPlaylist,
  refreshPlaylistFavoriteRows,
  renderPlaylistTabs,
  createPlaylistTab,
  activatePlaylistTab,
  activatePlaylistTabAtIndex,
  closePlaylistTab,
  restorePlaylistTabs,
  refreshPlaylistPlaybackState,
  renderAll,
  moveSelection,
  selectAllPlaylistTracks,
  moveBrowserSelection,
  moveDatabaseSidebarSelection,
  jumpFocusedListToEdge,
  playSelectedTrack,
  isPlaylistSelectionTarget,
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
  setContentFontSize,
  setUIChromeFontSize,
  setSidebarWidth,
  setAccentColor,
  setUIChromeColor,
  setUIChromePaletteColor,
  setSolidSelectionBar,
  commitFontSizeInput,
  commitSidebarFontSizeInput,
  setSidebarTextColor,
  setSidebarMonospace,
  setSidebarPathCounts,
  commitPlaylistFontSizeInput,
  setPlaylistTextColor,
  setPlaylistHeaderTextColor,
  setPlaylistMonospace,
  setApplicationMonospace,
  setUIChromeMonospace,
  setPlaylistHeaderBold,
  setTitlebarTextColor,
  setTitlebarBold,
  setColumnAutoSize,
  setAnimationTiming,
  setAnimationEnabled,
  setWindowAlwaysOnTop,
  applyAppearanceSettings,
  applyRoutingPreferences,
  commitSidebarWidthInput,
  setOptionsOpen,
  updateSB2Titlebar,
  toggleAllSidebarNodes,
  setAllDatabaseConsolesCollapsed,
  setAllSidebarNodesCollapsed,
  refreshDatabaseGamesForVisibleRoots,
  setSidebarMode,
  cycleSidebarMode,
  updateSidebarSearch,
  loadDatabaseFiles,
  loadDatabaseGames,
  loadDatabaseGame,
  toggleSelectedFavorites,
  refreshFavorites,
  showFavoritesPlaylist,
  showPlaybackHistory,
  activateDatabaseSelection,
  activateFocusedItem,
  renderSidebar,
  syncAnimatedRanges,
  failStartup,
  bootstrap
};
})();
