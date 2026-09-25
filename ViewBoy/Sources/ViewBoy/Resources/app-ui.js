(() => {
const uiApp = window.SPCBoyApp;
const { state, refs, persistSettings, loadSettings, targetPlaybackSeconds, COLUMN_DEFS } = uiApp;
const expandedFolders = new Set();
let draggedColumnId = null;
let metadataRefreshFrame = 0;
const metadataRefreshTrackIds = new Set();
let columnMenu = null;
let autoSizedPlaylistSignature = null;
let playlistRenderGeneration = 0;
let textMeasureContext = null;
let renderedDatabaseGames = null;
let databaseEmptyState = null;
let databaseConsoleGroups = [];
let collapsedDatabaseConsoles = new Set();
let databaseRowRenderGeneration = 0;
let browserClickTimer = 0;
let browserSelectionRequest = null;
let databaseGameLoadRequest = null;
let databaseGameSearchRecords = [];
let columnResizePointerId = null;
const PLAYLIST_VIRTUALIZATION_THRESHOLD = 200;
const PLAYLIST_VIRTUAL_OVERSCAN = 12;
let playlistVirtualRowHeight = 28;
let playlistViewportFrame = 0;
let playlistRowMeasurementFrame = 0;
let playlistVirtualWindowStart = null;
let playlistVirtualWindowEnd = null;
let playlistViewportRenderPending = false;

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
    contentMode: view === "paths" || view === "diskPath" ? "tree" : "database",
    resultSource: view === "paths" ? "catalog-path-index" : view === "diskPath" ? "disk-path-tree" : "catalog-console-index",
    isTemporary: view === "search"
  };
}

function rebuildDatabaseGameSearchIndex(games = state.databaseGames) {
  databaseGameSearchRecords = (Array.isArray(games) ? games : []).map((game) => ({
    game,
    searchText: `${game.name || ""} ${game.system || ""} ${game.rootName || ""} ${game.displayName || ""}`.toLowerCase()
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
  state.sidebarView = Object.freeze(await window.spcBoyWK.resolveSidebarState(state.sidebarMode, state.sidebarQuery));
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
  const favorites = await window.spcBoyWK.favoritesList(state.favoriteSortOrder);
  applyFavoriteSnapshot(favorites);
  return state.favorites;
}

async function toggleFavorites(tracks) {
  applyFavoriteSnapshot(await window.spcBoyWK.favoritesToggle(tracks, state.favoriteSortOrder));
}

function playVisibleTrack(trackId, startSeconds = 0) {
  return uiApp.playback.playTrack(trackId, startSeconds, false, { replaceQueue: true });
}
let browserSelectionGeneration = 0;
let selectedBrowserButton = null;
let selectedDatabaseGameButton = null;
let selectedDatabaseConsoleButton = null;
const playlistRowsByTrackId = new Map();
const playlistTrackByID = new Map();
const playlistIndexByID = new Map();
let selectedPlaylistTrackIDs = new Set();
let selectedPlaylistRow = null;
let currentPlaylistRow = null;
let selectionIndicatorFrame = 0;
let selectionIndicatorSuppressionGeneration = 0;
const SELECTION_SIDEBAR = 1;
const SELECTION_PLAYLIST = 2;
const SELECTION_OPTIONS = 4;
const SELECTION_ALL = SELECTION_SIDEBAR | SELECTION_PLAYLIST | SELECTION_OPTIONS;
let selectionIndicatorScopes = SELECTION_ALL;
let sidebarContentRendering = false;
let playlistRowsRendering = false;
const databaseGameButtonsByKey = new Map();
const databaseConsoleButtonsByName = new Map();
let visibleDatabaseGameKeys = null;
const browserButtonsByPath = new Map();
const visibleBrowserNodeIndexByPath = new Map();
let visibleBrowserNodeList = [];

function playlistUsesVirtualRows() {
  return state.playlist.length > PLAYLIST_VIRTUALIZATION_THRESHOLD;
}

function schedulePlaylistViewportRender() {
  if (!playlistUsesVirtualRows()) return;
  if (playlistRowsRendering) {
    playlistViewportRenderPending = true;
    return;
  }
  if (playlistViewportFrame) return;
  playlistViewportFrame = window.requestAnimationFrame(() => {
    playlistViewportFrame = 0;
    reconcilePlaylistViewport();
  });
}

function schedulePlaylistRowMeasurement() {
  if (!playlistUsesVirtualRows() || playlistRowMeasurementFrame) return;
  playlistRowMeasurementFrame = window.requestAnimationFrame(() => {
    playlistRowMeasurementFrame = 0;
    const row = refs.playlistBody.querySelector(".playlist-row");
    const measuredHeight = Math.round(row?.getBoundingClientRect?.().height || 0);
    if (!measuredHeight || measuredHeight === playlistVirtualRowHeight) return;
    playlistVirtualRowHeight = measuredHeight;
    renderPlaylist({ sort: false, persist: false, refreshIndex: false, animateSelection: false });
  });
}

function makePlaylistVirtualSpacer(height, edge) {
  const row = document.createElement("tr");
  row.className = `playlist-virtual-spacer playlist-virtual-spacer-${edge}`;
  row.setAttribute("aria-hidden", "true");
  const cell = document.createElement("td");
  cell.colSpan = Math.max(1, orderedColumns().length);
  cell.style.height = `${Math.max(0, Math.round(height))}px`;
  row.appendChild(cell);
  return row;
}

function playlistVirtualRange() {
  const scrollTop = refs.playlistBodyWrap?.scrollTop || 0;
  const viewportHeight = refs.playlistBodyWrap?.clientHeight || (playlistVirtualRowHeight * 24);
  return {
    start: Math.max(0, Math.floor(scrollTop / playlistVirtualRowHeight) - PLAYLIST_VIRTUAL_OVERSCAN),
    end: Math.min(
      state.playlist.length,
      Math.ceil((scrollTop + viewportHeight) / playlistVirtualRowHeight) + PLAYLIST_VIRTUAL_OVERSCAN
    )
  };
}

function updatePlaylistVirtualSpacer(edge, height) {
  const className = `playlist-virtual-spacer-${edge}`;
  let row = refs.playlistBody.querySelector(`.${className}`);
  if (height <= 0) {
    row?.remove();
    return null;
  }
  if (!row) row = makePlaylistVirtualSpacer(height, edge);
  const cell = row.firstElementChild;
  cell.colSpan = Math.max(1, orderedColumns().length);
  cell.style.height = `${Math.max(0, Math.round(height))}px`;
  return row;
}

function reconcilePlaylistViewport() {
  if (!playlistUsesVirtualRows() || playlistRowsRendering) return;
  const { start, end } = playlistVirtualRange();
  if (start === playlistVirtualWindowStart && end === playlistVirtualWindowEnd) return;
  playlistVirtualWindowStart = start;
  playlistVirtualWindowEnd = end;

  const topSpacer = updatePlaylistVirtualSpacer("top", start * playlistVirtualRowHeight);
  const bottomSpacer = updatePlaylistVirtualSpacer("bottom", (state.playlist.length - end) * playlistVirtualRowHeight);
  if (bottomSpacer && refs.playlistBody.lastChild !== bottomSpacer) {
    refs.playlistBody.appendChild(bottomSpacer);
  }
  for (const [trackId, row] of playlistRowsByTrackId) {
    const index = playlistIndexByID.get(trackId);
    if (index === undefined || index < start || index >= end) {
      row.remove();
      playlistRowsByTrackId.delete(trackId);
    }
  }

  let anchor = bottomSpacer;
  for (let index = end - 1; index >= start; index -= 1) {
    const track = state.playlist[index];
    let row = playlistRowsByTrackId.get(track.id);
    if (!row) row = makePlaylistRow(track, index);
    if (row.nextSibling !== anchor) refs.playlistBody.insertBefore(row, anchor);
    anchor = row;
  }
  if (topSpacer && refs.playlistBody.firstChild !== topSpacer) {
    refs.playlistBody.insertBefore(topSpacer, refs.playlistBody.firstChild);
  }
  selectedPlaylistRow = state.selectedTrackId ? playlistRowsByTrackId.get(state.selectedTrackId) || null : null;
  currentPlaylistRow = state.currentTrackId ? playlistRowsByTrackId.get(state.currentTrackId) || null : null;
  scheduleSelectionIndicators(false, SELECTION_PLAYLIST);
}

refs.playlistBodyWrap?.addEventListener("scroll", schedulePlaylistViewportRender, { passive: true });
refs.playlistBodyWrap?.addEventListener("scroll", () => {
  if (!playlistUsesVirtualRows()) scheduleSelectionIndicators(false, SELECTION_PLAYLIST);
}, { passive: true });
refs.treeRoot?.addEventListener("scroll", () => scheduleSelectionIndicators(false, SELECTION_SIDEBAR), { passive: true });
refs.optionsNav?.addEventListener("scroll", () => scheduleSelectionIndicators(false, SELECTION_OPTIONS), { passive: true });
window.addEventListener("resize", () => scheduleSelectionIndicators(false), { passive: true });

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  }[character]));
}

