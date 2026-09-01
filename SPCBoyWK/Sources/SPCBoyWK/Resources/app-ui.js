(() => {
const uiApp = window.SPCBoyApp;
const { state, refs, persistSettings, loadSettings, targetPlaybackSeconds, COLUMN_DEFS } = uiApp;
const { sidebarView, searchRecords, filterSearchRecords } = window.SPCBoyDatabaseView;
const { valueForColumn, sortValue } = window.SPCBoyPlaylistTable;
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
let playlistRowMeasurementFrame = 0;

function syncCollapsedConsolePersistence() {
  state.collapsedConsoleNames = [...collapsedDatabaseConsoles];
  persistSettings();
}

function currentSidebarView() {
  return state.sidebarView;
}

function rebuildDatabaseGameSearchIndex(games = state.databaseGames) {
  databaseGameSearchRecords = searchRecords(games);
}

function localDatabaseSearch(query) {
  return filterSearchRecords(databaseGameSearchRecords, query, state.databaseGames);
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
const playlistRowsByTrackId = new Map();
let selectedPlaylistRow = null;
let currentPlaylistRow = null;
let selectionIndicatorFrame = 0;

function playlistUsesVirtualRows() {
  return state.playlist.length > PLAYLIST_VIRTUALIZATION_THRESHOLD;
}

function schedulePlaylistViewportRender() {
  if (!playlistUsesVirtualRows() || playlistViewportFrame) return;
  playlistViewportFrame = window.requestAnimationFrame(() => {
    playlistViewportFrame = 0;
    renderPlaylist({ sort: false });
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
    renderPlaylist({ sort: false });
  });
}

function makePlaylistVirtualSpacer(height) {
  const row = document.createElement("tr");
  row.className = "playlist-virtual-spacer";
  row.setAttribute("aria-hidden", "true");
  const cell = document.createElement("td");
  cell.colSpan = Math.max(1, orderedColumns().length);
  cell.style.height = `${Math.max(0, Math.round(height))}px`;
  row.appendChild(cell);
  return row;
}

refs.playlistBodyWrap?.addEventListener("scroll", schedulePlaylistViewportRender, { passive: true });

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
  databaseRowRenderGeneration += 1;
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
  positionSelectionIndicator(refs.playlistBodyWrap, refs.playlistSelectionIndicator, selectedPlaylistRow);
}

function scheduleSelectionIndicators() {
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
  if (!state.selectedBrowserPath) return;
  const button = refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`);
  button?.scrollIntoView({ block: "nearest" });
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
    const selection = await loadBrowserSelection(node);
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
    const selection = await loadBrowserSelection(node);
    if (!selection) return;
    if (generation !== browserSelectionGeneration || state.selectedBrowserPath !== node.path) return;
    applyFolderSelection(selection);
  } catch (error) {
    console.error(error);
  }
}

async function handleBrowserPrimaryClick(node) {
  await handleBrowserGesture(node, "primaryClick", state.selectedBrowserPath === node.path);
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
  if (focus) refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
  if (previewLeaf && node.kind === "file") void previewBrowserLeaf(node);
}

function visibleBrowserNodes() {
  return [...refs.treeRoot.querySelectorAll(".tree-node")]
    .map((button) => findBrowserNode(filteredTree(), button.dataset.browserPath))
    .filter(Boolean);
}

function moveBrowserSelection(delta) {
  const nodes = visibleBrowserNodes();
  if (!nodes.length) return;
  const currentIndex = nodes.findIndex((node) => node.path === state.selectedBrowserPath);
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
  const selection = await loadBrowserSelection(node);
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
  refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
}

function renderTreeNode(node, container) {
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
  databaseGameButtons = [];
  databaseEmptyState = null;
  databaseConsoleGroups = [];
  selectedBrowserButton = null;
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
    scheduleSelectionIndicators();
    return;
  }

  ensureExpandedToSelection(visibleTree);
  visibleTree.forEach((node) => renderTreeNode(node, refs.treeRoot));
  scheduleSelectionIndicators();
}

function databaseGameKey(game) {
  return `${game.rootId}\u0000${game.name}\u0000${game.system}`;
}

function databaseConsoleName(game) {
  return game.system || "Unknown Console";
}

let databaseGroupTransitionGeneration = 0;

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
    window.clearTimeout(databaseGameClickTimer);
    if (event.detail > 1) return;
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    refs.treeRoot.querySelectorAll(".database-console-row.is-selected").forEach((row) => row.classList.remove("is-selected"));
    selectedDatabaseGameButton?.classList.remove("is-selected");
    selectedDatabaseGameButton = button;
    selectedDatabaseGameButton.classList.add("is-selected");
    scheduleSelectionIndicators();
    button.focus();
    // Database game rows are final sidebar leaves. Read the indexed tracks
    // immediately; this is a database preview, not a delayed filesystem scan.
    databaseGameClickTimer = window.setTimeout(() => {
      databaseGameClickTimer = 0;
      loadDatabaseGame(game).catch((error) => reportDatabaseSidebarError("preview the selected game", error));
    }, 220);
  });
  button.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    event.stopPropagation();
    window.clearTimeout(databaseGameClickTimer);
    databaseGameClickTimer = 0;
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    loadDatabaseGame(game).then((loaded) => {
      const targetID = loaded ? databaseLoadedSelectionID() : null;
      if (targetID) return playVisibleTrack(targetID, 0);
      return undefined;
    }).catch((error) => reportDatabaseSidebarError("play the selected game", error));
  });
  button.addEventListener("dblclick", (event) => {
    event.preventDefault();
    event.stopPropagation();
    window.clearTimeout(databaseGameClickTimer);
    databaseGameClickTimer = 0;
    state.selectedDatabaseGameKey = databaseGameKey(game);
    state.selectedDatabaseConsoleName = databaseConsoleName(game);
    void applySharedDatabaseGroupAction("selectGame", state.selectedDatabaseConsoleName, state.selectedDatabaseGameKey)
      .catch((error) => reportDatabaseSidebarError("select the database game", error));
    persistSettings();
    loadDatabaseGame(game).then((loaded) => {
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
  const pendingRows = databaseConsoleGroups.flatMap(({ games, consoleName }) =>
    (groupedGames.get(consoleName) || []).map((game) => ({ games, game }))
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
    } else {
      scheduleSelectionIndicators();
    }
  };

  window.requestAnimationFrame(appendBatch);
}

function renderDatabaseGames() {
  if (state.databaseSidebarLoading) {
    renderedDatabaseGames = null;
    const indicator = resetSidebarContent();
    const loading = document.createElement("div");
    loading.className = "empty sidebar-empty sidebar-loading";
    loading.textContent = "Loading catalog…";
    refs.treeRoot.appendChild(loading);
    positionSelectionIndicator(refs.treeRoot, indicator, null);
    return;
  }
  const gamesForView = visibleDatabaseGames();
  if (renderedDatabaseGames !== gamesForView) {
    resetSidebarContent();
    selectedDatabaseGameButton = null;
    databaseConsoleGroups = [];
    const groupedGames = new Map();
    for (const game of gamesForView) {
      const consoleName = databaseConsoleName(game);
      const games = groupedGames.get(consoleName) || [];
      games.push(game);
      groupedGames.set(consoleName, games);
    }
    databaseGameButtons = [];
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
      databaseConsoleGroups.push({ group, games, consoleName });
    });

    databaseEmptyState = document.createElement("div");
    databaseEmptyState.className = "empty sidebar-empty";
    refs.treeRoot.appendChild(databaseEmptyState);
    renderedDatabaseGames = gamesForView;
    appendDatabaseGameRowsInBatches(groupedGames);
  }

  const query = state.sidebarQuery.trim();
  for (const button of databaseGameButtons) {
    button.classList.remove("is-hidden");
    button.classList.toggle("is-selected", state.selectedDatabaseGameKey === button.dataset.databaseGameKey);
    if (state.selectedDatabaseGameKey === button.dataset.databaseGameKey) selectedDatabaseGameButton = button;
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
  scheduleSelectionIndicators();
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
  state.sidebarView = Object.freeze(sidebarView(state.sidebarMode, state.sidebarQuery));
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
    dumper: row.dumper || "—",
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
      window.clearTimeout(databaseGameClickTimer);
      databaseGameClickTimer = 0;
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
  return state.columnOrder
    .map((columnId) => COLUMN_DEFS.find((column) => column.id === columnId))
    .filter(Boolean);
}

function orderedColumns() {
  return allColumns().filter((column) => state.columnVisibility[column.id]);
}

function sortPlaylist() {
  const column = COLUMN_DEFS.find((candidate) => candidate.id === state.sortColumn) || COLUMN_DEFS.find((candidate) => candidate.id === "filename");
  const direction = state.sortDirection === "descending" ? -1 : 1;
  state.playlist.sort((left, right) => {
    const leftValue = sortValue(left, column, state.rootPath);
    const rightValue = sortValue(right, column, state.rootPath);
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
  const values = [column.label, ...sample.map((track, rowIndex) => String(valueForColumn(track, column, rowIndex, state.rootPath)))];
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
  renderPlaylistHeader();
  syncPlaylistColumnWidths();
}

function renderPlaylistHeader() {
  refs.playlistHeaderRow.innerHTML = "";

  for (const column of orderedColumns()) {
    const th = document.createElement("th");
    th.dataset.columnId = column.id;
    th.draggable = true;
    th.className = column.className || "";
    th.style.width = `${state.columnWidths[column.id]}%`;
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
    td.textContent = String(valueForColumn(track, column, rowIndex, state.rootPath));
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
  row.classList.toggle("is-current", state.currentTrackId === trackId);
}

function selectPlaylistTrack(trackId, { focus = false, extend = false, range = false } = {}) {
  const track = state.playlist.find((entry) => entry.id === trackId);
  if (!track) return null;

  const previousIds = new Set(state.selectedTrackIds);
  const selection = window.SPCBoyPlaylistController.reduceSelection({
    playlist: state.playlist,
    selectedIds: state.selectedTrackIds,
    anchorId: state.playlistSelectionAnchorId
  }, trackId, { extend, range });
  if (!selection) return null;
  state.selectedTrackIds = selection.selectedIds;
  state.selectedTrackId = selection.primaryId;
  state.lastSelectedTrackId = track.id;
  state.playlistSelectionAnchorId = selection.anchorId;
  if (previousIds.size !== selection.selectedIds.length || selection.selectedIds.some((id) => !previousIds.has(id))) persistSettings();

  for (const [id, row] of playlistRowsByTrackId) updatePlaylistRowState(row, id);
  const nextRow = playlistRowsByTrackId.get(track.id) || null;
  selectedPlaylistRow = nextRow;
  scheduleSelectionIndicators();
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
  scheduleSelectionIndicators();
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
      cell.textContent = String(valueForColumn(track, column, rowIndex, state.rootPath));
    }
    cell.style.width = `${state.columnWidths[column.id]}%`;
  }
  updatePlaylistRowState(row, trackId);
  return true;
}

function playlistSortDependsOnMetadata() {
  return ["title", "game", "artist", "dumper", "system", "lengthLabel"].includes(state.sortColumn);
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

function appendPlaylistRowsInBatches(generation, startIndex = 0, endIndex = state.playlist.length, spacers = null) {
  let rowIndex = startIndex;
  const appendBatch = () => {
    if (generation !== playlistRenderGeneration) return;
    const fragment = document.createDocumentFragment();
    if (rowIndex === startIndex && spacers?.top > 0) {
      fragment.appendChild(makePlaylistVirtualSpacer(spacers.top));
    }
    const startedAt = performance.now();
    while (rowIndex < endIndex && performance.now() - startedAt < 8) {
      const track = state.playlist[rowIndex];
      const row = document.createElement("tr");
      row.dataset.trackId = track.id;
      row.tabIndex = 0;
      row.setAttribute("aria-label", `${track.title || track.filename || "Track"}`);
      row.className = `playlist-row${state.selectedTrackIds.includes(track.id) ? " is-selected" : ""}${state.currentTrackId === track.id ? " is-current" : ""}`;
      playlistRowsByTrackId.set(track.id, row);
      if (state.selectedTrackId === track.id) selectedPlaylistRow = row;
      if (state.currentTrackId === track.id) currentPlaylistRow = row;

      for (const column of orderedColumns()) {
        row.appendChild(renderPlaylistCell(track, column, rowIndex));
      }

      row.addEventListener("click", (event) => {
        const selectedTrack = selectPlaylistTrack(track.id, {
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

      fragment.appendChild(row);
      rowIndex += 1;
    }
    refs.playlistBody.appendChild(fragment);
    if (rowIndex < endIndex) {
      window.requestAnimationFrame(appendBatch);
    } else {
      if (spacers?.bottom > 0) refs.playlistBody.appendChild(makePlaylistVirtualSpacer(spacers.bottom));
      scheduleSelectionIndicators();
      schedulePlaylistRowMeasurement();
    }
  };
  window.requestAnimationFrame(appendBatch);
}

function renderPlaylist({ sort = true } = {}) {
  playlistRenderGeneration += 1;
  const generation = playlistRenderGeneration;
  if (!state.selectedTrackIds.length && state.selectedTrackId) {
    state.selectedTrackIds = [state.selectedTrackId];
  }
  const playlistIDs = new Set(state.playlist.map((track) => track.id));
  state.selectedTrackIds = state.selectedTrackIds.filter((id) => playlistIDs.has(id));
  if (state.selectedTrackId && state.selectedTrackIds.length && !state.selectedTrackIds.includes(state.selectedTrackId)) {
    state.selectedTrackId = state.selectedTrackIds.at(-1) || null;
  }
  refs.playlistBody.innerHTML = "";
  playlistRowsByTrackId.clear();
  selectedPlaylistRow = null;
  currentPlaylistRow = null;
  if (sort) sortPlaylist();
  const virtualized = playlistUsesVirtualRows();
  // Auto-sizing every cell defeats a catalog lookup. Large database playlists
  // retain the current widths; explicit column auto-size remains available.
  const playlistSignature = virtualized ? null : playlistAutoSizeSignature();
  const shouldAutoSize = !virtualized && columnResizePointerId === null
    && state.columnAutoSize
    && playlistSignature !== autoSizedPlaylistSignature;

  if (state.playlist.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = `<td colspan="${Math.max(1, orderedColumns().length)}" class="empty-row"></td>`;
    refs.playlistBody.appendChild(row);
    scheduleSelectionIndicators();
    return;
  }

  if (shouldAutoSize) {
    autoSizedPlaylistSignature = playlistSignature;
    autoSizeColumns();
    renderPlaylistHeader();
    syncPlaylistColumnWidths();
  }
  if (!virtualized) {
    appendPlaylistRowsInBatches(generation);
    return;
  }

  const scrollTop = refs.playlistBodyWrap?.scrollTop || 0;
  const viewportHeight = refs.playlistBodyWrap?.clientHeight || (playlistVirtualRowHeight * 24);
  const firstVisibleRow = Math.max(0, Math.floor(scrollTop / playlistVirtualRowHeight) - PLAYLIST_VIRTUAL_OVERSCAN);
  const lastVisibleRow = Math.min(
    state.playlist.length,
    Math.ceil((scrollTop + viewportHeight) / playlistVirtualRowHeight) + PLAYLIST_VIRTUAL_OVERSCAN
  );
  appendPlaylistRowsInBatches(
    generation,
    firstVisibleRow,
    lastVisibleRow,
    {
      top: firstVisibleRow * playlistVirtualRowHeight,
      bottom: (state.playlist.length - lastVisibleRow) * playlistVirtualRowHeight
    }
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
  rootStyle.setProperty("--app-font-family", state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--sidebar-font-size-pt", String(state.sidebarFontSizePt));
  rootStyle.setProperty("--sidebar-text-color", state.sidebarTextColor);
  rootStyle.setProperty("--sidebar-font-family", state.sidebarMonospace || state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--playlist-font-size-pt", String(state.playlistFontSizePt));
  rootStyle.setProperty("--playlist-text-color", state.playlistTextColor);
  rootStyle.setProperty("--playlist-font-family", state.playlistMonospace || state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
  rootStyle.setProperty("--playlist-header-font-weight", state.playlistHeaderBold ? "700" : "400");
  rootStyle.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
  rootStyle.setProperty("--accent", state.accentColor);
  rootStyle.setProperty("--item-spacing-rem", String(state.uiItemSpacingRem));
  rootStyle.setProperty("--column-resize-duration", `${state.autoResizeAnimationEnabled ? state.autoResizeAnimationMilliseconds : 0}ms`);
  rootStyle.setProperty("--selection-animation-duration", `${state.selectionAnimationEnabled ? state.selectionAnimationMilliseconds : 0}ms`);
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
  if (playlistUsesVirtualRows() && !playlistRowsByTrackId.has(state.selectedTrackId)) {
    refs.playlistBodyWrap.scrollTop = Math.max(
      0,
      nextIndex * playlistVirtualRowHeight - (refs.playlistBodyWrap.clientHeight / 2)
    );
    renderPlaylist({ sort: false });
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

function setAnimationTiming(key, value) {
  window.SPCBoyOptionsController.setAnimation(state, uiApp.normalizeAnimationMilliseconds, key, value);
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
