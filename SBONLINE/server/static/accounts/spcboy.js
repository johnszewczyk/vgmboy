(() => {
  const page = document.querySelector(".spcboy-page");
  const library = document.querySelector("#spcboy-library");
  const mobileAppNav = document.querySelector("#spcboy-mobile-app-nav");
  const mobileAppButtons = [...document.querySelectorAll("[data-mobile-app-page]")];
  const mobileNowPlaying = document.querySelector("#spcboy-mobile-now-playing");
  const mobileNowArtwork = document.querySelector("#spcboy-mobile-now-artwork");
  const mobileNowTitle = document.querySelector("#spcboy-mobile-now-title");
  const mobileNowAlbum = document.querySelector("#spcboy-mobile-now-album");
  const mobileProgress = document.querySelector("#spcboy-mobile-progress");
  const mobileProgressFill = document.querySelector("#spcboy-mobile-progress-fill");
  const mobileElapsed = document.querySelector("#spcboy-mobile-elapsed");
  const mobileDuration = document.querySelector("#spcboy-mobile-duration");
  const mobileUpNext = document.querySelector("#spcboy-mobile-up-next");
  const mobilePlayButton = document.querySelector("#spcboy-mobile-play");
  const mobilePreviousButton = document.querySelector("#spcboy-mobile-previous");
  const mobileNextButton = document.querySelector("#spcboy-mobile-next");
  const mobileSoundSettings = document.querySelector("#spcboy-mobile-sound-settings");
  const mobileOptionsSettings = document.querySelector("#spcboy-mobile-options-settings");
  const mobileSoundPages = document.querySelector("#spcboy-mobile-sound-pages");
  const mobileOptionsPages = document.querySelector("#spcboy-mobile-options-pages");
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
  const galleryPanel = document.querySelector("#spcboy-gallery-panel");
  const galleryConsoleSelect = document.querySelector("#spcboy-gallery-console-select");
  const galleryGrid = document.querySelector("#spcboy-gallery-grid");
  const galleryDetail = document.querySelector("#spcboy-gallery-detail");
  const galleryDetailBack = document.querySelector("#spcboy-gallery-detail-back");
  const galleryDetailPlay = document.querySelector("#spcboy-gallery-detail-play");
  const galleryDetailArtwork = document.querySelector("#spcboy-gallery-detail-artwork");
  const galleryDetailTitle = document.querySelector("#spcboy-gallery-detail-title");
  const galleryDetailConsole = document.querySelector("#spcboy-gallery-detail-console");
  const galleryDetailCount = document.querySelector("#spcboy-gallery-detail-count");
  const galleryDetailTracks = document.querySelector("#spcboy-gallery-detail-tracks");
  const galleryDetailStatus = document.querySelector("#spcboy-gallery-detail-status");
  const galleryZoom = document.querySelector("#spcboy-gallery-zoom");
  const galleryZoomValue = document.querySelector("#spcboy-gallery-zoom-value");
  const galleryZoomOut = document.querySelector("#spcboy-gallery-zoom-out");
  const galleryZoomIn = document.querySelector("#spcboy-gallery-zoom-in");
  const galleryEmpty = document.querySelector("#spcboy-gallery-empty");
  const galleryMore = document.querySelector("#spcboy-gallery-more");
  const shuffleFavoritesButton = document.querySelector("#spcboy-shuffle-favorites");
  const searchMore = document.querySelector("#spcboy-search-more");
  const favoriteMore = document.querySelector("#spcboy-favorite-more");
  if (!page || !library) return;

  galleryConsoleSelect?.addEventListener("change", () => selectGalleryConsole(galleryConsoleSelect.value));

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
  const searchOnlyRows = new Map();
  const gameGroups = [];
  const gameGroupsByKey = new Map();
  const gameGroupsByConsoleGame = new Map();
  const galleryCards = [];
  let searchMatches = null;
  let searchNextPage = null;
  let searchLoading = false;
  let searchFailed = false;
  let searchInitialPending = false;
  let searchRequestToken = 0;
  let searchTimer = null;
  let searchController = null;
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
  let catalogLoaded = false;
  let catalogAvailable = false;
  let catalogLoadingPhase = "idle";
  let catalogLoadingStartedAt = 0;
  let catalogLoadingTimer = null;
  let galleryLoadingGeneration = 0;
  let galleryPrefetchStart = 0;
  let galleryPrefetchCount = 0;
  let resolveCatalogReady;
  const catalogReady = new Promise((resolve) => { resolveCatalogReady = resolve; });
  let currentTrack = null;
  let playbackSelectionToken = 0;
  let currentPlaybackId = null;
  let announcedPlaybackId = null;
  let streamOffsetSeconds = 0;
  const savedView = storage.get("view", "all");
  let view = ["all", "favorites", "recent", "gallery"].includes(savedView) ? savedView : "all";
  let mobileAppPage = view === "gallery" ? "gallery" : "playing";
  function syncWorkspaceHeading(name) {
    const viewLabel = ({ all: "Library", favorites: "Favorites", recent: "Recent", gallery: "Gallery" })[view] || "Library";
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
  let galleryConsoleName = "";
  let galleryVisibleCount = 80;
  let galleryZoomPercent = Math.max(50, Math.min(150, Number(storage.get("galleryZoomPercent", 100)) || 100));
  let galleryDetailEntry = null;
  let galleryDetailRequest = 0;
  function selectGalleryConsole(consoleName) {
    if (!consoleName) return;
    galleryVisibleCount = 80;
    galleryConsoleName = consoleName;
    if (galleryConsoleSelect) galleryConsoleSelect.value = consoleName;
    captureWorkspace();
    if (view === "gallery") renderGalleryWithLoading();
    else applyFilters();
  }
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
    if (!drawerSettingsPages || !mobileSoundPages || !mobileOptionsPages) return;
    if (isDesktop()) {
      drawerSettingsPages.append(playbackSettingsPage, audioSettingsPage, interfaceSettingsPage);
    } else {
      mobileSoundPages.append(audioSettingsPage, playbackSettingsPage);
      mobileOptionsPages.append(interfaceSettingsPage);
    }
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
      ? playlistColumnHead.querySelector('[data-column="favorite"]').getBoundingClientRect().height : 0;
    const available = Math.max(0, playlistContent.clientWidth - 2*inset - favoriteWidth - 2*gap);
    const totalWeight = columns.reduce((sum, column) => sum + column.weight, 0);
    const widths = columns.map(column => {
      const header = playlistColumnHeadCells.querySelector(`[data-column="${column.id}"]`);
      const minimum = Math.ceil(Math.max(column.id === 'index' ? header.getBoundingClientRect().height : 0,
        measurePlaylistColumnText(header, header.dataset.label || column.label) + 2*gap + 1));
      const savedWidth = Number(playlistColumnWidths[column.id]);
      return Math.max(minimum, Number.isFinite(savedWidth) && savedWidth > 0 ? savedWidth
        : (available-gap*(columns.length-1))*column.weight/totalWeight);
    });
    // Keep default widths independent of track text; users may save explicit widths.
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
    loadingNotice.classList.remove("is-gallery-loading");
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
    loadingNotice.classList.remove("is-gallery-loading");
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

  function beginGalleryLoading(message, total = null) {
    if (!loadingNotice || !loadingMessage || !galleryPanel) return;
    loadingNotice.hidden = false;
    loadingNotice.dataset.loadingType = "gallery";
    loadingNotice.classList.remove("is-error");
    loadingNotice.classList.add("is-gallery-loading");
    loadingMessage.textContent = message;
    loadingProgress.hidden = !Number.isInteger(total) || total <= 0;
    loadingProgress.max = Math.max(Number(total) || 1, 1);
    loadingProgress.value = 0;
    galleryPanel.setAttribute("aria-busy", "true");
    library.setAttribute("aria-busy", "true");
  }

  function updateGalleryLoading(completed, total) {
    if (!loadingMessage || !loadingProgress) return;
    loadingMessage.textContent = `Loading gallery artwork · ${completed} / ${total}`;
    loadingProgress.max = Math.max(total, 1);
    loadingProgress.value = completed;
    loadingProgress.hidden = false;
  }

  function finishGalleryLoading(generation) {
    if (generation !== galleryLoadingGeneration || loadingNotice?.dataset.loadingType !== "gallery") return;
    galleryPanel?.removeAttribute("aria-busy");
    library.removeAttribute("aria-busy");
    loadingNotice.hidden = true;
    loadingNotice.classList.remove("is-gallery-loading", "is-error");
    delete loadingNotice.dataset.loadingType;
  }

  function waitForGalleryImage(image) {
    const loaded = image.complete ? Promise.resolve() : new Promise((resolve) => {
      let timeout;
      const finish = () => {
        window.clearTimeout(timeout);
        resolve();
      };
      timeout = window.setTimeout(finish, 10000);
      image.addEventListener("load", finish, { once: true });
      image.addEventListener("error", finish, { once: true });
    });
    return loaded.then(async () => {
      if (image.naturalWidth && typeof image.decode === "function") {
        await Promise.race([
          image.decode().catch(() => {}),
          new Promise((resolve) => window.setTimeout(resolve, 1500)),
        ]);
      }
    });
  }

  async function renderGalleryWithLoading({ start = 0, count = 8, message = "Loading gallery…" } = {}) {
    if (!catalogLoaded || view !== "gallery") return;
    const generation = ++galleryLoadingGeneration;
    galleryPrefetchStart = Math.max(0, start);
    galleryPrefetchCount = Math.max(0, count);
    beginGalleryLoading(message);
    applyFilters();
    galleryPrefetchCount = 0;
    const images = [...galleryGrid.querySelectorAll("img")].slice(start, start + count);
    if (!images.length) {
      await new Promise((resolve) => requestAnimationFrame(resolve));
      finishGalleryLoading(generation);
      return;
    }
    let completed = 0;
    updateGalleryLoading(0, images.length);
    await Promise.all(images.map((image) => waitForGalleryImage(image).then(() => {
      completed += 1;
      if (generation === galleryLoadingGeneration) updateGalleryLoading(completed, images.length);
    })));
    finishGalleryLoading(generation);
  }

  function applyGalleryZoom() {
    if (!galleryZoom || !galleryZoomValue || !galleryGrid) return;
    const zoom = Math.max(Number(galleryZoom.min), Math.min(Number(galleryZoom.max), galleryZoomPercent));
    galleryZoomPercent = zoom;
    galleryZoom.value = String(zoom);
    galleryZoom.setAttribute("aria-valuetext", `${zoom} percent`);
    galleryZoomValue.value = `${zoom}%`;
    galleryZoomValue.textContent = `${zoom}%`;
    const baseTileRem = isDesktop() ? 8.5 : 6.6;
    galleryGrid.style.setProperty("--spcboy-gallery-tile-min", `${baseTileRem * zoom / 100}rem`);
  }

  function setGalleryZoom(value) {
    galleryZoomPercent = Math.max(50, Math.min(150, Math.round(Number(value) / 10) * 10));
    storage.set("galleryZoomPercent", galleryZoomPercent);
    applyGalleryZoom();
  }

  galleryZoom?.addEventListener("input", () => setGalleryZoom(galleryZoom.value));
  galleryZoomOut?.addEventListener("click", () => setGalleryZoom(galleryZoomPercent - 10));
  galleryZoomIn?.addEventListener("click", () => setGalleryZoom(galleryZoomPercent + 10));
  desktopLayout.addEventListener("change", applyGalleryZoom);
  applyGalleryZoom();

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

  function clearSearchOnlyRows() {
    const idsByEntry = new Map();
    for (const [row, entry] of searchOnlyRows) {
      const ids = idsByEntry.get(entry) ?? new Set();
      ids.add(row.dataset.id);
      idsByEntry.set(entry, ids);
      const rows = trackRowsById.get(row.dataset.id) ?? [];
      const remaining = rows.filter((candidate) => candidate !== row);
      if (remaining.length) trackRowsById.set(row.dataset.id, remaining);
      else trackRowsById.delete(row.dataset.id);
      row.remove();
    }
    searchOnlyRows.clear();
    for (const [entry, ids] of idsByEntry) entry.tracks = entry.tracks.filter((track) => !ids.has(track.id));
  }

  function placeSearchMore() {
    const mobileAggregate = !isDesktop() && (view === "favorites" || Boolean(search.value.trim()));
    const destination = view === "favorites" || view === "recent"
      ? cardPanel
      : view === "gallery"
      ? galleryPanel
      : isDesktop() || mobileAggregate ? playlistContent : trackList;
    if (searchMore && destination && searchMore.parentElement !== destination) destination.append(searchMore);
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

  function makeTrackRow(track, index) {
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
    button.addEventListener("click", () => selectTrack(track, true));

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
    for (const row of entry.list.querySelectorAll(".spcboy-track-row")) {
      searchOnlyRows.delete(row);
      const rows = trackRowsById.get(row.dataset.id) ?? [];
      const remaining = rows.filter((candidate) => candidate !== row);
      if (remaining.length) trackRowsById.set(row.dataset.id, remaining);
      else trackRowsById.delete(row.dataset.id);
    }
    entry.list.replaceChildren();
    entry.tracks = [];
  }

  function appendTrackRow(entry, data, { searchOnly = false } = {}) {
    const existingRow = entry.list.querySelector(`.spcboy-track-row[data-id="${CSS.escape(data.id)}"]`);
    if (existingRow) return tracksById.get(data.id);
    const track = cacheTrack(entry, data);
    const row = makeTrackRow(track, entry.tracks.length);
    row.querySelector(".spcboy-track")?.setAttribute("aria-current", String(currentTrack?.id === track.id));
    if (searchOnly) {
      row.dataset.searchOnly = "true";
      searchOnlyRows.set(row, entry);
    }
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

  function makeGalleryCard(entry) {
    if (entry.galleryCard) return entry.galleryCard;
    const card = document.createElement("article");
    card.className = "spcboy-gallery-card";
    card.dataset.albumKey = entry.key;
    const open = document.createElement("button");
    open.className = "spcboy-gallery-open";
    open.type = "button";
    open.setAttribute("aria-label", `Open ${entry.gameName} album`);
    const image = document.createElement("img");
    image.src = entry.artworkUrl;
    image.alt = "";
    image.width = 240;
    image.height = 240;
    image.loading = "lazy";
    image.decoding = "async";
    const cover = document.createElement("span");
    cover.className = "spcboy-gallery-cover";
    cover.append(image);
    const name = document.createElement("button");
    name.className = "spcboy-gallery-name";
    name.type = "button";
    name.textContent = entry.gameName;
    open.append(cover);
    open.addEventListener("click", () => openGalleryAlbum(entry));
    name.addEventListener("click", () => openGalleryAlbum(entry));
    const meta = document.createElement("div");
    meta.className = "spcboy-gallery-meta";
    meta.append(name, makeAlbumFavoriteButton(entry.albumId, entry.gameName));
    card.append(open, meta);
    entry.galleryCard = card;
    return card;
  }

  function releaseGalleryCard(entry) {
    if (!entry.galleryCard) return;
    entry.galleryCard.querySelector("img")?.removeAttribute("src");
    entry.galleryCard.remove();
    entry.galleryCard = null;
  }

  function releaseGalleryCards() {
    for (const entry of galleryCards) releaseGalleryCard(entry);
    galleryGrid.replaceChildren();
    galleryVisibleCount = 80;
  }

  function renderGallery() {
    if (galleryConsoleSelect) galleryConsoleSelect.value = galleryConsoleName;
    for (const system of trackList.querySelectorAll(".spcboy-system")) {
      const selected = view === "gallery" && system.dataset.console === galleryConsoleName;
      system.classList.toggle("is-gallery-selected", selected);
      const summary = system.querySelector("summary");
      if (selected) summary?.setAttribute("aria-current", "true");
      else summary?.removeAttribute("aria-current");
    }
    if (searchInitialPending) {
      galleryGrid.hidden = true;
      galleryEmpty.hidden = false;
      galleryMore.hidden = true;
      galleryEmpty.textContent = "Searching hosted tracks…";
      return 0;
    }
    const matchingAlbums = galleryCards.filter((entry) => entry.consoleName === galleryConsoleName && !entry.row.hidden);
    const shownAlbums = new Set(matchingAlbums.slice(0, galleryVisibleCount));
    for (const entry of galleryCards) {
      if (!shownAlbums.has(entry)) releaseGalleryCard(entry);
    }
    let visibleAlbums = 0;
    for (const entry of shownAlbums) {
      const card = makeGalleryCard(entry);
      if (card.parentElement !== galleryGrid) galleryGrid.append(card);
      card.hidden = false;
      const image = card.querySelector("img");
      image.loading = visibleAlbums >= galleryPrefetchStart
        && visibleAlbums < galleryPrefetchStart + galleryPrefetchCount
        ? "eager"
        : "lazy";
      visibleAlbums += 1;
    }
    galleryMore.hidden = matchingAlbums.length <= galleryVisibleCount;
    galleryMore.textContent = `Load more albums (${visibleAlbums.toLocaleString()} / ${matchingAlbums.length.toLocaleString()})`;
    galleryGrid.hidden = false;
    galleryEmpty.hidden = visibleAlbums > 0;
    galleryEmpty.textContent = search.value.trim()
      ? "No matching albums with artwork."
      : "No artwork is available for this console yet.";
    return visibleAlbums;
  }

  function clearGalleryDetailTracks() {
    for (const row of galleryDetailTracks?.querySelectorAll(".spcboy-track-row") ?? []) {
      const rows = trackRowsById.get(row.dataset.id) ?? [];
      const remaining = rows.filter((candidate) => candidate !== row);
      if (remaining.length) trackRowsById.set(row.dataset.id, remaining);
      else trackRowsById.delete(row.dataset.id);
    }
    galleryDetailTracks?.replaceChildren();
  }

  function showGalleryAlbumDetails(entry) {
    if (!entry || !galleryDetail) return;
    const request = ++galleryDetailRequest;
    galleryDetailEntry = entry;
    galleryPanel.classList.add("is-detail-open");
    galleryGrid.hidden = true;
    galleryMore.hidden = true;
    galleryEmpty.hidden = true;
    galleryDetail.hidden = false;
    galleryDetailTitle.textContent = entry.gameName;
    galleryDetailConsole.textContent = entry.consoleName;
    galleryDetailCount.textContent = `${entry.trackCount.toLocaleString()} tracks`;
    galleryDetailArtwork.src = entry.detailArtworkUrl || entry.artworkUrl;
    galleryDetailArtwork.alt = `${entry.gameName} album artwork`;
    galleryDetailStatus.replaceChildren();
    galleryDetailStatus.textContent = "Loading tracks…";
    galleryDetailStatus.hidden = false;
    galleryDetailPlay.disabled = true;
    clearGalleryDetailTracks();

    ensureAlbumTracks(entry).then((albumTracks) => {
      if (request !== galleryDetailRequest || galleryDetailEntry !== entry) return;
      galleryDetailCount.textContent = `${albumTracks.length.toLocaleString()} tracks`;
      galleryDetailPlay.disabled = albumTracks.length === 0;
      if (!albumTracks.length) {
        galleryDetailStatus.textContent = "Tracks could not be loaded.";
        const retry = document.createElement("button");
        retry.className = "spcboy-gallery-detail-retry";
        retry.type = "button";
        retry.textContent = "Retry";
        retry.addEventListener("click", () => showGalleryAlbumDetails(entry));
        galleryDetailStatus.append(" ", retry);
        return;
      }
      galleryDetailStatus.hidden = true;
      albumTracks.forEach((track, index) => {
        const row = makeTrackRow(track, index);
        row.classList.add("spcboy-gallery-detail-row");
        galleryDetailTracks.append(row);
        const rows = trackRowsById.get(track.id) ?? [];
        rows.push(row);
        trackRowsById.set(track.id, rows);
      });
    });
  }

  function closeGalleryAlbumDetails() {
    if (!galleryDetail || !galleryDetailEntry) return;
    galleryDetailRequest += 1;
    galleryDetailEntry = null;
    clearGalleryDetailTracks();
    galleryDetailArtwork.removeAttribute("src");
    galleryDetailStatus.replaceChildren();
    galleryDetailStatus.hidden = true;
    galleryDetail.hidden = true;
    galleryPanel.classList.remove("is-detail-open");
    renderGallery();
  }

  async function playGalleryDetailAlbum() {
    const entry = galleryDetailEntry;
    if (!entry) return;
    const albumTracks = await ensureAlbumTracks(entry);
    if (galleryDetailEntry === entry && albumTracks.length) {
      window.SitePlayer?.playPlaylist(albumTracks);
    }
  }

  function openGalleryAlbum(entry) {
    if (!entry) return;
    if (!isDesktop()) {
      showGalleryAlbumDetails(entry);
      return;
    }
    if (view === "gallery") {
      releaseGalleryCards();
      view = "all";
      storage.set("view", view);
      search.value = "";
      if (headerSearch) headerSearch.value = "";
      pendingHeaderSearch = null;
      syncViewButtons();
      scheduleCatalogSearch();
    }
    selectedGameKey = entry.key;
    selectGame(entry.key);
    entry.details.scrollIntoView?.({ block: "nearest" });
    scheduleSelectionIndicators();
  }

  function syncTrackContainers() {
    const desktop = isDesktop();
    const mobileAggregate = !desktop && (view === "favorites" || Boolean(search.value.trim()));
    for (const entry of gameGroups) {
      const destination = desktop || mobileAggregate ? entry.playlistGroup : entry.slot;
      if (entry.list.parentElement !== destination) destination.append(entry.list);
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

  async function renderCatalog(catalog) {
    trackList.replaceChildren();
    tracks = [];
    tracksById.clear();
    trackIndexById.clear();
    trackRowsById.clear();
    searchOnlyRows.clear();
    gameGroups.length = 0;
    gameGroupsByKey.clear();
    gameGroupsByConsoleGame.clear();
    galleryCards.length = 0;
    galleryVisibleCount = 80;
    galleryConsoleSelect?.replaceChildren();
    galleryGrid.replaceChildren();
    galleryConsoleName = "";
    const consoles = Array.isArray(catalog.consoles) ? catalog.consoles : [];
    if (galleryConsoleSelect) galleryConsoleSelect.disabled = consoles.length === 0;
    const totalGames = consoles.reduce((total, consoleData) => total + (Array.isArray(consoleData.games) ? consoleData.games.length : 0), 0);
    let renderedGames = 0;
    updateCatalogBuildProgress(0, totalGames);
    for (const [consoleIndex, consoleData] of consoles.entries()) {
      const consoleName = canonicalConsoleName(consoleData.name);
      if (!galleryConsoleName) galleryConsoleName = consoleName;
      if (galleryConsoleSelect) {
        const option = document.createElement("option");
        option.value = consoleName;
        option.textContent = consoleName;
        galleryConsoleSelect.append(option);
      }
      const games = Array.isArray(consoleData.games) ? consoleData.games : [];
      const system = makeDetails("spcboy-system", consoleName, games.length);
      system.dataset.console = consoleName;
      const content = document.createElement("div");
      content.className = "spcboy-system-content";
      system.append(content);
      trackList.append(system);
      system.querySelector("summary").addEventListener("click", (event) => {
        if (view === "gallery" && isDesktop()) {
          event.preventDefault();
          selectGalleryConsole(consoleName);
        }
      });
      system.addEventListener("toggle", (event) => {
        if (!event.isTrusted || !system.open || isDesktop()) return;
        for (const other of trackList.querySelectorAll(".spcboy-system")) {
          if (other === system) continue;
          other.open = false;
          other.querySelectorAll(".spcboy-game").forEach((details) => { details.open = false; });
        }
      });
      for (const [gameIndex, gameData] of games.entries()) {
        const trackCount = Math.max(0, Number(gameData.trackCount) || 0);
        const group = makeDetails("spcboy-game", gameData.name, trackCount);
        if (!trackCount) group.classList.add("is-leaf");
        const albumId = typeof gameData.albumId === "string" ? gameData.albumId : "";
        const artworkUrl = typeof gameData.artworkUrl === "string" ? gameData.artworkUrl : "";
        const detailArtworkUrl = typeof gameData.detailArtworkUrl === "string" ? gameData.detailArtworkUrl : artworkUrl;
        const gameKey = `${consoleIndex}:${gameIndex}`;
        group.dataset.gameKey = gameKey;
        const gameRow = document.createElement("div");
        gameRow.className = "spcboy-game-row";
        gameRow.append(group);
        if (albumId) {
          const albumFavorite = makeAlbumFavoriteButton(albumId, gameData.name);
          albumFavorite.hidden = !isDesktop();
          gameRow.append(albumFavorite);
        }
        const slot = document.createElement("div");
        slot.className = "spcboy-track-slot";
        const list = document.createElement("ol");
        list.className = "spcboy-tracks";
        list.setAttribute("aria-label", `${gameData.name} tracks`);

        const playlistGroup = document.createElement("section");
        playlistGroup.className = "spcboy-playlist-group";
        const playlistGroupTitle = document.createElement("h3");
        playlistGroupTitle.className = "spcboy-playlist-group-title";
        playlistGroupTitle.textContent = `${gameData.name} · ${consoleName}`;
        playlistGroup.append(playlistGroupTitle, list);
        group.append(slot);
        content.append(gameRow);

        const entry = {
          key: gameKey,
          albumId,
          artworkUrl,
          detailArtworkUrl,
          consoleName,
          gameName: gameData.name,
          trackCount,
          tracks: [],
          loaded: false,
          loading: false,
          loadPromise: null,
          row: gameRow,
          details: group,
          slot,
          list,
          playlistGroup,
          title: playlistGroupTitle,
        };
        group.querySelector("summary").addEventListener("click", (event) => {
          if (isDesktop()) {
            event.preventDefault();
            selectGame(gameKey);
          }
        });
        group.addEventListener("toggle", (event) => {
          if (event.isTrusted && group.open && !isDesktop()) selectGame(gameKey);
        });
        gameGroups.push(entry);
        gameGroupsByKey.set(gameKey, entry);
        gameGroupsByConsoleGame.set(`${consoleName}\u0000${gameData.name}`, entry);
        if (artworkUrl) galleryCards.push(entry);
        renderedGames += 1;
        if (renderedGames % 32 === 0) {
          updateCatalogBuildProgress(renderedGames, totalGames);
          await new Promise((resolve) => window.requestAnimationFrame(resolve));
        }
      }
    }
    updateCatalogBuildProgress(renderedGames, totalGames);
    setCatalogFinishing();
    if (galleryConsoleSelect) galleryConsoleSelect.value = galleryConsoleName;
    syncSidebarAlbumFavorites();
    trackList.append(empty);
    catalogLoaded = true;
    catalogAvailable = true;
    resolveCatalogReady();
    renderMobileNowPlaying(window.SitePlayer?.getCurrentTrack?.() || currentTrack);
    renderMobileUpNext();
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
          selectTrack(requestedTrack, true);
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
    selectedGameKey = gameKey;
    syncWorkspaceHeading(selectedEntry.gameName || "Playlist");
    if (isDesktop() && (view === "favorites" || view === "recent")) {
      captureWorkspace();
      applyFilters();
      return;
    }
    for (const entry of gameGroups) {
      const selected = entry.key === gameKey;
      entry.details.classList.toggle("is-selected", selected);
      if (isDesktop() && openSidebar) entry.details.open = selected && view !== "favorites";
    }
    if (isDesktop() && openSidebar) {
      const selectedSystem = selectedEntry.details.closest(".spcboy-system");
      if (selectedSystem) selectedSystem.open = true;
    }
    if (!isDesktop() && openSidebar) {
      const selectedSystem = selectedEntry.details.closest(".spcboy-system");
      for (const entry of gameGroups) {
        if (entry !== selectedEntry) entry.details.open = false;
      }
      for (const system of trackList.querySelectorAll(".spcboy-system")) {
        if (system !== selectedSystem) system.open = false;
      }
      if (selectedSystem) selectedSystem.open = true;
      selectedEntry.details.open = true;
    }
    ensureAlbumTracks(selectedEntry);
    captureWorkspace();
    if (isDesktop() && (view === "favorites" || (view === "all" && !search.value.trim()))) renderDesktopPlaylist();
    scheduleSelectionIndicators();
  }

  function syncResponsiveLists() {
    const desktop = isDesktop();
    syncSidebarAlbumFavorites();
    if (!desktop) {
      trackList.querySelectorAll(".spcboy-system, .spcboy-game").forEach((details) => { details.open = false; });
      for (const entry of gameGroups) entry.details.classList.toggle("is-selected", entry.key === selectedGameKey);
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
    return source.filter(track => !query || matchesSearchText(
      `${track.title} ${track.artist || ""} ${track.game} ${canonicalConsoleName(track.console)}`, query));
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
        const row = makeTrackRow(track, index);
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
    for (const entry of gameGroups) {
      entry.row.hidden = !keys.has(entry.key);
      entry.details.classList.toggle("is-selected", entry.key === selectedGameKey);
      entry.details.open = false;
    }
    for (const system of trackList.querySelectorAll('.spcboy-system')) {
      const entries = gameGroups.filter(entry => entry.details.closest('.spcboy-system') === system);
      const visibleEntries = entries.filter(entry => !entry.row.hidden)
        .sort((left, right) => (albumOrder.get(left.key) ?? Infinity) - (albumOrder.get(right.key) ?? Infinity));
      for (const entry of visibleEntries) entry.row.parentElement?.append(entry.row);
      const count = visibleEntries.length;
      system.hidden = count === 0;
      const label = system.querySelector('summary > .spcboy-count');
      if (label) label.textContent = String(count);
      if (expandAlbums && count) system.open = true;
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
    if (searchMore) searchMore.hidden = true;
    playlistContent.replaceChildren();
    renderCollectionPlaylist(tracks);
    libraryState.textContent = `${tracks.length.toLocaleString()} ${recent ? "recent plays" : "favorites"} · ${keys.size.toLocaleString()} albums`;
  }

  function renderDesktopPlaylist() {
    const mobileAggregate = !isDesktop() && (view === "favorites" || Boolean(search.value.trim()));
    if ((!isDesktop() && !mobileAggregate) || view === "gallery") return;
    playlistContent.replaceChildren();
    const query = search.value.trim().toLocaleLowerCase();
    if (isDesktop() && (view === "favorites" || view === "recent")) {
      renderCollectionPlaylist(collectionTracks());
      return;
    }
    const aggregate = view === "favorites" || Boolean(query);
    const candidates = aggregate
      ? gameGroups.filter((entry) => [...entry.list.querySelectorAll(".spcboy-track-row")].some((row) => !row.hidden))
      : [gameGroupsByKey.get(selectedGameKey)].filter((entry) => entry && !entry.row.hidden);

    if (!candidates.length) {
      playlistEmpty.hidden = false;
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
      const searchable = `${track.title} ${track.artist ?? ""} ${track.game} ${canonicalConsoleName(track.console)}`;
      if (query && !matchesSearchText(searchable, query)) continue;
      cardList.append(makeTrackCard(track, visibleCount));
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
    if (searchMore) searchMore.hidden = true;
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
      const searchText = `${entry.title} ${searchTrack?.artist ?? ""} ${entry.game} ${consoleName}`;
      if (query && !matchesSearchText(searchText, query)) continue;

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
          if (playable) selectTrack(playable, true);
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
    if (searchMore) searchMore.hidden = true;
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
    const showingGallery = view === "gallery";
    const desktopFavorites = isDesktop() && view === "favorites";
    const showingCards = !isDesktop() && (showingRecent || view === "favorites");
    const query = search.value.trim();
    const matchingFavoriteGameKeys = new Set(favoritePlaylistTracks
      .filter((track) => (favorites.has(track.id) || favoriteAlbums.has(track.albumId))
        && (!query || matchesSearchText(`${track.title} ${track.artist ?? ""} ${track.game} ${canonicalConsoleName(track.console)}`, query)))
      .map((track) => track.gameKey));
    const mobileAggregate = !isDesktop() && (view === "favorites" || Boolean(query));
    library.classList.toggle("is-searching", searchInitialPending && !showingRecent);
    library.classList.toggle("is-mobile-results", mobileAggregate);
    library.classList.toggle("is-card-view", showingCards);
    library.classList.toggle("is-recent", showingRecent);
    library.classList.toggle("is-gallery", showingGallery);
    library.classList.toggle("is-favorites", view === "favorites");
    trackList.hidden = showingCards || (showingGallery && !isDesktop()) || mobileAggregate;
    playlistPane.hidden = showingCards || showingGallery || (!isDesktop() && !mobileAggregate);
    cardPanel.hidden = !showingCards;
    galleryPanel.hidden = !showingGallery;
    shuffleFavoritesButton.hidden = view !== "favorites";
    if (isDesktop() && (view === "favorites" || showingRecent)) {
      renderDesktopCollection();
      return;
    }
    if (collectionSidebarView !== null) {
      for (const entry of gameGroups) entry.row.parentElement?.append(entry.row);
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
      if (searchMore) searchMore.hidden = true;
      if (view === "recent") renderRecents();
      else renderFavorites();
      placeSearchMore();
      scheduleSelectionIndicators();
      return;
    }
    let visibleTracks = 0;
    let visibleGames = 0;
    for (const [id, matchingRows] of trackRowsById) {
      const track = tracksById.get(id);
      const isFavorite = favorites.has(id) || Boolean(track?.albumId && favoriteAlbums.has(track.albumId));
      const isVisibleInView = view === "all" || showingGallery
        || (view === "favorites" && isFavorite);
      for (const row of matchingRows) {
        const track = tracksById.get(id);
        const matchesCurrentQuery = !query
          || (desktopFavorites
            ? matchesSearchText(`${track?.title ?? ""} ${track?.artist ?? ""} ${track?.game ?? ""} ${canonicalConsoleName(track?.console ?? "")}`, query)
            : Boolean(searchMatches?.has(id)));
        const isVisible = isVisibleInView && matchesCurrentQuery;
        row.hidden = !isVisible;
        if (isVisible) visibleTracks += 1;
      }
    }
    for (const entry of gameGroups) {
      const rows = [...entry.list.querySelectorAll(".spcboy-track-row")];
      const hasVisibleRows = rows.some((row) => !row.hidden);
      const shown = query
        ? desktopFavorites
          ? matchingFavoriteGameKeys.has(entry.key)
          : hasVisibleRows
        : view === "all" || (view === "favorites" && (hasVisibleRows || favoriteAlbums.has(entry.albumId)))
          || (showingGallery && entry.artworkUrl);
      const favoriteGroupVisible = desktopFavorites && (!query || matchesSearchText(`${entry.gameName} ${entry.consoleName}`, query));
      entry.row.hidden = desktopFavorites ? !favoriteGroupVisible : !shown;
      const selectionKey = desktopFavorites ? null : selectedGameKey;
      entry.details.classList.toggle("is-selected", entry.key === selectionKey);
      if (desktopFavorites ? favoriteGroupVisible : shown) visibleGames += 1;
    }
    for (const system of library.querySelectorAll(".spcboy-system")) {
      const shown = gameGroups.some((entry) => entry.details.closest(".spcboy-system") === system && !entry.row.hidden);
      system.hidden = !(showingGallery && !query) && !shown;
    }
    empty.hidden = desktopFavorites || visibleTracks !== 0 || (view === "all" && !query) || (showingGallery && !query)
      || (view === "favorites" && favoritePlaylistLoading);
    const hasFavorites = favorites.size > 0 || favoriteAlbums.size > 0;
    empty.textContent = view === "favorites" && !hasFavorites
      ? "Favorite a track or album to build your Favorites playlist."
      : query && searchLoading ? "Searching hosted tracks…"
        : query && searchFailed ? "Search is temporarily unavailable. Try again."
          : view === "favorites" && favoritePlaylistLoading ? "Loading your favorites…"
            : view === "favorites" && favoritePlaylistFailed ? "Favorites could not load. Switch tabs and try again."
              : "No matching tracks.";
    if (view === "favorites" && !hasFavorites) playlistEmpty.textContent = "Favorite a track or album to build your Favorites playlist.";
    else if (query && searchLoading) playlistEmpty.textContent = "Searching hosted tracks…";
    else if (query && searchFailed) playlistEmpty.textContent = "Search is temporarily unavailable. Try again.";
    else if (view === "favorites" && favoritePlaylistLoading) playlistEmpty.textContent = "Loading your favorites…";
    else if (view === "favorites" && favoritePlaylistFailed) playlistEmpty.textContent = "Favorites could not load. Switch tabs and try again.";
    else playlistEmpty.textContent = "No matching tracks.";
    if (showingGallery) {
      const galleryCount = renderGallery();
      libraryState.textContent = query && searchLoading ? "Searching…" : `${galleryCount.toLocaleString()} albums`;
    } else {
      if (isDesktop() || mobileAggregate) renderDesktopPlaylist();
      libraryState.textContent = query && searchLoading ? "Searching…" : gameCountLabel(visibleGames);
    }
    if (searchMore) {
      searchMore.hidden = !query || !searchNextPage || view === "recent";
      searchMore.disabled = searchLoading;
      searchMore.textContent = searchLoading ? "Searching…" : "Load more results";
    }
    if (favoriteMore) {
      favoriteMore.hidden = view !== "favorites" || !favoritePlaylistNextPage || favoritePlaylistLoading || !favoritePlaylistTracks.length;
      favoriteMore.disabled = favoritePlaylistLoading;
      favoriteMore.textContent = favoritePlaylistLoading ? "Loading favorites…" : "Load more favorites";
    }
    placeSearchMore();
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  }

  async function loadSearchPage(query, pageNumber, requestToken) {
    const controller = new AbortController();
    searchController = controller;
    const url = new URL(page.dataset.searchUrl, window.location.href);
    url.searchParams.set("q", query);
    url.searchParams.set("page", String(pageNumber));
    try {
      const response = await fetch(url, {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`Search request returned ${response.status}.`);
      const payload = await response.json();
      if (requestToken !== searchRequestToken || query !== search.value.trim()) return;
      if (!Array.isArray(payload.results)) throw new Error("Search results are invalid.");
      if (pageNumber === 1) searchMatches = new Set();
      for (const result of payload.results) {
        if (typeof result.id !== "string") continue;
        searchMatches.add(result.id);
        const entry = gameGroupsByConsoleGame.get(`${canonicalConsoleName(result.console)}\u0000${result.game}`);
        if (entry && !entry.loaded) appendTrackRow(entry, result, { searchOnly: true });
      }
      searchNextPage = Number.isInteger(payload.nextPage) ? payload.nextPage : null;
      searchLoading = false;
      searchFailed = false;
      searchInitialPending = false;
      applyFilters();
    } catch {
      if (requestToken !== searchRequestToken || controller.signal.aborted) return;
      searchLoading = false;
      searchFailed = true;
      searchInitialPending = false;
      searchNextPage = null;
      applyFilters();
    }
  }

  function scheduleCatalogSearch() {
    captureWorkspace();
    const query = search.value.trim();
    if (view === "gallery") galleryVisibleCount = 80;
    window.clearTimeout(searchTimer);
    if (searchController) searchController.abort();
    searchRequestToken += 1;
    clearSearchOnlyRows();
    searchMatches = query ? new Set() : null;
    const localCollection = view === "favorites" || view === "recent";
    searchNextPage = query && !localCollection ? 1 : null;
    searchLoading = Boolean(query) && !localCollection;
    searchFailed = false;
    searchInitialPending = Boolean(query) && !localCollection;
    if (localCollection) {
      applyFilters();
      return;
    }
    if (query) {
      library.classList.toggle("is-searching", view !== "recent");
      libraryState.textContent = "Searching…";
      empty.hidden = false;
      empty.textContent = "Searching hosted tracks…";
      playlistEmpty.hidden = false;
      playlistEmpty.textContent = "Searching hosted tracks…";
      if (view === "gallery") {
        galleryGrid.hidden = true;
        galleryEmpty.hidden = false;
        galleryEmpty.textContent = "Searching hosted tracks…";
      }
      if (view === "recent") applyFilters();
    } else applyFilters();
    if (!query) return;
    const token = searchRequestToken;
    searchTimer = window.setTimeout(() => {
      const load = () => {
        if (token === searchRequestToken && query === search.value.trim()) loadSearchPage(query, 1, token);
      };
      if (catalogLoaded) load();
      else catalogReady.then(load);
    }, 65);
  }

  function loadMoreSearchResults() {
    if (!searchNextPage || searchLoading) return;
    const query = search.value.trim();
    if (!query) return;
    searchLoading = true;
    const requestedPage = searchNextPage;
    applyFilters();
    loadSearchPage(query, requestedPage, searchRequestToken);
  }

  async function selectTrack(track, startPlayback) {
    const selectionToken = ++playbackSelectionToken;
    const resolvedGroup = track.gameKey
      ? gameGroupsByKey.get(track.gameKey)
      : gameGroupsByConsoleGame.get(`${canonicalConsoleName(track.console)}\u0000${track.game}`);
    if (resolvedGroup) track = cacheTrack(resolvedGroup, track);
    const playingFavorites = view === "favorites";
    const playingCollection = playingFavorites || view === "recent";
    if (track.gameKey && !playingCollection) {
      selectGame(track.gameKey);
      const selectedGroup = gameGroupsByKey.get(track.gameKey);
      if (selectedGroup) {
        const selectedSystem = selectedGroup.details.closest(".spcboy-system");
        if (selectedSystem) selectedSystem.open = true;
        if (!isDesktop()) selectedGroup.details.open = true;
      }
    }
    syncCurrentTrackRows(currentTrack?.id, false);
    currentTrack = track;
    syncCurrentTrackRows(track.id, true);

    if (view === "recent") applyFilters();
    scheduleSelectionIndicators();

    if (startPlayback) {
      const query = search.value.trim();
      const albumTracks = view === "recent"
        ? collectionTracks().filter(candidate => candidate.available !== false && (!selectedGameKey || candidate.gameKey === selectedGameKey))
        : playingFavorites
        ? (await loadFavoritePlaylist({allPages:true})).filter(candidate =>
            (!selectedGameKey || candidate.gameKey === selectedGameKey) &&
            (!query || matchesSearchText(`${candidate.title} ${candidate.artist ?? ""} ${candidate.game} ${candidate.console}`, query)))
        : resolvedGroup ? await ensureAlbumTracks(resolvedGroup) : [];
      if (selectionToken !== playbackSelectionToken) return;
      const playlist = albumTracks.length ? albumTracks : [track];
      await window.SitePlayer?.playPlaylist(playlist, {
        startTrackId: track.id,
        toggle: true,
      });
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
  playlistContent.addEventListener("scroll", syncPlaylistHeaderScroll, {passive:true});
  document.fonts.ready.then(schedulePlaylistColumnLayout);
  window.addEventListener("resize", schedulePlaylistColumnLayout, { passive: true });
  document.addEventListener("sb:interface-changed", schedulePlaylistColumnLayout);
  galleryMore?.addEventListener("click", () => {
    const start = galleryVisibleCount;
    galleryVisibleCount += 80;
    renderGalleryWithLoading({ start, message: "Loading more gallery artwork…" });
  });
  galleryDetailBack?.addEventListener("click", closeGalleryAlbumDetails);
  galleryDetailPlay?.addEventListener("click", playGalleryDetailAlbum);
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
    if (isDesktop() && galleryDetailEntry) closeGalleryAlbumDetails();
    syncSidebarAlbumFavorites();
    syncViewButtons();
    hoveredSidebarItem = null;
    hoveredPlaylistRow = null;
    lastPlaylistIndicatorTrackId = null;
    syncResponsiveLists();
    applyGalleryZoom();
    schedulePlaylistColumnLayout();
    scheduleSelectionIndicators();
  });
  foldAllButton?.addEventListener("click", () => {
    trackList.querySelectorAll(".spcboy-system, .spcboy-game").forEach((details) => { details.open = false; });
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
      const previousView = view;
      view = tab.dataset.view;
      storage.set("view", view);
      if (view === "favorites" || view === "recent") selectedGameKey = null;
      if (previousView === "gallery" && view !== "gallery") {
        closeGalleryAlbumDetails();
        releaseGalleryCards();
      }
      syncViewButtons();
      captureWorkspace();
      scheduleSelectionIndicators();
      if (view === "gallery") renderGalleryWithLoading();
      else if (search.value.trim()) scheduleCatalogSearch();
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
  function mobileGroupForTrack(track) {
    if (!track) return null;
    const albumId = track.albumId
      || String(track.albumPlaylistUrl || "").match(/\/spcboy\/album\/([0-9a-f]{32})\.json(?:$|\?)/)?.[1]
      || "";
    return (albumId && gameGroups.find((group) => group.albumId === albumId))
      || (track.console && track.game
        ? gameGroupsByConsoleGame.get(`${canonicalConsoleName(track.console)}\u0000${track.game}`)
        : null)
      || (track.gameKey ? gameGroupsByKey.get(track.gameKey) : null)
      || null;
  }
  function renderMobileAlbumTracks(group, albumTracks, activeTrack) {
    if (!mobileUpNext) return;
    mobileUpNext.replaceChildren();
    if (!albumTracks.length) {
      const item = document.createElement("li");
      if (group.loadFailed) {
        const retry = document.createElement("button");
        retry.type = "button";
        retry.textContent = "Retry track list";
        retry.addEventListener("click", () => {
          retry.disabled = true;
          ensureAlbumTracks(group, { retry: true }).then((tracks) => {
            renderMobileAlbumTracks(group, tracks, window.SitePlayer?.getCurrentTrack?.() || currentTrack);
          });
        });
        item.append(retry);
      }
      mobileUpNext.append(item);
      return;
    }
    albumTracks.forEach((track, index) => {
      const item = document.createElement("li");
      const button = document.createElement("button");
      const isCurrent = track.id === activeTrack?.id;
      button.type = "button";
      button.setAttribute("aria-label", `Play ${track.title}${group.gameName ? `, ${group.gameName}` : ""}`);
      if (isCurrent) button.setAttribute("aria-current", "true");
      const title = document.createElement("span");
      title.textContent = track.title || track.id;
      const number = document.createElement("span");
      number.textContent = String(index + 1).padStart(2, "0");
      button.append(title, number);
      button.addEventListener("click", () => selectTrack(track, true));
      item.append(button);
      mobileUpNext.append(item);
    });
  }
  function renderMobileUpNext() {
    if (!mobileUpNext) return;
    if (isDesktop()) {
      mobileUpNext.replaceChildren();
      mobileTrackListAlbumId = "";
      return;
    }
    const activeTrack = window.SitePlayer?.getCurrentTrack?.() || currentTrack;
    const group = mobileGroupForTrack(activeTrack);
    if (group) {
      if (group.albumId !== mobileTrackListAlbumId) {
        mobileTrackListAlbumId = group.albumId;
        mobileTrackListGeneration += 1;
        mobileUpNext.replaceChildren();
      }
      if (group.loaded) {
        renderMobileAlbumTracks(group, group.tracks, activeTrack);
        return;
      }
      const generation = mobileTrackListGeneration;
      if (!mobileUpNext.firstElementChild) {
        const loading = document.createElement("li");
        loading.className = "spcboy-mobile-track-list-state";
        loading.textContent = "Loading tracks…";
        mobileUpNext.append(loading);
      }
      ensureAlbumTracks(group).then((albumTracks) => {
        const latestTrack = window.SitePlayer?.getCurrentTrack?.() || currentTrack;
        if (generation !== mobileTrackListGeneration || mobileGroupForTrack(latestTrack)?.albumId !== group.albumId) return;
        renderMobileAlbumTracks(group, albumTracks, latestTrack);
        renderMobileNowPlaying(latestTrack);
      });
      return;
    }
    mobileTrackListAlbumId = "";
    mobileUpNext.replaceChildren();
    const tracks = (window.SitePlayer?.getQueue?.() || []).slice(0, 3);
    const queueActions = [...document.querySelectorAll("#site-player-queue .site-player-queue-track")];
    tracks.forEach((track, index) => {
      const item = document.createElement("li");
      const button = document.createElement("button");
      button.type = "button";
      button.setAttribute("aria-label", `Play ${track.title}${track.game ? `, ${track.game}` : ""}`);
      const title = document.createElement("span");
      title.textContent = track.title || track.id;
      const album = document.createElement("span");
      album.textContent = track.game || "";
      button.append(title, album);
      button.addEventListener("click", () => {
        if (queueActions[index]) queueActions[index].click();
        else window.SitePlayer?.playNow?.(track);
      });
      item.append(button);
      mobileUpNext.append(item);
    });
  }
  function renderMobileNowPlaying(track = currentTrack) {
    if (!mobileNowPlaying) return;
    const activeTrack = track || null;
    const matchingGroup = mobileGroupForTrack(activeTrack);
    const artworkURL = activeTrack
      ? (matchingGroup?.detailArtworkUrl || activeTrack.artworkUrl || tracksById.get(activeTrack.id)?.artworkUrl || matchingGroup?.artworkUrl || "")
      : "";
    mobileNowPlaying.classList.toggle("is-empty", !activeTrack);
    mobileNowPlaying.classList.toggle("has-artwork", Boolean(artworkURL));
    if (mobileNowTitle) mobileNowTitle.textContent = activeTrack?.title || "Nothing playing";
    if (mobileNowAlbum) mobileNowAlbum.textContent = activeTrack?.game || matchingGroup?.gameName || activeTrack?.console || "";
    if (mobileNowArtwork) {
      mobileNowArtwork.hidden = false;
      mobileNowArtwork.alt = artworkURL ? `${activeTrack.game || activeTrack.title} artwork` : "";
      mobileNowArtwork.dataset.fallbackArtwork = matchingGroup?.artworkUrl && artworkURL !== matchingGroup.artworkUrl
        ? matchingGroup.artworkUrl : "";
      if (artworkURL && mobileNowArtwork.getAttribute("src") !== artworkURL) mobileNowArtwork.src = artworkURL;
      if (!artworkURL) mobileNowArtwork.removeAttribute("src");
    }
    const timeline = mobileNowPlaying.querySelector(".spcboy-mobile-now-timeline");
    if (timeline) timeline.hidden = !activeTrack;
    const playing = Boolean(activeTrack && window.SitePlayer?.isPlaying?.());
    if (mobilePlayButton) {
      mobilePlayButton.disabled = playButton?.disabled ?? !activeTrack;
      mobilePlayButton.classList.toggle("is-playing", playing);
      mobilePlayButton.setAttribute("aria-label", playing ? "Pause" : "Play");
    }
    if (mobilePreviousButton) mobilePreviousButton.disabled = previousButton?.disabled ?? !activeTrack;
    if (mobileNextButton) mobileNextButton.disabled = nextButton?.disabled ?? !activeTrack;
    const clockParts = document.querySelector("#spcboy-playback-clock")?.textContent.split(" / ") || [];
    const elapsedText = activeTrack ? (clockParts[0] || "0:00") : "0:00";
    const durationText = activeTrack ? (clockParts[1] || formatMobileTime(window.SitePlayer?.getDuration?.(activeTrack))) : "0:00";
    if (mobileElapsed) mobileElapsed.textContent = elapsedText;
    if (mobileDuration) mobileDuration.textContent = durationText;
    const elapsed = parseMobileTime(elapsedText);
    const duration = parseMobileTime(durationText);
    const progress = Number.isFinite(duration) && duration > 0 ? Math.max(0, Math.min(100, elapsed / duration * 100)) : 0;
    if (mobileProgressFill) mobileProgressFill.style.width = `${progress}%`;
    if (mobileProgress) mobileProgress.setAttribute("aria-valuenow", String(Math.round(progress)));
  }
  function setMobileAppPage(nextPage, { syncView = true } = {}) {
    if (!mobileAppNav || !mobileNowPlaying) return;
    if (!["playing", "library", "gallery", "sound", "options"].includes(nextPage)) return;
    mobileAppPage = nextPage;
    if (isDesktop()) {
      library.hidden = false;
      mobileNowPlaying.hidden = true;
      mobileSoundSettings.hidden = true;
      mobileOptionsSettings.hidden = true;
      document.body.classList.remove("spcboy-mobile-playing", "spcboy-mobile-library", "spcboy-mobile-gallery", "spcboy-mobile-sound", "spcboy-mobile-options");
      return;
    }
    mobileNowPlaying.hidden = mobileAppPage !== "playing";
    library.hidden = mobileAppPage !== "library" && mobileAppPage !== "gallery";
    mobileSoundSettings.hidden = mobileAppPage !== "sound";
    mobileOptionsSettings.hidden = mobileAppPage !== "options";
    audioSettingsPage.hidden = mobileAppPage !== "sound";
    playbackSettingsPage.hidden = mobileAppPage !== "sound";
    interfaceSettingsPage.hidden = mobileAppPage !== "options";
    document.body.classList.remove("spcboy-mobile-playing", "spcboy-mobile-library", "spcboy-mobile-gallery", "spcboy-mobile-sound", "spcboy-mobile-options");
    document.body.classList.add(`spcboy-mobile-${mobileAppPage}`);
    for (const button of mobileAppButtons) {
      const selected = button.dataset.mobileAppPage === mobileAppPage;
      if (selected) button.setAttribute("aria-current", "page");
      else button.removeAttribute("aria-current");
    }
    if (!syncView) return;
    const targetView = nextPage === "gallery" ? "gallery" : nextPage === "library" ? "all" : null;
    if (targetView && view !== targetView) tabs.find(tab => tab.dataset.view === targetView)?.click();
  }
  mobileAppNav?.addEventListener("click", event => {
    const nextPage = event.target instanceof Element
      ? event.target.closest("[data-mobile-app-page]")?.dataset.mobileAppPage
      : null;
    if (!nextPage) return;
    setMobileAppPage(nextPage);
  });
  mobilePlayButton?.addEventListener("click", () => playButton?.click());
  mobilePreviousButton?.addEventListener("click", () => previousButton?.click());
  mobileNextButton?.addEventListener("click", () => nextButton?.click());
  const queueObserverTarget = document.querySelector("#site-player-queue");
  if (queueObserverTarget && mobileUpNext) {
    new MutationObserver(renderMobileUpNext).observe(queueObserverTarget, { childList: true });
  }
  if (mobileAppNav) {
    placeMobileSettingsPages();
    setMobileAppPage(mobileAppPage, { syncView: false });
    const activeTrack = window.SitePlayer?.getCurrentTrack?.() || currentTrack;
    if (activeTrack) currentTrack = activeTrack;
    renderMobileNowPlaying(activeTrack);
    renderMobileUpNext();
  }
  audio?.addEventListener("timeupdate", () => renderMobileNowPlaying());
  audio?.addEventListener("playing", () => renderMobileNowPlaying());
  audio?.addEventListener("pause", () => renderMobileNowPlaying());
  audio?.addEventListener("ended", () => renderMobileNowPlaying());
  mobileNowArtwork?.addEventListener("error", () => {
    const fallback = mobileNowArtwork.dataset.fallbackArtwork;
    if (fallback && mobileNowArtwork.getAttribute("src") !== fallback) {
      mobileNowArtwork.dataset.fallbackArtwork = "";
      mobileNowArtwork.src = fallback;
      return;
    }
    mobileNowArtwork.removeAttribute("src");
    mobileNowPlaying?.classList.remove("has-artwork");
  });
  recentMore.addEventListener("click", () => loadRecents());
  searchMore?.addEventListener("click", loadMoreSearchResults);
  favoriteMore?.addEventListener("click", () => loadFavoritePlaylist());
  window.addEventListener("siteplayer:track", (event) => {
    const rawTrack = event.detail?.track;
    if (!rawTrack) return;
    if (rawTrack.id !== currentTrack?.id) playbackSelectionToken += 1;
    const group = rawTrack.gameKey
      ? gameGroupsByKey.get(rawTrack.gameKey)
      : gameGroupsByConsoleGame.get(`${canonicalConsoleName(rawTrack.console)}\u0000${rawTrack.game}`);
    syncCurrentTrackRows(currentTrack?.id, false);
    currentTrack = tracksById.get(rawTrack.id) || (group ? cacheTrack(group, rawTrack) : rawTrack);
    syncCurrentTrackRows(currentTrack.id, true);
    renderMobileNowPlaying(currentTrack);
    renderMobileUpNext();
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
  const workspaceViews = ['all','gallery','favorites','recent'];
  const savedWorkspace = storage.get('workspaceTabs', null);
  const hasSavedWorkspace = savedWorkspace?.version === 1 && Array.isArray(savedWorkspace.tabs) && savedWorkspace.tabs.length > 0;
  const seenWorkspaceIds = new Set();
  let workspaceTabs = (hasSavedWorkspace ? savedWorkspace.tabs : []).slice(0,24).flatMap(tab => {
    if (!tab || typeof tab.id !== 'string' || tab.id.length > 80 || seenWorkspaceIds.has(tab.id)) return [];
    seenWorkspaceIds.add(tab.id);
    return [{ id: tab.id, view: workspaceViews.includes(tab.view) ? tab.view : 'all',
      albumId: typeof tab.albumId === 'string' && /^[0-9a-f]{32}$/.test(tab.albumId) ? tab.albumId : null,
      query: typeof tab.query === 'string' ? tab.query.slice(0,256) : '',
      console: typeof tab.console === 'string' ? tab.console.slice(0,160) : '',
      sidebarScroll: Math.max(0,Math.min(1000000,Number(tab.sidebarScroll)||0)),
      playlistScroll: Math.max(0,Math.min(1000000,Number(tab.playlistScroll)||0)),
    }];
  });
  if (!workspaceTabs.length) workspaceTabs = [{ id: crypto.randomUUID(), view, albumId: null, query: '', console: '' }];
  let activeWorkspaceId = workspaceTabs.some(tab => tab.id === savedWorkspace?.activeId) ? savedWorkspace.activeId : workspaceTabs[0].id;
  let restoringWorkspace = false;
  let workspaceScrollTimer = 0;
  let contextEntry = null;
  let contextReturnFocus = null;
  function activeWorkspace() { return workspaceTabs.find(tab => tab.id === activeWorkspaceId); }
  function workspaceLabel(tab) {
    if (tab.query) return `Search: ${tab.query}`;
    if (tab.view !== 'all') return ({gallery:'Gallery',favorites:'Favorites',recent:'Recent'})[tab.view];
    return gameGroups.find(entry => entry.albumId === tab.albumId)?.gameName || 'Library';
  }
  function persistWorkspaces() {
    storage.set('workspaceTabs', { version:1, activeId:activeWorkspaceId, tabs:workspaceTabs });
  }
  function captureWorkspace({ render = true } = {}) {
    if (restoringWorkspace || !catalogAvailable || !page.isConnected) return;
    const tab = activeWorkspace();
    if (!tab) return;
    Object.assign(tab, { view, query:search.value.slice(0,256), console:galleryConsoleName,
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
    closeGalleryAlbumDetails();
    restoringWorkspace = true;
    closeWorkspaceMenu();
    activeWorkspaceId = id;
    const tab = activeWorkspace();
    view = tab.view;
    search.value = tab.query;
    galleryConsoleName = tab.console || gameGroups[0]?.consoleName || '';
    const selectedAlbumId = tab.albumId;
    const entry = gameGroups.find(entry => entry.albumId === selectedAlbumId);
    selectedGameKey = entry?.key || null;
    trackList.querySelectorAll("details[open]").forEach(details => { details.open = false; });
    syncViewButtons();
    if (entry) selectGame(entry.key);
    // Clearing a search also aborts the previous tab's pending search request.
    scheduleCatalogSearch();
    if (view === 'gallery') renderGalleryWithLoading();
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
    const tab = { id:crypto.randomUUID(), view:'all', albumId:entry?.albumId || null, query:'', console:entry?.consoleName || '', sidebarScroll:0, playlistScroll:0 };
    workspaceTabs.push(tab);
    if (!background) restoreWorkspace(tab.id, {initial:true});
    else { persistWorkspaces(); renderWorkspaces(); }
  }
  function openWorkspaceForAlbum(albumId) {
    const entry = gameGroups.find(candidate => candidate.albumId === albumId);
    if (!entry) return false;
    if (!isDesktop()) {
      setMobileAppPage("gallery", { syncView: false });
      if (view !== "gallery") tabs.find(tab => tab.dataset.view === "gallery")?.click();
      openGalleryAlbum(entry);
      return true;
    }
    const existing = workspaceTabs.find(tab => tab.albumId === albumId);
    if (existing) {
      if (existing.id === activeWorkspaceId) captureWorkspace({render:false});
      existing.view = "all";
      existing.query = "";
      existing.console = entry.consoleName;
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
    if (!workspaceTabs.length) workspaceTabs.push({id:crypto.randomUUID(),view:'all',albumId:null,query:'',console:''});
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
    if (!(event.metaKey || event.ctrlKey) || !event.target.closest('summary,.spcboy-track,.spcboy-gallery-open,.spcboy-gallery-name')) return;
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
      if (view === "gallery") renderGalleryWithLoading();
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