function ensureSidebarSelectionIndicator() {
  if (refs.sidebarSelectionIndicator?.isConnected) return refs.sidebarSelectionIndicator;
  const indicator = document.createElement("div");
  indicator.id = "sidebar-selection-indicator";
  indicator.className = "list-selection-indicator";
  indicator.setAttribute("aria-hidden", "true");
  document.body.appendChild(indicator);
  refs.sidebarSelectionIndicator = indicator;
  return indicator;
}

function resetSidebarContent() {
  sidebarContentRendering = true;
  databaseRowRenderGeneration += 1;
  const indicator = ensureSidebarSelectionIndicator();
  refs.treeRoot.replaceChildren();
  return indicator;
}

function positionSelectionIndicator(container, indicator, target) {
  if (!container || !indicator || !target?.isConnected || !container.contains(target)) {
    if (indicator) indicator.style.opacity = "0";
    return;
  }
  const containerBounds = container.getBoundingClientRect();
  const targetBounds = target.getBoundingClientRect();
  const visibleLeft = Math.max(containerBounds.left, targetBounds.left);
  const visibleRight = Math.min(containerBounds.right, targetBounds.right);
  const visibleBottom = Math.min(containerBounds.bottom, targetBounds.bottom);
  const visibleTop = Math.max(containerBounds.top, targetBounds.top);
  if (!targetBounds.width || !targetBounds.height || visibleRight <= visibleLeft || visibleBottom <= visibleTop) {
    indicator.style.opacity = "0";
    return;
  }
  const left = visibleLeft;
  const top = visibleBottom - 1;
  indicator.style.width = `${visibleRight - visibleLeft}px`;
  indicator.style.transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`;
  indicator.style.opacity = "1";
}

function syncSelectionIndicators() {
  selectionIndicatorFrame = 0;
  const scopes = selectionIndicatorScopes || SELECTION_ALL;
  selectionIndicatorScopes = 0;
  if (scopes & SELECTION_SIDEBAR) {
    const sidebarTarget = currentSidebarView().contentMode === "tree"
      ? selectedBrowserButton
      : selectedDatabaseGameButton || selectedDatabaseConsoleButton;
    if (!sidebarContentRendering) {
      positionSelectionIndicator(refs.treeRoot, ensureSidebarSelectionIndicator(), sidebarTarget);
    }
  }
  if ((scopes & SELECTION_PLAYLIST) && !playlistRowsRendering) {
    positionSelectionIndicator(refs.playlistBodyWrap, refs.playlistSelectionIndicator, selectedPlaylistRow);
  }
  if (scopes & SELECTION_OPTIONS) {
    const optionsTarget = {
      database: refs.optionsDatabaseTab,
      interface: refs.optionsInterfaceTab,
      windows: refs.optionsWindowsTab,
      audio: refs.optionsAudioTab,
      diagnostics: refs.optionsDiagnosticsTab,
      playback: refs.optionsPlaybackTab,
      routing: refs.optionsRoutingTab
    }[state.optionsSection] || refs.optionsDatabaseTab;
    positionSelectionIndicator(refs.optionsNav, refs.optionsSelectionIndicator, optionsTarget);
  }
  if (document.documentElement.classList.contains("selection-indicators-following-scroll")) {
    const generation = selectionIndicatorSuppressionGeneration;
    window.requestAnimationFrame(() => {
      if (generation === selectionIndicatorSuppressionGeneration) {
        document.documentElement.classList.remove("selection-indicators-following-scroll");
      }
    });
  }
}

function scheduleSelectionIndicators(animated = true, scopes = SELECTION_ALL) {
  selectionIndicatorSuppressionGeneration += 1;
  selectionIndicatorScopes |= scopes;
  document.documentElement.classList.toggle("selection-indicators-following-scroll", !animated);
  if (selectionIndicatorFrame) return;
  selectionIndicatorFrame = window.requestAnimationFrame(syncSelectionIndicators);
}

function findBrowserNode(nodes, targetPath) {
  for (const node of nodes) {
    if (node.path === targetPath) return node;
    const child = findBrowserNode(node.children || [], targetPath);
    if (child) return child;
  }
  return null;
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
  selectedBrowserButton?.scrollIntoView({ block: "nearest" });
}

async function loadBrowserChildren(node) {
  if (node.kind !== "folder" || node.childrenLoaded) return;
  node.children = await window.spcBoyWK.listFolder(node.path);
  node.childrenLoaded = true;
}

function catalogPlaylistSelection(rows, selectedPath) {
  if (rows?.stale === true) return null;
  return {
    selectedFolderPath: selectedPath,
    selectedBrowserPath: state.selectedBrowserPath,
    playlist: databaseRowsToPlaylistTracks(rows, [])
  };
}

async function invalidatePlaylistCatalogSession() {
  await window.spcBoyWK.catalogSessionInvalidate("playlist");
}

async function loadBrowserSelection(node) {
  if (node.catalogFile) {
    return catalogPlaylistSelection(await window.spcBoyWK.databaseFileTracks([node.catalogFile]), node.catalogFile.path);
  }
  if (node.catalogFolder) {
    return catalogPlaylistSelection(await window.spcBoyWK.databaseFolderTracks([node.catalogFolder]), node.catalogFolder.folderPath);
  }
  const selection = node.kind === "folder"
    ? window.spcBoyWK.selectFolder(node.path)
    : window.spcBoyWK.selectFile(node.path);
  return selection.then((value) => value?.stale === true ? null : value);
}

function loadBrowserSelectionOnce(node) {
  const now = performance.now();
  const current = browserSelectionRequest;
  if (current?.path === node.path && (current.pending || now < current.expiresAt)) {
    return current.promise;
  }
  const request = { path: node.path, pending: true, expiresAt: Number.POSITIVE_INFINITY, promise: null };
  request.promise = loadBrowserSelection(node).then((selection) => {
    request.pending = false;
    if (selection && selection.stale !== true) {
      request.expiresAt = performance.now() + 350;
      window.setTimeout(() => {
        if (browserSelectionRequest === request && performance.now() >= request.expiresAt) {
          browserSelectionRequest = null;
        }
      }, 360);
    } else if (browserSelectionRequest === request) {
      browserSelectionRequest = null;
    }
    return selection;
  }, (error) => {
    if (browserSelectionRequest === request) browserSelectionRequest = null;
    throw error;
  });
  browserSelectionRequest = request;
  return request.promise;
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
  const generation = ++browserSelectionGeneration;
  try {
    state.selectedBrowserPath = node.path;
    persistSettings();
    if (node.kind === "folder") {
      expandedFolders.add(node.path);
      await loadBrowserChildren(node);
    }
    const selection = await loadBrowserSelectionOnce(node);
    if (!selection
        || generation !== browserSelectionGeneration
        || state.selectedBrowserPath !== node.path) return;
    applyFolderSelection(selection);
    const target = selection.playlist?.[0];
    if (playNow && target) await playVisibleTrack(target.id, 0);
  } catch (error) {
    console.error(error);
  }
}

async function previewBrowserLeaf(node) {
  const generation = ++browserSelectionGeneration;
  try {
    const selection = await loadBrowserSelectionOnce(node);
    if (!selection) return;
    if (generation !== browserSelectionGeneration || state.selectedBrowserPath !== node.path) return;
    applyFolderSelection(selection);
  } catch (error) {
    console.error(error);
  }
}

async function handleBrowserPrimaryClick(node, wasSelected) {
  await handleBrowserGesture(node, "primaryClick", wasSelected);
}

async function handleBrowserGesture(node, gesture, wasSelected = false) {
  const intent = await window.SPCBoySidebarController.resolveIntent(node, gesture, wasSelected);
  if (intent === "preview") await previewBrowserLeaf(node);
  else if (intent === "toggleExpansion") await toggleBrowserNode(node);
  else if (intent === "activate") await activateBrowserNode(node);
}

function selectBrowserNode(node, { focus = false, previewLeaf = true } = {}) {
  if (state.selectedBrowserPath !== node.path) {
    browserSelectionGeneration += 1;
  }
  state.selectedBrowserPath = node.path;
  persistSettings();
  syncTreeSelection();
  if (focus) selectedBrowserButton?.focus();
  if (previewLeaf && node.kind === "file") void previewBrowserLeaf(node);
}

function visibleBrowserNodes() {
  return visibleBrowserNodeList;
}

function moveBrowserSelection(delta) {
  const nodes = visibleBrowserNodes();
  if (!nodes.length) return;
  const currentIndex = visibleBrowserNodeIndexByPath.get(state.selectedBrowserPath) ?? -1;
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
  state.selectedTrackId = uniqueAdditions[0].id;
  state.lastSelectedTrackId = state.selectedTrackId;
  persistSettings();
  renderTree();
  syncTreeSelection();
  renderPlaylist();
  uiApp.playback.updateTimingSummary();
}

async function queueBrowserNode(node) {
  const selection = await loadBrowserSelectionOnce(node);
  if (!selection) return;
  appendPlaylistTracks(Array.isArray(selection.playlist) ? selection.playlist : [], node.path);
}

async function toggleBrowserNode(node) {
  if (node.kind !== "folder") return;
  if (node.path === state.rootPath) return;
  if (expandedFolders.has(node.path)) expandedFolders.delete(node.path);
  else {
    expandedFolders.add(node.path);
    await loadBrowserChildren(node);
  }
  renderTree();
  syncTreeSelection();
  browserButtonsByPath.get(node.path)?.focus();
}

function renderTreeNode(node, container) {
  const wrapper = document.createElement("div");
  wrapper.className = "tree-item";
  const button = document.createElement("button");
  const expanded = isNodeExpanded(node);
  button.dataset.browserPath = node.path;
  button.className = `tree-node${state.selectedBrowserPath === node.path ? " is-selected" : ""}`;
  if (state.selectedBrowserPath === node.path) selectedBrowserButton = button;
  browserButtonsByPath.set(node.path, button);
  visibleBrowserNodeIndexByPath.set(node.path, visibleBrowserNodeList.length);
  visibleBrowserNodeList.push(node);
  button.classList.toggle("tree-file", node.kind === "file");
  button.setAttribute("aria-expanded", node.kind === "folder" ? String(expanded) : "false");
  button.innerHTML = `
    <span class="tree-disclosure">${node.kind === "folder" ? (expanded ? "▾" : "▸") : "·"}</span><span class="tree-label">${escapeHtml(node.name)}</span>
  `;
  button.addEventListener("click", (event) => {
    window.clearTimeout(browserClickTimer);
    const wasSelected = state.selectedBrowserPath === node.path;
    const disclosureClick = event.target.closest?.(".tree-disclosure");
    selectBrowserNode(node, { focus: true, previewLeaf: false });
    if (event.detail > 1) return;
    if (node.kind === "file") {
      void previewBrowserLeaf(node);
      return;
    }
    if (disclosureClick && node.kind === "folder") {
      void toggleBrowserNode(node);
      return;
    }
    if (!wasSelected) return;
    browserClickTimer = window.setTimeout(() => void handleBrowserPrimaryClick(node, wasSelected), 220);
  });
  button.addEventListener("dblclick", (event) => {
    event.preventDefault();
    event.stopPropagation();
    window.clearTimeout(browserClickTimer);
    if (event.target.closest?.(".tree-disclosure")) return;
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
    return currentSidebarView().view === "paths" ? state.databaseFileTree : state.tree;
  }

  function filterNode(node) {
    const filteredChildren = node.children.map(filterNode).filter(Boolean);
    const searchableText = `${node.name || ""} ${node.path || ""}`.toLowerCase();
    if (terms.every((term) => searchableText.includes(term)) || filteredChildren.length > 0) {
      return {
        ...node,
        children: filteredChildren
      };
    }
    return null;
  }

  const sourceTree = currentSidebarView().view === "paths" ? state.databaseFileTree : state.tree;
  const localMatches = sourceTree.map(filterNode).filter(Boolean);
  return localMatches;
}

const sidebarNaturalCollator = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" });

function renderTree() {
  renderedDatabaseGames = null;
  databaseEmptyState = null;
  databaseConsoleGroups = [];
  databaseGameButtonsByKey.clear();
  databaseConsoleButtonsByName.clear();
  visibleDatabaseGameKeys = null;
  browserButtonsByPath.clear();
  visibleBrowserNodeIndexByPath.clear();
  visibleBrowserNodeList = [];
  selectedBrowserButton = null;
  selectedDatabaseGameButton = null;
  selectedDatabaseConsoleButton = null;
  resetSidebarContent();
  const visibleTree = filteredTree();
  if (visibleTree.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty sidebar-empty";
    empty.textContent = currentSidebarView().view === "paths"
      ? "No catalog paths match this view."
      : state.rootPath
        ? "No subfolders match this view."
        : "Choose Open Path to browse a local folder.";
    refs.treeRoot.appendChild(empty);
    sidebarContentRendering = false;
    scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
    return;
  }

  ensureExpandedToSelection(visibleTree);
  visibleTree.forEach((node) => renderTreeNode(node, refs.treeRoot));
  sidebarContentRendering = false;
  scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
}

function databaseGameKey(game) {
  return `${game.rootId}\u0000${game.name}\u0000${game.system}`;
}

function databaseConsoleName(game) {
  return game.system || "Unknown Console";
}

let databaseGroupTransitionGeneration = 0;

function syncDatabaseSelectionButtons() {
  const nextGame = state.selectedDatabaseGameKey
    ? databaseGameButtonsByKey.get(state.selectedDatabaseGameKey) || null
    : null;
  const nextConsole = !state.selectedDatabaseGameKey && state.selectedDatabaseConsoleName
    ? databaseConsoleButtonsByName.get(state.selectedDatabaseConsoleName) || null
    : null;
  if (selectedDatabaseGameButton !== nextGame) {
    selectedDatabaseGameButton?.classList.remove("is-selected");
    nextGame?.classList.add("is-selected");
    selectedDatabaseGameButton = nextGame;
  }
  if (selectedDatabaseConsoleButton !== nextConsole) {
    selectedDatabaseConsoleButton?.classList.remove("is-selected");
    nextConsole?.classList.add("is-selected");
    selectedDatabaseConsoleButton = nextConsole;
  }
}

function syncDatabaseGameVisibility(visibleGames) {
  const nextKeys = Array.isArray(state.databaseSearchGames)
    ? new Set(visibleGames.map(databaseGameKey))
    : null;

  if (nextKeys === null) {
    if (visibleDatabaseGameKeys !== null) {
      for (const button of databaseGameButtonsByKey.values()) button.classList.remove("is-hidden");
    }
    visibleDatabaseGameKeys = null;
    return;
  }

  if (visibleDatabaseGameKeys === null) {
    for (const [key, button] of databaseGameButtonsByKey) {
      if (!nextKeys.has(key)) button.classList.add("is-hidden");
    }
  } else {
    for (const key of visibleDatabaseGameKeys) {
      if (!nextKeys.has(key)) databaseGameButtonsByKey.get(key)?.classList.add("is-hidden");
    }
    for (const key of nextKeys) {
      if (!visibleDatabaseGameKeys.has(key)) databaseGameButtonsByKey.get(key)?.classList.remove("is-hidden");
    }
  }
  visibleDatabaseGameKeys = nextKeys;
}

function databaseGroupStateSnapshot() {
  const knownGroupNames = databaseConsoleGroups.map(({ consoleName }) => consoleName);
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
  for (const knownName of databaseConsoleGroups.map(({ consoleName }) => consoleName)) {
    if (expanded.has(knownName)) collapsedDatabaseConsoles.delete(knownName);
    else collapsedDatabaseConsoles.add(knownName);
  }
  state.selectedDatabaseConsoleName = next.selectedGroupName || null;
  state.selectedDatabaseGameKey = next.selectedGameID || null;
  syncDatabaseSelectionButtons();
  scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
  syncCollapsedConsolePersistence();
  return true;
}

function visibleDatabaseGames() {
  return Array.isArray(state.databaseSearchGames) ? state.databaseSearchGames : state.databaseGames;
}

function databaseLoadedSelectionID() {
  return state.selectedTrackId || state.playlist[0]?.id || null;
}

function makeDatabaseGameButton(game) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "database-game-row";
  button.dataset.databaseGameKey = databaseGameKey(game);
  button.dataset.searchText = `${game.name} ${game.rootName || ""}`.toLowerCase();
  button.innerHTML = `<span class="database-disclosure">·</span><span class="database-game-name">${escapeHtml(game.displayName || game.name)}</span>${state.sidebarPathCounts ? `<span class="database-game-meta">${game.trackCount}</span>` : ""}`;
  button.addEventListener("click", (event) => {
    if (event.detail > 1) return;
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    syncDatabaseSelectionButtons();
    scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
    button.focus();
    // Database game rows are final sidebar leaves. Preview the indexed tracks
    // on the first click; a double-click reuses this request before activating it.
    loadDatabaseGameOnce(game).catch((error) => reportDatabaseSidebarError("preview the selected game", error));
  });
  button.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    event.stopPropagation();
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    loadDatabaseGameOnce(game).then((loaded) => {
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) return playVisibleTrack(targetID, 0);
      return undefined;
    }).catch((error) => reportDatabaseSidebarError("play the selected game", error));
  });
  button.addEventListener("dblclick", (event) => {
    event.preventDefault();
    event.stopPropagation();
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    loadDatabaseGameOnce(game).then((loaded) => {
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) return playVisibleTrack(targetID, 0);
      return undefined;
    }).catch((error) => reportDatabaseSidebarError("play the selected game", error));
  });
  button.addEventListener("contextmenu", (event) => {
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    persistSettings();
    showContextMenu(event, [
      ["Show in Finder", async () => {
        const rows = await window.spcBoyWK.databaseGameTracks([game]);
        if (rows?.stale === true) return;
        const row = rows[0];
        if (row) await window.spcBoyWK.showInFinder(row.archivePath || row.path);
      }],
      ["Play Now", async () => {
        const loaded = await loadDatabaseGame(game);
        const targetID = loaded ? databaseLoadedSelectionID() : null;
        if (targetID) await playVisibleTrack(targetID, 0);
      }],
      ["Queue", async () => {
        const rows = await window.spcBoyWK.databaseGameTracks([game]);
        if (rows?.stale === true) return;
        appendPlaylistTracks(databaseRowsToPlaylistTracks(rows, [game]));
      }]
    ]);
  });
  return button;
}

function appendDatabaseGameRowsInBatches(groupedGames) {
  const generation = databaseRowRenderGeneration;
  let groupIndex = 0;
  let rowIndex = 0;

  const appendBatch = () => {
    if (generation !== databaseRowRenderGeneration) return;
    const startedAt = performance.now();
    while (groupIndex < databaseConsoleGroups.length && performance.now() - startedAt < 8) {
      const { games, consoleName } = databaseConsoleGroups[groupIndex];
      const groupRows = groupedGames.get(consoleName) || [];
      if (rowIndex >= groupRows.length) {
        groupIndex += 1;
        rowIndex = 0;
        continue;
      }
      const game = groupRows[rowIndex++];
      const button = makeDatabaseGameButton(game);
      const key = databaseGameKey(game);
      if (visibleDatabaseGameKeys && !visibleDatabaseGameKeys.has(key)) button.classList.add("is-hidden");
      games.appendChild(button);
      databaseGameButtonsByKey.set(key, button);
    }
    if (groupIndex < databaseConsoleGroups.length) {
      window.requestAnimationFrame(appendBatch);
    } else {
      syncDatabaseSelectionButtons();
      sidebarContentRendering = false;
      scheduleSelectionIndicators(false, SELECTION_SIDEBAR);
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
    sidebarContentRendering = false;
    scheduleSelectionIndicators(false, SELECTION_SIDEBAR);
    return;
  }
  const allGames = state.databaseGames;
  const gamesForView = visibleDatabaseGames();
  if (renderedDatabaseGames !== allGames) {
    resetSidebarContent();
    selectedDatabaseGameButton = null;
    selectedDatabaseConsoleButton = null;
    databaseConsoleGroups = [];
    databaseGameButtonsByKey.clear();
    databaseConsoleButtonsByName.clear();
    visibleDatabaseGameKeys = null;
    const groupedGames = new Map();
    for (const game of allGames) {
      const consoleName = databaseConsoleName(game);
      const games = groupedGames.get(consoleName) || [];
      games.push(game);
      groupedGames.set(consoleName, games);
    }
    [...groupedGames.keys()].sort((left, right) => sidebarNaturalCollator.compare(left, right)).forEach((consoleName) => {
      const group = document.createElement("div");
      group.className = "database-console-group";
      const heading = document.createElement("button");
      heading.type = "button";
      heading.className = `database-console-row${state.selectedDatabaseConsoleName === consoleName && !state.selectedDatabaseGameKey ? " is-selected" : ""}`;
      heading.dataset.databaseConsoleName = consoleName;
      heading.tabIndex = 0;
      const expanded = !collapsedDatabaseConsoles.has(consoleName);
      heading.innerHTML = `<span class="database-disclosure">${expanded ? "▾" : "▸"}</span><span class="database-console-label">${escapeHtml(consoleName)}</span>`;
      const games = document.createElement("div");
      games.className = "database-console-games";
      games.classList.toggle("is-hidden", !expanded);
      heading.addEventListener("click", async () => {
        try {
          await applySharedDatabaseGroupAction("toggle", consoleName);
          renderDatabaseGames();
        } catch (error) {
          reportDatabaseSidebarError("toggle the database console", error);
        }
      });
      heading.addEventListener("keydown", (event) => {
        if (event.key !== " ") return;
        event.preventDefault();
        heading.click();
      });
      heading.addEventListener("dblclick", (event) => {
        event.preventDefault();
        event.stopPropagation();
        void (async () => {
          await applySharedDatabaseGroupAction("select", consoleName);
          await activateDatabaseSelection();
        })().catch((error) => reportDatabaseSidebarError("play the selected console", error));
      });
      group.append(heading, games);
      refs.treeRoot.appendChild(group);
      databaseConsoleGroups.push({ group, games, consoleName, heading });
      databaseConsoleButtonsByName.set(consoleName, heading);
    });

    databaseEmptyState = document.createElement("div");
    databaseEmptyState.className = "empty sidebar-empty";
    refs.treeRoot.appendChild(databaseEmptyState);
    renderedDatabaseGames = allGames;
    appendDatabaseGameRowsInBatches(groupedGames);
  }

  const query = state.sidebarQuery.trim();
  syncDatabaseGameVisibility(gamesForView);
  syncDatabaseSelectionButtons();
  const matchingConsoles = query ? new Set(gamesForView.map(databaseConsoleName)) : null;

  for (const { group, games, consoleName } of databaseConsoleGroups) {
    group.classList.toggle("is-hidden", Boolean(matchingConsoles && !matchingConsoles.has(consoleName)));
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
  scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
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
  state.sidebarView = Object.freeze(localSidebarView(state.sidebarMode, state.sidebarQuery));
  renderSidebar();
}

const SIDEBAR_VIEW_CYCLE = ["consoles", "paths"];

async function cycleSidebarMode() {
  if (state.localBrowserEnabled) return;
  const current = currentSidebarView().storedMode;
  const currentIndex = SIDEBAR_VIEW_CYCLE.indexOf(current);
  const next = SIDEBAR_VIEW_CYCLE[(currentIndex + 1 + SIDEBAR_VIEW_CYCLE.length) % SIDEBAR_VIEW_CYCLE.length];
  await setSidebarMode(next);
}

async function loadDatabaseGame(game) {
  return loadDatabaseGamesIntoPlaylist([game]);
}

function loadDatabaseGameOnce(game) {
  const key = databaseGameKey(game);
  const current = databaseGameLoadRequest;
  if (current?.key === key && (current.pending || performance.now() < current.expiresAt)) {
    return current.promise;
  }
  const request = { key, pending: true, expiresAt: Number.POSITIVE_INFINITY, promise: null };
  request.promise = loadDatabaseGame(game).then((loaded) => {
    request.pending = false;
    if (loaded) {
      request.expiresAt = performance.now() + 350;
      window.setTimeout(() => {
        if (databaseGameLoadRequest === request && performance.now() >= request.expiresAt) {
          databaseGameLoadRequest = null;
        }
      }, 360);
    } else if (databaseGameLoadRequest === request) {
      databaseGameLoadRequest = null;
    }
    return loaded;
  }, (error) => {
    if (databaseGameLoadRequest === request) databaseGameLoadRequest = null;
    throw error;
  });
  databaseGameLoadRequest = request;
  return request.promise;
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
  const rows = await window.spcBoyWK.databaseGameTracks(games);
  if (rows?.stale === true) return;
  await toggleFavorites(databaseRowsToPlaylistTracks(rows, games));
  renderSidebar();
  renderPlaylist();
}

function reportDatabaseSidebarError(action, error) {
  const detail = String(error?.message || error || "Unknown database error");
  state.databaseSidebarError = `Could not ${action}: ${detail}`;
  console.error(`[SPCBoy] could not ${action}`, error);
  if (currentSidebarView().contentMode === "database") renderDatabaseGames();
}

function databaseRowsToPlaylistTracks(rows, games) {
  const fallbackGame = games[0] || {};
  return rows.map((row, index) => ({
    id: row.playlistId,
    favoriteId: row.favoriteId || null,
    index: index + 1,
    path: row.path,
    rootPath: row.rootPath || fallbackGame.rootPath || state.rootPath,
    sourceFilename: row.filename,
    trackIndex: Number(row.trackIndex) || 0,
    trackCount: Math.max(1, Number(row.trackCount) || 1),
    archivePath: row.archivePath || null,
    archiveEntry: row.archiveEntry || null,
    fileSize: Number(row.fileSize) || 0,
    modifiedAt: Number(row.modifiedAt) || 0,
    sourceSignature: row.sourceSignature || null,
    scanVersion: Number(row.scanVersion) || 0,
    filename: `${row.filename}${Number(row.trackCount) > 1 ? ` [${Number(row.trackIndex) + 1}]` : ""}`,
    displayName: `${row.filename.replace(/\.[^.]+$/i, "")}${Number(row.trackCount) > 1 ? ` [${Number(row.trackIndex) + 1}]` : ""}`,
    title: row.title || row.filename.replace(/\.[^.]+$/i, ""),
    game: row.game || fallbackGame.name || "—",
    artist: row.artist || "—",
    system: row.system || fallbackGame.system || "—",
    lengthLabel: row.playLengthMs > 0 ? uiApp.formatTime(Math.round(row.playLengthMs / 1000)) : "—",
    basePlaybackSeconds: row.playLengthMs > 0 ? row.playLengthMs / 1000 : 0,
    metadataLoaded: row.metadataLoaded === true,
    catalogRow: true
  }));
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
      const loaded = await loadDatabaseGamesIntoPlaylist(games);
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) await playVisibleTrack(targetID, 0);
      return;
    }
  }
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
      state.selectedDatabaseGameKey = databaseGameButton.dataset.databaseGameKey;
      state.selectedDatabaseConsoleName = databaseConsoleName(game);
      persistSettings();
      const loaded = await loadDatabaseGameOnce(game);
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
    resetSidebarContent();
    const loading = document.createElement("div");
    loading.className = "empty sidebar-empty sidebar-loading";
    loading.textContent = "Loading catalog…";
    refs.treeRoot.appendChild(loading);
    sidebarContentRendering = false;
    scheduleSelectionIndicators(false, SELECTION_SIDEBAR);
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
    selectedBrowserButton = state.selectedBrowserPath ? browserButtonsByPath.get(state.selectedBrowserPath) || null : null;
    selectedBrowserButton?.classList.add("is-selected");
  }
  scrollSelectedBrowserItemIntoView();
  scheduleSelectionIndicators(true, SELECTION_SIDEBAR);
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

function updateAutomaticColumnVisibility() {
  const hidden = new Set();
  if (state.playlist.length) {
    const sample = state.playlist.length > 1200
      ? [...state.playlist.slice(0, 600), ...state.playlist.slice(-600)]
      : state.playlist;
    for (const column of allColumns()) {
      if (!state.columnVisibility[column.id] || column.id === "favorite" || column.id === "index") continue;
      const meaningful = sample.some((track, index) => {
        const value = String(playlistColumnValue(track, column, index) ?? "").trim();
        return value !== "" && value !== "—" && value !== "-";
      });
      if (!meaningful) hidden.add(column.id);
    }
    if (allColumns().every((column) => !state.columnVisibility[column.id] || hidden.has(column.id))) {
      const fallback = allColumns().find((column) => state.columnVisibility[column.id]);
      if (fallback) hidden.delete(fallback.id);
    }
  }
  const changed = hidden.size !== state.automaticallyHiddenColumns.size
    || [...hidden].some((id) => !state.automaticallyHiddenColumns.has(id));
  state.automaticallyHiddenColumns = hidden;
  return changed;
}

function playlistSortValue(track, column) {
  if (column.id === "lengthLabel") {
    return Number(track.basePlaybackSeconds) || 0;
  }
  return String(playlistColumnValue(track, column)).toLocaleLowerCase();
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

function sortPlaylist() {
  const column = COLUMN_DEFS.find((candidate) => candidate.id === state.sortColumn) || COLUMN_DEFS.find((candidate) => candidate.id === "filename");
  const direction = state.sortDirection === "descending" ? -1 : 1;
  state.playlist.sort((left, right) => {
    const leftValue = playlistSortValue(left, column);
    const rightValue = playlistSortValue(right, column);
    if (leftValue < rightValue) return -1 * direction;
    if (leftValue > rightValue) return 1 * direction;
    return String(left.id).localeCompare(String(right.id));
  });
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
  const pointerId = event.pointerId;
  columnResizePointerId = pointerId;
  const onMove = (moveEvent) => {
    if (moveEvent.pointerId !== pointerId) return;
    const nextWidth = Math.max(4, Math.min(80, startWidth + ((moveEvent.clientX - startX) / tableWidth) * 100));
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
    const targetOtherTotal = Math.max(4 * otherColumns.length, 100 - draggedWidth);
    const otherTotal = otherColumns.reduce((sum, column) => sum + state.columnWidths[column.id], 0);
    if (otherTotal > 0) {
      for (const column of otherColumns) {
        state.columnWidths[column.id] = Math.max(4, state.columnWidths[column.id] * targetOtherTotal / otherTotal);
      }
    } else {
      const fallback = targetOtherTotal / Math.max(1, otherColumns.length);
      for (const column of otherColumns) state.columnWidths[column.id] = fallback;
    }
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
  const sample = state.playlist.length > 1200
    ? [...state.playlist.slice(0, 600), ...state.playlist.slice(-600)]
    : state.playlist;
  const values = [column.label, ...sample.map((track, rowIndex) => String(playlistColumnValue(track, column, rowIndex)))];
  return Math.max(...values.map((value) => textMeasureContext.measureText(value).width), 0) + 24;
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
    playlistTable.style.minWidth = width;
  });
  columns.forEach((column, index) => {
    state.columnWidths[column.id] = (preferredWidths[index] / totalWidth) * 100;
  });
  persistSettings();
}

function autoSizeColumn(columnId) {
  if (!state.playlist.length || !state.columnVisibility[columnId]) return;
  const columns = orderedColumns();
  const startingWidths = Object.fromEntries(columns.map((column) => [column.id, state.columnWidths[column.id]]));
  const tableWidth = refs.playlistHeaderRow.closest("table").getBoundingClientRect().width;
  const nextWidth = Math.max(4, Math.min(80, (columnContentWidth(columnId) / tableWidth) * 100));
  const previousWidth = state.columnWidths[columnId];
  const otherColumns = columns.filter((column) => column.id !== columnId);
  const otherTotal = otherColumns.reduce((sum, column) => sum + state.columnWidths[column.id], 0);
  const targetOtherTotal = Math.max(4 * otherColumns.length, 100 - nextWidth);
  state.columnWidths[columnId] = nextWidth;
  if (otherTotal > 0) {
    for (const column of otherColumns) {
      state.columnWidths[column.id] = Math.max(4, state.columnWidths[column.id] * targetOtherTotal / otherTotal);
    }
  } else {
    const fallback = targetOtherTotal / Math.max(1, otherColumns.length);
    for (const column of otherColumns) state.columnWidths[column.id] = fallback;
  }
  if (!Number.isFinite(previousWidth)) state.columnWidths[columnId] = nextWidth;
  persistSettings();
  if (primePlaylistColumnResize(startingWidths)) {
    window.requestAnimationFrame(() => syncPlaylistColumnWidths());
  } else {
    renderPlaylistHeader();
    syncPlaylistColumnWidths();
  }
}

function renderPlaylistHeader(widths = state.columnWidths) {
  refs.playlistHeaderRow.innerHTML = "";

  for (const column of orderedColumns()) {
    const th = document.createElement("th");
    th.dataset.columnId = column.id;
    th.draggable = true;
    th.className = column.className || "";
    th.style.width = `${widths[column.id]}%`;
    th.title = column.sortable === false ? "Line number" : `Sort by ${column.label}`;

    const label = document.createElement("span");
    label.className = "playlist-header-label toolbar-control";
    label.textContent = column.label;
    if (state.sortColumn === column.id) {
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

    if (column.sortable !== false) th.addEventListener("click", (event) => {
      if (event.target === resizeHandle || columnResizePointerId !== null) return;
      if (state.sortColumn === column.id) {
        state.sortDirection = state.sortDirection === "ascending" ? "descending" : "ascending";
      } else {
        state.sortColumn = column.id;
        state.sortDirection = "ascending";
      }
      persistSettings();
      sortPlaylist();
      renderPlaylistHeader();
      renderPlaylist();
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
      state.columnOrder = uiApp.normalizeColumnOrder(nextOrder);
      persistSettings();
      renderPlaylistHeader();
      renderPlaylist();
    });

    refs.playlistHeaderRow.appendChild(th);
  }
}

function renderPlaylistCell(track, column, rowIndex, widths = state.columnWidths) {
  const td = document.createElement("td");
  td.className = column.className || "";
  td.dataset.columnId = column.id;
  td.style.width = `${widths[column.id]}%`;
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
  row.classList.toggle("is-selected", selectedPlaylistTrackIDs.has(trackId));
  row.classList.toggle("is-current", state.currentTrackId === trackId);
}

function selectPlaylistTrack(trackId, { focus = false, extend = false, range = false } = {}) {
  const track = playlistTrackByID.get(trackId) || state.playlist.find((entry) => entry.id === trackId);
  if (!track) return null;

  const previousIds = new Set(state.selectedTrackIds);
  const selection = window.SPCBoyPlaylistController.reduceSelection({
    playlist: state.playlist,
    selectedIds: state.selectedTrackIds,
    selectedIDSet: selectedPlaylistTrackIDs,
    anchorId: state.playlistSelectionAnchorId,
    indexByID: playlistIndexByID
  }, trackId, { extend, range });
  if (!selection) return null;
  state.selectedTrackIds = selection.selectedIds;
  selectedPlaylistTrackIDs = new Set(selection.selectedIds);
  state.selectedTrackId = selection.primaryId;
  state.lastSelectedTrackId = track.id;
  state.playlistSelectionAnchorId = selection.anchorId;
  if (previousIds.size !== selection.selectedIds.length || selection.selectedIds.some((id) => !previousIds.has(id))) persistSettings();
  window.ViewBoyTabs?.scheduleSelectionSave?.();

  for (const id of previousIds) {
    if (!selectedPlaylistTrackIDs.has(id)) playlistRowsByTrackId.get(id)?.classList.remove("is-selected");
  }
  for (const id of selectedPlaylistTrackIDs) {
    if (!previousIds.has(id)) playlistRowsByTrackId.get(id)?.classList.add("is-selected");
  }
  const nextRow = playlistRowsByTrackId.get(track.id) || null;
  selectedPlaylistRow = nextRow;
  scheduleSelectionIndicators(true, SELECTION_PLAYLIST);
  if (focus) nextRow?.focus({ preventScroll: true });
  return track;
}

function refreshPlaylistPlaybackState() {
  for (const [id, row] of playlistRowsByTrackId) updatePlaylistRowState(row, id);
  const nextSelectedRow = state.selectedTrackId ? playlistRowsByTrackId.get(state.selectedTrackId) || null : null;
  selectedPlaylistRow = nextSelectedRow;

  currentPlaylistRow?.classList.remove("is-current");
  const nextCurrentRow = state.currentTrackId ? playlistRowsByTrackId.get(state.currentTrackId) || null : null;
  nextCurrentRow?.classList.add("is-current");
  currentPlaylistRow = nextCurrentRow;
  scheduleSelectionIndicators(true, SELECTION_PLAYLIST);
}

function refreshPlaylistRow(trackId) {
  const track = playlistTrackByID.get(trackId);
  const rowIndex = playlistIndexByID.get(trackId);
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

function playlistSortDependsOnMetadata() {
  return ["title", "game", "artist", "system", "lengthLabel"].includes(state.sortColumn);
}

function syncPlaylistColumnWidths(widths = state.columnWidths) {
  const firstBodyRow = refs.playlistBody.querySelector(".playlist-row");
  for (const row of playlistRowsByTrackId.values()) {
    row.classList.toggle("playlist-width-source", row === firstBodyRow);
  }
  for (const column of orderedColumns()) {
    const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
    if (header) header.style.width = `${widths[column.id]}%`;
  }
  for (const row of playlistRowsByTrackId.values()) {
    for (const column of orderedColumns()) {
      const cell = row.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
      if (cell) cell.style.width = `${widths[column.id]}%`;
    }
  }
}

function primePlaylistColumnResize(startingWidths) {
  if (!state.autoResizeAnimationEnabled || state.autoResizeAnimationMilliseconds <= 0) return false;
  const changed = orderedColumns().some((column) =>
    Math.abs(state.columnWidths[column.id] - startingWidths[column.id]) > 0.01
  );
  if (!changed) return false;

  renderPlaylistHeader(startingWidths);
  syncPlaylistColumnWidths(startingWidths);
  // Resolve the old widths before the next animation frame installs the new
  // widths. WebKit can then run its native transition at display rate.
  void refs.playlistHeaderTable.offsetWidth;
  return true;
}

function makePlaylistRow(track, rowIndex, widths = state.columnWidths) {
  const row = document.createElement("tr");
  const isWidthSource = playlistRowsByTrackId.size === 0;
  row.dataset.trackId = track.id;
  row.tabIndex = 0;
  row.setAttribute("aria-label", `${track.title || track.filename || "Track"}`);
  row.className = `playlist-row${isWidthSource ? " playlist-width-source" : ""}${selectedPlaylistTrackIDs.has(track.id) ? " is-selected" : ""}${state.currentTrackId === track.id ? " is-current" : ""}`;
  playlistRowsByTrackId.set(track.id, row);
  if (state.selectedTrackId === track.id) selectedPlaylistRow = row;
  if (state.currentTrackId === track.id) currentPlaylistRow = row;

  for (const column of orderedColumns()) {
    row.appendChild(renderPlaylistCell(track, column, rowIndex, widths));
  }

  row.addEventListener("click", (event) => {
    selectPlaylistTrack(track.id, {
      focus: true,
      extend: event.metaKey || event.ctrlKey,
      range: event.shiftKey
    });
    uiApp.playback.updateTimingSummary();
  });

  row.addEventListener("dblclick", () => {
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
    event.preventDefault();
    event.stopPropagation();
    const selectedTrack = selectPlaylistTrack(track.id);
    if (!selectedTrack) return;
    playVisibleTrack(selectedTrack.id, 0).catch((error) => {
      console.error(error);
    });
  });
  return row;
}

function appendPlaylistRowsInBatches(generation, startIndex = 0, endIndex = state.playlist.length, spacers = null, animateSelection = true, initialColumnWidths = null) {
  let rowIndex = startIndex;
  const appendBatch = () => {
    if (generation !== playlistRenderGeneration) return;
    const fragment = document.createDocumentFragment();
    if (rowIndex === startIndex && spacers?.top > 0) {
      fragment.appendChild(makePlaylistVirtualSpacer(spacers.top, "top"));
    }
    const startedAt = performance.now();
    while (rowIndex < endIndex && performance.now() - startedAt < 8) {
      fragment.appendChild(makePlaylistRow(state.playlist[rowIndex], rowIndex, initialColumnWidths || state.columnWidths));
      rowIndex += 1;
    }
    refs.playlistBody.appendChild(fragment);
    if (rowIndex < endIndex) {
      window.requestAnimationFrame(appendBatch);
    } else {
      if (spacers?.bottom > 0) refs.playlistBody.appendChild(makePlaylistVirtualSpacer(spacers.bottom, "bottom"));
      playlistRowsRendering = false;
      if (initialColumnWidths) window.requestAnimationFrame(() => syncPlaylistColumnWidths());
      scheduleSelectionIndicators(animateSelection, SELECTION_PLAYLIST);
      schedulePlaylistRowMeasurement();
      if (playlistViewportRenderPending) {
        playlistViewportRenderPending = false;
        schedulePlaylistViewportRender();
      }
    }
  };
  window.requestAnimationFrame(appendBatch);
}

function renderPlaylist({ sort = true, persist = true, refreshIndex = true, animateSelection = true } = {}) {
  if (persist) queueMicrotask(() => window.ViewBoyTabs?.scheduleSave?.());
  if (refreshIndex && updateAutomaticColumnVisibility()) renderPlaylistHeader();
  playlistRenderGeneration += 1;
  const generation = playlistRenderGeneration;
  playlistRowsRendering = true;
  playlistViewportRenderPending = false;
  playlistVirtualWindowStart = null;
  playlistVirtualWindowEnd = null;
  if (!animateSelection) document.documentElement.classList.add("selection-indicators-following-scroll");
  if (refreshIndex) {
    if (!state.selectedTrackIds.length && state.selectedTrackId) {
      state.selectedTrackIds = [state.selectedTrackId];
    }
    const playlistIDs = new Set(state.playlist.map((track) => track.id));
    state.selectedTrackIds = state.selectedTrackIds.filter((id) => playlistIDs.has(id));
    if (state.selectedTrackId && state.selectedTrackIds.length && !state.selectedTrackIds.includes(state.selectedTrackId)) {
      state.selectedTrackId = state.selectedTrackIds.at(-1) || null;
    }
  }
  refs.playlistBody.innerHTML = "";
  playlistRowsByTrackId.clear();
  selectedPlaylistRow = null;
  currentPlaylistRow = null;
  if (sort) sortPlaylist();
  if (refreshIndex) {
    playlistTrackByID.clear();
    playlistIndexByID.clear();
    state.playlist.forEach((track, index) => {
      playlistTrackByID.set(track.id, track);
      playlistIndexByID.set(track.id, index);
    });
    selectedPlaylistTrackIDs = new Set(state.selectedTrackIds);
  }
  const virtualized = playlistUsesVirtualRows();
  // Auto-sizing every cell defeats a catalog lookup. Large database playlists
  // retain the current widths; explicit column auto-size remains available.
  const playlistSignature = virtualized ? null : playlistAutoSizeSignature();
  const shouldAutoSize = !virtualized && columnResizePointerId === null
    && state.columnAutoSize
    && playlistSignature !== autoSizedPlaylistSignature;
  let initialColumnWidths = null;

  if (state.playlist.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = `<td colspan="${Math.max(1, orderedColumns().length)}" class="empty-row"></td>`;
    refs.playlistBody.appendChild(row);
    playlistRowsRendering = false;
    scheduleSelectionIndicators(animateSelection, SELECTION_PLAYLIST);
    return;
  }

  if (shouldAutoSize) {
    autoSizedPlaylistSignature = playlistSignature;
    const startingWidths = Object.fromEntries(orderedColumns().map((column) => [column.id, state.columnWidths[column.id]]));
    autoSizeColumns();
    if (primePlaylistColumnResize(startingWidths)) initialColumnWidths = startingWidths;
    else {
      renderPlaylistHeader();
      syncPlaylistColumnWidths();
    }
  }
  if (!virtualized) {
    appendPlaylistRowsInBatches(generation, 0, state.playlist.length, null, animateSelection, initialColumnWidths);
    return;
  }

  const { start: firstVisibleRow, end: lastVisibleRow } = playlistVirtualRange();
  playlistVirtualWindowStart = firstVisibleRow;
  playlistVirtualWindowEnd = lastVisibleRow;
  appendPlaylistRowsInBatches(
    generation,
    firstVisibleRow,
    lastVisibleRow,
    {
      top: firstVisibleRow * playlistVirtualRowHeight,
      bottom: (state.playlist.length - lastVisibleRow) * playlistVirtualRowHeight
    },
    animateSelection
  );
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
  rootStyle.setProperty("--ui-font-size-pt", String(state.uiFontSizePt));
  rootStyle.setProperty("--app-font-family", "var(--viewboy-font-family)");
  rootStyle.setProperty("--sidebar-font-size-pt", String(state.sidebarFontSizePt));
  rootStyle.setProperty("--sidebar-text-color", state.sidebarTextColor);
  rootStyle.setProperty("--sidebar-font-family", "var(--viewboy-font-family)");
  rootStyle.setProperty("--playlist-font-size-pt", String(state.playlistFontSizePt));
  rootStyle.setProperty("--playlist-text-color", state.playlistTextColor);
  rootStyle.setProperty("--playlist-font-family", "var(--viewboy-font-family)");
  rootStyle.setProperty("--playlist-header-font-weight", state.playlistHeaderBold ? "700" : "400");
  rootStyle.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
  rootStyle.setProperty("--accent", state.accentColor);
  rootStyle.setProperty("--item-spacing-rem", String(state.uiItemSpacingRem));
  rootStyle.setProperty("--column-resize-duration", `${state.autoResizeAnimationEnabled ? state.autoResizeAnimationMilliseconds : 0}ms`);
  rootStyle.setProperty("--selection-animation-duration", `${state.selectionAnimationEnabled ? state.selectionAnimationMilliseconds : 0}ms`);
  if (refs.uiFontSizeReadout) refs.uiFontSizeReadout.textContent = `${state.uiFontSizePt} PT`;
}

function appearanceSettings() {
  return {
    uiItemSpacingRem: state.uiItemSpacingRem,
    sidebarWidthPercent: state.sidebarWidthPercent,
    sidebarFontSizePt: state.sidebarFontSizePt,
    sidebarTextColor: state.sidebarTextColor,
    sidebarMonospace: state.sidebarMonospace,
    sidebarPathCounts: state.sidebarPathCounts,
    playlistFontSizePt: state.playlistFontSizePt,
    playlistTextColor: state.playlistTextColor,
    playlistMonospace: state.playlistMonospace,
    applicationMonospace: state.applicationMonospace,
    playlistHeaderBold: state.playlistHeaderBold,
    accentColor: state.accentColor
  };
}

function broadcastAppearanceSettings() {
  window.spcBoyWK?.setAppearanceSettings?.(appearanceSettings());
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
  const conflicts = window.SPCBoyPlaybackBackends?.conflicts || [];
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
  const candidates = window.SPCBoyPlaybackBackends?.candidatesForPath?.(`route${extension}`) || [];
  if (!candidates.some((backend) => backend.id === backendId)) return;
  const nextPreferences = { ...state.routingPreferences };
  if (backendId === candidates[0]?.id) delete nextPreferences[extension];
  else nextPreferences[extension] = backendId;
  state.routingPreferences = nextPreferences;
  persistSettings();
  window.spcBoyWK?.setRoutingPreferences?.(nextPreferences).then((normalizedPreferences) => {
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
  refs.optionsOverlay.classList.toggle("is-hidden", !state.optionsOpen);
  refs.optionsOverlay.setAttribute("aria-hidden", state.optionsOpen ? "false" : "true");
  const databaseSelected = state.optionsSection === "database";
  const routingSelected = state.optionsSection === "routing";
  const playbackSelected = state.optionsSection === "playback";
  const diagnosticsSelected = state.optionsSection === "diagnostics";
  const audioSelected = state.optionsSection === "audio";
  const interfaceSelected = state.optionsSection === "interface";
  const windowsSelected = state.optionsSection === "windows";
  refs.optionsDatabaseTab.classList.toggle("is-selected", databaseSelected);
  refs.optionsRoutingTab.classList.toggle("is-selected", routingSelected);
  refs.optionsPlaybackTab.classList.toggle("is-selected", playbackSelected);
  refs.optionsDiagnosticsTab.classList.toggle("is-selected", diagnosticsSelected);
  refs.optionsAudioTab.classList.toggle("is-selected", audioSelected);
  refs.optionsInterfaceTab.classList.toggle("is-selected", interfaceSelected);
  refs.optionsWindowsTab.classList.toggle("is-selected", windowsSelected);
  refs.optionsInterfaceSection.classList.toggle("is-hidden", !interfaceSelected);
  refs.optionsWindowsSection.classList.toggle("is-hidden", !windowsSelected);
  refs.optionsDatabaseSection.classList.toggle("is-hidden", !databaseSelected);
  refs.optionsRoutingSection.classList.toggle("is-hidden", !routingSelected);
  refs.optionsPlaybackSection.classList.toggle("is-hidden", !playbackSelected);
  refs.optionsDiagnosticsSection.classList.toggle("is-hidden", !diagnosticsSelected);
  refs.optionsAudioSection.classList.toggle("is-hidden", !audioSelected);
  scheduleSelectionIndicators(true, SELECTION_OPTIONS);
  renderRoutingConflicts();
  if (document.activeElement !== refs.sidebarFontSizeInput) refs.sidebarFontSizeInput.value = String(state.uiFontSizePt);
  if (document.activeElement !== refs.sidebarTextColorInput) refs.sidebarTextColorInput.value = state.sidebarTextColor;
  refs.sidebarPathCountsCheckbox.checked = state.sidebarPathCounts;
  if (document.activeElement !== refs.accentColorInput) refs.accentColorInput.value = state.accentColor;
  if (refs.aacExportDirectoryPath) refs.aacExportDirectoryPath.value = state.aacExportDirectory || "";
  if (refs.aacExportStatus) refs.aacExportStatus.textContent = state.aacExportStatus || "";
  if (refs.aacExportCancelButton) refs.aacExportCancelButton.disabled = !state.aacExportInProgress;
  refs.playlistHeaderBoldCheckbox.checked = state.playlistHeaderBold;
  if (document.activeElement !== refs.spcUnknownDurationInput) refs.spcUnknownDurationInput.value = uiApp.formatTime(state.unknownDurationSeconds);
  refs.columnAutoSizeCheckbox.checked = state.columnAutoSize;
  refs.autoResizeAnimationEnabledCheckbox.checked = state.autoResizeAnimationEnabled;
  refs.animationDurationInput.value = String(state.autoResizeAnimationMilliseconds);
  refs.selectionAnimationEnabledCheckbox.checked = state.selectionAnimationEnabled;
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
  refs.libraryDatabaseLocationStatus.textContent = state.databaseLocationStatus || "ViewBoy reads this schema-24 catalog. ScanSong owns scan paths, scanning, link checks, and cleanup.";
  refs.libraryDatabaseReloadButton.disabled = Boolean(state.databaseLocation?.requiresRestart);
  refs.libraryClearCacheButton.disabled = false;
  refs.databaseCacheSummary.textContent = state.archiveCacheSummary ? formatArchiveCacheSummary(state.archiveCacheSummary) : "—";
  refs.equalizerEnabledCheckbox.checked = state.equalizerEnabled;
  refs.equalizerToolbarButton.classList.toggle("is-selected", state.equalizerEnabled);
  refs.equalizerToolbarButton.setAttribute("aria-pressed", state.equalizerEnabled ? "true" : "false");
  refs.equalizerToolbarButton.title = state.equalizerEnabled ? "Disable Equalizer" : "Enable Equalizer";
  refs.equalizerToolbarButton.setAttribute("aria-label", refs.equalizerToolbarButton.title);
  refs.monoToolbarButton.classList.toggle("is-selected", state.monoEnabled);
  refs.monoToolbarButton.setAttribute("aria-pressed", state.monoEnabled ? "true" : "false");
  refs.monoToolbarButton.title = state.monoEnabled ? "Disable Mono" : "Enable Mono";
  refs.monoToolbarButton.setAttribute("aria-label", refs.monoToolbarButton.title);
  refs.appVolumeInput.value = String(state.appVolume);
  refs.appVolumeValue.textContent = `${Math.round(state.appVolume * 100)}%`;
  const muted = state.appVolume <= 0.001;
  refs.muteToolbarButton.classList.toggle("is-selected", muted);
  refs.muteToolbarButton.setAttribute("aria-pressed", muted ? "true" : "false");
  refs.muteToolbarButton.title = muted ? "Restore Volume" : "Mute";
  refs.muteToolbarButton.setAttribute("aria-label", refs.muteToolbarButton.title);
  refs.muteToolbarIcon.setAttribute("href", muted ? "#icon-volume-off" : "#icon-volume");
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

function selectedTrackIndex() {
  return playlistIndexByID.get(state.selectedTrackId) ?? -1;
}

function scrollSelectedTrackIntoView() {
  if (!state.selectedTrackId) {
    return;
  }

  const row = playlistRowsByTrackId.get(state.selectedTrackId);
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
  if (playlistUsesVirtualRows() && !playlistRowsByTrackId.has(state.selectedTrackId)) {
    refs.playlistBodyWrap.scrollTop = Math.max(
      0,
      nextIndex * playlistVirtualRowHeight - (refs.playlistBodyWrap.clientHeight / 2)
    );
    renderPlaylist({ sort: false, persist: false, refreshIndex: false });
    selectPlaylistTrack(state.selectedTrackId, { focus: true, range, extend });
  }
  scrollSelectedTrackIntoView();
}

function selectAllPlaylistTracks() {
  if (!state.playlist.length) return;
  state.selectedTrackIds = state.playlist.map((track) => track.id);
  state.selectedTrackId = state.playlist[0].id;
  state.lastSelectedTrackId = state.selectedTrackId;
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

function setPlayTime(nextSeconds) {
  state.manualPlayTimeSeconds = uiApp.normalizeLongPlayTime(nextSeconds);
  persistSettings();
  renderAll();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
}

function setSpcForceManualTime(nextEnabled) {
  state.longPlayEnabled = Boolean(nextEnabled);
  persistSettings();
  renderAll();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
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
  const configured = await window.spcBoyWK?.configureArchiveCache?.(settings);
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

function audioSettingsPayload() {
  return {
    equalizerEnabled: state.equalizerEnabled,
    equalizerBandGains: [...state.equalizerBandGains],
    appVolume: state.appVolume,
    monoEnabled: state.monoEnabled
  };
}

function broadcastAudioSettings() {
  const settings = audioSettingsPayload();
  window.spcBoyWK?.nativePlaybackAudioConfig?.(state.appVolume, state.equalizerEnabled, state.equalizerBandGains, state.monoEnabled).catch?.(() => {});
  uiApp.playback.setAudioSettings?.(settings);
}

function setEqualizerEnabled(enabled) {
  state.equalizerEnabled = Boolean(enabled);
  persistSettings();
  broadcastAudioSettings();
  renderAll();
}

function setEqualizerBandGain(index, gain) {
  if (!state.equalizerBandGains[index]) state.equalizerBandGains[index] = 0;
  state.equalizerBandGains[index] = uiApp.normalizeEqualizerGain(gain);
  persistSettings();
  broadcastAudioSettings();
  renderAll();
}

function resetEqualizer() {
  state.equalizerBandGains = state.equalizerBandGains.map(() => 0);
  persistSettings();
  broadcastAudioSettings();
  renderAll();
}

function setAppVolume(volume) {
  state.appVolume = uiApp.normalizeAppVolume(volume);
  persistSettings();
  broadcastAudioSettings();
  renderAll();
}

function setMonoEnabled(enabled) {
  state.monoEnabled = Boolean(enabled);
  persistSettings();
  broadcastAudioSettings();
  renderAll();
}

function adjustAppVolume(delta) {
  setAppVolume(state.appVolume + Number(delta || 0));
}

function commitSpcLengthInput(rawValue) {
  const parsedSeconds = uiApp.parseDurationSeconds(rawValue);
  state.manualPlayTimeSeconds = uiApp.normalizeLongPlayTime(parsedSeconds ?? state.manualPlayTimeSeconds);
  persistSettings();
  uiApp.playback.refreshPlaybackForTimingChange().catch((error) => {
    console.error(error);
  });
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

function setFontSize(nextSize) {
  const size = uiApp.normalizeFontSize(nextSize);
  state.uiFontSizePt = size;
  state.sidebarFontSizePt = size;
  state.playlistFontSizePt = size;
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function previewFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  if (parsedValue === null) return;
  const size = uiApp.normalizeFontSize(parsedValue);
  state.uiFontSizePt = size;
  state.sidebarFontSizePt = size;
  state.playlistFontSizePt = size;
  applyUISettings();
}

function setSidebarWidth(nextWidth) {
  state.sidebarWidthPercent = uiApp.normalizeSidebarWidth(nextWidth);
  persistSettings();
  broadcastAppearanceSettings();
  renderAll();
}

function commitFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  setFontSize(parsedValue ?? state.uiFontSizePt);
}

function commitSidebarFontSizeInput(rawValue) {
  const parsedValue = uiApp.parseNumericInput(rawValue);
  setFontSize(parsedValue ?? state.uiFontSizePt);
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

function setAnimationTiming(value) {
  const milliseconds = uiApp.normalizeAnimationMilliseconds(value);
  state.autoResizeAnimationMilliseconds = milliseconds;
  state.selectionAnimationMilliseconds = milliseconds;
  persistSettings();
  renderAll();
}

function setAnimationEnabled(key, enabled) {
  state[key] = Boolean(enabled);
  persistSettings();
  renderAll();
}

function setWindowAlwaysOnTop(key, enabled) {
  window.SPCBoyOptionsController.setWindowLevel(state, key, enabled);
  persistSettings();
  renderAll();
}

function applyAppearanceSettings(settings) {
  if (settings.uiItemSpacingRem !== undefined) state.uiItemSpacingRem = uiApp.normalizeItemSpacing(settings.uiItemSpacingRem);
  if (settings.sidebarWidthPercent !== undefined) state.sidebarWidthPercent = uiApp.normalizeSidebarWidth(settings.sidebarWidthPercent);
  const interfaceFontSize = settings.uiFontSizePt ?? settings.sidebarFontSizePt ?? settings.playlistFontSizePt;
  if (interfaceFontSize !== undefined) {
    const size = uiApp.normalizeFontSize(interfaceFontSize);
    state.uiFontSizePt = size;
    state.sidebarFontSizePt = size;
    state.playlistFontSizePt = size;
  }
  const interfaceFontColor = settings.sidebarTextColor ?? settings.playlistTextColor;
  if (interfaceFontColor !== undefined) {
    const color = uiApp.normalizeFontColor(interfaceFontColor);
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
  if (settings.accentColor !== undefined) state.accentColor = uiApp.normalizeAccentColor(settings.accentColor);
  persistSettings();
  renderAll();
}

function setAccentColor(color) {
  state.accentColor = uiApp.normalizeAccentColor(color);
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

  collapsedDatabaseConsoles = new Set(state.collapsedConsoleNames);
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
  previewFontSizeInput,
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
