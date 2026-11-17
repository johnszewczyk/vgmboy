(() => {
  const page = document.querySelector(".spcboy-page");
  const library = document.querySelector("#spcboy-library");
  const mobileApp = document.querySelector("#spcboy-mobile-app");
  const mobileAppNav = document.querySelector("#spcboy-mobile-app-nav");
  const mobileAppButtons = [...document.querySelectorAll("[data-mobile-app-page]")];
  const mobileScreenPlaying = document.querySelector("#spcboy-mobile-screen-playing");
  const mobileScreenLibrary = document.querySelector("#spcboy-mobile-screen-library");
  const mobileScreenRecent = document.querySelector("#spcboy-mobile-screen-recent");
  const mobileScreenFavorites = document.querySelector("#spcboy-mobile-screen-favorites");
  const mobileScreenSound = document.querySelector("#spcboy-mobile-screen-sound");
  const mobileScreenNav = document.querySelector("#spcboy-mobile-screen-nav");
  const mobileScreenAdmin = document.querySelector("#spcboy-mobile-screen-admin");
  const mobileNowArtwork = document.querySelector("#spcboy-mobile-now-art");
  const mobileNowTitle = document.querySelector("#spcboy-mobile-now-title");
  const mobileNowAlbum = document.querySelector("#spcboy-mobile-now-album");
  const mobileElapsed = document.querySelector("#spcboy-mobile-elapsed");
  const mobileDuration = document.querySelector("#spcboy-mobile-duration");
  const mobilePlayButton = document.querySelector("#spcboy-mobile-play");
  const mobilePreviousButton = document.querySelector("#spcboy-mobile-previous");
  const mobileNextButton = document.querySelector("#spcboy-mobile-next");
  const mobileUpNext = document.querySelector("#spcboy-mobile-up-next");
  const mobileDock = document.querySelector("#spcboy-mobile-dock");
  const mobileDockArt = document.querySelector("#spcboy-mobile-dock-art");
  const mobileDockTitle = document.querySelector("#spcboy-mobile-dock-title");
  const mobileDockSubtitle = document.querySelector("#spcboy-mobile-dock-subtitle");
  const mobileDockPlay = document.querySelector("#spcboy-mobile-dock-play");
  const mobileDockProgressFill = document.querySelector("#spcboy-mobile-dock-progress-fill");
  const mobileToast = document.querySelector("#spcboy-mobile-toast");
  const drawerSettingsPages = document.querySelector("#drawer-options .spcboy-settings-pages");
  const audioSettingsPage = document.querySelector("#spcboy-settings-page-audio");
  const playbackSettingsPage = document.querySelector("#spcboy-settings-page-playback");
  const interfaceSettingsPage = document.querySelector("#spcboy-settings-page-interface");
  const trackList = document.querySelector("#spcboy-library-tracks");
  const playlistContent = document.querySelector("#spcboy-playlist-content");
  const playlistEmpty = document.querySelector("#spcboy-playlist-empty");
  const cardPanel = document.querySelector("#spcboy-card-panel");
  const cardList = document.querySelector("#spcboy-card-list");
  const cardEmpty = document.querySelector("#spcboy-card-empty");
  const recentMore = document.querySelector("#spcboy-recent-more");
  const shuffleFavoritesButton = document.querySelector("#spcboy-shuffle-favorites");
  const favoriteMore = document.querySelector("#spcboy-favorite-more");
  if (!page || !library) return;

  const search = document.querySelector("#spcboy-search");
  const empty = document.querySelector("#spcboy-empty");
  const libraryState = document.querySelector("#spcboy-library-state");
  document.querySelector("#site-player")?.prepend(libraryState);
  const loadingNotice = document.querySelector("#spcboy-library-loading");
  const loadingMessage = document.querySelector("#spcboy-loading-message");
  const loadingProgress = document.querySelector("#spcboy-loading-progress");
  const playerState = document.querySelector("#spcboy-player-state");
  const audio = document.querySelector("#spcboy-audio");
  const playButton = document.querySelector("#spcboy-play");
  const previousButton = document.querySelector("#spcboy-previous");
  const nextButton = document.querySelector("#spcboy-next");
  const tabs = [...document.querySelectorAll(".spcboy-tabs [data-view]")];
  const tabsNav = document.querySelector(".spcboy-tabs");
  const tabsIndicator = document.querySelector(".spcboy-tabs-indicator");
  const foldAllButton = document.querySelector("#spcboy-fold-all");
  const sidebarIndicator = document.querySelector(".spcboy-sidebar-indicator");
  const playlistPane = document.querySelector("#spcboy-playlist-pane");
  const playlistIndicator = document.querySelector(".spcboy-playlist-indicator");
  const playlistColumnHead = document.querySelector(".spcboy-column-head");
  const playlistColumnHeadCells = playlistColumnHead?.querySelector(".spcboy-column-head > div");
  const playlistColumnControls = [...document.querySelectorAll("[data-spcboy-column]")];
  const PLAYLIST_COLUMN_DEFAULTS = Object.freeze({
    favorite: true,
    index: true,
    title: true,
    game: true,
    artist: true,
    system: true,
    year: true,
    dumper: true,
    timestamp: true,
    length: true,
  });
  const PLAYLIST_COLUMN_DEFINITIONS = Object.freeze([
    { id: "index", label: "#", weight: 0.15 },
    { id: "title", label: "TITLE", weight: 1.45 },
    { id: "game", label: "GAME", weight: 1.05 },
    { id: "artist", label: "ARTIST", weight: 1.0 },
    { id: "system", label: "SYSTEM", weight: 0.78 },
    { id: "year", label: "YEAR", weight: 0.25 },
    { id: "dumper", label: "DUMPER", weight: 1.0 },
    { id: "timestamp", label: "DATE/TIME", weight: 1.0 },
    { id: "length", label: "LENGTH", weight: 0.1 },
  ]);
  const storage = {
    get(key, fallback) {
      return window.SBOProfileStorage?.get("library", key, fallback) ?? fallback;
    },
    set(key, value) {
      window.SBOProfileStorage?.set("library", key, value);
    },
    remove(key) {
      window.SBOProfileStorage?.remove("library", key);
    },
  };
  function normalizePlaylistColumnVisibility(value) {
    const normalized = { ...PLAYLIST_COLUMN_DEFAULTS };
    if (value && typeof value === "object" && !Array.isArray(value)) {
      for (const id of Object.keys(PLAYLIST_COLUMN_DEFAULTS)) {
        if (typeof value[id] === "boolean") normalized[id] = value[id];
      }
    }
    normalized.title = true;
    return normalized;
  }
  const playlistColumnVisibility = normalizePlaylistColumnVisibility(storage.get("columnVisibility", null));
  const columnIds = PLAYLIST_COLUMN_DEFINITIONS.map(column => column.id);
  const savedOrder = storage.get('columnOrder', []);
  let playlistColumnOrder = [...new Set([...(Array.isArray(savedOrder) ? savedOrder.filter(id => columnIds.includes(id)) : []), ...columnIds])];
  let playlistColumnWidths = storage.get('columnWidths', {});
  if (!playlistColumnWidths || typeof playlistColumnWidths !== 'object' || Array.isArray(playlistColumnWidths)) playlistColumnWidths = {};
  let playlistColumnLayoutFrame = 0;
  let playlistColumnResize = null;
  const favorites = new Set(storage.get("favorites", []));
  const favoriteAlbums = new Set(storage.get("favoriteAlbums", []));
  let tracks = [];
  const tracksById = new Map();
  const trackIndexById = new Map();
  const trackRowsById = new Map();
  const searchOpenedSystems = new Set();
  const gameGroups = [];
  const systemRecords = [];
  const systemRecordByEl = new Map();
  const materializedPlaylistEntries = new Set();
  const gameGroupsByKey = new Map();
  const gameGroupsByAlbumId = new Map();
  const gameGroupsByConsoleGame = new Map();
  let recentEntries = [];
  let collectionSidebarView = null;
  const recentHiddenEventIds = new Set();
  let recentNextPage = 1;
  let recentLoadedPageCount = 0;
  let recentLoading = false;
  let recentLoaded = false;
  let recentFailed = false;
  let recentRefreshedPlaybackId = null;
  let favoritePlaylistTracks = [];
  let favoritePlaylistLoaded = false;
  let favoritePlaylistNextPage = 1;
  let favoritePlaylistLoading = false;
  let favoritePlaylistFailed = false;
  let favoritePlaylistPromise = null;
  let rawCatalog = null;
  let catalogLoaded = false;
  let catalogAvailable = false;
  let catalogLoadingPhase = "idle";
  let catalogLoadingStartedAt = 0;
  let catalogLoadingTimer = null;
  let resolveCatalogReady;
  const catalogReady = new Promise((resolve) => { resolveCatalogReady = resolve; });
  let currentTrack = null;
  let lastPlayerTrackId = window.SitePlayer?.getCurrentTrack?.()?.id || null;
  let playbackSelectionToken = 0;
  let pendingSelectionToken = 0;
  let currentPlaybackId = null;
  let announcedPlaybackId = null;
  let streamOffsetSeconds = 0;
  const savedView = storage.get("view", "all");
  let view = ["all", "favorites", "recent"].includes(savedView) ? savedView : "all";
  let mobileAppPage = "playing";
  function syncWorkspaceHeading(name) {
    const viewLabel = ({ all: "Library", favorites: "Favorites", recent: "Recent" })[view] || "Library";
    const heading = document.querySelector("#sbonline-playlist-title");
    if (heading) heading.textContent = name || viewLabel;
    const context = document.querySelector("#sbonline-context");
    if (context) context.textContent = viewLabel;
  }
  function syncViewButtons() {
    syncWorkspaceHeading();
    const workspaceToolbar = document.querySelector('.sbonline-playlist-heading');
    const stage = document.querySelector('#spcboy-stage');
    const mobile = window.matchMedia('(max-width:780px)').matches;
    if (workspaceToolbar && stage) {
      if (mobile && workspaceToolbar.parentElement !== library) library.insertBefore(workspaceToolbar,stage);
      else if (!mobile && workspaceToolbar.parentElement !== stage) stage.prepend(workspaceToolbar);
    }
    for (const tab of tabs) {
      const selected = tab.dataset.view === view;
      tab.classList.toggle("is-active", selected);
      tab.setAttribute("aria-pressed", String(selected));
    }
  }
  let selectedGameKey = null;
  let nowPlayingTimer = null;
  const desktopLayout = window.matchMedia("(min-width: 781px)");
  let selectionIndicatorFrame = 0;
  let lastPlaylistIndicatorTrackId = null;
  let hoveredSidebarItem = null;
  let hoveredPlaylistRow = null;
  let cardSwipeReady = false;
  let favoritesChangedExternally = false;
  document.addEventListener('site:favorites-updated', event => {
    const result = event.detail || {};
    const changedTrackIDs = new Set();
    const changedAlbumIDs = new Set();
    const fullUpdate = Array.isArray(result.trackIds) && Array.isArray(result.albumIds);
    if (fullUpdate) {
      const nextTracks = new Set(result.trackIds);
      const nextAlbums = new Set(result.albumIds);
      for (const id of favorites) if (!nextTracks.has(id)) changedTrackIDs.add(id);
      for (const id of nextTracks) if (!favorites.has(id)) changedTrackIDs.add(id);
      for (const id of favoriteAlbums) if (!nextAlbums.has(id)) changedAlbumIDs.add(id);
      for (const id of nextAlbums) if (!favoriteAlbums.has(id)) changedAlbumIDs.add(id);
      favorites.clear();
      nextTracks.forEach(id => favorites.add(id));
      favoriteAlbums.clear();
      nextAlbums.forEach(id => favoriteAlbums.add(id));
    } else if (typeof result.trackId === "string" && typeof result.favorite === "boolean") {
      changedTrackIDs.add(result.trackId);
      result.favorite ? favorites.add(result.trackId) : favorites.delete(result.trackId);
    } else if (typeof result.albumId === "string" && typeof result.favorite === "boolean") {
      changedAlbumIDs.add(result.albumId);
      result.favorite ? favoriteAlbums.add(result.albumId) : favoriteAlbums.delete(result.albumId);
    } else {
      return;
    }
    resetFavoritePlaylist();
    if (fullUpdate) {
      for (const button of document.querySelectorAll("[data-site-favorite-toggle]")) {
        const id = button.dataset.favoriteId;
        if (button.dataset.favoriteKind === "album") setAlbumFavoriteButton(button, favoriteAlbums.has(id));
        else setTrackFavoriteButton(button, favorites.has(id));
      }
    } else {
      for (const id of changedTrackIDs) syncFavorite(null, id);
      for (const id of changedAlbumIDs) syncAlbumFavorite(null, id);
    }
    favoritesChangedExternally = true;
    if (page.isConnected) {
      favoritesChangedExternally = false;
      if (view === "favorites") loadFavoritePlaylist();
      else if (!isDesktop()) loadFavoritePlaylist({ allPages: true }).then(() => { if (!isDesktop()) renderMobileFavorites(); }).catch(() => {});
      applyFilters();
    }
  });
  const headerSearch = document.querySelector('#mobile-header-search-input');
  let headerSearchReady = false;
  let pendingHeaderSearch = null;
  function applyHeaderSearch() {
    if (!page.isConnected || !headerSearchReady || !pendingHeaderSearch) return;
    const { query, all } = pendingHeaderSearch; pendingHeaderSearch = null;
    if (all) { view = 'all'; storage.set('view',view); syncViewButtons(); }
    search.value = query; if (headerSearch) headerSearch.value = query;
    scheduleCatalogSearch();
  }
  document.addEventListener('site:player-search', event => {
    if (!page.isConnected) return;
    pendingHeaderSearch = event.detail; applyHeaderSearch();
  });
  headerSearch?.addEventListener('input', () => {
    if (!page.isConnected || isDesktop()) return;
    pendingHeaderSearch = {query:headerSearch.value,all:false}; applyHeaderSearch();
  });
  document.addEventListener('site:navigated', () => {
    if (page.isConnected && headerSearch) headerSearch.value = search.value;
    if(page.isConnected&&favoritesChangedExternally){favoritesChangedExternally=false;if(view==='favorites')loadFavoritePlaylist();applyFilters();}
  });

  function isDesktop() {
    return desktopLayout.matches;
  }

  function placeMobileSettingsPages() {
    // Mobile uses its own dedicated markup in spcboy_mobile_shell.html;
    // desktop settings pages permanently remain in #drawer-options.
  }

  function applyPlaylistColumnVisibility() {
    for (const [id, visible] of Object.entries(playlistColumnVisibility)) {
      library.classList.toggle(`is-column-hidden-${id}`, !visible);
      for (const cell of playlistContent.querySelectorAll(`[data-column="${id}"]`)) cell.hidden = !visible;
      for (const cell of playlistColumnHead?.querySelectorAll(`[data-column="${id}"]`) || []) cell.hidden = !visible;
      for (const cell of cardList.querySelectorAll(`[data-column="${id}"]`)) cell.hidden = !visible;
    }
    for (const card of cardList.querySelectorAll(".spcboy-media-card")) applyMediaCardColumns(card);
    if (playlistColumnHead) {
      playlistColumnHead.style.gridTemplateColumns = playlistColumnVisibility.favorite
        ? "var(--sb-control) minmax(0, 1fr)"
        : "0 minmax(0, 1fr)";
    }
    for (const control of playlistColumnControls) {
      control.checked = playlistColumnVisibility[control.dataset.spcboyColumn] !== false;
    }
    schedulePlaylistColumnLayout();
  }

  function applyPlaylistColumnVisibilityToRow(row) {
    for (const [id, visible] of Object.entries(playlistColumnVisibility)) {
      for (const cell of row.querySelectorAll(`[data-column="${id}"]`)) cell.hidden = !visible;
    }
    const favorite = row.querySelector(".spcboy-favorite");
    if (favorite) favorite.hidden = !playlistColumnVisibility.favorite;
    for (const cell of row.querySelectorAll('.spcboy-track > [data-column]')) {
      cell.style.order = String(playlistColumnOrder.indexOf(cell.dataset.column));
    }
  }

  function applyMediaCardColumns(card) {
    for (const [id, visible] of Object.entries(playlistColumnVisibility)) {
      for (const cell of card.querySelectorAll(`[data-column="${id}"]`)) cell.hidden = !visible;
    }
    const game = card.querySelector('[data-column="game"]');
    const system = card.querySelector('[data-column="system"]');
    const separator = card.querySelector(".spcboy-media-card-separator");
    if (separator) separator.hidden = !game || !system || game.hidden || system.hidden;
  }

  function measurePlaylistColumnText(element, text) {
    return window.SBPresentation.measureText(text, getComputedStyle(element));
  }

  function updatePlaylistColumnLayout() {
    playlistColumnLayoutFrame = 0;
    if (!page.isConnected || !isDesktop() || playlistPane.hidden || !playlistColumnHeadCells) return;
    const rows = [...playlistContent.querySelectorAll('.spcboy-track-row .spcboy-track')]
      .filter(row => row.getClientRects().length);
    const definitions = playlistColumnOrder.map(id => PLAYLIST_COLUMN_DEFINITIONS.find(column => column.id === id));
    // Empty metadata is hidden for this playlist, without changing saved choices.
    const columns = definitions.filter(column => {
      const preserveEmptyHeading = column.id === 'index'
        || (column.id === 'timestamp' && (view === 'favorites' || view === 'recent'));
      const populated = !rows.length || preserveEmptyHeading
        || rows.some(row => {
          const value = row.querySelector(`[data-column="${column.id}"]`)?.textContent.trim();
          return value && value !== '—' && value !== '-';
        });
      const visible = playlistColumnVisibility[column.id] && populated;
      playlistColumnHeadCells.querySelector(`[data-column="${column.id}"]`).hidden = !visible;
      for (const row of rows) row.querySelector(`[data-column="${column.id}"]`).hidden = !visible;
      return visible;
    });
    const gap = parseFloat(getComputedStyle(playlistColumnHeadCells).columnGap) || 0;
    const inset = parseFloat(getComputedStyle(playlistContent).paddingLeft) || 0;
    const favoriteWidth = playlistColumnVisibility.favorite
      ? playlistColumnHead.querySelector('[data-column="favorite"]').getBoundingClientRect().width : 0;
    const available = Math.max(0, playlistContent.clientWidth - 2*inset - favoriteWidth - 2*gap);
    const columnSpace = Math.max(0, available - gap*(columns.length-1));
    const minimums = columns.map(column => {
      const header = playlistColumnHeadCells.querySelector(`[data-column="${column.id}"]`);
      return Math.ceil(Math.max(column.id === 'index' ? header.getBoundingClientRect().height : 0,
        measurePlaylistColumnText(header, header.dataset.label || column.label) + 2*gap + 1));
    });
    const savedWidths = columns.map(column => Number(playlistColumnWidths[column.id]));
    const hasSavedWidth = savedWidths.map(width => Number.isFinite(width) && width > 0);
    const allWidthsSaved = hasSavedWidth.every(Boolean);
    const preferences = columns.map((column, index) => allWidthsSaved
      ? Math.max(1, savedWidths[index] - minimums[index]) : column.weight);
    const flexibleIndices = columns.map((_column, index) => index).filter(index => allWidthsSaved || !hasSavedWidth[index]);
    const pinnedWidth = columns.reduce((sum, _column, index) =>
      sum + (hasSavedWidth[index] && !allWidthsSaved ? Math.max(minimums[index], savedWidths[index]) : 0), 0);
    const flexibleSpace = Math.max(0, columnSpace - pinnedWidth
      - minimums.reduce((sum, minimum, index) => sum + (flexibleIndices.includes(index) ? minimum : 0), 0));
    const totalPreference = flexibleIndices.reduce((sum, index) => sum + preferences[index], 0);
    const widths = columns.map((column, index) => {
      if (hasSavedWidth[index] && !allWidthsSaved) return Math.max(minimums[index], savedWidths[index]);
      return minimums[index] + (totalPreference ? flexibleSpace*preferences[index]/totalPreference : 0);
    });
    // Saved manual widths retain their proportions while following viewport changes.
    library.style.setProperty('--sb-column-template', widths.map(width => `${width}px`).join(' '));
    const total = widths.reduce((sum, width) => sum + width, 0) + gap*(columns.length-1) + favoriteWidth + 2*gap + 2*inset;
    library.style.setProperty('--sb-playlist-width', `${Math.ceil(total)}px`);
    // Reordering hidden columns must not leave gaps or disturb saved ordering.
    for (const row of rows) for (const cell of row.querySelectorAll('[data-column]')) {
      cell.style.order = String(playlistColumnOrder.indexOf(cell.dataset.column));
    }
    syncPlaylistHeaderScroll();
  }
  function syncPlaylistHeaderScroll() {
    if (playlistColumnHead && isDesktop()) playlistColumnHead.style.transform = `translateX(${-playlistContent.scrollLeft}px)`;
  }

  function schedulePlaylistColumnLayout() {
    if (playlistColumnLayoutFrame) return;
    playlistColumnLayoutFrame = window.requestAnimationFrame(updatePlaylistColumnLayout);
  }

  function savePlaylistColumnSettings() {
    storage.set("columnVisibility", playlistColumnVisibility);
    storage.set("columnOrder", playlistColumnOrder);
    storage.set("columnWidths", playlistColumnWidths);
    schedulePlaylistColumnLayout();
  }

  function beginPlaylistColumnResize(event, header) {
    if (!isDesktop() || event.button !== 0 || playlistColumnResize) return;
    event.preventDefault(); event.stopPropagation();
    const cells = [...playlistColumnHeadCells.querySelectorAll('[data-column]')].filter(cell => !cell.hidden);
    const start = event.clientX, id = header.dataset.column, pointerId = event.pointerId;
    const widths = new Map(cells.map(cell => [cell.dataset.column, cell.getBoundingClientRect().width]));
    const minimums = new Map(cells.map(cell => [cell.dataset.column, Math.ceil(Math.max(cell.dataset.column === "index" ? cell.getBoundingClientRect().height : 0, measurePlaylistColumnText(cell, cell.dataset.label) + 1 + 2*(parseFloat(getComputedStyle(playlistColumnHeadCells).columnGap)||0)))]));
    const others = cells.filter(cell => cell !== header).map(cell => cell.dataset.column);
    const total = [...widths.values()].reduce((sum, width) => sum + width, 0);
    const minimumOther = others.reduce((sum, key) => sum + minimums.get(key), 0);
    for (const [key, width] of widths) playlistColumnWidths[key] = width;
    const handle = event.currentTarget;
    handle.setPointerCapture(pointerId);
    const extras = others.map(key => Math.max(0, widths.get(key) - minimums.get(key)));
    const extraTotal = extras.reduce((sum, value) => sum + value, 0);
    let lastX = start;
    const move = e => {
      if (e.pointerId !== pointerId) return;
      if (Number.isFinite(e.clientX)) lastX = e.clientX;
      const width = Math.max(minimums.get(id), Math.min(total - minimumOther, widths.get(id) + lastX - start));
      playlistColumnWidths[id] = width;
      const remaining = Math.max(0, total - width - minimumOther);
      others.forEach((key, index) => playlistColumnWidths[key] = minimums.get(key) + remaining*(extraTotal ? extras[index]/extraTotal : 1/others.length));
      schedulePlaylistColumnLayout();
    };
    const finish = e => {
      if (e.pointerId !== pointerId || !playlistColumnResize) return;
      if (e.type === 'pointerup') move(e);
      playlistColumnResize = null;
      handle.removeEventListener('pointermove', move);
      handle.removeEventListener('pointerup', finish);
      handle.removeEventListener('pointercancel', finish);
      handle.removeEventListener('lostpointercapture', finish);
      if (handle.hasPointerCapture(pointerId)) handle.releasePointerCapture(pointerId);
      applyPlaylistColumnVisibility(); savePlaylistColumnSettings();
    };
    playlistColumnResize = { pointerId };
    handle.addEventListener('pointermove', move);
    handle.addEventListener('pointerup', finish);
    handle.addEventListener('pointercancel', finish);
    handle.addEventListener('lostpointercapture', finish);
  }

  if (playlistColumnHeadCells) {
    for (const id of playlistColumnOrder) {
      const header = playlistColumnHeadCells.querySelector(`[data-column="${id}"]`);
      if (!header) continue;
      header.dataset.label = header.textContent;
      header.draggable = true;
      header.tabIndex = 0;
      header.setAttribute('role', 'columnheader');
      const handle = document.createElement('span');
      handle.className = 'sb-column-handle';
      handle.title = `Resize ${header.textContent}`;
      handle.addEventListener('pointerdown', event => beginPlaylistColumnResize(event, header));
      header.append(handle); playlistColumnHeadCells.append(header);
    }
    window.SBPresentation.columns(playlistColumnHeadCells, {
      selector: '[data-column]', key: cell => cell.dataset.column,
      preview(order) {
        playlistColumnOrder = order;
        for (const row of playlistContent.querySelectorAll('.spcboy-track-row')) applyPlaylistColumnVisibilityToRow(row);
        schedulePlaylistColumnLayout();
      },
      commit() { savePlaylistColumnSettings(); }
    });
  }
  applyPlaylistColumnVisibility();

  function beginCatalogLoading() {
    if (!loadingNotice || !loadingMessage) return;
    loadingNotice.hidden = false;
    loadingNotice.dataset.loadingType = "catalog";
    loadingNotice.classList.remove("is-error");
    loadingProgress.hidden = true;
    loadingProgress.value = 0;
    catalogLoadingPhase = "fetch";
    catalogLoadingStartedAt = performance.now();
    const updateElapsed = () => {
      if (catalogLoadingPhase !== "fetch") return;
      const seconds = Math.floor((performance.now() - catalogLoadingStartedAt) / 1000);
      loadingMessage.textContent = `Fetching library catalog · ${seconds}s`;
    };
    updateElapsed();
    window.clearInterval(catalogLoadingTimer);
    catalogLoadingTimer = window.setInterval(updateElapsed, 1000);
    library.setAttribute("aria-busy", "true");
  }

  function updateCatalogBuildProgress(completed, total) {
    if (!loadingMessage || !loadingProgress) return;
    catalogLoadingPhase = "build";
    loadingMessage.textContent = `Building library · ${completed.toLocaleString()} / ${total.toLocaleString()} games`;
    loadingProgress.max = Math.max(total, 1);
    loadingProgress.value = completed;
    loadingProgress.hidden = false;
  }

  function setCatalogFinishing() {
    catalogLoadingPhase = "build";
    loadingMessage.textContent = "Applying library views…";
    loadingProgress.hidden = true;
  }

  function finishCatalogLoading(errorMessage = "") {
    window.clearInterval(catalogLoadingTimer);
    catalogLoadingTimer = null;
    catalogLoadingPhase = errorMessage ? "error" : "done";
    library.removeAttribute("aria-busy");
    if (!loadingNotice) return;
    if (errorMessage) {
      loadingNotice.classList.add("is-error");
      loadingProgress.hidden = true;
      loadingMessage.textContent = errorMessage;
      loadingNotice.hidden = false;
    } else {
      loadingNotice.hidden = true;
      delete loadingNotice.dataset.loadingType;
    }
  }

  function positionSelectionIndicators() {
    selectionIndicatorFrame = 0;
    if (!page.isConnected) return;
    const activeTab = tabs.find((tab) => tab.classList.contains("is-active"));
    if (activeTab && tabsNav && tabsIndicator) {
      const navRect = tabsNav.getBoundingClientRect();
      const tabRect = activeTab.getBoundingClientRect();
      tabsIndicator.style.width = `${tabRect.width}px`;
      tabsIndicator.style.transform = `translate3d(${tabRect.left - navRect.left}px, 0, 0)`;
    }

    if (!isDesktop()) {
      hoveredSidebarItem = null;
      hoveredPlaylistRow = null;
      if (sidebarIndicator) sidebarIndicator.style.opacity = "0";
      if (playlistIndicator) playlistIndicator.style.opacity = "0";
      lastPlaylistIndicatorTrackId = null;
      return;
    }

    const selectedSummary = trackList.querySelector(".spcboy-game-row:not([hidden]) .spcboy-game.is-selected > summary");
    const selectedSidebarItem = isDesktop() && hoveredSidebarItem?.isConnected && hoveredSidebarItem.getClientRects().length
      ? hoveredSidebarItem
      : !isDesktop()
      ? trackList.querySelector('.spcboy-track[aria-current="true"]:not([hidden])') || selectedSummary
      : selectedSummary;
    if (selectedSidebarItem && sidebarIndicator) {
      const treeRect = document.querySelector(".spcboy-tree").getBoundingClientRect();
      const itemRect = selectedSidebarItem.getBoundingClientRect();
      if (treeRect.width && treeRect.height && itemRect.bottom > treeRect.top && itemRect.top < treeRect.bottom) {
        sidebarIndicator.style.width = `${itemRect.width}px`;
        sidebarIndicator.style.height = `${itemRect.height}px`;
        sidebarIndicator.style.transform = `translate3d(${itemRect.left - treeRect.left}px, ${itemRect.top - treeRect.top + document.querySelector(".spcboy-tree").scrollTop}px, 0)`;
        sidebarIndicator.style.opacity = "1";
      } else sidebarIndicator.style.opacity = "0";
    } else if (sidebarIndicator) sidebarIndicator.style.opacity = "0";

    const selectedTrack = playlistContent.querySelector('.spcboy-track[aria-current="true"]');
    const activeTrack = isDesktop() && hoveredPlaylistRow?.isConnected && hoveredPlaylistRow.getClientRects().length
      ? hoveredPlaylistRow.querySelector(".spcboy-track")
      : selectedTrack;
    if (activeTrack && playlistPane && playlistIndicator && !playlistPane.hidden) {
      const paneRect = playlistPane.getBoundingClientRect();
      const trackRect = (activeTrack.closest(".spcboy-track-row") || activeTrack).getBoundingClientRect();
      if (paneRect.width && paneRect.height && trackRect.bottom > paneRect.top && trackRect.top < paneRect.bottom) {
        if (isDesktop() && currentTrack?.id && currentTrack.id !== lastPlaylistIndicatorTrackId) {
          playlistIndicator.classList.remove("is-select-fading");
          void playlistIndicator.offsetWidth;
          playlistIndicator.classList.add("is-select-fading");
        }
        lastPlaylistIndicatorTrackId = currentTrack?.id ?? null;
        playlistIndicator.style.width = `${trackRect.width}px`;
        playlistIndicator.style.height = `${trackRect.height}px`;
        playlistIndicator.style.transform = `translate3d(${trackRect.left - paneRect.left}px, ${trackRect.top - paneRect.top}px, 0)`;
        playlistIndicator.style.opacity = "1";
      } else {
        lastPlaylistIndicatorTrackId = null;
        playlistIndicator.style.opacity = "0";
      }
    } else if (playlistIndicator) {
      lastPlaylistIndicatorTrackId = null;
      playlistIndicator.style.opacity = "0";
    }
  }

  function scheduleSelectionIndicators() {
    if (selectionIndicatorFrame) return;
    selectionIndicatorFrame = window.requestAnimationFrame(positionSelectionIndicators);
  }

  function formatTime(seconds) {
    if (seconds === Infinity) return "∞";
    if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
    const whole = Math.floor(seconds);
    const hours = Math.floor(whole / 3600);
    const minutes = Math.floor((whole % 3600) / 60);
    const remainder = String(whole % 60).padStart(2, "0");
    return hours ? `${hours}:${String(minutes).padStart(2, "0")}:${remainder}` : `${minutes}:${remainder}`;
  }

  function canonicalDuration(track) {
    const seconds = Number(track?.durationSeconds);
    return Number.isFinite(seconds) && seconds > 0 ? seconds : 0;
  }

  function normalizeSearchText(value) {
    return String(value ?? "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/ß/g, "ss");
  }

  function canonicalConsoleName(value) {
    const name = String(value ?? "").trim();
    return ({
      "Game Boy Mono": "Nintendo Game Boy",
      "Nintendo Entertainment System": "Nintendo NES",
      "Super Nintendo": "Nintendo SNES",
    })[name] ?? name;
  }

  function gameCountLabel(count) {
    const games = `${count.toLocaleString()} ${count === 1 ? "game" : "games"}`;
    if (count !== gameGroups.length) return games;
    const trackCount = gameGroups.reduce((total, entry) => total + entry.trackCount, 0);
    return `${games} · ${trackCount.toLocaleString()} tracks`;
  }

  function searchTerms(value) {
    return normalizeSearchText(value).match(/[\p{L}\p{N}]+/gu) ?? [];
  }

  function matchesSearchText(value, query) {
    const haystack = normalizeSearchText(value);
    const terms = searchTerms(query);
    return terms.length > 0 && terms.every((term) => haystack.includes(term));
  }

  function matchesTrackQuery(track, query) {
    if (!query) return true;
    return matchesSearchText(track?.game ?? "", query);
  }

  function placeSearchMore() {
    const favoriteDestination = view === "favorites" && isDesktop() ? playlistContent : cardPanel;
    const recentDestination = view === "recent" && isDesktop() ? playlistContent : cardPanel;
    if (recentMore.parentElement !== recentDestination) recentDestination.append(recentMore);
    if (favoriteMore && favoriteMore.parentElement !== favoriteDestination) favoriteDestination.append(favoriteMore);
  }

  function makeDetails(className, label, count, open = false) {
    const details = document.createElement("details");
    details.className = className;
    details.open = open;
    const summary = document.createElement("summary");
    const name = document.createElement("span");
    name.className = className === "spcboy-system" ? "spcboy-system-name" : "spcboy-game-name";
    name.textContent = label;
    const countNode = document.createElement("span");
    countNode.className = "spcboy-count";
    countNode.textContent = String(count);
    countNode.dataset.totalCount = String(count);
    summary.append(name, countNode);
    details.append(summary);
    return details;
  }

  function setupCardSwipe() {
    if (cardSwipeReady || !cardList) return;
    cardSwipeReady = true;
    let start = null;
    let clearSuppressedClick = 0;
    let clearSwipeHint = 0;
    cardList.addEventListener("pointerdown", (event) => {
      const target = event.target instanceof Element ? event.target : null;
      const card = target?.closest(".spcboy-media-card");
      if (!card || event.pointerType !== "touch" || !event.isPrimary || isDesktop()
        || !["recent", "favorites"].includes(view)) return;
      const action = view === "recent"
        ? card.querySelector(".spcboy-card-remove")
        : card.classList.contains("is-favorite-removable")
          ? card.querySelector(".spcboy-media-card-favorite")
          : null;
      if (!action) return;
      if (target.closest(".spcboy-card-remove, .spcboy-media-card-favorite")) {
        delete card.dataset.suppressSwipeClick;
        window.clearTimeout(clearSuppressedClick);
        return;
      }
      const width = action.getBoundingClientRect().width || 64;
      const baseOffset = card.classList.contains("is-swipe-revealed") ? -width : 0;
      start = { card, x: event.clientX, y: event.clientY, pointerId: event.pointerId, width, baseOffset };
      if (card.classList.contains("is-favorite-removable") && baseOffset === 0) {
        window.clearTimeout(clearSwipeHint);
        cardList.querySelectorAll(".spcboy-media-card.is-swipe-hint").forEach((other) => other.classList.remove("is-swipe-hint"));
        card.classList.add("is-swipe-hint");
        clearSwipeHint = window.setTimeout(() => card.classList.remove("is-swipe-hint"), 260);
      }
    }, { passive: true });
    window.addEventListener("pointermove", (event) => {
      if (!start || event.pointerId !== start.pointerId) return;
      const deltaX = event.clientX - start.x;
      const deltaY = event.clientY - start.y;
      const horizontalDistance = Math.abs(deltaX);
      const verticalDistance = Math.abs(deltaY);
      if (verticalDistance >= 8 && verticalDistance > horizontalDistance * 1.25) {
        window.clearTimeout(clearSwipeHint);
        start.card.classList.remove("is-swipe-hint", "is-swipe-dragging");
        start.card.style.removeProperty("--favorite-swipe-offset");
        start = null;
        return;
      }
      if (horizontalDistance === 0) return;
      window.clearTimeout(clearSwipeHint);
      start.card.classList.remove("is-swipe-hint");
      start.card.classList.add("is-swipe-dragging");
      const offset = Math.max(-start.width, Math.min(0, start.baseOffset + deltaX));
      start.card.style.setProperty("--favorite-swipe-offset", `${offset}px`);
    }, { passive: true });
    window.addEventListener("pointerup", (event) => {
      if (!start || event.pointerId !== start.pointerId) return;
      const { card, width, baseOffset } = start;
      const deltaX = event.clientX - start.x;
      const deltaY = event.clientY - start.y;
      start = null;
      card.classList.remove("is-swipe-dragging");
      card.style.removeProperty("--favorite-swipe-offset");
      if (!card.isConnected || Math.abs(deltaX) < 8 || Math.abs(deltaX) < Math.abs(deltaY) * 1.25) return;
      const offset = Math.max(-width, Math.min(0, baseOffset + deltaX));
      if (offset <= -(width * 0.45)) {
        card.parentElement?.querySelectorAll(".spcboy-media-card.is-swipe-revealed").forEach((other) => {
          if (other !== card) other.classList.remove("is-swipe-revealed");
        });
        card.classList.add("is-swipe-revealed");
      } else {
        card.classList.remove("is-swipe-revealed");
      }
      if (Math.abs(deltaX) < 8) return;
      card.dataset.suppressSwipeClick = "true";
      window.clearTimeout(clearSuppressedClick);
      clearSuppressedClick = window.setTimeout(() => delete card.dataset.suppressSwipeClick, 250);
    }, { passive: true });
    window.addEventListener("pointercancel", (event) => {
      if (!start || event.pointerId !== start.pointerId) return;
      window.clearTimeout(clearSwipeHint);
      start.card.classList.remove("is-swipe-hint", "is-swipe-dragging");
      start.card.style.removeProperty("--favorite-swipe-offset");
      start = null;
    }, { passive: true });
    cardList.addEventListener("click", (event) => {
      const card = event.target instanceof Element ? event.target.closest(".spcboy-media-card") : null;
      if (card?.dataset.suppressSwipeClick !== "true") return;
      delete card.dataset.suppressSwipeClick;
      window.clearTimeout(clearSuppressedClick);
      event.preventDefault();
      event.stopImmediatePropagation();
    }, true);
  }

  async function hideRecentEvent(eventId) {
    const csrf = document.querySelector("#spcboy-csrf-form [name='csrfmiddlewaretoken']")?.value;
    const response = await fetch(page.dataset.recentsUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRFToken": csrf || "" },
      body: JSON.stringify({ hideEventId: Number(eventId) }),
    });
    if (!response.ok) throw new Error("Recent play could not be hidden.");
    recentHiddenEventIds.add(String(eventId));
    await loadRecents(true, Math.max(1, recentLoadedPageCount));
  }

  function syncCardRemoveAction(card, track, { recentEventId = null } = {}) {
    const canHideRecent = view === "recent" && recentEventId != null;
    const canRemoveFavorite = !isDesktop() && view === "favorites";
    card.classList.toggle("is-favorite-removable", canRemoveFavorite);
    let remove = card.querySelector(".spcboy-card-remove");
    if (!canHideRecent) {
      remove?.remove();
      if (!canRemoveFavorite) card.classList.remove("is-swipe-revealed");
      return;
    }
    if (remove) return;
    remove = document.createElement("button");
    remove.className = "spcboy-card-remove";
    remove.type = "button";
    remove.setAttribute("aria-label", `Hide ${track.title} from your recent plays`);
    remove.title = "Hide from Recent";
    remove.innerHTML = '<svg aria-hidden="true" viewBox="0 0 24 24"><path d="M4 7h16M9 7V4h6v3m3 0-.8 13H6.8L6 7m4 3v7m4-7v7"/></svg>';
    remove.addEventListener("click", () => {
      remove.disabled = true;
      hideRecentEvent(recentEventId).catch(() => {
        playerState.textContent = "Could not hide that recent play. Try again.";
        remove.disabled = false;
      });
    });
    card.append(remove);
  }

  function makeTrackCard(track, index, { playedAt = "", onPlay = null, recentEventId = null } = {}) {
    const card = document.createElement("li");
    card.className = "spcboy-media-card";
    card.dataset.id = track.id;
    if (recentEventId != null) card.dataset.recentEventId = String(recentEventId);
    card.dataset.search = track.searchText || normalizeSearchText(`${track.title} ${track.artist ?? ""} ${track.game} ${track.console}`);
    card.setAttribute("aria-current", String(currentTrack?.id === track.id));

    const play = document.createElement("button");
    play.className = "spcboy-media-card-play";
    play.type = "button";
    play.setAttribute("aria-label", `Play ${track.title}, ${track.game}`);
    play.setAttribute("aria-current", String(currentTrack?.id === track.id));
    play.innerHTML = `<span class="spcboy-media-card-cover"><img alt="" width="60" height="60" loading="lazy" decoding="async"><span aria-hidden="true">♫</span></span><span class="spcboy-media-card-number" data-column="index"></span><span class="spcboy-media-card-copy"><span class="spcboy-media-card-title" data-column="title"></span><span class="spcboy-media-card-detail"><span data-column="game"></span><span class="spcboy-media-card-separator" aria-hidden="true"> · </span><span data-column="system"></span></span></span><span class="spcboy-media-card-artist" data-column="artist"></span><span class="spcboy-media-card-meta"><span class="spcboy-media-card-length" data-column="length"></span></span>`;
    const artwork = play.querySelector(".spcboy-media-card-cover img");
    if (track.artworkUrl) artwork.src = track.artworkUrl;
    else artwork.hidden = true;
    play.querySelector(".spcboy-media-card-number").textContent = String(index + 1).padStart(2, "0");
    play.querySelector(".spcboy-media-card-title").textContent = track.title;
    play.querySelector('[data-column="game"]').textContent = track.game || "—";
    play.querySelector('[data-column="system"]').textContent = canonicalConsoleName(track.console) || "—";
    play.querySelector(".spcboy-media-card-artist").textContent = track.artist || "—";
    play.querySelector(".spcboy-media-card-length").textContent = formatTime(canonicalDuration(track));
    play.addEventListener("click", () => onPlay ? onPlay() : selectTrack(track, true));

    const favorite = document.createElement("button");
    favorite.className = "site-favorite-toggle spcboy-media-card-favorite";
    favorite.type = "button";
    favorite.dataset.siteFavoriteToggle = "";
    favorite.dataset.favoriteKind = "track";
    favorite.dataset.favoriteId = track.id;
    favorite.dataset.favoriteTitle = track.title;
    favorite.dataset.column = "favorite";
    favorite.setAttribute("aria-label", `Favorite ${track.title}`);
    favorite.innerHTML = '<svg aria-hidden="true"><use href="#icon-star"/></svg>';

    card.append(play, favorite);
    syncFavorite(favorite, track.id);
    applyMediaCardColumns(card);
    if (playedAt) {
      const time = window.SiteComponents?.recordTime(playedAt, { className: "spcboy-media-card-time site-record-time--inline" });
      if (time) play.querySelector(".spcboy-media-card-meta").append(time);
    }
    syncCardRemoveAction(card, track, { recentEventId });
    setupCardSwipe();
    return card;
  }

  function makeTrackRow(track, index, playbackOptions = null) {
    const item = document.createElement("li");
    item.className = "spcboy-track-row";
    item.dataset.id = track.id;
    item.dataset.search = track.searchText || normalizeSearchText(`${track.title} ${track.artist ?? ""} ${track.game} ${track.console}`);

    const button = document.createElement("button");
    button.className = "spcboy-track";
    button.type = "button";
    button.setAttribute("aria-label", `Play ${track.title}, ${track.game}`);
    button.setAttribute("aria-current", String(currentTrack?.id === track.id));
    button.innerHTML = `<img class="spcboy-track-artwork" data-column="artwork" alt="" width="60" height="60" loading="lazy"><span class="spcboy-track-number" data-column="index"></span><span class="spcboy-track-title" data-column="title"></span><span class="spcboy-track-game" data-column="game"></span><span class="spcboy-track-artist" data-column="artist"></span><span class="spcboy-track-system" data-column="system"></span><span class="spcboy-track-length" data-column="length"></span>`;
    const artwork = button.querySelector(".spcboy-track-artwork");
    if (track.artworkUrl) artwork.src = track.artworkUrl;
    else artwork.hidden = true;
    button.querySelector(".spcboy-track-number").textContent = String(index + 1).padStart(2, "0");
    const title = button.querySelector(".spcboy-track-title");
    title.textContent = track.title;
    button.querySelector(".spcboy-track-game").textContent = track.game || "—";
    button.querySelector(".spcboy-track-artist").textContent = track.artist || "—";
    button.querySelector(".spcboy-track-system").textContent = track.console || "—";
    button.querySelector(".spcboy-track-length").textContent = formatTime(canonicalDuration(track));
    for (const id of ['year', 'dumper', 'timestamp']) {
      const cell = document.createElement('span');
      cell.dataset.column = id;
      cell.className = `spcboy-track-${id}`;
      cell.textContent = track[id] || '—';
      button.append(cell);
    }
    button.disabled = track.available === false;
    button.addEventListener("click", () => selectTrack(track, true, playbackOptions || {}));

    const favorite = document.createElement("button");
    favorite.className = "site-favorite-toggle spcboy-favorite";
    favorite.type = "button";
    favorite.dataset.siteFavoriteToggle = "";
    favorite.dataset.favoriteKind = "track";
    favorite.dataset.favoriteId = track.id;
    favorite.dataset.favoriteTitle = track.title;
    favorite.dataset.column = "favorite";
    favorite.setAttribute("aria-label", `Favorite ${track.title}`);
    favorite.innerHTML = '<svg aria-hidden="true"><use href="#icon-star"/></svg>';
    syncFavorite(favorite, track.id);

    item.append(button, favorite);
    return item;
  }

  function cacheTrack(entry, data) {
    const existing = tracksById.get(data.id);
    const track = {
      ...(existing || {}),
      ...data,
      game: entry.gameName,
      console: entry.consoleName,
      albumId: entry.albumId,
      artworkUrl: entry.artworkUrl,
      gameKey: entry.key,
    };
    track.searchText = normalizeSearchText(`${track.title} ${track.artist ?? ""} ${track.game} ${track.console}`);
    tracksById.set(track.id, track);
    if (trackIndexById.has(track.id)) tracks[trackIndexById.get(track.id)] = track;
    else {
      trackIndexById.set(track.id, tracks.length);
      tracks.push(track);
    }
    return track;
  }

  function clearEntryRows(entry) {
    if (!entry.list) {
      entry.tracks = [];
      return;
    }
    for (const row of entry.list.querySelectorAll(".spcboy-track-row")) {
      const rows = trackRowsById.get(row.dataset.id) ?? [];
      const remaining = rows.filter((candidate) => candidate !== row);
      if (remaining.length) trackRowsById.set(row.dataset.id, remaining);
      else trackRowsById.delete(row.dataset.id);
    }
    entry.list.replaceChildren();
    entry.tracks = [];
  }

  function appendTrackRow(entry, data) {
    ensureEntryPlaylistDom(entry);
    const existingRow = entry.list.querySelector(`.spcboy-track-row[data-id="${CSS.escape(data.id)}"]`);
    if (existingRow) return tracksById.get(data.id);
    const track = cacheTrack(entry, data);
    const row = makeTrackRow(track, entry.tracks.length, { source: "album", group: entry });
    row.querySelector(".spcboy-track")?.setAttribute("aria-current", String(currentTrack?.id === track.id));
    entry.tracks.push(track);
    entry.list.append(row);
    if (playlistContent.contains(row)) applyPlaylistColumnVisibilityToRow(row);
    const rows = trackRowsById.get(track.id) ?? [];
    rows.push(row);
    trackRowsById.set(track.id, rows);
    return track;
  }

  async function ensureAlbumTracks(entry, { retry = false } = {}) {
    if (!entry) return [];
    if (entry.loaded) return entry.tracks;
    if (entry.loadPromise && !retry) return entry.loadPromise;
    ensureEntryPlaylistDom(entry);
    entry.list.querySelectorAll(".spcboy-tracks-state, .spcboy-tracks-retry").forEach((node) => node.remove());
    entry.loading = true;
    entry.loadFailed = false;
    const loading = document.createElement("li");
    loading.className = "spcboy-tracks-state";
    loading.textContent = `Loading ${entry.trackCount.toLocaleString()} tracks…`;
    entry.list.append(loading);
    const url = new URL(page.dataset.albumUrl.replace("ALBUM_ID", encodeURIComponent(entry.albumId)), window.location.href);
    const controller = new AbortController();
    const requestTimeout = window.setTimeout(() => controller.abort(), 20000);
    entry.loadPromise = fetch(url, {
      credentials: "same-origin",
      signal: controller.signal,
      headers: { Accept: "application/json" },
    }).then((response) => {
      if (!response.ok) throw new Error(`Playlist request returned ${response.status}.`);
      return response.json();
    }).then((payload) => {
      if (!Array.isArray(payload.tracks)) throw new Error("Playlist data is invalid.");
      clearEntryRows(entry);
      for (const data of payload.tracks) appendTrackRow(entry, data);
      entry.loaded = true;
      entry.trackCount = entry.tracks.length;
      entry.loadFailed = false;
      entry.title.textContent = `${entry.gameName} · ${entry.consoleName}`;
      window.SitePlayer?.setLibrary(tracks);
      return entry.tracks;
    }).catch((error) => {
      loading.remove();
      entry.loadFailed = true;
      const retryButton = document.createElement("button");
      retryButton.type = "button";
      retryButton.className = "spcboy-tracks-retry";
      retryButton.textContent = "Could not load tracks · Retry";
      retryButton.addEventListener("click", () => ensureAlbumTracks(entry, { retry: true }));
      entry.list.append(retryButton);
      playerState.textContent = error.name === "AbortError"
        ? "Track loading timed out. Retry when your connection is ready."
        : error.message || "Playlist could not be loaded.";
      return [];
    }).finally(() => {
      window.clearTimeout(requestTimeout);
      entry.loading = false;
      entry.loadPromise = null;
      applyFilters();
    });
    return entry.loadPromise;
  }

  function rowsForTrack(id) {
    return trackRowsById.get(id) ?? [];
  }

  function syncCurrentTrackRows(id, active) {
    if (!id) return;
    const rows = [
      ...rowsForTrack(id),
      ...playlistContent.querySelectorAll(`.spcboy-track-row[data-id="${CSS.escape(id)}"]`),
      ...cardList.querySelectorAll(`.spcboy-media-card[data-id="${CSS.escape(id)}"]`),
    ];
    for (const row of rows) {
      row.setAttribute("aria-current", String(active));
      row.querySelector(".spcboy-media-card-play")?.setAttribute("aria-current", String(active));
      row.querySelector(".spcboy-track")?.setAttribute("aria-current", String(active));
    }
  }

  function syncFavorite(button, id) {
    const active = favorites.has(id);
    const buttons = rowsForTrack(id)
      .map((row) => row.querySelector(".spcboy-favorite"))
      .filter(Boolean);
    buttons.push(...playlistContent.querySelectorAll(`.spcboy-track-row[data-id="${CSS.escape(id)}"] .spcboy-favorite`));
    buttons.push(...cardList.querySelectorAll(`.spcboy-media-card[data-id="${CSS.escape(id)}"] .spcboy-media-card-favorite`));
    buttons.push(...document.querySelectorAll(`#spcboy-mobile-app .spcboy-mobile-track-favorite[data-favorite-id="${CSS.escape(id)}"]`));
    if (button && !buttons.includes(button)) buttons.push(button);
    for (const target of buttons) {
      const card = target.closest(".spcboy-media-card");
      const includedByAlbum = view === "favorites" && card
        && favoriteAlbums.has(tracksById.get(id)?.albumId);
      setTrackFavoriteButton(target, active || includedByAlbum);
    }
  }

  function setTrackFavoriteButton(button, active) {
    if (!button) return;
    button.classList.toggle("is-favorite", active);
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
    const title = button.dataset.favoriteTitle || button.closest(".spcboy-media-card")?.querySelector(".spcboy-media-card-title")?.textContent || "track";
    button.setAttribute("aria-label", `${active ? "Remove" : "Add"} ${title} from favorites`);
    button.title = `${active ? "Remove" : "Add"} ${title} ${active ? "from" : "to"} favorites`;
  }

  function makeAlbumFavoriteButton(albumId, gameName) {
    const button = document.createElement("button");
    button.className = "site-favorite-toggle spcboy-album-favorite";
    button.type = "button";
    button.dataset.albumFavorite = albumId;
    button.dataset.albumName = gameName;
    button.dataset.siteFavoriteToggle = "";
    button.dataset.favoriteKind = "album";
    button.dataset.favoriteId = albumId;
    button.dataset.favoriteTitle = gameName;
    button.setAttribute("aria-label", `Favorite ${gameName} album`);
    button.title = `Favorite ${gameName} album`;
    syncAlbumFavorite(button, albumId);
    return button;
  }

  function syncSidebarAlbumFavorites() {
    const visible = isDesktop();
    for (const button of trackList.querySelectorAll(".spcboy-game-row > .spcboy-album-favorite")) {
      button.hidden = !visible;
    }
  }

  function syncAlbumFavorite(button, albumId) {
    const active = favoriteAlbums.has(albumId);
    const buttons = [...document.querySelectorAll(`[data-album-favorite="${albumId}"]`)];
    if (button && !buttons.includes(button)) buttons.push(button);
    for (const target of buttons) {
      setAlbumFavoriteButton(target, active);
    }
  }

  function setAlbumFavoriteButton(button, active) {
    if (!button) return;
    const albumName = button.dataset.albumName || button.dataset.favoriteTitle || "album";
    button.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><use href="#icon-star"/></svg>';
    button.classList.toggle("is-favorite", active);
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
    button.setAttribute("aria-label", `${active ? "Remove" : "Add"} ${albumName} from favorites`);
    button.title = `${active ? "Remove" : "Add"} ${albumName} ${active ? "from" : "to"} favorites`;
  }

  function syncTrackContainers() {
    const desktop = isDesktop();
    const mobileAggregate = !desktop && view === "favorites";
    for (const entry of materializedPlaylistEntries) {
      if (!entry.list) continue;
      if (!desktop && !mobileAggregate && !entry.row) ensureEntrySidebarDom(entry);
      const destination = desktop || mobileAggregate ? entry.playlistGroup : entry.slot;
      if (destination && entry.list.parentElement !== destination) destination.append(entry.list);
      if (!desktop && !mobileAggregate) {
        for (const row of entry.list.querySelectorAll(".spcboy-track-row")) {
          for (const cell of row.querySelectorAll("[data-column]")) {
            if (cell.dataset.column !== "artwork") cell.hidden = false;
          }
          const favorite = row.querySelector(".spcboy-favorite");
          if (favorite) favorite.hidden = false;
        }
      }
    }
    placeSearchMore();
  }

  async function loadFavorites() {
    try {
      await window.SBOProfileStorage?.ready;
      const localIds = [...favorites];
      const localAlbumIds = [...favoriteAlbums];
      const response = await fetch(page.dataset.favoritesUrl, {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) throw new Error("Favorites are unavailable.");
      const payload = await response.json();
      const serverIds = Array.isArray(payload.trackIds) ? payload.trackIds : [];
      const serverAlbumIds = Array.isArray(payload.albumIds) ? payload.albumIds : [];
      favorites.clear();
      for (const id of [...serverIds, ...localIds]) if (typeof id === "string") favorites.add(id);
      favoriteAlbums.clear();
      for (const id of [...serverAlbumIds, ...localAlbumIds]) if (typeof id === "string") favoriteAlbums.add(id);
      for (const [id, rows] of trackRowsById) {
        for (const row of rows) syncFavorite(row.querySelector(".spcboy-favorite"), id);
      }
      for (const button of document.querySelectorAll("[data-album-favorite]")) {
        syncAlbumFavorite(button, button.dataset.albumFavorite);
      }
      if (localIds.length || localAlbumIds.length) {
        const csrf = document.querySelector("#spcboy-csrf-form [name='csrfmiddlewaretoken']")?.value;
        const saved = await fetch(page.dataset.favoritesUrl, {
          method: "POST",
          credentials: "same-origin",
          headers: { "Content-Type": "application/json", "X-CSRFToken": csrf || "" },
          body: JSON.stringify({ trackIds: [...favorites], albumIds: [...favoriteAlbums] }),
        });
        if (!saved.ok) throw new Error("Favorites did not sync.");
        storage.remove("favorites");
        storage.remove("favoriteAlbums");
      }
      applyFilters();
      if (view === "favorites") loadFavoritePlaylist();
    } catch {
      /* The browser copy remains usable if the network is briefly unavailable. */
    }
  }

  function resetFavoritePlaylist() {
    favoritePlaylistTracks = [];
    favoritePlaylistNextPage = 1;
    favoritePlaylistLoaded = false;
    favoritePlaylistFailed = false;
  }

  async function loadFavoritePlaylist({ allPages = false } = {}) {
    if (favoritePlaylistLoaded) return favoritePlaylistTracks;
    if (favoritePlaylistPromise) {
      const pendingTracks = await favoritePlaylistPromise;
      return allPages && favoritePlaylistNextPage ? loadFavoritePlaylist({ allPages: true }) : pendingTracks;
    }
    favoritePlaylistLoading = true;
    applyFilters();
    favoritePlaylistPromise = (async () => {
      await catalogReady;
      do {
        const requestedPage = favoritePlaylistNextPage;
        if (!requestedPage) break;
        const url = new URL(page.dataset.favoritePlaylistUrl, window.location.href);
        url.searchParams.set("page", String(requestedPage));
        const response = await fetch(url, {
          credentials: "same-origin",
          headers: { Accept: "application/json" },
        });
        if (!response.ok) throw new Error(`Favorites request returned ${response.status}.`);
        const payload = await response.json();
        if (!Array.isArray(payload.tracks)) throw new Error("Favorite playlist data is invalid.");
        for (const data of payload.tracks) {
          const entry = gameGroupsByConsoleGame.get(`${canonicalConsoleName(data.console)}\u0000${data.game}`);
          if (!entry || typeof data.id !== "string") continue;
          const date = new Date(data.addedAt || "");
          const enriched = {
            ...data,
            timestamp: Number.isFinite(date.getTime()) ? date.toLocaleString('en-US', {
              timeZone: 'America/Detroit', year: 'numeric', month: '2-digit', day: '2-digit',
              hour: '2-digit', minute: '2-digit'
            }) : "",
          };
          const track = cacheTrack(entry, enriched);
          favoritePlaylistTracks.push(track);
        }
        favoritePlaylistNextPage = Number.isInteger(payload.nextPage) ? payload.nextPage : null;
        favoritePlaylistLoaded = favoritePlaylistNextPage === null;
      } while (allPages && favoritePlaylistNextPage);
      favoritePlaylistFailed = false;
      window.SitePlayer?.setLibrary(tracks);
      return favoritePlaylistTracks;
    })().catch((error) => {
      favoritePlaylistFailed = true;
      playerState.textContent = error.message || "Favorites could not be loaded.";
      return [];
    }).finally(() => {
      favoritePlaylistLoading = false;
      favoritePlaylistPromise = null;
      applyFilters();
    });
    return favoritePlaylistPromise;
  }

  function ensureEntryPlaylistDom(entry) {
    if (!entry || entry.list) return;
    const slot = document.createElement("div");
    slot.className = "spcboy-track-slot";
    const list = document.createElement("ol");
    list.className = "spcboy-tracks";
    list.setAttribute("aria-label", `${entry.gameName} tracks`);
    const playlistGroup = document.createElement("section");
    playlistGroup.className = "spcboy-playlist-group";
    const playlistGroupTitle = document.createElement("h3");
    playlistGroupTitle.className = "spcboy-playlist-group-title";
    playlistGroupTitle.textContent = `${entry.gameName} · ${entry.consoleName}`;
    playlistGroup.append(playlistGroupTitle, list);
    if (entry.details) entry.details.append(slot);
    entry.slot = slot;
    entry.list = list;
    entry.playlistGroup = playlistGroup;
    entry.title = playlistGroupTitle;
    materializedPlaylistEntries.add(entry);
  }

  function ensureEntrySidebarDom(entry) {
    if (!entry || entry.row) return;
    const group = makeDetails("spcboy-game", entry.gameName, entry.trackCount);
    if (!entry.trackCount) group.classList.add("is-leaf");
    group.dataset.gameKey = entry.key;
    const gameRow = document.createElement("div");
    gameRow.className = "spcboy-game-row";
    gameRow.hidden = Boolean(entry.hidden);
    gameRow.append(group);
    if (entry.albumId) {
      const albumFavorite = makeAlbumFavoriteButton(entry.albumId, entry.gameName);
      albumFavorite.hidden = !isDesktop();
      gameRow.append(albumFavorite);
    }
    if (entry.slot) group.append(entry.slot);
    if (entry.key === selectedGameKey) group.classList.add("is-selected");
    entry.row = gameRow;
    entry.details = group;
  }

  function ensureConsoleContentRendered(systemRecord) {
    if (!systemRecord || systemRecord.rendered) return;
    const fragment = document.createDocumentFragment();
    const showAlbumFavorite = isDesktop();
    for (const entry of systemRecord.entries) {
      ensureEntrySidebarDom(entry);
      const albumFav = entry.row.querySelector(".spcboy-album-favorite");
      if (albumFav) albumFav.hidden = !showAlbumFavorite;
      entry.row.hidden = Boolean(entry.hidden);
      entry.details.classList.toggle("is-selected", entry.key === selectedGameKey);
      fragment.append(entry.row);
    }
    systemRecord.contentEl.append(fragment);
    systemRecord.rendered = true;
  }

  let trackListDelegationReady = false;
  function setupTrackListDelegation() {
    if (trackListDelegationReady || !trackList) return;
    trackListDelegationReady = true;
    trackList.addEventListener("click", (event) => {
      const target = event.target instanceof Element ? event.target : null;
      if (!target) return;
      const systemSummary = target.closest(".spcboy-system > summary");
      if (systemSummary) {
        if (event.isTrusted) searchOpenedSystems.delete(systemSummary.parentElement);
        return;
      }
      const gameSummary = target.closest(".spcboy-game > summary");
      if (gameSummary && isDesktop()) {
        event.preventDefault();
        selectGame(gameSummary.parentElement.dataset.gameKey);
      }
    });
    trackList.addEventListener("toggle", (event) => {
      const details = event.target instanceof Element ? event.target : null;
      if (!details) return;
      if (details.classList.contains("spcboy-system")) {
        if (details.open) {
          ensureConsoleContentRendered(systemRecordByEl.get(details));
          if (event.isTrusted && !isDesktop()) {
            for (const rec of systemRecords) {
              if (rec.el === details) continue;
              rec.el.open = false;
              if (rec.rendered) {
                for (const entry of rec.entries) {
                  if (entry.details) entry.details.open = false;
                }
              }
            }
          }
        }
        return;
      }
      if (details.classList.contains("spcboy-game") && event.isTrusted && details.open && !isDesktop()) {
        selectGame(details.dataset.gameKey);
      }
    }, true);
  }

  async function renderCatalog(catalog) {
    setupTrackListDelegation();
    rawCatalog = catalog;
    trackList.replaceChildren();
    searchOpenedSystems.clear();
    materializedPlaylistEntries.clear();
    tracks = [];
    tracksById.clear();
    trackIndexById.clear();
    trackRowsById.clear();
    gameGroups.length = 0;
    systemRecords.length = 0;
    systemRecordByEl.clear();
    gameGroupsByKey.clear();
    gameGroupsByAlbumId.clear();
    gameGroupsByConsoleGame.clear();
    const consoles = Array.isArray(catalog.consoles) ? catalog.consoles : [];
    const totalGames = consoles.reduce((total, consoleData) => total + (Array.isArray(consoleData.games) ? consoleData.games.length : 0), 0);
    updateCatalogBuildProgress(0, totalGames);
    const consoleFragment = document.createDocumentFragment();
    for (const [consoleIndex, consoleData] of consoles.entries()) {
      const consoleName = canonicalConsoleName(consoleData.name);
      const games = Array.isArray(consoleData.games) ? consoleData.games : [];
      const system = makeDetails("spcboy-system", consoleName, games.length);
      system.dataset.console = consoleName;
      const content = document.createElement("div");
      content.className = "spcboy-system-content";
      system.append(content);
      consoleFragment.append(system);
      const systemRecord = {
        consoleName,
        el: system,
        contentEl: content,
        entries: [],
        rendered: false,
      };
      systemRecords.push(systemRecord);
      systemRecordByEl.set(system, systemRecord);
      for (const [gameIndex, gameData] of games.entries()) {
        const trackCount = Math.max(0, Number(gameData.trackCount) || 0);
        const albumId = typeof gameData.albumId === "string" ? gameData.albumId : "";
        const artworkUrl = typeof gameData.artworkUrl === "string" ? gameData.artworkUrl : "";
        const gameKey = `${consoleIndex}:${gameIndex}`;
        const entry = {
          key: gameKey,
          albumId,
          artworkUrl,
          consoleName,
          gameName: gameData.name,
          normalizedName: normalizeSearchText(gameData.name),
          trackCount,
          tracks: [],
          loaded: false,
          loading: false,
          loadPromise: null,
          system: systemRecord,
          row: null,
          details: null,
          slot: null,
          list: null,
          playlistGroup: null,
          title: null,
          hidden: false,
        };
        systemRecord.entries.push(entry);
        gameGroups.push(entry);
        gameGroupsByKey.set(gameKey, entry);
        if (albumId) gameGroupsByAlbumId.set(albumId, entry);
        gameGroupsByConsoleGame.set(`${consoleName}\u0000${gameData.name}`, entry);
      }
    }
    trackList.append(consoleFragment, empty);
    updateCatalogBuildProgress(totalGames, totalGames);
    setCatalogFinishing();
    syncSidebarAlbumFavorites();
    catalogLoaded = true;
    catalogAvailable = true;
    resolveCatalogReady();
    try {
      renderMobileNowPlaying(window.SitePlayer?.getCurrentTrack?.() || currentTrack);
      renderMobileUpNext();
      if (!isDesktop()) {
        if (mobileAppPage === "library") renderMobileLibrary();
      }
    } catch (err) {
      console.warn("Mobile initial render warning:", err);
    }
    selectedGameKey = gameGroups[0]?.key ?? null;
    if (!hasSavedWorkspace) activeWorkspace().albumId = gameGroups[0]?.albumId || null;
    libraryState.textContent = gameCountLabel(gameGroups.length);
    empty.textContent = gameGroups.length ? "No matching tracks." : "No playable tracks are installed yet.";
    playlistEmpty.textContent = gameGroups.length ? "No matching tracks." : "No playable tracks are installed yet.";
    syncResponsiveLists();
    window.SitePlayer?.setLibrary(tracks);
    restoreWorkspace(activeWorkspaceId, {initial:true});
    if (recentLoaded) renderRecents();
    const requestedURL = new URL(window.location.href);
    const requestedTrackId = requestedURL.searchParams.get("play");
    const requestedAlbumId = requestedURL.searchParams.get("album");
    const requestedWorkspaceAlbumId = requestedURL.searchParams.get("openAlbum");
    if (requestedTrackId) {
      fetchTrackDetail(requestedTrackId).then((requestedTrack) => {
        if (requestedTrack) {
        requestedURL.searchParams.delete("play");
        requestedURL.searchParams.delete("album");
        window.history.replaceState(null, "", requestedURL);
        selectTrack(requestedTrack, true, { source: "album" });
      } else playerState.textContent = "That track is no longer available in the library.";
      }).catch(() => { playerState.textContent = "That track is no longer available in the library."; });
    } else if (requestedAlbumId) {
      if (!/^[0-9a-f]{32}$/.test(requestedAlbumId)) {
        playerState.textContent = "That album is no longer available in the library.";
      } else {
        const albumURL = new URL(page.dataset.albumUrl.replace("ALBUM_ID", encodeURIComponent(requestedAlbumId)), window.location.href);
        fetch(albumURL, { credentials: "same-origin", headers: { Accept: "application/json" } })
          .then((response) => {
            if (!response.ok) throw new Error(`Album request returned ${response.status}.`);
            return response.json();
          })
          .then((payload) => {
            if (!Array.isArray(payload.tracks) || !payload.tracks.length) throw new Error("Album playlist is empty.");
            requestedURL.searchParams.delete("album");
            window.history.replaceState(null, "", requestedURL);
            window.SitePlayer?.playPlaylist(payload.tracks);
          })
          .catch(() => { playerState.textContent = "That album could not be loaded. Try again."; });
      }
    } else if (requestedWorkspaceAlbumId) {
      if (!/^[0-9a-f]{32}$/.test(requestedWorkspaceAlbumId)
        || !openWorkspaceForAlbum(requestedWorkspaceAlbumId)) {
        playerState.textContent = "That album is no longer available in the library.";
      } else {
        requestedURL.searchParams.delete("openAlbum");
        window.history.replaceState(null, "", requestedURL);
      }
    }
  }

  async function fetchTrackDetail(trackId) {
    const url = new URL(page.dataset.trackUrl.replace("TRACK_ID", encodeURIComponent(trackId)), window.location.href);
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    });
    if (!response.ok) return null;
    const payload = await response.json();
    const data = payload.track;
    const entry = data && gameGroupsByConsoleGame.get(`${canonicalConsoleName(data.console)}\u0000${data.game}`);
    if (!entry) return null;
    return cacheTrack(entry, data);
  }

  function selectGame(gameKey, { openSidebar = true } = {}) {
    const selectedEntry = gameGroupsByKey.get(gameKey);
    if (!selectedEntry) return;
    const prevEntry = gameGroupsByKey.get(selectedGameKey);
    selectedGameKey = gameKey;
    syncWorkspaceHeading(selectedEntry.gameName || "Playlist");
    if (isDesktop() && (view === "favorites" || view === "recent")) {
      captureWorkspace();
      applyFilters();
      return;
    }
    if (prevEntry && prevEntry !== selectedEntry && prevEntry.details) {
      prevEntry.details.classList.remove("is-selected");
      if (isDesktop() && openSidebar) prevEntry.details.open = false;
    }
    if (isDesktop() || !openSidebar) {
      ensureConsoleContentRendered(selectedEntry.system);
    } else if (openSidebar) {
      ensureConsoleContentRendered(selectedEntry.system);
    }
    ensureEntryPlaylistDom(selectedEntry);
    if (selectedEntry.details) {
      selectedEntry.details.classList.add("is-selected");
      if (isDesktop() && openSidebar) selectedEntry.details.open = view !== "favorites";
    }
    if (isDesktop() && openSidebar && selectedEntry.system?.el) {
      selectedEntry.system.el.open = true;
    }
    if (!isDesktop() && openSidebar) {
      const selectedSystem = selectedEntry.system?.el;
      for (const rec of systemRecords) {
        if (rec.el !== selectedSystem) rec.el.open = false;
        if (rec.rendered) {
          for (const entry of rec.entries) {
            if (entry !== selectedEntry && entry.details) entry.details.open = false;
          }
        }
      }
      if (selectedSystem) selectedSystem.open = true;
      if (selectedEntry.details) selectedEntry.details.open = true;
    }
    ensureAlbumTracks(selectedEntry);
    captureWorkspace();
    if (isDesktop() && (view === "favorites" || (view === "all" && !search.value.trim()))) renderDesktopPlaylist();
    scheduleSelectionIndicators();
  }

  function syncResponsiveLists() {
    const desktop = isDesktop();
    search.setAttribute("aria-label", "Search game titles");
    search.placeholder = "Search games";
    syncSidebarAlbumFavorites();
    if (!desktop) {
      trackList.querySelectorAll(".spcboy-system, .spcboy-game").forEach((details) => { details.open = false; });
      for (const rec of systemRecords) {
        if (!rec.rendered) continue;
        for (const entry of rec.entries) entry.details?.classList.toggle("is-selected", entry.key === selectedGameKey);
      }
    }
    syncTrackContainers();
    placeSearchMore();
    applyFilters();
  }

  function recentPlaylistTracks() {
    return recentEntries.filter(entry => !recentHiddenEventIds.has(String(entry.eventId))).map(entry => {
      const known = tracksById.get(entry.trackId);
      const consoleName = canonicalConsoleName(entry.console);
      const group = gameGroupsByConsoleGame.get(`${consoleName}\u0000${entry.game}`);
      const date = new Date(entry.playedAt);
      return {
        ...known, ...entry, id: entry.trackId, console: consoleName,
        gameKey: group?.key || known?.gameKey,
        albumId: group?.albumId || known?.albumId,
        artworkUrl: group?.artworkUrl || known?.artworkUrl || "",
        durationSeconds: Number(entry.durationSeconds) || known?.durationSeconds || 0,
        timestamp: Number.isFinite(date.getTime()) ? date.toLocaleString('en-US', {
          timeZone: 'America/Detroit', year: 'numeric', month: '2-digit', day: '2-digit',
          hour: '2-digit', minute: '2-digit'
        }) : "",
      };
    });
  }

  function collectionTracks() {
    const source = view === "recent" ? recentPlaylistTracks() : favoritePlaylistTracks.filter(track =>
      favorites.has(track.id) || favoriteAlbums.has(track.albumId));
    const query = search.value.trim();
    return source.filter(track => matchesTrackQuery(track, query));
  }

  function renderCollectionPlaylist(tracks) {
    const selected = selectedGameKey ? tracks.filter(track => track.gameKey === selectedGameKey) : tracks;
    playlistEmpty.hidden = Boolean(selected.length);
    if (!selected.length) playlistContent.append(playlistEmpty);
    else {
      const group = document.createElement("section");
      group.className = "spcboy-playlist-group";
      const list = document.createElement("ol");
      list.className = "spcboy-tracks spcboy-collection-track-list";
      list.setAttribute("aria-label", view === "recent" ? "Recent tracks" : "Favorite tracks");
      selected.forEach((track, index) => {
        const row = makeTrackRow(track, index, { source: view === "recent" ? "recent" : "favorites", tracks: selected });
        if (track.eventId != null) row.dataset.recentEventId = String(track.eventId);
        applyPlaylistColumnVisibilityToRow(row);
        list.append(row);
      });
      group.append(list);
      playlistContent.append(group);
    }
    placeSearchMore();
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  }

  function renderDesktopCollection() {
    const tracks = collectionTracks();
    const recent = view === "recent";
    const timestampHeader = playlistColumnHeadCells?.querySelector('[data-column="timestamp"]');
    if (timestampHeader) {
      timestampHeader.textContent = recent ? "PLAYED" : "ADDED";
      timestampHeader.dataset.label = timestampHeader.textContent;
    }
    const keys = new Set(tracks.map(track => track.gameKey).filter(Boolean));
    const albumOrder = new Map();
    for (const [index, track] of tracks.entries()) {
      if (track.gameKey && !albumOrder.has(track.gameKey)) albumOrder.set(track.gameKey, index);
    }
    const loaded = view === "recent" ? recentLoaded : favoritePlaylistLoaded;
    if (loaded && selectedGameKey && !keys.has(selectedGameKey)) selectedGameKey = null;
    const expandAlbums = collectionSidebarView !== view && keys.size > 0;
    if (keys.size) collectionSidebarView = view;
    for (const rec of systemRecords) {
      let hasVisible = false;
      for (const entry of rec.entries) {
        const show = keys.has(entry.key);
        entry.hidden = !show;
        if (show) hasVisible = true;
      }
      rec.el.hidden = !hasVisible;
      if (hasVisible) {
        ensureConsoleContentRendered(rec);
        const visibleEntries = [];
        for (const entry of rec.entries) {
          if (entry.row) entry.row.hidden = entry.hidden;
          entry.details?.classList.toggle("is-selected", entry.key === selectedGameKey);
          if (entry.details) entry.details.open = false;
          if (!entry.hidden) visibleEntries.push(entry);
        }
        visibleEntries.sort((left, right) => (albumOrder.get(left.key) ?? Infinity) - (albumOrder.get(right.key) ?? Infinity));
        for (const entry of visibleEntries) rec.contentEl.append(entry.row);
        const count = visibleEntries.length;
        const label = rec.el.querySelector("summary > .spcboy-count");
        if (label) label.textContent = String(count);
        if (expandAlbums && count) rec.el.open = true;
      } else {
        const label = rec.el.querySelector("summary > .spcboy-count");
        if (label) label.textContent = "0";
      }
    }
    const loading = recent ? recentLoading : favoritePlaylistLoading;
    const failed = recent ? recentFailed : favoritePlaylistFailed;
    playlistEmpty.textContent = loading ? (recent ? "Loading your recent plays…" : "Loading your favorites…")
      : failed ? "Could not load this playlist. Try again."
      : search.value.trim() ? "No matching tracks."
      : recent ? "Tracks will appear here after you play them." : "Favorite a track or album to build your Favorites playlist.";
    empty.hidden = true;
    favoriteMore.hidden = recent || !favoritePlaylistNextPage || favoritePlaylistLoading || !favoritePlaylistTracks.length;
    favoriteMore.disabled = favoritePlaylistLoading;
    recentMore.hidden = !recent || (recentNextPage === null || (!recentLoaded && !recentFailed));
    recentMore.disabled = recentLoading;
    recentMore.textContent = recentLoading ? "Loading…" : recentFailed ? "Retry" : "Load older";
    playlistContent.replaceChildren();
    renderCollectionPlaylist(tracks);
    libraryState.textContent = `${tracks.length.toLocaleString()} ${recent ? "recent plays" : "favorites"} · ${keys.size.toLocaleString()} albums`;
  }

  function renderDesktopPlaylist() {
    const mobileAggregate = !isDesktop() && view === "favorites";
    if (!isDesktop() && !mobileAggregate) return;
    playlistContent.replaceChildren();
    const query = search.value.trim().toLocaleLowerCase();
    if (isDesktop() && (view === "favorites" || view === "recent")) {
      renderCollectionPlaylist(collectionTracks());
      return;
    }
    const aggregate = view === "favorites";
    const selectedFallback = gameGroupsByKey.get(selectedGameKey);
    if (selectedFallback && !selectedFallback.hidden) ensureEntryPlaylistDom(selectedFallback);
    const candidates = aggregate
      ? [...materializedPlaylistEntries].filter((entry) => entry.list && [...entry.list.querySelectorAll(".spcboy-track-row")].some((row) => !row.hidden))
      : [selectedFallback].filter((entry) => entry && !entry.hidden);

    if (!candidates.length) {
      playlistEmpty.hidden = false;
      playlistEmpty.textContent = query && view !== "favorites"
        ? "Select a matching game to view its tracks."
        : "No matching tracks.";
      playlistContent.append(playlistEmpty);
      schedulePlaylistColumnLayout();
      scheduleSelectionIndicators();
      return;
    }

    playlistEmpty.hidden = true;
    for (const entry of candidates) {
      entry.title.hidden = !aggregate;
      entry.playlistGroup.hidden = false;
      playlistContent.append(entry.playlistGroup);
      for (const row of entry.list.querySelectorAll(".spcboy-track-row")) {
        applyPlaylistColumnVisibilityToRow(row);
      }
    }
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  }

  function renderFavorites() {
    cardList.replaceChildren();
    const query = search.value.trim();
    let visibleCount = 0;
    for (const track of favoritePlaylistTracks) {
      if (!favorites.has(track.id) && !favoriteAlbums.has(track.albumId)) continue;
      if (query && !matchesTrackQuery(track, query)) continue;
      cardList.append(makeTrackCard(track, visibleCount, {
        onPlay: () => selectTrack(track, true, { source: "favorites" }),
      }));
      visibleCount += 1;
    }
    cardPanel.setAttribute("aria-label", "Your favorite tracks");
    cardList.setAttribute("aria-label", "Favorite tracks");
    cardEmpty.hidden = visibleCount > 0 || favoritePlaylistLoading;
    cardEmpty.textContent = favoritePlaylistFailed
      ? "Favorites could not load. Switch tabs and try again."
      : favoritePlaylistLoading
        ? "Loading your favorites…"
        : favoritePlaylistTracks.length && query
          ? "No favorites match your search."
          : favorites.size || favoriteAlbums.size
            ? "Your favorites will appear here."
            : "Favorite a track or album to build your Favorites list.";
    favoriteMore.hidden = !favoritePlaylistNextPage || favoritePlaylistLoading || !favoritePlaylistTracks.length;
    favoriteMore.disabled = favoritePlaylistLoading;
    favoriteMore.textContent = favoritePlaylistLoading ? "Loading favorites…" : "Load more favorites";
    recentMore.hidden = true;
    libraryState.textContent = `${favoritePlaylistTracks.length.toLocaleString()} favorites loaded`;
  }

  function renderRecents() {
    cardList.replaceChildren();
    const query = search.value.trim();
    let visibleCount = 0;
    for (const entry of recentEntries) {
      if (recentHiddenEventIds.has(String(entry.eventId))) continue;
      const searchTrack = tracksById.get(entry.trackId);
      const consoleName = canonicalConsoleName(entry.console);
      if (query && !matchesTrackQuery({ game: entry.game }, query)) continue;

      const group = gameGroupsByConsoleGame.get(`${consoleName}\u0000${entry.game}`);
      const track = searchTrack || {
        id: entry.trackId,
        title: entry.title,
        artist: "",
        game: entry.game,
        console: consoleName,
        durationSeconds: Number(entry.durationSeconds) || 0,
        ...(group ? { gameKey: group.key, albumId: group.albumId, artworkUrl: group.artworkUrl } : {}),
      };

      const recentTrack = {
        ...track,
        ...entry,
        id: entry.trackId,
        title: entry.title,
        game: entry.game,
        console: consoleName,
        durationSeconds: Number(entry.durationSeconds) || track.durationSeconds || 0,
        artworkUrl: track.artworkUrl || group?.artworkUrl || "",
      };
      const row = makeTrackCard(recentTrack, visibleCount, {
        playedAt: entry.playedAt,
        recentEventId: entry.eventId,
        onPlay: async () => {
          if (!entry.trackId) return;
          let playable = tracksById.get(entry.trackId);
          if (!playable) {
            try { playable = await fetchTrackDetail(entry.trackId); }
            catch { /* The snapshot can still try playback if metadata lookup is briefly offline. */ }
          }
          if (playable) selectTrack(playable, true, { source: "recent" });
          else playerState.textContent = "That recent track is no longer in the hosted library.";
        },
      });
      const playButton = row.querySelector(".spcboy-media-card-play");
      playButton?.toggleAttribute("disabled", !entry.trackId);
      playButton?.setAttribute("aria-label", `Play ${entry.title}, ${entry.game}`);
      cardList.append(row);
      visibleCount += 1;
    }

    cardPanel.setAttribute("aria-label", "Your recent playback");
    cardList.setAttribute("aria-label", "Recent tracks");
    cardEmpty.hidden = visibleCount !== 0 || recentLoading;
    cardEmpty.textContent = query
      ? "No recent plays match your search."
      : "Tracks will appear here after you play them.";
    favoriteMore.hidden = true;
    recentMore.hidden = recentNextPage === null || (!recentLoaded && !recentFailed);
    recentMore.disabled = recentLoading;
    recentMore.textContent = recentLoading ? "Loading…" : recentFailed ? "Retry" : "Load older";
    libraryState.textContent = `${recentEntries.length.toLocaleString()} recent plays loaded`;
  }

  async function loadRecents(reset = false, throughPages = 1) {
    if (recentLoading || (!reset && recentNextPage === null)) return;
    if (reset) {
      recentEntries = [];
      recentNextPage = 1;
      recentLoadedPageCount = 0;
      recentLoaded = false;
      recentFailed = false;
    }
    recentLoading = true;
    if (view === "recent") applyFilters();
    cardEmpty.hidden = false;
    cardEmpty.textContent = "Loading your recent plays…";
    recentMore.disabled = true;
    let requestedPage = reset ? 1 : recentNextPage;
    try {
      let pagesFetched = 0;
      do {
        const url = new URL(page.dataset.recentsUrl, window.location.href);
        url.searchParams.set("page", String(requestedPage));
        const response = await fetch(url, {
          credentials: "same-origin",
          headers: { Accept: "application/json" },
        });
        if (!response.ok) throw new Error(`Recent plays request returned ${response.status}.`);
        const payload = await response.json();
        const results = Array.isArray(payload.results) ? payload.results : [];
        recentEntries = reset && pagesFetched === 0 ? results : [...recentEntries, ...results];
        recentNextPage = Number.isInteger(payload.nextPage) ? payload.nextPage : null;
        recentLoadedPageCount = requestedPage;
        pagesFetched += 1;
        requestedPage = recentNextPage;
      } while (reset && pagesFetched < Math.max(1, Number(throughPages) || 1) && recentNextPage !== null);
      recentLoaded = true;
      recentFailed = false;
    } catch {
      cardEmpty.hidden = false;
      cardEmpty.textContent = "Could not load your recent plays. Try again.";
      recentNextPage = requestedPage;
      recentFailed = true;
    } finally {
      recentLoading = false;
      if (view === "recent") applyFilters();
      if (!recentLoaded) {
        cardEmpty.hidden = false;
        cardEmpty.textContent = "Could not load your recent plays. Try again.";
      }
    }

    window.SitePlayer?.setLibrary(tracks);
  }

  function applyFilters() {
    syncTrackContainers();
    const showingRecent = view === "recent";
    const showingCards = !isDesktop() && (showingRecent || view === "favorites");
    const query = search.value.trim();
    const titleOnlySearch = Boolean(query);
    const mobileAggregate = !isDesktop() && view === "favorites";
    library.classList.toggle("is-mobile-results", mobileAggregate);
    library.classList.toggle("is-card-view", showingCards);
    library.classList.toggle("is-recent", showingRecent);
    library.classList.toggle("is-favorites", view === "favorites");
    trackList.hidden = showingCards || mobileAggregate;
    playlistPane.hidden = showingCards || (!isDesktop() && !mobileAggregate);
    cardPanel.hidden = !showingCards;
    shuffleFavoritesButton.hidden = view !== "favorites";
    if (isDesktop() && (view === "favorites" || showingRecent)) {
      renderDesktopCollection();
      return;
    }
    if (collectionSidebarView !== null) {
      for (const rec of systemRecords) {
        if (!rec.rendered) continue;
        for (const entry of rec.entries) {
          if (entry.row) rec.contentEl.append(entry.row);
        }
      }
    }
    collectionSidebarView = null;
    const timestampHeader = playlistColumnHeadCells?.querySelector('[data-column="timestamp"]');
    if (timestampHeader) {
      timestampHeader.textContent = "DATE/TIME";
      timestampHeader.dataset.label = "DATE/TIME";
    }
    for (const label of trackList.querySelectorAll('.spcboy-system > summary > .spcboy-count')) {
      label.textContent = label.dataset.totalCount;
    }
    if (showingCards) {
      if (view === "recent") renderRecents();
      else renderFavorites();
      placeSearchMore();
      scheduleSelectionIndicators();
      return;
    }
    let visibleTracks = 0;
    let visibleGames = 0;
    const desktop = isDesktop();
    const queryTerms = titleOnlySearch ? searchTerms(query) : [];
    for (const [id, matchingRows] of trackRowsById) {
      const track = tracksById.get(id);
      const isFavorite = favorites.has(id) || Boolean(track?.albumId && favoriteAlbums.has(track.albumId));
      const isVisibleInView = view === "all"
        || (view === "favorites" && isFavorite);
      for (const row of matchingRows) {
        const matchesCurrentQuery = !query || matchesTrackQuery(track, query);
        const isVisible = isVisibleInView && matchesCurrentQuery;
        row.hidden = !isVisible;
        if (isVisible) visibleTracks += 1;
      }
    }
    for (const rec of systemRecords) {
      let systemHasVisible = false;
      for (const entry of rec.entries) {
        let shown = false;
        if (titleOnlySearch) {
          shown = queryTerms.length > 0 && queryTerms.every((term) => entry.normalizedName.includes(term));
        } else if (view === "all") {
          shown = true;
        } else if (view === "favorites") {
          const hasVisibleRows = Boolean(entry.list && [...entry.list.querySelectorAll(".spcboy-track-row")].some((row) => !row.hidden));
          shown = hasVisibleRows || favoriteAlbums.has(entry.albumId);
        }
        entry.hidden = !shown;
        if (entry.row) entry.row.hidden = !shown;
        if (entry.details) entry.details.classList.toggle("is-selected", entry.key === selectedGameKey);
        if (shown) {
          visibleGames += 1;
          systemHasVisible = true;
        }
      }
      rec.el.hidden = !systemHasVisible;
      if (titleOnlySearch && systemHasVisible) {
        if (!rec.el.open) {
          rec.el.open = true;
          searchOpenedSystems.add(rec.el);
        }
        if (desktop) ensureConsoleContentRendered(rec);
      } else if (desktop && rec.el.open && systemHasVisible) {
        ensureConsoleContentRendered(rec);
      }
    }
    if (!query) {
      for (const system of searchOpenedSystems) system.open = false;
      searchOpenedSystems.clear();
    }
    empty.hidden = (titleOnlySearch ? visibleGames !== 0 : visibleTracks !== 0) || (view === "all" && !query)
      || (view === "favorites" && favoritePlaylistLoading);
    const hasFavorites = favorites.size > 0 || favoriteAlbums.size > 0;
    empty.textContent = view === "favorites" && !hasFavorites
      ? "Favorite a track or album to build your Favorites playlist."
      : view === "favorites" && favoritePlaylistLoading ? "Loading your favorites…"
        : view === "favorites" && favoritePlaylistFailed ? "Favorites could not load. Switch tabs and try again."
          : titleOnlySearch ? "No matching games."
            : "No matching tracks.";
    if (view === "favorites" && !hasFavorites) playlistEmpty.textContent = "Favorite a track or album to build your Favorites playlist.";
    else if (view === "favorites" && favoritePlaylistLoading) playlistEmpty.textContent = "Loading your favorites…";
    else if (view === "favorites" && favoritePlaylistFailed) playlistEmpty.textContent = "Favorites could not load. Switch tabs and try again.";
    else playlistEmpty.textContent = "No matching tracks.";
    if (isDesktop() || mobileAggregate) renderDesktopPlaylist();
    libraryState.textContent = gameCountLabel(visibleGames);
    if (favoriteMore) {
      favoriteMore.hidden = view !== "favorites" || !favoritePlaylistNextPage || favoritePlaylistLoading || !favoritePlaylistTracks.length;
      favoriteMore.disabled = favoritePlaylistLoading;
      favoriteMore.textContent = favoritePlaylistLoading ? "Loading favorites…" : "Load more favorites";
    }
    placeSearchMore();
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  }

  function scheduleCatalogSearch() {
    captureWorkspace();
    applyFilters();
  }

  async function selectTrack(track, startPlayback, options = {}) {
    const selectionToken = ++playbackSelectionToken;
    pendingSelectionToken = startPlayback ? selectionToken : 0;
    const explicitGroup = options?.group || null;
    const explicitTracks = Array.isArray(options?.tracks) ? options.tracks : null;
    const playlistSource = options?.source || view;
    const resolvedGroup = explicitGroup || (track.gameKey
      ? gameGroupsByKey.get(track.gameKey)
      : gameGroupsByConsoleGame.get(`${canonicalConsoleName(track.console)}\u0000${track.game}`));
    if (resolvedGroup) track = cacheTrack(resolvedGroup, track);
    const playingFavorites = playlistSource === "favorites";
    const playingCollection = playingFavorites || playlistSource === "recent" || playlistSource === "queue";
    if (track.gameKey && !playingCollection) {
      selectGame(track.gameKey);
      const selectedGroup = gameGroupsByKey.get(track.gameKey);
      if (selectedGroup) {
        const selectedSystem = selectedGroup.system?.el || selectedGroup.details?.closest?.(".spcboy-system");
        if (selectedSystem) selectedSystem.open = true;
        if (!isDesktop() && selectedGroup.details) selectedGroup.details.open = true;
      }
    }
    syncCurrentTrackRows(currentTrack?.id, false);
    currentTrack = track;
    syncCurrentTrackRows(track.id, true);

    if (view === "recent") applyFilters();
    scheduleSelectionIndicators();

    if (startPlayback) {
      try {
        const query = search.value.trim();
        let albumTracks;
        if (explicitTracks) {
          albumTracks = explicitTracks;
        } else if (playlistSource === "recent") {
          albumTracks = collectionTracks().filter(candidate => candidate.available !== false && (!selectedGameKey || candidate.gameKey === selectedGameKey));
        } else if (playingFavorites) {
          const favoriteTracks = typeof favoritePlaylistLoaded !== "undefined" && favoritePlaylistLoaded
            ? favoritePlaylistTracks
            : await loadFavoritePlaylist({ allPages: true });
          albumTracks = favoriteTracks.filter(candidate =>
            (!selectedGameKey || candidate.gameKey === selectedGameKey) &&
            matchesTrackQuery(candidate, query));
        } else if (resolvedGroup) {
          albumTracks = resolvedGroup.loaded && Array.isArray(resolvedGroup.tracks) && resolvedGroup.tracks.length
            ? resolvedGroup.tracks
            : await ensureAlbumTracks(resolvedGroup, { retry: Boolean(resolvedGroup.loadFailed) });
        } else {
          albumTracks = [];
        }
        if (selectionToken !== playbackSelectionToken) return;
        if (pendingSelectionToken === selectionToken) pendingSelectionToken = 0;
        const containsTarget = albumTracks.some((candidate) => candidate && candidate.id === track.id);
        const playlist = containsTarget && albumTracks.length ? albumTracks : [track];
        await window.SitePlayer?.playPlaylist(playlist, {
          startTrackId: track.id,
          startTrack: track,
          toggle: isDesktop(),
        });
      } finally {
        if (pendingSelectionToken === selectionToken) pendingSelectionToken = 0;
      }
      return;
    }
    await window.SitePlayer?.play(track, { toggle: false });
  }

  search.addEventListener("input", scheduleCatalogSearch);
  for (const control of playlistColumnControls) {
    control.addEventListener("change", () => {
      playlistColumnVisibility[control.dataset.spcboyColumn] = control.checked;
      applyPlaylistColumnVisibility();
      savePlaylistColumnSettings();
    });
  }
  const playlistContentObserver = new MutationObserver(schedulePlaylistColumnLayout);
  playlistContentObserver.observe(playlistContent, { childList: true, subtree: true });
  const playlistResizeObserver = new ResizeObserver(schedulePlaylistColumnLayout);
  playlistResizeObserver.observe(playlistPane);
  playlistResizeObserver.observe(playlistContent);
  playlistContent.addEventListener("scroll", syncPlaylistHeaderScroll, {passive:true});
  document.fonts.ready.then(schedulePlaylistColumnLayout);
  window.addEventListener("resize", schedulePlaylistColumnLayout, { passive: true });
  document.addEventListener("sb:interface-changed", schedulePlaylistColumnLayout);
  shuffleFavoritesButton.addEventListener("click", async () => {
    const playlist = await loadFavoritePlaylist({ allPages: true });
    if (!playlist.length) {
      if (!favoritePlaylistFailed) playerState.textContent = "Favorite a track or album to build your Favorites playlist.";
      return;
    }
    window.SitePlayer?.playPlaylist(playlist, { shuffle: true });
  });
  desktopLayout.addEventListener("change", () => {
    placeMobileSettingsPages();
    setMobileAppPage(mobileAppPage, { syncView: false });
    syncSidebarAlbumFavorites();
    syncViewButtons();
    hoveredSidebarItem = null;
    hoveredPlaylistRow = null;
    lastPlaylistIndicatorTrackId = null;
    syncResponsiveLists();
    if (search.value.trim()) scheduleCatalogSearch();
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  });
  foldAllButton?.addEventListener("click", () => {
    const anyOpen = systemRecords.some((rec) => rec.el.open)
      || Boolean(trackList.querySelector(".spcboy-game[open]"));
    if (anyOpen) {
      for (const rec of systemRecords) {
        rec.el.open = false;
        if (rec.rendered) {
          for (const entry of rec.entries) {
            if (entry.details) entry.details.open = false;
          }
        }
      }
    } else {
      for (const rec of systemRecords) {
        if (rec.el.hidden) continue;
        rec.el.open = true;
        if (isDesktop()) ensureConsoleContentRendered(rec);
      }
    }
    hoveredSidebarItem = null;
    scheduleSelectionIndicators();
  });
  const sidebarTree = document.querySelector(".spcboy-tree");
  sidebarTree?.addEventListener("pointermove", (event) => {
    if (event.pointerType === "touch") {
      if (hoveredSidebarItem) {
        hoveredSidebarItem = null;
        scheduleSelectionIndicators();
      }
      return;
    }
    const target = event.target instanceof Element ? event.target.closest(".spcboy-system > summary, .spcboy-game > summary, .spcboy-track") : null;
    if (target !== hoveredSidebarItem) {
      hoveredSidebarItem = target;
      scheduleSelectionIndicators();
    }
  }, { passive: true });
  sidebarTree?.addEventListener("pointerleave", () => { hoveredSidebarItem = null; scheduleSelectionIndicators(); });
  sidebarTree?.addEventListener("scroll", scheduleSelectionIndicators, { passive: true });
  playlistContent?.addEventListener("pointermove", (event) => {
    if (event.pointerType === "touch") {
      if (hoveredPlaylistRow) {
        hoveredPlaylistRow = null;
        scheduleSelectionIndicators();
      }
      return;
    }
    const target = event.target instanceof Element ? event.target.closest(".spcboy-track")?.closest(".spcboy-track-row") : null;
    if (target !== hoveredPlaylistRow) {
      hoveredPlaylistRow = target;
      scheduleSelectionIndicators();
    }
  }, { passive: true });
  playlistContent?.addEventListener("pointerleave", () => { hoveredPlaylistRow = null; scheduleSelectionIndicators(); });
  playlistContent?.addEventListener("scroll", scheduleSelectionIndicators, { passive: true });
  window.addEventListener("resize", scheduleSelectionIndicators);
  for (const tab of tabs) {
    tab.addEventListener("click", () => {
      view = tab.dataset.view;
      storage.set("view", view);
      if (view === "favorites" || view === "recent") selectedGameKey = null;
      syncViewButtons();
      captureWorkspace();
      scheduleSelectionIndicators();
      if (search.value.trim()) scheduleCatalogSearch();
      else applyFilters();
      if (view === "recent") loadRecents(true);
      if (view === "favorites") loadFavoritePlaylist();
    });
  }
  function formatMobileTime(value) {
    if (value === Infinity) return "∞";
    const seconds = Math.max(0, Math.floor(Number(value) || 0));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainder = seconds % 60;
    return hours
      ? `${hours}:${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`
      : `${minutes}:${String(remainder).padStart(2, "0")}`;
  }
  function parseMobileTime(value) {
    if (value === "∞") return Infinity;
    const parts = String(value || "0:00").split(":").map(Number);
    if (parts.some(part => !Number.isFinite(part))) return 0;
    return parts.reduce((total, part) => total * 60 + part, 0);
  }
  let mobileTrackListAlbumId = "";
  let mobileTrackListGeneration = 0;
  let mobileLibraryRenderToken = 0;
  let mobileToastTimer = null;
  let openMobileConsole = "";
  let openMobileAlbumId = "";

  function debounceMobileInput(callback, delay = 150) {
    let timer = null;
    return (...args) => {
      window.clearTimeout(timer);
      timer = window.setTimeout(() => {
        timer = null;
        callback(...args);
      }, delay);
    };
  }

  function showMobileToast(message) {
    if (!mobileToast) return;
    mobileToast.textContent = message;
    mobileToast.classList.add("is-visible");
    window.clearTimeout(mobileToastTimer);
    mobileToastTimer = window.setTimeout(() => {
      mobileToast.classList.remove("is-visible");
    }, 1500);
  }

  function mobileGroupForTrack(track) {
    if (!track) return null;
    const albumId = track.albumId
      || String(track.albumPlaylistUrl || "").match(/\/spcboy\/album\/([0-9a-f]{32})\.json(?:$|\?)/)?.[1]
      || "";
    return (albumId && gameGroupsByAlbumId.get(albumId))
      || (track.console && track.game
        ? gameGroupsByConsoleGame.get(`${canonicalConsoleName(track.console)}\u0000${track.game}`)
        : null)
      || (track.gameKey ? gameGroupsByKey.get(track.gameKey) : null)
      || null;
  }

  function setMobileAppPage(nextPage, { syncView = true } = {}) {
    if (!mobileAppNav) return;
    if (!["playing", "library", "recent", "favorites", "sound", "nav", "admin"].includes(nextPage)) return;
    mobileAppPage = nextPage;
    if (syncView && !isDesktop()) {
      const mobileViewMap = { library: "all", recent: "recent", favorites: "favorites" };
      if (nextPage in mobileViewMap && view !== mobileViewMap[nextPage]) {
        view = mobileViewMap[nextPage];
        storage.set("view", view);
        syncViewButtons();
      }
    }
    const navButtons = mobileAppNav.querySelectorAll("[data-mobile-app-page]");
    for (const button of navButtons) {
      const targetPage = button.dataset.mobileAppPage;
      const selected = targetPage === nextPage || (targetPage === "nav" && nextPage === "admin");
      if (selected) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    }
    if (mobileScreenPlaying) mobileScreenPlaying.classList.toggle("is-hidden", nextPage !== "playing");
    if (mobileScreenLibrary) mobileScreenLibrary.classList.toggle("is-hidden", nextPage !== "library");
    if (mobileScreenRecent) mobileScreenRecent.classList.toggle("is-hidden", nextPage !== "recent");
    if (mobileScreenFavorites) mobileScreenFavorites.classList.toggle("is-hidden", nextPage !== "favorites");
    if (mobileScreenSound) mobileScreenSound.classList.toggle("is-hidden", nextPage !== "sound");
    if (mobileScreenNav) mobileScreenNav.classList.toggle("is-hidden", nextPage !== "nav");
    if (mobileScreenAdmin) mobileScreenAdmin.classList.toggle("is-hidden", nextPage !== "admin");

    if (mobileDock) {
      mobileDock.classList.toggle("is-hidden", nextPage === "playing");
    }

    try {
      if (nextPage === "playing") renderMobileNowPlaying();
      else if (nextPage === "library") renderMobileLibrary();
      else if (nextPage === "recent") renderMobileRecents();
      else if (nextPage === "favorites") renderMobileFavorites();
      else if (nextPage === "sound") syncMobileSoundControls();
      else if (nextPage === "admin") void loadMobileAdmin();
    } catch (err) {
      console.warn("Mobile page render warning:", err);
    }
  }

  function renderMobileLibrary() {
    const tree = document.querySelector("#spcboy-mobile-library-tree");
    const searchInput = document.querySelector("#spcboy-mobile-library-search");
    if (!tree) return;
    const renderToken = ++mobileLibraryRenderToken;
    if (!catalogAvailable && !gameGroups.length) {
      tree.innerHTML = '<p class="spcboy-mobile-empty">Loading hosted games…</p>';
      return;
    }
    const query = (searchInput?.value || "").trim().toLowerCase();
    let consoles = Array.isArray(rawCatalog?.consoles) ? rawCatalog.consoles : [];
    if (!consoles.length && gameGroups.length) {
      const names = [...new Set(gameGroups.map((g) => g.consoleName))];
      consoles = names.map((name) => ({ name, games: gameGroups.filter((g) => g.consoleName === name) }));
    }
    const frag = document.createDocumentFragment();

    consoles.forEach((consoleData) => {
      const consoleName = canonicalConsoleName(consoleData.name);
      const games = gameGroups.filter((group) => {
        if (group.consoleName !== consoleName) return false;
        if (!query) return true;
        return group.gameName.toLowerCase().includes(query)
          || (group.tracks && group.tracks.some(t => (t.title || "").toLowerCase().includes(query)));
      });
      if (!games.length) return;

      const isOpen = openMobileConsole === consoleName || Boolean(query);
      const groupSection = document.createElement("section");
      groupSection.className = "spcboy-mobile-console-group";

      const toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "spcboy-mobile-console-toggle";
      toggle.setAttribute("aria-expanded", String(isOpen));

      const name = document.createElement("span");
      name.className = "spcboy-mobile-console-name";
      name.textContent = consoleName;

      const count = document.createElement("span");
      count.className = "spcboy-mobile-console-count";
      count.textContent = `${games.length} album${games.length === 1 ? "" : "s"}`;

      const chevron = document.createElement("span");
      chevron.className = "spcboy-mobile-console-chevron";
      chevron.setAttribute("aria-hidden", "true");
      chevron.textContent = isOpen ? "⌄" : "›";

      toggle.append(name, count, chevron);
      toggle.addEventListener("click", () => {
        openMobileConsole = openMobileConsole === consoleName ? "" : consoleName;
        openMobileAlbumId = "";
        renderMobileLibrary();
      });
      groupSection.append(toggle);

      if (isOpen) {
        const albumsContainer = document.createElement("div");
        albumsContainer.className = "spcboy-mobile-console-albums";

        games.forEach((gameEntry) => {
          const albumEntry = document.createElement("div");
          albumEntry.className = "spcboy-mobile-album-entry";

          const isAlbumOpen = openMobileAlbumId === gameEntry.key || (Boolean(query) && gameEntry.gameName.toLowerCase().includes(query));
          const albumToggle = document.createElement("button");
          albumToggle.type = "button";
          albumToggle.className = "spcboy-mobile-album-toggle";
          albumToggle.setAttribute("aria-expanded", String(isAlbumOpen));

          const albumTitle = document.createElement("span");
          albumTitle.className = "spcboy-mobile-album-title";
          albumTitle.textContent = gameEntry.gameName;

          const albumCount = document.createElement("span");
          albumCount.className = "spcboy-mobile-album-count";
          albumCount.textContent = `${gameEntry.trackCount} track${gameEntry.trackCount === 1 ? "" : "s"}`;

          const albumChevron = document.createElement("span");
          albumChevron.className = "spcboy-mobile-album-chevron";
          albumChevron.textContent = isAlbumOpen ? "⌄" : "›";

          albumToggle.append(albumTitle, albumCount, albumChevron);
          albumToggle.addEventListener("click", () => {
            openMobileAlbumId = openMobileAlbumId === gameEntry.key ? "" : gameEntry.key;
            renderMobileLibrary();
          });
          albumEntry.append(albumToggle);

          if (isAlbumOpen) {
            const inlineTracks = document.createElement("div");
            inlineTracks.className = "spcboy-mobile-inline-tracks";
            const trackItems = document.createElement("div");
            trackItems.className = "spcboy-mobile-inline-track-items";
            inlineTracks.append(trackItems);

            if (gameEntry.loaded && gameEntry.tracks.length) {
              renderInlineTrackList(gameEntry, trackItems, query);
            } else {
              const loadingEl = document.createElement("div");
              loadingEl.className = "spcboy-mobile-track";
              loadingEl.textContent = "Loading tracks…";
              trackItems.append(loadingEl);
              ensureAlbumTracks(gameEntry).then((tracks) => {
                if (renderToken !== mobileLibraryRenderToken || !trackItems.isConnected) return;
                trackItems.replaceChildren();
                if (!tracks.length && gameEntry.loadFailed) {
                  const retryBtn = document.createElement("button");
                  retryBtn.type = "button";
                  retryBtn.className = "spcboy-mobile-track spcboy-mobile-track-retry";
                  retryBtn.textContent = "Could not load tracks · Tap to retry";
                  retryBtn.addEventListener("click", () => {
                    ensureAlbumTracks(gameEntry, { retry: true }).then(() => renderMobileLibrary());
                  });
                  trackItems.append(retryBtn);
                  return;
                }
                renderInlineTrackList(gameEntry, trackItems, query);
              });
            }

            albumEntry.append(inlineTracks);
          }
          albumsContainer.append(albumEntry);
        });
        groupSection.append(albumsContainer);
      }
      frag.append(groupSection);
    });

    if (!frag.childElementCount) {
      const empty = document.createElement("p");
      empty.className = "spcboy-mobile-empty";
      empty.textContent = "No matching games or tracks.";
      frag.append(empty);
    }
    tree.replaceChildren(frag);
  }

  function createMobileTrackFavoriteButton(track) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "site-favorite-toggle spcboy-mobile-track-favorite";
    button.dataset.siteFavoriteToggle = "";
    button.dataset.favoriteKind = "track";
    button.dataset.favoriteId = track.id;
    button.dataset.favoriteTitle = track.title || track.id;
    button.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><use href="#icon-star"/></svg>';
    setTrackFavoriteButton(button, favorites.has(track.id));
    return button;
  }

  function createMobileTrackRowItem(track, idx, { subtitle = null, isPlaying = false, onPlay } = {}) {
    const row = document.createElement("li");
    row.className = "spcboy-mobile-track-item" + (isPlaying ? " is-playing" : "");

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "spcboy-mobile-track-row spcboy-mobile-recent-track-row" + (isPlaying ? " is-playing" : "");
    btn.dataset.trackId = track.id;

    const num = document.createElement("span");
    num.className = "spcboy-mobile-track-num";
    num.textContent = String(idx + 1).padStart(2, "0");

    if (subtitle !== null) {
      const info = document.createElement("div");
      info.className = "spcboy-mobile-recent-info";
      const title = document.createElement("span");
      title.className = "spcboy-mobile-track-title";
      title.textContent = track.title || track.id;
      const meta = document.createElement("span");
      meta.className = "spcboy-mobile-recent-meta";
      meta.textContent = subtitle;
      info.append(title, meta);
      btn.append(num, info);
    } else {
      const title = document.createElement("span");
      title.className = "spcboy-mobile-track-title";
      title.textContent = track.title || track.id;
      btn.append(num, title);
    }

    btn.onclick = (e) => {
      e.preventDefault();
      onPlay?.(btn, num);
    };

    row.append(btn, createMobileTrackFavoriteButton(track));
    return row;
  }

  function renderInlineTrackList(gameEntry, container, query) {
    const activeTrack = window.SitePlayer?.getCurrentTrack?.() || currentTrack;
    gameEntry.tracks.forEach((track, idx) => {
      if (query && !track.title.toLowerCase().includes(query) && !gameEntry.gameName.toLowerCase().includes(query)) return;
      const row = document.createElement("div");
      row.className = "spcboy-mobile-inline-track-row" + (activeTrack?.id === track.id ? " is-playing" : "");
      const trackBtn = document.createElement("button");
      trackBtn.type = "button";
      trackBtn.className = "spcboy-mobile-track" + (activeTrack?.id === track.id ? " is-playing" : "");
      const num = document.createElement("span");
      num.textContent = String(idx + 1).padStart(2, "0");
      const titleSpan = document.createElement("span");
      titleSpan.className = "spcboy-mobile-track-title";
      titleSpan.textContent = track.title || track.id;
      trackBtn.append(num, titleSpan);
      trackBtn.addEventListener("click", () => {
        selectTrack(track, true, { source: "album", group: gameEntry, tracks: gameEntry.tracks });
        setMobileAppPage("playing");
      });
      row.append(trackBtn, createMobileTrackFavoriteButton(track));
      container.append(row);
    });
  }

  let activeFaderAnimationId = null;
  let currentMobileEqPreset = 0;

  function updateMobileEqToolbar(activeMode) {
    document.querySelectorAll("[data-mobile-eq-mode]").forEach((btn) => {
      const mode = btn.dataset.mobileEqMode;
      const isActive = String(mode) === String(activeMode);
      btn.classList.toggle("is-active", isActive);
      btn.setAttribute("aria-pressed", String(isActive));
    });
  }

  function animateMobileFaders(targetGains, { duration = 240, onComplete } = {}) {
    if (activeFaderAnimationId) {
      cancelAnimationFrame(activeFaderAnimationId);
      activeFaderAnimationId = null;
    }
    const sliders = [...document.querySelectorAll("[data-mobile-eq-band]")];
    if (!sliders.length) {
      if (typeof onComplete === "function") onComplete();
      return;
    }
    const outputs = sliders.map((s) => document.querySelector(`[data-mobile-eq-value="${Number(s.dataset.mobileEqBand)}"]`));
    const startGains = sliders.map((s) => Number(s.value) || 0);
    const startTime = performance.now();

    function easeOutCubic(t) {
      return 1 - Math.pow(1 - t, 3);
    }

    function step(now) {
      const elapsed = now - startTime;
      const progress = Math.min(1, elapsed / duration);
      const eased = easeOutCubic(progress);

      sliders.forEach((slider, idx) => {
        const start = startGains[idx];
        const target = targetGains[idx] ?? 0;
        const current = start + (target - start) * eased;
        slider.value = current.toFixed(1);
        const output = outputs[idx];
        if (output) {
          const rounded = Math.round(current * 2) / 2;
          output.textContent = (rounded > 0 ? "+" : "") + rounded.toFixed(1);
        }
      });

      if (progress < 1) {
        activeFaderAnimationId = requestAnimationFrame(step);
      } else {
        activeFaderAnimationId = null;
        sliders.forEach((slider, idx) => {
          const target = targetGains[idx] ?? 0;
          slider.value = String(target);
          const output = outputs[idx];
          if (output) {
            output.textContent = (target > 0 ? "+" : "") + target.toFixed(1);
          }
        });
        if (typeof onComplete === "function") onComplete();
      }
    }
    activeFaderAnimationId = requestAnimationFrame(step);
  }

  function syncMobileSoundControls() {
    if (!window.SitePlayer) return;
    const vol = window.SitePlayer.getVolume?.();
    const volInput = document.querySelector("#spcboy-mobile-volume");
    const volValue = document.querySelector("#spcboy-mobile-volume-value");
    if (volInput && typeof vol === "number") volInput.value = String(vol);
    if (volValue && typeof vol === "number") volValue.textContent = `${Math.round(vol * 5)}%`;

    const eqEnabled = Boolean(window.SitePlayer.isEqualizerEnabled?.());
    const sharedPreset = window.SitePlayer.getSelectedEqualizerPresetIndex?.();
    if (typeof sharedPreset === "number" && Number.isInteger(sharedPreset)) {
      currentMobileEqPreset = sharedPreset;
    }
    const activePreset = typeof currentMobileEqPreset === "number" ? currentMobileEqPreset : 0;
    updateMobileEqToolbar(activePreset);
    const mobileEqToggle = document.querySelector("#spcboy-mobile-equalizer");
    if (mobileEqToggle) {
      mobileEqToggle.setAttribute("aria-checked", String(eqEnabled));
      mobileEqToggle.textContent = eqEnabled ? "ON" : "OFF";
    }
    document.querySelector(".spcboy-mobile-eq-bands")?.classList?.toggle("is-inactive", !eqEnabled);

    const gains = window.SitePlayer.getEqualizerBands?.() || [];
    gains.forEach((gain, idx) => {
      const input = document.querySelector(`[data-mobile-eq-band="${idx}"]`);
      const output = document.querySelector(`[data-mobile-eq-value="${idx}"]`);
      if (input && activeFaderAnimationId === null) input.value = String(gain);
      if (output && activeFaderAnimationId === null) output.textContent = (gain > 0 ? "+" : "") + Number(gain).toFixed(1);
    });

    const skips = window.SitePlayer.getFadedSkips?.();
    const skipToggle = document.querySelector("#spcboy-mobile-faded-skip");
    const fadeInput = document.querySelector("#spcboy-mobile-fade-seconds");
    if (skipToggle && skips) {
      skipToggle.setAttribute("aria-checked", String(skips.enabled));
      skipToggle.textContent = skips.enabled ? "Yes" : "No";
    }
    if (fadeInput && skips) fadeInput.value = String(skips.seconds);

    const speed = window.SitePlayer.getPlaybackSpeed?.();
    const speedToggle = document.querySelector("#spcboy-mobile-speed-enabled");
    const speedFraction = document.querySelector("#spcboy-mobile-speed");
    if (speedToggle && speed) {
      speedToggle.setAttribute("aria-checked", String(speed.enabled));
      speedToggle.textContent = speed.enabled ? "Yes" : "No";
    }
    if (speedFraction && speed) speedFraction.value = speed.fraction;

    const longPlay = window.SitePlayer.getLongPlay?.();
    const lpToggle = document.querySelector("#spcboy-mobile-long-play");
    const lpInput = document.querySelector("#spcboy-mobile-long-play-duration");
    if (lpToggle && longPlay) {
      lpToggle.setAttribute("aria-checked", String(longPlay.enabled));
      lpToggle.textContent = longPlay.enabled ? "Yes" : "No";
    }
    const fmt = window.SitePlayer?.formatPlaybackTime || formatMobileTime;
    if (lpInput && longPlay) lpInput.value = fmt(longPlay.seconds);
  }

  let currentRenderedNowAlbumKey = null;

  function showMobileLoadingIndicator(text = "Preparing audio stream…") {
    const artLoading = document.querySelector("#spcboy-mobile-art-loading");
    const loadingText = artLoading?.querySelector(".spcboy-mobile-loading-text");
    const dockSpinner = document.querySelector("#spcboy-mobile-dock-spinner");
    if (loadingText) loadingText.textContent = text;
    if (artLoading) artLoading.classList.remove("is-hidden");
    if (dockSpinner) dockSpinner.classList.remove("is-hidden");
  }

  function hideMobileLoadingIndicator() {
    const artLoading = document.querySelector("#spcboy-mobile-art-loading");
    const dockSpinner = document.querySelector("#spcboy-mobile-dock-spinner");
    if (artLoading) artLoading.classList.add("is-hidden");
    if (dockSpinner) dockSpinner.classList.add("is-hidden");
    document.querySelectorAll(".spcboy-mobile-track-row.is-loading").forEach((el) => el.classList.remove("is-loading"));
  }

  function renderMobileNowAlbumTracks(activeTrack) {
    const listEl = document.querySelector("#spcboy-mobile-now-tracklist");
    const countEl = document.querySelector("#spcboy-mobile-now-album-count");
    const headingEl = document.querySelector("#spcboy-mobile-now-album-heading");
    const statusEl = document.querySelector("#spcboy-mobile-now-tracklist-status");
    if (!listEl) return;

    if (!activeTrack) {
      currentRenderedNowAlbumKey = null;
      listEl.replaceChildren();
      if (countEl) countEl.textContent = "";
      if (headingEl) headingEl.textContent = "Album Tracks";
      return;
    }

    const group = mobileGroupForTrack(activeTrack);
    const albumKey = group?.key || activeTrack.gameKey || activeTrack.albumId || activeTrack.game || "unknown";
    const albumName = activeTrack.game || group?.gameName || "Album Tracks";
    if (headingEl) headingEl.textContent = albumName;

    // Fast-path: if this album's DOM is already built, DO NOT wipe children or re-create elements.
    // Simply update the active .is-playing row state in place.
    // This stops ALL jumpiness, scroll jumping, and touch-interruptions when songs change or time updates!
    if (currentRenderedNowAlbumKey === albumKey && listEl.children.length > 0) {
      const rows = listEl.querySelectorAll(".spcboy-mobile-track-row");
      for (const row of rows) {
        const isPlaying = row.dataset.trackId === activeTrack.id;
        row.classList.toggle("is-playing", isPlaying);
        row.closest(".spcboy-mobile-track-item")?.classList.toggle("is-playing", isPlaying);
        if (isPlaying) row.classList.remove("is-loading");
      }
      return;
    }

    currentRenderedNowAlbumKey = albumKey;

    if (group) {
      if (countEl) countEl.textContent = `${group.trackCount || group.tracks?.length || ""} tracks`;
      ensureAlbumTracks(group, { retry: group.loadFailed }).then((tracks) => {
        if (currentRenderedNowAlbumKey !== albumKey) return;
        if (!tracks.length && group.loadFailed) {
          currentRenderedNowAlbumKey = null;
          if (statusEl) {
            statusEl.textContent = "Could not load album tracks. Tap to retry.";
            statusEl.classList.remove("is-hidden");
            statusEl.onclick = () => {
              statusEl.onclick = null;
              renderMobileNowAlbumTracks(activeTrack);
            };
          }
          return;
        }
        if (statusEl) {
          statusEl.onclick = null;
          statusEl.classList.add("is-hidden");
        }
        listEl.replaceChildren();
        tracks.forEach((track, idx) => {
          const isPlaying = track.id === activeTrack.id;
          listEl.append(createMobileTrackRowItem(track, idx, {
                        isPlaying,
            onPlay: (btn) => {
              btn.classList.add("is-loading");
              showMobileLoadingIndicator(track.title || "Loading track…");
              selectTrack(track, true, { source: "album", group, tracks });
            },
          }));
        });
      }).catch(() => {
        if (statusEl) {
          statusEl.textContent = "Could not load album tracks.";
          statusEl.classList.remove("is-hidden");
        }
      });
      return;
    }

    const queueTracks = [activeTrack, ...(window.SitePlayer?.getQueue?.() || [])];
    if (countEl) countEl.textContent = `${queueTracks.length} tracks`;
    listEl.replaceChildren();
    queueTracks.forEach((track, idx) => {
      const isPlaying = track.id === activeTrack.id;
      listEl.append(createMobileTrackRowItem(track, idx, {
                isPlaying,
        onPlay: (btn) => {
          btn.classList.add("is-loading");
          showMobileLoadingIndicator(track.title || "Loading track…");
          selectTrack(track, true, { source: "queue", tracks: queueTracks });
        },
      }));
    });
  }

  function renderMobileRecents() {
    const listEl = document.querySelector("#spcboy-mobile-recent-tracks");
    const countEl = document.querySelector("#spcboy-mobile-recent-count");
    const emptyEl = document.querySelector("#spcboy-mobile-recent-empty");
    const moreBtn = document.querySelector("#spcboy-mobile-recent-more");
    const searchInput = document.querySelector("#spcboy-mobile-recent-search");
    if (!listEl) return;

    if (!recentLoaded && !recentLoading) {
      loadRecents(false).then(() => renderMobileRecents()).catch(() => {});
    }

    if (recentLoading && !recentEntries.length) {
      if (emptyEl) {
        emptyEl.textContent = "Loading your recent plays…";
        emptyEl.classList.remove("is-hidden");
      }
      listEl.replaceChildren();
      return;
    }

    const query = (searchInput?.value || "").trim().toLowerCase();
    const tracks = recentPlaylistTracks().filter((track) => {
      if (!query) return true;
      return (track.title || "").toLowerCase().includes(query)
        || (track.game || "").toLowerCase().includes(query)
        || (track.console || "").toLowerCase().includes(query);
    });

    if (countEl) {
      countEl.textContent = `${tracks.length} track${tracks.length === 1 ? "" : "s"}`;
    }

    if (!tracks.length) {
      listEl.replaceChildren();
      if (emptyEl) {
        emptyEl.textContent = query ? "No recent plays match your search." : "No recently played tracks yet.";
        emptyEl.classList.remove("is-hidden");
      }
      if (moreBtn) moreBtn.classList.add("is-hidden");
      return;
    }

    if (emptyEl) emptyEl.classList.add("is-hidden");
    listEl.replaceChildren();

    const activeTrack = currentTrack || window.SitePlayer?.getCurrentTrack?.();

    tracks.forEach((track, idx) => {
      const isPlaying = Boolean(activeTrack && track.id === activeTrack.id);
      const subtitle = `${track.game || "Unknown Game"}${track.timestamp ? " · " + track.timestamp : ""}`;
      listEl.append(createMobileTrackRowItem(track, idx, {
                subtitle,
        isPlaying,
        onPlay: (btn) => {
          btn.classList.add("is-loading");
          showMobileLoadingIndicator(track.title || "Loading track…");
          selectTrack(track, true, { source: "recent", tracks });
        },
      }));
    });

    if (moreBtn) {
      const canLoadMore = recentNextPage !== null;
      moreBtn.classList.toggle("is-hidden", !canLoadMore);
      moreBtn.disabled = recentLoading;
      moreBtn.textContent = recentLoading ? "Loading…" : "Load more recent plays";
    }
  }

  function renderMobileFavorites() {
    const listEl = document.querySelector("#spcboy-mobile-favorites-tracks");
    const countEl = document.querySelector("#spcboy-mobile-favorites-count");
    const emptyEl = document.querySelector("#spcboy-mobile-favorites-empty");
    const searchInput = document.querySelector("#spcboy-mobile-favorites-search");
    if (!listEl) return;

    if (!favoritePlaylistLoaded && !favoritePlaylistLoading) {
      loadFavoritePlaylist({ allPages: true }).then(() => renderMobileFavorites()).catch(() => {});
    }

    if (favoritePlaylistLoading && !favoritePlaylistTracks.length) {
      if (emptyEl) {
        emptyEl.textContent = "Loading your favorites…";
        emptyEl.classList.remove("is-hidden");
      }
      listEl.replaceChildren();
      return;
    }

    const query = (searchInput?.value || "").trim().toLowerCase();
    const tracks = favoritePlaylistTracks.filter((track) => {
      if (!query) return true;
      return (track.title || "").toLowerCase().includes(query)
        || (track.game || track.gameTitle || "").toLowerCase().includes(query)
        || (track.console || track.system || "").toLowerCase().includes(query);
    });

    if (countEl) {
      countEl.textContent = String(tracks.length);
    }

    if (!tracks.length) {
      if (emptyEl) {
        emptyEl.textContent = query
          ? "No favorites matched your search."
          : "No favorite tracks yet. Star tracks in Library to build your Favorites.";
        emptyEl.classList.remove("is-hidden");
      }
      listEl.replaceChildren();
      return;
    }

    if (emptyEl) emptyEl.classList.add("is-hidden");
    const frag = document.createDocumentFragment();
    const activeTrack = currentTrack || window.SitePlayer?.getCurrentTrack?.();

    tracks.forEach((track, idx) => {
      const isPlaying = Boolean(activeTrack && track.id === activeTrack.id);
      const subtitle = [track.game || track.gameTitle, track.console || track.system].filter(Boolean).join(" · ");
      frag.append(createMobileTrackRowItem(track, idx, {
                subtitle,
        isPlaying,
        onPlay: (btn, num) => {
          btn.classList.add("is-loading");
          num.textContent = "⏳";
          showMobileLoadingIndicator(track.title || "Loading track…");
          window.SitePlayer?.playPlaylist(tracks, {
            startTrackId: track.id,
            startTrack: track,
            startIndex: idx,
            toggle: false,
          });
        },
      }));
    });

    listEl.replaceChildren(frag);
  }

  function renderMobileUpNext() {
    renderMobileNowAlbumTracks(currentTrack || window.SitePlayer?.getCurrentTrack?.());
  }

  const mobilePlaybackClock = document.querySelector("#spcboy-playback-clock");

  function updateMobilePlaybackProgress(track = currentTrack) {
    const activeTrack = track || window.SitePlayer?.getCurrentTrack?.() || null;
    const clockParts = mobilePlaybackClock?.textContent.split(" / ") || [];
    const elapsedText = activeTrack ? (clockParts[0] || "0:00") : "0:00";
    const durationText = activeTrack ? (clockParts[1] || formatMobileTime(window.SitePlayer?.getDuration?.(activeTrack))) : "0:00";
    if (mobileElapsed) mobileElapsed.textContent = elapsedText;
    if (mobileDuration) mobileDuration.textContent = durationText;

    const elapsed = parseMobileTime(elapsedText);
    const duration = parseMobileTime(durationText);
    const ratio = Number.isFinite(duration) && duration > 0 ? Math.max(0, Math.min(1, elapsed / duration)) : 0;
    const transform = `scaleX(${ratio})`;
    if (mobileDockProgressFill) mobileDockProgressFill.style.transform = transform;
  }

  function renderMobileNowPlaying(track = currentTrack) {
    const activeTrack = track || window.SitePlayer?.getCurrentTrack?.() || null;
    const matchingGroup = mobileGroupForTrack(activeTrack);
    const artworkURL = activeTrack
      ? (activeTrack.artworkUrl || tracksById.get(activeTrack.id)?.artworkUrl || matchingGroup?.artworkUrl || "")
      : "";

    if (mobileNowTitle) mobileNowTitle.textContent = activeTrack?.title || "Nothing playing";
    if (mobileNowAlbum) mobileNowAlbum.textContent = activeTrack?.game || matchingGroup?.gameName || activeTrack?.console || "";
    if (mobileNowArtwork) {
      mobileNowArtwork.alt = artworkURL ? `${activeTrack.game || activeTrack.title} artwork` : "";
      if (artworkURL && mobileNowArtwork.getAttribute("src") !== artworkURL) mobileNowArtwork.src = artworkURL;
      if (!artworkURL) mobileNowArtwork.removeAttribute("src");
    }

    const playing = Boolean(activeTrack && window.SitePlayer?.isPlaying?.());
    if (mobilePlayButton) {
      mobilePlayButton.disabled = !activeTrack;
      mobilePlayButton.textContent = playing ? "Ⅱ" : "▶";
      mobilePlayButton.setAttribute("aria-label", playing ? "Pause" : "Play");
    }
    if (mobilePreviousButton) mobilePreviousButton.disabled = !activeTrack;
    if (mobileNextButton) mobileNextButton.disabled = !activeTrack;

    // Update Dock
    if (mobileDockTitle) mobileDockTitle.textContent = activeTrack?.title || "Nothing playing";
    if (mobileDockSubtitle) mobileDockSubtitle.textContent = activeTrack ? `${activeTrack.game || matchingGroup?.gameName || ""} · ${activeTrack.console || ""}` : "";
    if (mobileDockArt) {
      if (artworkURL && mobileDockArt.getAttribute("src") !== artworkURL) mobileDockArt.src = artworkURL;
      if (!artworkURL) mobileDockArt.removeAttribute("src");
    }
    if (mobileDockPlay) {
      mobileDockPlay.disabled = !activeTrack;
      mobileDockPlay.textContent = playing ? "Ⅱ" : "▶";
      mobileDockPlay.setAttribute("aria-label", playing ? "Pause" : "Play");
    }

    updateMobilePlaybackProgress(activeTrack);
    renderMobileNowAlbumTracks(activeTrack);
  }

  mobileApp?.addEventListener("click", (event) => {
    const rawTarget = event.target && event.target.nodeType === 3 ? event.target.parentElement : event.target;
    const btn = rawTarget && typeof rawTarget.closest === "function" ? rawTarget.closest("[data-mobile-app-page]") : null;
    if (!btn) return;
    event.preventDefault();
    const nextPage = btn.dataset.mobileAppPage;
    if (nextPage) setMobileAppPage(nextPage);
  });

    const dockMain = document.querySelector("#spcboy-mobile-dock-main");
  if (dockMain) {
    dockMain.onclick = (event) => {
      const rawTarget = event.target && event.target.nodeType === 3 ? event.target.parentElement : event.target;
      if (rawTarget && typeof rawTarget.closest === "function" && rawTarget.closest("#spcboy-mobile-dock-play")) return;
      event.preventDefault();
      setMobileAppPage("playing");
    };
  }

  const dockPlayBtn = document.querySelector("#spcboy-mobile-dock-play");
  if (dockPlayBtn) {
    dockPlayBtn.onclick = (event) => {
      event.stopPropagation();
      event.preventDefault();
      window.SitePlayer?.togglePlayback?.();
    };
  }

  if (mobilePlayButton) {
    mobilePlayButton.onclick = (event) => {
      event.preventDefault();
      window.SitePlayer?.togglePlayback?.();
    };
  }
  if (mobilePreviousButton) {
    mobilePreviousButton.onclick = (event) => {
      event.preventDefault();
      window.SitePlayer?.previous?.();
    };
  }
  if (mobileNextButton) {
    mobileNextButton.onclick = (event) => {
      event.preventDefault();
      window.SitePlayer?.next?.();
    };
  }

  const mobileVolSlider = document.querySelector("#spcboy-mobile-volume");
  if (mobileVolSlider) {
    const handleMobileVol = (e) => {
      const val = Number(e.target.value);
      window.SitePlayer?.setVolume?.(val);
      const valEl = document.querySelector("#spcboy-mobile-volume-value");
      if (valEl) valEl.textContent = `${Math.round(val * 5)}%`;
    };
    mobileVolSlider.addEventListener("input", handleMobileVol);
    mobileVolSlider.addEventListener("change", handleMobileVol);
  }

  document.querySelectorAll("[data-mobile-eq-mode]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const presetIdx = Number(btn.dataset.mobileEqMode);
      if (!Number.isInteger(presetIdx) || presetIdx < 0 || presetIdx > 2) return;
      currentMobileEqPreset = presetIdx;
      const presets = window.SitePlayer?.getEqualizerPresets?.() || [];
      const preset = presets[presetIdx];
      const targetGains = preset?.gains && preset.saved ? preset.gains : Array(10).fill(0);
      updateMobileEqToolbar(presetIdx);
      animateMobileFaders(targetGains, { duration: 240 });
      await window.SitePlayer?.applyEqualizerPreset?.(presetIdx);
      showMobileToast(preset?.saved ? `Preset ${presetIdx + 1} loaded` : `Preset ${presetIdx + 1} (Flat)`);
    });
  });

  const mobileEqToggleBtn = document.querySelector("#spcboy-mobile-equalizer");
  if (mobileEqToggleBtn) {
    mobileEqToggleBtn.addEventListener("click", async () => {
      const nextEnabled = !window.SitePlayer?.isEqualizerEnabled?.();
      await window.SitePlayer?.setEqualizerEnabled?.(nextEnabled);
      syncMobileSoundControls();
      showMobileToast(nextEnabled ? "Equalizer ON" : "Equalizer OFF");
    });
  }

  document.querySelectorAll("[data-mobile-eq-band]").forEach((input) => {
    input.addEventListener("input", () => {
      const idx = Number(input.dataset.mobileEqBand);
      const val = Number(input.value);
      window.SitePlayer?.setEqualizerBandGain?.(idx, val);
      const output = document.querySelector(`[data-mobile-eq-value="${idx}"]`);
      if (output) output.textContent = (val > 0 ? "+" : "") + val.toFixed(1);
      updateMobileEqToolbar(currentMobileEqPreset);
    });
  });

  const resetFlatBtn = document.querySelector("#spcboy-mobile-reset-flat");
  if (resetFlatBtn) {
    resetFlatBtn.onclick = () => {
      animateMobileFaders(Array(10).fill(0), { duration: 240 });
      window.SitePlayer?.resetEqualizer?.();
      updateMobileEqToolbar(currentMobileEqPreset);
      showMobileToast("Equalizer reset to Flat");
    };
  }

  // Native Mobile Admin Console
  let mobileAdminPendingDeleteId = null;
  let mobileAdminBusy = false;

  function makeMobileNode(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = String(text);
    return node;
  }

  async function copyMobileAdminText(value, label) {
    if (!value) return;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        showMobileToast(`${label} copied`);
        return;
      }
    } catch {}
    showMobileToast("Copy failed · select text manually");
  }

  function renderMobileAdmin(data) {
    if (!mobileScreenAdmin || !data) return;
    const bitrateSelect = document.querySelector("#spcboy-mobile-admin-bitrate");
    const limitInput = document.querySelector("#spcboy-mobile-admin-session-limit");
    const statusBadge = document.querySelector("#spcboy-mobile-admin-status");
    const inviteCount = document.querySelector("#spcboy-mobile-admin-invite-count");
    const createdInviteBox = document.querySelector("#spcboy-mobile-admin-created-invite");
    const invitesList = document.querySelector("#spcboy-mobile-admin-invites-list");
    const accountCount = document.querySelector("#spcboy-mobile-admin-account-count");
    const accountsList = document.querySelector("#spcboy-mobile-admin-accounts-list");
    const displayNameInput = document.querySelector("#spcboy-mobile-admin-display-name");
    const passwordState = document.querySelector("#spcboy-mobile-admin-password-state");
    const createdPasswordBox = document.querySelector("#spcboy-mobile-admin-created-password");
    const genPasswordBtn = document.querySelector("#spcboy-mobile-admin-gen-password");
    const revokePasswordBtn = document.querySelector("#spcboy-mobile-admin-revoke-password");
    const metricsGrid = document.querySelector("#spcboy-mobile-admin-server-metrics");
    const loginsList = document.querySelector("#spcboy-mobile-admin-logins-list");

    if (statusBadge) statusBadge.textContent = "";

    if (bitrateSelect && Array.isArray(data.siteSettings?.aacChoices)) {
      bitrateSelect.replaceChildren();
      for (const choice of data.siteSettings.aacChoices) {
        const option = makeMobileNode("option", "", choice.label);
        option.value = String(choice.value);
        if (Number(choice.value) === Number(data.siteSettings.aacBitrate)) option.selected = true;
        bitrateSelect.appendChild(option);
      }
    }
    if (limitInput && data.siteSettings?.sessionLimitMinutes !== undefined) {
      limitInput.value = String(data.siteSettings.sessionLimitMinutes);
    }

    if (createdInviteBox) {
      if (data.createdInvite) {
        createdInviteBox.replaceChildren();
        createdInviteBox.classList.remove("is-hidden");
        const heading = makeMobileNode(
          "strong",
          "",
          data.createdInvite.isRecovery
            ? `Recovery invite for ${data.createdInvite.username}`
            : "New one-time member invite ready",
        );
        const codeBox = makeMobileNode("div", "spcboy-mobile-admin-code", data.createdInvite.code);
        const actions = makeMobileNode("div", "spcboy-mobile-admin-actions");
        const copyCodeBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Copy Code");
        copyCodeBtn.type = "button";
        copyCodeBtn.onclick = () => void copyMobileAdminText(data.createdInvite.code, "Invite code");
        const copyLinkBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Copy Link");
        copyLinkBtn.type = "button";
        copyLinkBtn.onclick = () => void copyMobileAdminText(data.createdInvite.joinUrl, "Invite link");
        actions.append(copyCodeBtn, copyLinkBtn);
        createdInviteBox.append(heading, codeBox, actions);
      } else {
        createdInviteBox.classList.add("is-hidden");
        createdInviteBox.replaceChildren();
      }
    }

    const invites = Array.isArray(data.invitations) ? data.invitations : [];
    if (inviteCount) inviteCount.textContent = String(invites.length);
    if (invitesList) {
      invitesList.replaceChildren();
      if (!invites.length) {
        invitesList.appendChild(makeMobileNode("p", "spcboy-mobile-empty", "No open invitations."));
      } else {
        for (const inv of invites) {
          const item = makeMobileNode("div", "spcboy-mobile-admin-item");
          const head = makeMobileNode("div", "spcboy-mobile-admin-item-head");
          const title = makeMobileNode(
            "h4",
            "spcboy-mobile-admin-item-title",
            inv.isRecovery ? `Recovery · ${inv.username}` : "Member invitation",
          );
          const pill = makeMobileNode("span", "spcboy-mobile-admin-pill is-active", "Open");
          head.append(title, pill);
          item.appendChild(head);
          item.appendChild(makeMobileNode("small", "spcboy-mobile-dim", `Expires ${inv.expiresAt}`));
          if (inv.visibleCode) {
            item.appendChild(makeMobileNode("div", "spcboy-mobile-admin-code", inv.visibleCode));
          }
          const actions = makeMobileNode("div", "spcboy-mobile-admin-actions");
          if (inv.visibleCode) {
            const copyBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Copy Code");
            copyBtn.type = "button";
            copyBtn.onclick = () => void copyMobileAdminText(inv.visibleCode, "Invite code");
            actions.appendChild(copyBtn);
          }
          if (inv.joinUrl) {
            const linkBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Copy Link");
            linkBtn.type = "button";
            linkBtn.onclick = () => void copyMobileAdminText(inv.joinUrl, "Invite link");
            actions.appendChild(linkBtn);
          }
          const revokeBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary spcboy-mobile-admin-danger-btn", "Revoke");
          revokeBtn.type = "button";
          revokeBtn.onclick = () => void postMobileAdminAction({ action: "revoke-invite", selector: inv.selector });
          actions.appendChild(revokeBtn);
          item.appendChild(actions);
          invitesList.appendChild(item);
        }
      }
    }

    const accounts = Array.isArray(data.accounts) ? data.accounts : [];
    if (accountCount) accountCount.textContent = String(accounts.length);
    if (accountsList) {
      accountsList.replaceChildren();
      for (const account of accounts) {
        const item = makeMobileNode("div", "spcboy-mobile-admin-item");
        const head = makeMobileNode("div", "spcboy-mobile-admin-item-head");
        const title = makeMobileNode("h4", "spcboy-mobile-admin-item-title", account.displayName || account.username);
        const pillText = !account.isActive
          ? "Suspended"
          : account.isSitePersona
            ? "Persona"
            : account.setupPending
              ? "Setup pending"
              : "Active";
        const pillClass = !account.isActive
          ? "spcboy-mobile-admin-pill is-suspended"
          : account.isActive && !account.setupPending && !account.isSitePersona
            ? "spcboy-mobile-admin-pill is-active"
            : "spcboy-mobile-admin-pill";
        const pill = makeMobileNode("span", pillClass, pillText);
        head.append(title, pill);
        item.appendChild(head);

        const meta = `${account.roleLabel} · ${account.activeSessionCount} active · ${account.audioQuota}`;
        item.appendChild(makeMobileNode("small", "spcboy-mobile-dim", meta));
        if (account.lastLoginAt) {
          item.appendChild(makeMobileNode("small", "spcboy-mobile-dim", `Last sign-in ${account.lastLoginAt}`));
        }

        if (account.canManage) {
          const actions = makeMobileNode("div", "spcboy-mobile-admin-actions");
          const toggleBtn = makeMobileNode(
            "button",
            "spcboy-mobile-btn-secondary",
            account.isActive ? "Suspend" : "Reactivate",
          );
          toggleBtn.type = "button";
          toggleBtn.onclick = () => {
            mobileAdminPendingDeleteId = null;
            void postMobileAdminAction({ action: "toggle-user", userId: account.id });
          };
          actions.appendChild(toggleBtn);

          if (account.isActive) {
            const recoveryBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Recovery");
            recoveryBtn.type = "button";
            recoveryBtn.onclick = () => {
              mobileAdminPendingDeleteId = null;
              void postMobileAdminAction({ action: "recovery-invite", userId: account.id });
            };
            actions.appendChild(recoveryBtn);
          }

          if (mobileAdminPendingDeleteId === account.id) {
            const confirmBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary spcboy-mobile-admin-danger-btn is-confirming", "Confirm Delete");
            confirmBtn.type = "button";
            confirmBtn.onclick = () => {
              mobileAdminPendingDeleteId = null;
              void postMobileAdminAction({ action: "delete-user", userId: account.id });
            };
            const cancelBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Cancel");
            cancelBtn.type = "button";
            cancelBtn.onclick = () => {
              mobileAdminPendingDeleteId = null;
              renderMobileAdmin(data);
            };
            actions.append(confirmBtn, cancelBtn);
          } else {
            const deleteBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary spcboy-mobile-admin-danger-btn", "Delete");
            deleteBtn.type = "button";
            deleteBtn.onclick = () => {
              mobileAdminPendingDeleteId = account.id;
              renderMobileAdmin(data);
            };
            actions.appendChild(deleteBtn);
          }
          item.appendChild(actions);
        }
        accountsList.appendChild(item);
      }
    }

    if (displayNameInput && data.selfAccount?.displayName !== undefined) {
      displayNameInput.value = data.selfAccount.displayName;
    }
    if (passwordState && genPasswordBtn && revokePasswordBtn) {
      const hasPassword = Boolean(data.selfAccount?.hasLoginPassword);
      passwordState.textContent = hasPassword
        ? "A generated password is active for devices without passkeys."
        : "For devices that cannot use passkeys.";
      genPasswordBtn.textContent = hasPassword ? "Replace Password" : "Generate Password";
      revokePasswordBtn.classList.toggle("is-hidden", !hasPassword);
    }
    if (createdPasswordBox) {
      if (data.createdLoginPassword) {
        createdPasswordBox.replaceChildren();
        createdPasswordBox.classList.remove("is-hidden");
        createdPasswordBox.appendChild(makeMobileNode("strong", "", "One-time login password (shown once)"));
        createdPasswordBox.appendChild(makeMobileNode("div", "spcboy-mobile-admin-code", data.createdLoginPassword));
        const actions = makeMobileNode("div", "spcboy-mobile-admin-actions");
        const copyPwBtn = makeMobileNode("button", "spcboy-mobile-btn-secondary", "Copy Password");
        copyPwBtn.type = "button";
        copyPwBtn.onclick = () => void copyMobileAdminText(data.createdLoginPassword, "Login password");
        actions.appendChild(copyPwBtn);
        createdPasswordBox.appendChild(actions);
      } else if (!data.selfAccount?.hasLoginPassword) {
        createdPasswordBox.classList.add("is-hidden");
        createdPasswordBox.replaceChildren();
      }
    }

    if (metricsGrid && data.server) {
      metricsGrid.replaceChildren();
      const metrics = [
        ["Memory", `${data.server.memory} (${data.server.memoryPercent}%)`],
        ["Disk", `${data.server.disk} (${data.server.diskPercent}%)`],
        ["Load", data.server.load || "Unavailable"],
        ["Uptime", data.server.uptime || "0d 0h"],
      ];
      for (const [label, value] of metrics) {
        const box = makeMobileNode("div", "spcboy-mobile-admin-metric");
        box.append(makeMobileNode("span", "", label), makeMobileNode("strong", "", value));
        metricsGrid.appendChild(box);
      }
    }

    if (loginsList) {
      loginsList.replaceChildren();
      const events = Array.isArray(data.recentLogins) ? data.recentLogins : [];
      if (!events.length) {
        loginsList.appendChild(makeMobileNode("p", "spcboy-mobile-empty", "No recent sign-in events."));
      } else {
        for (const ev of events) {
          const item = makeMobileNode("div", "spcboy-mobile-admin-item");
          const head = makeMobileNode("div", "spcboy-mobile-admin-item-head");
          const ok = ev.eventType === "success";
          head.append(
            makeMobileNode("h4", "spcboy-mobile-admin-item-title", ev.username),
            makeMobileNode("span", `spcboy-mobile-admin-pill ${ok ? "is-active" : "is-suspended"}`, ok ? "Success" : "Failed"),
          );
          item.append(head, makeMobileNode("small", "spcboy-mobile-dim", `${ev.occurredAt} · ${ev.ipAddress}`));
          loginsList.appendChild(item);
        }
      }
    }
  }

  async function loadMobileAdmin() {
    const adminUrl = mobileScreenAdmin?.dataset?.adminUrl;
    if (!adminUrl) return;
    const statusBadge = document.querySelector("#spcboy-mobile-admin-status");
    if (statusBadge) statusBadge.textContent = "Loading…";
    try {
      const response = await fetch(adminUrl, { credentials: "same-origin" });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not load admin controls.");
      renderMobileAdmin(data);
    } catch (error) {
      if (statusBadge) statusBadge.textContent = "Error";
      showMobileToast(error.message || "Could not load admin controls.");
    }
  }

  async function postMobileAdminAction(payload) {
    const adminUrl = mobileScreenAdmin?.dataset?.adminUrl;
    if (!adminUrl || mobileAdminBusy) return;
    mobileAdminBusy = true;
    const csrf = document.querySelector("#spcboy-csrf-form [name='csrfmiddlewaretoken']")?.value;
    try {
      const response = await fetch(adminUrl, {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", "X-CSRFToken": csrf || "" },
        body: JSON.stringify(payload),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Admin action failed.");
      renderMobileAdmin(data);
      if (data.message) showMobileToast(data.message);
    } catch (error) {
      showMobileToast(error.message || "Admin action failed.");
    } finally {
      mobileAdminBusy = false;
    }
  }

  document.querySelector("#spcboy-mobile-admin-save-settings")?.addEventListener("click", () => {
    const aacBitrate = document.querySelector("#spcboy-mobile-admin-bitrate")?.value;
    const sessionLimitMinutes = document.querySelector("#spcboy-mobile-admin-session-limit")?.value;
    void postMobileAdminAction({ action: "save-site-settings", aacBitrate, sessionLimitMinutes });
  });
  document.querySelector("#spcboy-mobile-admin-create-invite")?.addEventListener("click", () => {
    void postMobileAdminAction({ action: "create-invite" });
  });
  document.querySelector("#spcboy-mobile-admin-save-name")?.addEventListener("click", () => {
    const displayName = document.querySelector("#spcboy-mobile-admin-display-name")?.value || "";
    void postMobileAdminAction({ action: "update-display-name", displayName });
  });
  document.querySelector("#spcboy-mobile-admin-gen-password")?.addEventListener("click", () => {
    void postMobileAdminAction({ action: "generate-login-password" });
  });
  document.querySelector("#spcboy-mobile-admin-revoke-password")?.addEventListener("click", () => {
    void postMobileAdminAction({ action: "revoke-login-password" });
  });
  document.querySelector("#spcboy-mobile-admin-refresh")?.addEventListener("click", () => {
    void loadMobileAdmin();
  });

  const skipBtn = document.querySelector("#spcboy-mobile-faded-skip");
  if (skipBtn) {
    skipBtn.onclick = () => {
      const skips = window.SitePlayer?.getFadedSkips?.();
      const next = !skips?.enabled;
      const fadeInput = document.querySelector("#spcboy-mobile-fade-seconds");
      const secondsVal = fadeInput?.value ? Number(fadeInput.value) : null;
      skipBtn.setAttribute("aria-checked", String(next));
      skipBtn.textContent = next ? "Yes" : "No";
      window.SitePlayer?.setFadedSkips?.(next, secondsVal);
      syncMobileSoundControls();
    };
  }

  const fadeSecsInput = document.querySelector("#spcboy-mobile-fade-seconds");
  if (fadeSecsInput) {
    const applyFade = () => {
      window.SitePlayer?.setFadedSkips?.(null, Number(fadeSecsInput.value));
      syncMobileSoundControls();
    };
    fadeSecsInput.onchange = applyFade;
    fadeSecsInput.onkeydown = (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        applyFade();
        fadeSecsInput.blur();
      }
    };
  }

  const speedBtn = document.querySelector("#spcboy-mobile-speed-enabled");
  if (speedBtn) {
    speedBtn.onclick = () => {
      const speed = window.SitePlayer?.getPlaybackSpeed?.();
      const next = !speed?.enabled;
      const speedInput = document.querySelector("#spcboy-mobile-speed");
      const fractionVal = speedInput?.value?.trim() || "";
      speedBtn.setAttribute("aria-checked", String(next));
      speedBtn.textContent = next ? "Yes" : "No";
      window.SitePlayer?.setPlaybackSpeed?.(next, fractionVal || null);
      syncMobileSoundControls();
    };
  }

  const speedFractionInput = document.querySelector("#spcboy-mobile-speed");
  if (speedFractionInput) {
    const applySpeed = () => {
      const val = speedFractionInput.value.trim();
      const parsed = window.SitePlayer?.parseSpeedFraction?.(val);
      if (parsed) {
        speedFractionInput.value = parsed.fraction;
      }
      window.SitePlayer?.setPlaybackSpeed?.(null, val);
      syncMobileSoundControls();
    };
    speedFractionInput.onchange = applySpeed;
    speedFractionInput.onkeydown = (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        applySpeed();
        speedFractionInput.blur();
      }
    };
  }

  const lpBtn = document.querySelector("#spcboy-mobile-long-play");
  if (lpBtn) {
    lpBtn.onclick = () => {
      const lp = window.SitePlayer?.getLongPlay?.();
      const next = !lp?.enabled;
      const lpInput = document.querySelector("#spcboy-mobile-long-play-duration");
      const durationVal = lpInput?.value?.trim() || "";
      lpBtn.setAttribute("aria-checked", String(next));
      lpBtn.textContent = next ? "Yes" : "No";
      window.SitePlayer?.setLongPlay?.(next, durationVal || null);
      syncMobileSoundControls();
    };
  }

  const lpDurationInput = document.querySelector("#spcboy-mobile-long-play-duration");
  if (lpDurationInput) {
    const applyLongPlay = () => {
      const val = lpDurationInput.value.trim();
      window.SitePlayer?.setLongPlay?.(null, val);
      syncMobileSoundControls();
    };
    lpDurationInput.onchange = applyLongPlay;
    lpDurationInput.onkeydown = (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        applyLongPlay();
        lpDurationInput.blur();
      }
    };
  }

  document.querySelector("#spcboy-mobile-library-search")?.addEventListener("input", debounceMobileInput(() => {
    renderMobileLibrary();
  }));
    document.querySelector("#spcboy-mobile-recent-search")?.addEventListener("input", debounceMobileInput(() => {
    renderMobileRecents();
  }));
  document.querySelector("#spcboy-mobile-recent-more")?.addEventListener("click", () => {
    loadRecents(false).then(() => renderMobileRecents());
  });
  document.querySelector("#spcboy-mobile-favorites-search")?.addEventListener("input", debounceMobileInput(() => {
    renderMobileFavorites();
  }));
  document.querySelector("#spcboy-mobile-shuffle-favs")?.addEventListener("click", async () => {
    const tracks = await loadFavoritePlaylist({ allPages: true });
    if (tracks.length) {
      showMobileLoadingIndicator("Shuffling Favorites…");
      window.SitePlayer?.playPlaylist(tracks, { shuffle: true, toggle: false });
    }
  });

  window.addEventListener("siteplayer:settings-changed", () => {
    if (!isDesktop()) syncMobileSoundControls();
  });

  const queueObserverTarget = document.querySelector("#site-player-queue");
  if (queueObserverTarget && mobileUpNext) {
    new MutationObserver(renderMobileUpNext).observe(queueObserverTarget, { childList: true });
  }

  if (mobileAppNav) {
    try {
      setMobileAppPage(mobileAppPage);
      const activeTrack = window.SitePlayer?.getCurrentTrack?.() || currentTrack;
      if (activeTrack) currentTrack = activeTrack;
      renderMobileNowPlaying(activeTrack);
    } catch (err) {
      console.warn("Initial mobile page setup warning:", err);
    }
  }

  audio?.addEventListener("timeupdate", () => {
    if (!isDesktop()) updateMobilePlaybackProgress();
  });
  audio?.addEventListener("playing", () => {
    hideMobileLoadingIndicator();
    renderMobileNowPlaying();
  });
  audio?.addEventListener("canplay", () => {
    hideMobileLoadingIndicator();
  });
  audio?.addEventListener("pause", () => {
    renderMobileNowPlaying();
  });
  audio?.addEventListener("ended", () => {
    hideMobileLoadingIndicator();
    renderMobileNowPlaying();
  });
  audio?.addEventListener("waiting", () => {
    showMobileLoadingIndicator("Buffering stream…");
  });
  audio?.addEventListener("loadstart", () => {
    showMobileLoadingIndicator("Preparing audio stream…");
  });
  audio?.addEventListener("error", () => {
    hideMobileLoadingIndicator();
    showMobileToast("Playback error. Tap to retry.");
  });
  mobileNowArtwork?.addEventListener("error", () => {
    const fallback = mobileNowArtwork.dataset.fallbackArtwork;
    if (fallback && mobileNowArtwork.getAttribute("src") !== fallback) {
      mobileNowArtwork.dataset.fallbackArtwork = "";
      mobileNowArtwork.src = fallback;
      return;
    }
    mobileNowArtwork.removeAttribute("src");
  });
  mobileDockArt?.addEventListener("error", () => {
    mobileDockArt.removeAttribute("src");
  });
  recentMore.addEventListener("click", () => loadRecents());
  favoriteMore?.addEventListener("click", () => loadFavoritePlaylist());
  window.addEventListener("siteplayer:track", (event) => {
    const rawTrack = event.detail?.track;
    if (!rawTrack) return;
    const staleWhileSelecting = Boolean(pendingSelectionToken && rawTrack.id && rawTrack.id === lastPlayerTrackId);
    if (rawTrack.id) lastPlayerTrackId = rawTrack.id;
    if (staleWhileSelecting) return;
    if (rawTrack.id !== currentTrack?.id) playbackSelectionToken += 1;
    const group = rawTrack.gameKey
      ? gameGroupsByKey.get(rawTrack.gameKey)
      : gameGroupsByConsoleGame.get(`${canonicalConsoleName(rawTrack.console)}\u0000${rawTrack.game}`);
    syncCurrentTrackRows(currentTrack?.id, false);
    currentTrack = tracksById.get(rawTrack.id) || (group ? cacheTrack(group, rawTrack) : rawTrack);
    syncCurrentTrackRows(currentTrack.id, true);
    renderMobileNowPlaying(currentTrack);
    renderMobileUpNext();
    if (mobileAppPage === "recent") renderMobileRecents();
    if (mobileAppPage === "favorites") renderMobileFavorites();
    scheduleSelectionIndicators();
    if (view === "recent" && event.detail.playing && !recentLoading && recentRefreshedPlaybackId !== event.detail.playbackId) {
      recentRefreshedPlaybackId = event.detail.playbackId;
      loadRecents(true);
    }
  });

  // Tabs are browsing contexts over the one catalog and one audio player.
  // Persist stable album IDs, never positional game keys or track metadata.
  const workspaceStrip = document.querySelector('#sbonline-workspace-tabs');
  const addWorkspaceButton = document.querySelector('#sbonline-add-tab');
  const workspaceMenu = document.querySelector('#sbonline-context-menu');
  const workspaceViews = ['all','favorites','recent'];
  const savedWorkspace = storage.get('workspaceTabs', null);
  const hasSavedWorkspace = savedWorkspace?.version === 1 && Array.isArray(savedWorkspace.tabs) && savedWorkspace.tabs.length > 0;
  const seenWorkspaceIds = new Set();
  let workspaceTabs = (hasSavedWorkspace ? savedWorkspace.tabs : []).slice(0,24).flatMap(tab => {
    if (!tab || typeof tab.id !== 'string' || tab.id.length > 80 || seenWorkspaceIds.has(tab.id)) return [];
    seenWorkspaceIds.add(tab.id);
    return [{ id: tab.id, view: workspaceViews.includes(tab.view) ? tab.view : 'all',
      albumId: typeof tab.albumId === 'string' && /^[0-9a-f]{32}$/.test(tab.albumId) ? tab.albumId : null,
      query: typeof tab.query === 'string' ? tab.query.slice(0,256) : '',
      sidebarScroll: Math.max(0,Math.min(1000000,Number(tab.sidebarScroll)||0)),
      playlistScroll: Math.max(0,Math.min(1000000,Number(tab.playlistScroll)||0)),
    }];
  });
  if (!workspaceTabs.length) workspaceTabs = [{ id: crypto.randomUUID(), view, albumId: null, query: '' }];
  let activeWorkspaceId = workspaceTabs.some(tab => tab.id === savedWorkspace?.activeId) ? savedWorkspace.activeId : workspaceTabs[0].id;
  let restoringWorkspace = false;
  let workspaceScrollTimer = 0;
  let contextEntry = null;
  let contextReturnFocus = null;
  function activeWorkspace() { return workspaceTabs.find(tab => tab.id === activeWorkspaceId); }
  function workspaceLabel(tab) {
    if (tab.query) return `Search: ${tab.query}`;
    if (tab.view !== 'all') return ({favorites:'Favorites',recent:'Recent'})[tab.view];
    return gameGroupsByAlbumId.get(tab.albumId)?.gameName || 'Library';
  }
  function persistWorkspaces() {
    storage.set('workspaceTabs', { version:1, activeId:activeWorkspaceId, tabs:workspaceTabs });
  }
  function captureWorkspace({ render = true } = {}) {
    if (restoringWorkspace || !catalogAvailable || !page.isConnected) return;
    const tab = activeWorkspace();
    if (!tab) return;
    Object.assign(tab, { view, query:search.value.slice(0,256),
      albumId: gameGroupsByKey.get(selectedGameKey)?.albumId || null,
      sidebarScroll: sidebarTree.scrollTop,
      playlistScroll: playlistContent.scrollTop });
    persistWorkspaces();
    if (render) renderWorkspaces();
  }
  function renderWorkspaces() {
    const scroll = workspaceStrip.scrollLeft;
    workspaceStrip.replaceChildren();
    for (const tab of workspaceTabs) {
      const item = document.createElement('div');
      item.className = `sbonline-workspace-tab${tab.id === activeWorkspaceId ? ' is-active' : ''}`;
      const select = document.createElement('button');
      select.type = 'button'; select.setAttribute('role','tab');
      select.id = `workspace-${tab.id}`;
      select.setAttribute('aria-selected', String(tab.id === activeWorkspaceId));
      select.setAttribute('aria-controls','spcboy-stage');
      select.tabIndex = tab.id === activeWorkspaceId ? 0 : -1;
      select.textContent = workspaceLabel(tab); select.title = select.textContent;
      select.addEventListener('click', () => restoreWorkspace(tab.id));
      select.addEventListener('auxclick', event => { if (event.button === 1) { event.preventDefault(); closeWorkspace(tab.id); } });
      select.addEventListener('keydown', event => {
        const index = workspaceTabs.indexOf(tab);
        let next;
        if (event.key === 'ArrowRight') next = workspaceTabs[(index+1)%workspaceTabs.length];
        if (event.key === 'ArrowLeft') next = workspaceTabs[(index-1+workspaceTabs.length)%workspaceTabs.length];
        if (event.key === 'Home') next = workspaceTabs[0];
        if (event.key === 'End') next = workspaceTabs.at(-1);
        if (next) { event.preventDefault(); restoreWorkspace(next.id); document.getElementById(`workspace-${next.id}`)?.focus(); }
        if (event.key === 'Delete') { event.preventDefault(); closeWorkspace(tab.id); }
      });
      const close = document.createElement('button');
      close.type = 'button'; close.className = 'sbonline-tab-close';
      close.setAttribute('aria-label', `Close ${select.textContent} tab`); close.title = 'Close tab';
      close.innerHTML = '<svg viewBox="0 0 11 11" aria-hidden="true"><path d="m3 3 5 5m0-5L3 8" fill="none" stroke="currentColor" stroke-width="1"/></svg>';
      close.addEventListener('click', () => closeWorkspace(tab.id));
      item.append(select,close); workspaceStrip.append(item);
    }
    workspaceStrip.scrollLeft = scroll;
    addWorkspaceButton.disabled = workspaceTabs.length >= 24;
  }
  function restoreWorkspace(id, { initial = false } = {}) {
    if (!workspaceTabs.some(tab => tab.id === id)) return;
    if (!initial) captureWorkspace({render:false});
    restoringWorkspace = true;
    closeWorkspaceMenu();
    activeWorkspaceId = id;
    const tab = activeWorkspace();
    view = tab.view;
    search.value = tab.query;
    const selectedAlbumId = tab.albumId;
    const entry = selectedAlbumId ? gameGroupsByAlbumId.get(selectedAlbumId) : null;
    selectedGameKey = entry?.key || null;
    trackList.querySelectorAll("details[open]").forEach(details => { details.open = false; });
    syncViewButtons();
    if (entry) selectGame(entry.key);
    // Clearing a search also aborts the previous tab's pending search request.
    scheduleCatalogSearch();
    if (view === 'favorites') loadFavoritePlaylist();
    if (view === 'recent') loadRecents();
    restoringWorkspace = false;
    storage.set('view',view);
    persistWorkspaces(); renderWorkspaces();
    syncWorkspaceHeading(workspaceLabel(tab));
    requestAnimationFrame(() => {
      sidebarTree.scrollTop = tab.sidebarScroll || 0;
      playlistContent.scrollTop = tab.playlistScroll || 0;
      if (entry && !entry.loaded) ensureAlbumTracks(entry).then(() => {
        if (activeWorkspaceId === id) playlistContent.scrollTop = tab.playlistScroll || 0;
      });
      document.getElementById(`workspace-${id}`)?.scrollIntoView({block:'nearest',inline:'nearest'});
    });
  }
  function openWorkspace(entry = null, { background = false } = {}) {
    if (workspaceTabs.length >= 24) { playerState.textContent = 'Close a tab before opening another (24 maximum).'; return; }
    captureWorkspace({render:false});
    const tab = { id:crypto.randomUUID(), view:'all', albumId:entry?.albumId || null, query:'', sidebarScroll:0, playlistScroll:0 };
    workspaceTabs.push(tab);
    if (!background) restoreWorkspace(tab.id, {initial:true});
    else { persistWorkspaces(); renderWorkspaces(); }
  }
  function openWorkspaceForAlbum(albumId) {
    const entry = albumId ? gameGroupsByAlbumId.get(albumId) : null;
    if (!entry) return false;
    if (!isDesktop()) {
      setMobileAppPage("library");
      selectGame(entry.key);
      return true;
    }
    const existing = workspaceTabs.find(tab => tab.albumId === albumId);
    if (existing) {
      if (existing.id === activeWorkspaceId) captureWorkspace({render:false});
      existing.view = "all";
      existing.query = "";
      restoreWorkspace(existing.id, {initial:existing.id === activeWorkspaceId});
    } else {
      if (workspaceTabs.length >= 24) {
        playerState.textContent = "Close a tab before opening another (24 maximum).";
        return true;
      }
      openWorkspace(entry);
    }
    return true;
  }
  document.addEventListener("click", event => {
    const link = event.target instanceof Element ? event.target.closest("#spcboy-current-album") : null;
    if (!link || !page.isConnected || !link.dataset.albumId || event.button !== 0
      || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (!openWorkspaceForAlbum(link.dataset.albumId)) return;
    event.preventDefault();
    event.stopPropagation();
  }, true);
  document.addEventListener("site:open-spcboy-album", event => {
    const albumId = event.detail?.albumId;
    if (typeof albumId === "string") openWorkspaceForAlbum(albumId);
  });
  function closeWorkspace(id) {
    const index = workspaceTabs.findIndex(tab => tab.id === id);
    if (index < 0) return;
    captureWorkspace({render:false});
    workspaceTabs.splice(index,1);
    if (!workspaceTabs.length) workspaceTabs.push({id:crypto.randomUUID(),view:'all',albumId:null,query:''});
    if (id === activeWorkspaceId) restoreWorkspace(workspaceTabs[Math.min(index,workspaceTabs.length-1)].id, {initial:true});
    else { persistWorkspaces(); renderWorkspaces(); }
    document.getElementById(`workspace-${activeWorkspaceId}`)?.focus();
  }
  function entryForWorkspaceTarget(target) {
    const album = target.closest('[data-game-key],[data-album-key]');
    if (album) return gameGroupsByKey.get(album.dataset.gameKey || album.dataset.albumKey);
    const row = target.closest('.spcboy-track-row');
    return row ? gameGroupsByKey.get(tracksById.get(row.dataset.id)?.gameKey) : null;
  }
  function closeWorkspaceMenu({focus=false} = {}) {
    workspaceMenu.hidden = true;
    if (focus) contextReturnFocus?.focus();
    contextEntry = null;
  }
  page.addEventListener('contextmenu', event => {
    const entry = entryForWorkspaceTarget(event.target);
    if (!entry) return;
    event.preventDefault(); contextEntry = entry; contextReturnFocus = event.target.closest('button,summary');
    workspaceMenu.hidden = false;
    const rect = workspaceMenu.getBoundingClientRect();
    workspaceMenu.style.left = `${Math.max(4,Math.min(event.clientX,innerWidth-rect.width-4))}px`;
    workspaceMenu.style.top = `${Math.max(4,Math.min(event.clientY,innerHeight-rect.height-4))}px`;
    workspaceMenu.querySelector('button').focus();
  });
  page.addEventListener('click', event => {
    if (!(event.metaKey || event.ctrlKey) || !event.target.closest('summary,.spcboy-track')) return;
    const entry = entryForWorkspaceTarget(event.target);
    if (!entry) return;
    event.preventDefault(); event.stopPropagation(); openWorkspace(entry,{background:true});
  },true);
  page.addEventListener('auxclick', event => {
    if (event.button !== 1) return;
    const entry = entryForWorkspaceTarget(event.target);
    if (entry) { event.preventDefault(); openWorkspace(entry,{background:true}); }
  });
  workspaceMenu.addEventListener('click', event => {
    const action = event.target.closest('[data-tab-action]')?.dataset.tabAction;
    const entry = contextEntry;
    closeWorkspaceMenu();
    if (action && entry) openWorkspace(entry,{background:action === 'background'});
  });
  workspaceMenu.addEventListener('keydown', event => {
    const buttons = [...workspaceMenu.querySelectorAll('button')];
    const index = buttons.indexOf(document.activeElement);
    if (['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
      event.preventDefault();
      buttons[event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length-1 : (index+(event.key === 'ArrowDown'?1:-1)+buttons.length)%buttons.length].focus();
    }
    if (event.key === 'Tab') closeWorkspaceMenu();
  });
  document.addEventListener('pointerdown', event => { if (!workspaceMenu.contains(event.target)) closeWorkspaceMenu(); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !workspaceMenu.hidden) { event.preventDefault(); closeWorkspaceMenu({focus:true}); } });
  document.addEventListener('site:pageleave', () => { captureWorkspace({render:false}); closeWorkspaceMenu(); });
  window.addEventListener('pagehide', () => captureWorkspace({render:false}));
  for (const scroller of [playlistContent,document.querySelector('.spcboy-tree')]) scroller.addEventListener('scroll', () => {
    clearTimeout(workspaceScrollTimer);
    workspaceScrollTimer = setTimeout(() => captureWorkspace({render:false}),120);
  },{passive:true});
  document.addEventListener('site:navigated', () => {
    if (!page.isConnected) return;
    syncViewButtons();
    syncWorkspaceHeading(workspaceLabel(activeWorkspace()));
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  });
  addWorkspaceButton.addEventListener('click', () => { openWorkspace(); search.focus(); });
  renderWorkspaces();
  syncViewButtons();

  syncTrackContainers();
  beginCatalogLoading();
  fetch(page.dataset.catalogUrl, { credentials: "same-origin", headers: { Accept: "application/json" } })
    .then((response) => {
      if (!response.ok) throw new Error(`Catalog request returned ${response.status}.`);
      return response.json();
    })
    .then(async (catalog) => {
      await renderCatalog(catalog);
      headerSearchReady = true; applyHeaderSearch();
      if (headerSearch) headerSearch.value = search.value;
      finishCatalogLoading();
      if (view === "recent") loadRecents(true);
      if (!new URLSearchParams(window.location.search).has("play") && !new URLSearchParams(window.location.search).has("album")) {
        const activeTrack = window.SitePlayer?.getCurrentTrack();
        if (activeTrack) window.dispatchEvent(new CustomEvent("siteplayer:track", { detail: { track: activeTrack } }));
      }
    })
    .catch((error) => {
      catalogLoaded = true;
      resolveCatalogReady();
      libraryState.textContent = "Library unavailable";
      empty.textContent = error.message.includes("503")
        ? "The SPCBOY trial library has not been installed yet."
        : "Could not load the SPCBOY library. Reload to try again.";
      playlistEmpty.textContent = empty.textContent;
      finishCatalogLoading(error.message.includes("503")
        ? "Library is not installed on the server (503)."
        : "Library unavailable · reload to retry");
    });
  loadFavorites();
})();
