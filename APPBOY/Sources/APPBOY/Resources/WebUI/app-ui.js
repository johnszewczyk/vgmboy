(() => {
  const app = window.APPBOYApp;
  const { state, refs } = app;

  let activeIndicatorTarget = null;

  function isCompactViewport() {
    return window.matchMedia("(max-width: 767px)").matches;
  }

  function moveSelectionIndicator(target, { instant = false } = {}) {
    const el = refs.indicator;
    if (!el) return;
    if (!target || !state.preferences.selectionAnimationEnabled || !document.body.contains(target)) {
      el.classList.remove("is-ready");
      el.classList.add("is-hidden");
      return;
    }
    const rect = target.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
      el.classList.remove("is-ready");
      el.classList.add("is-hidden");
      return;
    }
    activeIndicatorTarget = target;
    if (instant) {
      el.style.transition = "none";
    } else {
      el.style.transition = "";
    }
    el.classList.remove("is-hidden");
    el.style.width = `${rect.width}px`;
    el.style.height = `${rect.height}px`;
    el.style.transform = `translate3d(${rect.left}px, ${rect.top}px, 0)`;
    requestAnimationFrame(() => {
      el.classList.add("is-ready");
    });
  }

  function refreshIndicatorPosition() {
    if (activeIndicatorTarget && !state.optionsOpen) {
      moveSelectionIndicator(activeIndicatorTarget, { instant: true });
    } else {
      refs.indicator?.classList.add("is-hidden");
    }
  }

  function updateTitlebarAndStats() {
    const tab = app.activeTab();
    const c = state.catalog;
    refs.consoleLabel.textContent = state.contentMode === "gallery"
      ? "GALLERY"
      : (tab?.consoleName || "LIBRARY").toUpperCase();
    refs.albumLabel.textContent = state.contentMode === "gallery"
      ? "ARTWORK GRID"
      : (tab?.title || "NO PLAYLIST");
    refs.sourceChip.textContent = (c.sourceLabel || "BUILT-IN").toUpperCase();

    const sysWord = c.consoleCount === 1 ? "SYSTEM" : "SYSTEMS";
    const albWord = c.albumCount === 1 ? "ALBUM" : "ALBUMS";
    refs.sidebarStats.textContent = `${c.consoleCount} ${sysWord} · ${c.albumCount} ${albWord} · ${c.trackCount} TRK`;
  }

  function syncModeButtons() {
    document.body.dataset.mobilePane = state.mobilePane;
    const modeButtons = refs.mobileModeBar.querySelectorAll("[data-mobile-target]");
    let selectedBtn = null;
    modeButtons.forEach((btn) => {
      const active = btn.dataset.mobileTarget === state.mobilePane;
      btn.classList.toggle("is-selected", active);
      if (active) selectedBtn = btn;
    });

    const isGallery = state.contentMode === "gallery";
    refs.playlistView.classList.toggle("is-hidden", isGallery);
    refs.galleryView.classList.toggle("is-hidden", !isGallery);

    const tab = app.activeTab();
    refs.splitGalleryBtn?.setAttribute("aria-pressed", isGallery ? "true" : "false");
    refs.splitFavoritesBtn?.setAttribute(
      "aria-pressed",
      !isGallery && tab?.sourceKind === "favorites" ? "true" : "false"
    );
    refs.splitRecentBtn?.setAttribute(
      "aria-pressed",
      !isGallery && tab?.sourceKind === "history" ? "true" : "false"
    );

    if (isCompactViewport() && selectedBtn) {
      moveSelectionIndicator(selectedBtn);
    }
  }

  function setMobilePane(targetPane) {
    if (targetPane === "favorites") {
      void openFavoritesTab();
      return;
    }
    if (targetPane === "recent") {
      void openRecentTab();
      return;
    }
    if (targetPane === "gallery") {
      state.contentMode = "gallery";
      state.mobilePane = "gallery";
      renderGallery();
      updateTitlebarAndStats();
      syncModeButtons();
      return;
    }
    if (targetPane === "playlist") {
      state.contentMode = "playlist";
      state.mobilePane = "playlist";
      updateTitlebarAndStats();
      syncModeButtons();
      return;
    }
    state.mobilePane = "library";
    syncModeButtons();
  }

  function filteredConsoles() {
    const q = state.searchQuery.trim().toLowerCase();
    if (!q) return state.catalog.consoles || [];
    const out = [];
    for (const group of state.catalog.consoles || []) {
      const consoleMatch = group.name.toLowerCase().includes(q) || group.shortCode.toLowerCase().includes(q);
      const matchingAlbums = group.albums.filter((alb) =>
        consoleMatch
        || alb.title.toLowerCase().includes(q)
        || alb.artist.toLowerCase().includes(q)
        || alb.year.toLowerCase().includes(q)
      );
      if (matchingAlbums.length > 0) {
        out.push({ ...group, albums: matchingAlbums });
      }
    }
    return out;
  }

  function isAlbumAllFavorited(album) {
    // Check loaded tab tracks if cached, else check matching prefix in favoriteIds
    let matchedCount = 0;
    for (const favId of state.favoriteIds) {
      if (favId.startsWith(`${album.id}-t`)) matchedCount += 1;
    }
    return album.trackCount > 0 && matchedCount >= album.trackCount;
  }

  function renderLibraryTree() {
    const groups = filteredConsoles();
    const searching = state.searchQuery.trim().length > 0;
    const showCounts = Boolean(state.preferences.sidebarTrackCounts);

    const anyExpanded = (state.catalog.consoles || []).some((c) => state.expandedConsoleIds.has(c.id));
    refs.foldIconUse?.setAttribute("href", anyExpanded ? "#icon-list-collapse" : "#icon-list-expand");
    refs.foldToggleBtn?.setAttribute("title", anyExpanded ? "Collapse all" : "Expand all");
    refs.foldToggleBtn?.setAttribute("aria-label", anyExpanded ? "Collapse all" : "Expand all");

    if (!groups.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = searching ? "No matching consoles or albums." : "No catalog albums available.";
      refs.treeRoot.replaceChildren(empty);
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const group of groups) {
      const expanded = searching || state.expandedConsoleIds.has(group.id);
      const wrapper = document.createElement("div");
      wrapper.className = "console-group";

      const headerBtn = document.createElement("button");
      headerBtn.type = "button";
      headerBtn.className = "console-row";
      headerBtn.setAttribute("aria-expanded", expanded ? "true" : "false");

      const disc = document.createElement("span");
      disc.className = "console-disclosure";
      disc.textContent = expanded ? "▾" : "▸";

      const code = document.createElement("span");
      code.className = "console-code";
      code.textContent = group.shortCode;

      const name = document.createElement("span");
      name.className = "console-name";
      name.textContent = group.name;

      const count = document.createElement("span");
      count.className = "console-count";
      count.textContent = String(group.albums.length);

      headerBtn.append(disc, code, name, count);
      headerBtn.addEventListener("click", () => {
        if (state.expandedConsoleIds.has(group.id)) {
          state.expandedConsoleIds.delete(group.id);
        } else {
          state.expandedConsoleIds.add(group.id);
        }
        renderLibraryTree();
      });
      wrapper.appendChild(headerBtn);

      if (expanded) {
        const list = document.createElement("div");
        list.className = "console-albums";
        for (const album of group.albums) {
          const item = document.createElement("div");
          item.className = "album-item";
          if (state.selectedAlbumId === album.id) item.classList.add("is-selected");

          const rowBtn = document.createElement("button");
          rowBtn.type = "button";
          rowBtn.className = "album-row";

          const copy = document.createElement("span");
          copy.className = "album-copy";
          const title = document.createElement("span");
          title.className = "album-title";
          title.textContent = album.title;
          const sub = document.createElement("span");
          sub.className = "album-sub";
          sub.textContent = `${album.artist} · ${album.year}`;
          copy.append(title, sub);
          rowBtn.appendChild(copy);

          if (showCounts) {
            const trkCount = document.createElement("span");
            trkCount.className = "album-track-count";
            trkCount.textContent = `${album.trackCount}`;
            rowBtn.appendChild(trkCount);
          }

          rowBtn.addEventListener("click", () => {
            void openAlbumInPlaylist(album, { autoPlay: false });
          });

          const favBtn = document.createElement("button");
          favBtn.type = "button";
          favBtn.className = "album-fav-button";
          const allFav = isAlbumAllFavorited(album);
          if (allFav) favBtn.classList.add("is-favorite");
          favBtn.setAttribute("aria-label", `Favorite album ${album.title}`);
          favBtn.innerHTML = '<svg class="ui-icon" aria-hidden="true"><use href="#icon-star"></use></svg>';
          favBtn.addEventListener("click", async (ev) => {
            ev.stopPropagation();
            await toggleAlbumFavorite(album.id);
          });

          item.append(rowBtn, favBtn);
          list.appendChild(item);
        }
        wrapper.appendChild(list);
      }
      fragment.appendChild(wrapper);
    }
    refs.treeRoot.replaceChildren(fragment);
  }

  async function openAlbumInPlaylist(album, { autoPlay = false } = {}) {
    state.selectedAlbumId = album.id;
    let tracks = [];
    if (window.appBoy?.albumTracks) {
      tracks = await window.appBoy.albumTracks(album.id);
    }

    let targetTab = app.activeTab();
    if (!targetTab || targetTab.sourceKind === "favorites" || targetTab.sourceKind === "history") {
      targetTab = state.tabs.find((t) => t.sourceKind === "album") || null;
      if (!targetTab) {
        targetTab = {
          id: `tab-${Date.now()}`,
          title: album.title,
          consoleName: album.consoleName,
          sourceKind: "album",
          sourceId: album.id,
          selectedTrackId: tracks[0]?.id || null
        };
        state.tabs.push(targetTab);
      }
      state.activeTabId = targetTab.id;
    }

    targetTab.title = album.title;
    targetTab.consoleName = album.consoleName;
    targetTab.sourceKind = "album";
    targetTab.sourceId = album.id;
    targetTab.selectedTrackId = tracks[0]?.id || null;
    state.tabTracks.set(targetTab.id, tracks);

    state.contentMode = "playlist";
    if (isCompactViewport()) {
      state.mobilePane = "playlist";
    }

    renderLibraryTree();
    renderTabs();
    renderPlaylistRows();
    updateTitlebarAndStats();
    syncModeButtons();
    app.playback.renderTransportChrome();
    app.scheduleWorkspaceSave();

    if (autoPlay && tracks[0]) {
      await app.playback.startTrack(tracks[0], targetTab.id);
    }
  }

  async function openFavoritesTab() {
    const tracks = window.appBoy?.favoritesList ? await window.appBoy.favoritesList() : [];
    let favTab = state.tabs.find((t) => t.sourceKind === "favorites");
    if (!favTab) {
      favTab = {
        id: "tab-favorites",
        title: "Favorites",
        consoleName: "COLLECTION",
        sourceKind: "favorites",
        sourceId: null,
        selectedTrackId: tracks[0]?.id || null
      };
      state.tabs.push(favTab);
    }
    state.activeTabId = favTab.id;
    state.tabTracks.set(favTab.id, tracks);
    if (!favTab.selectedTrackId && tracks[0]) favTab.selectedTrackId = tracks[0].id;

    state.contentMode = "playlist";
    state.mobilePane = isCompactViewport() ? "favorites" : state.mobilePane;
    renderTabs();
    renderPlaylistRows();
    updateTitlebarAndStats();
    syncModeButtons();
    app.playback.renderTransportChrome();
    app.scheduleWorkspaceSave();
  }

  async function openRecentTab() {
    const tracks = window.appBoy?.historyList ? await window.appBoy.historyList() : [];
    let histTab = state.tabs.find((t) => t.sourceKind === "history");
    if (!histTab) {
      histTab = {
        id: "tab-history",
        title: "Recent",
        consoleName: "HISTORY",
        sourceKind: "history",
        sourceId: null,
        selectedTrackId: tracks[0]?.id || null
      };
      state.tabs.push(histTab);
    }
    state.activeTabId = histTab.id;
    state.tabTracks.set(histTab.id, tracks);
    if (!histTab.selectedTrackId && tracks[0]) histTab.selectedTrackId = tracks[0].id;

    state.contentMode = "playlist";
    state.mobilePane = isCompactViewport() ? "recent" : state.mobilePane;
    renderTabs();
    renderPlaylistRows();
    updateTitlebarAndStats();
    syncModeButtons();
    app.playback.renderTransportChrome();
    app.scheduleWorkspaceSave();
  }

  function createNewTab() {
    const current = app.activeTab();
    const currentTracks = app.activeTracks().slice();
    const id = `tab-${Date.now()}`;
    const newTab = {
      id,
      title: current ? `${current.title}` : "Playlist",
      consoleName: current?.consoleName || "SNES",
      sourceKind: current?.sourceKind === "album" ? "album" : "custom",
      sourceId: current?.sourceId || null,
      selectedTrackId: current?.selectedTrackId || currentTracks[0]?.id || null
    };
    state.tabs.push(newTab);
    state.tabTracks.set(id, currentTracks);
    state.activeTabId = id;
    state.contentMode = "playlist";
    renderTabs();
    renderPlaylistRows();
    updateTitlebarAndStats();
    syncModeButtons();
    app.scheduleWorkspaceSave();
  }

  function closeTab(tabId) {
    if (state.tabs.length <= 1) return;
    const idx = state.tabs.findIndex((t) => t.id === tabId);
    if (idx < 0) return;
    state.tabs.splice(idx, 1);
    state.tabTracks.delete(tabId);
    if (state.activeTabId === tabId) {
      const fallback = state.tabs[Math.max(0, idx - 1)] || state.tabs[0];
      state.activeTabId = fallback.id;
    }
    renderTabs();
    renderPlaylistRows();
    updateTitlebarAndStats();
    syncModeButtons();
    app.playback.renderTransportChrome();
    app.scheduleWorkspaceSave();
  }

  function renderTabs() {
    const fragment = document.createDocumentFragment();
    const canClose = state.tabs.length > 1;

    for (const tab of state.tabs) {
      const wrap = document.createElement("div");
      wrap.className = "playlist-tab";
      if (tab.id === state.activeTabId) wrap.classList.add("is-active");

      const selectBtn = document.createElement("button");
      selectBtn.type = "button";
      selectBtn.className = "playlist-tab-select";
      selectBtn.setAttribute("role", "tab");
      selectBtn.setAttribute("aria-selected", tab.id === state.activeTabId ? "true" : "false");
      selectBtn.textContent = tab.title;
      selectBtn.addEventListener("click", () => {
        state.activeTabId = tab.id;
        state.contentMode = "playlist";
        if (isCompactViewport()) {
          state.mobilePane = tab.sourceKind === "favorites"
            ? "favorites"
            : tab.sourceKind === "history"
              ? "recent"
              : "playlist";
        }
        renderTabs();
        renderPlaylistRows();
        updateTitlebarAndStats();
        syncModeButtons();
        app.playback.renderTransportChrome();
        app.scheduleWorkspaceSave();
      });
      wrap.appendChild(selectBtn);

      if (canClose) {
        const closeBtn = document.createElement("button");
        closeBtn.type = "button";
        closeBtn.className = "playlist-tab-close";
        closeBtn.setAttribute("aria-label", `Close ${tab.title}`);
        closeBtn.innerHTML = '<svg class="ui-icon" aria-hidden="true"><use href="#icon-xmark"></use></svg>';
        closeBtn.addEventListener("click", (ev) => {
          ev.stopPropagation();
          closeTab(tab.id);
        });
        wrap.appendChild(closeBtn);
      }

      fragment.appendChild(wrap);
    }
    refs.tabsContainer.replaceChildren(fragment);
  }

  function sortedTracksForDisplay(tracks) {
    if (!state.sortColumn) return tracks;
    const copy = tracks.slice();
    const dir = state.sortDirection === "desc" ? -1 : 1;
    copy.sort((a, b) => {
      if (state.sortColumn === "time") {
        return ((a.durationSeconds || 0) - (b.durationSeconds || 0)) * dir;
      }
      if (state.sortColumn === "album") {
        return String(a.albumTitle || "").localeCompare(String(b.albumTitle || "")) * dir;
      }
      return String(a.title || "").localeCompare(String(b.title || "")) * dir;
    });
    return copy;
  }

  function toggleSort(column) {
    if (state.sortColumn === column) {
      if (state.sortDirection === "asc") {
        state.sortDirection = "desc";
      } else {
        state.sortColumn = null;
        state.sortDirection = "asc";
      }
    } else {
      state.sortColumn = column;
      state.sortDirection = "asc";
    }
    refs.sortTitleBtn.classList.toggle("is-sorted", state.sortColumn === "title");
    refs.sortAlbumBtn.classList.toggle("is-sorted", state.sortColumn === "album");
    refs.sortTimeBtn.classList.toggle("is-sorted", state.sortColumn === "time");
    renderPlaylistRows();
  }

  async function toggleTrackFavorite(trackId) {
    if (window.appBoy?.favoritesToggle) {
      const res = await window.appBoy.favoritesToggle(trackId);
      state.favoriteIds = new Set(res.favoriteTrackIds || []);
    } else if (state.favoriteIds.has(trackId)) {
      state.favoriteIds.delete(trackId);
    } else {
      state.favoriteIds.add(trackId);
    }

    for (const tracks of state.tabTracks.values()) {
      for (const t of tracks) {
        if (t.id === trackId) t.isFavorite = state.favoriteIds.has(trackId);
      }
    }
    if (app.activeTab()?.sourceKind === "favorites" && window.appBoy?.favoritesList) {
      state.tabTracks.set(app.activeTab().id, await window.appBoy.favoritesList());
    }
    renderLibraryTree();
    renderPlaylistRows();
  }

  async function toggleAlbumFavorite(albumId) {
    if (window.appBoy?.favoritesAlbumToggle) {
      const res = await window.appBoy.favoritesAlbumToggle(albumId);
      state.favoriteIds = new Set(res.favoriteTrackIds || []);
    }
    for (const tracks of state.tabTracks.values()) {
      for (const t of tracks) {
        t.isFavorite = state.favoriteIds.has(t.id);
      }
    }
    if (app.activeTab()?.sourceKind === "favorites" && window.appBoy?.favoritesList) {
      state.tabTracks.set(app.activeTab().id, await window.appBoy.favoritesList());
    }
    renderLibraryTree();
    renderPlaylistRows();
  }

  function renderPlaylistRows() {
    const tab = app.activeTab();
    const rawTracks = app.activeTracks();
    const tracks = sortedTracksForDisplay(rawTracks);

    if (!tracks.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = tab?.sourceKind === "favorites"
        ? "No favorite tracks yet. Tap a star to add tracks."
        : tab?.sourceKind === "history"
          ? "No recently played tracks yet."
          : "Select an album in Library to load tracks.";
      refs.playlistBody.replaceChildren(empty);
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const track of tracks) {
      const row = document.createElement("div");
      row.className = "track-row";
      row.setAttribute("role", "listitem");
      const isSelected = tab?.selectedTrackId === track.id;
      const isPlaying = state.playback.trackId === track.id && state.playback.transportState !== "stopped";
      if (isSelected) row.classList.add("is-selected");
      if (isPlaying) row.classList.add("is-playing");

      const num = document.createElement("span");
      num.className = "track-num";
      num.textContent = String(track.trackNumber || 1).padStart(2, "0");

      const main = document.createElement("span");
      main.className = "track-main";
      const title = document.createElement("span");
      title.className = "track-title";
      title.textContent = track.title;
      const subMobile = document.createElement("span");
      subMobile.className = "track-sub-mobile";
      subMobile.textContent = `${track.artist} · ${track.albumTitle} [${track.format || track.consoleName}]`;
      main.append(title, subMobile);

      const albumCell = document.createElement("span");
      albumCell.className = "track-album split-only-col";
      albumCell.textContent = track.albumTitle;

      const sysCell = document.createElement("span");
      sysCell.className = "track-sys split-only-col";
      sysCell.textContent = track.format || track.consoleName;

      const isFav = state.favoriteIds.has(track.id) || Boolean(track.isFavorite);
      const favBtn = document.createElement("button");
      favBtn.type = "button";
      favBtn.className = "track-fav-button";
      if (isFav) favBtn.classList.add("is-favorite");
      favBtn.setAttribute("aria-label", `Favorite ${track.title}`);
      favBtn.innerHTML = '<svg class="ui-icon" aria-hidden="true"><use href="#icon-star"></use></svg>';
      favBtn.addEventListener("click", (ev) => {
        ev.stopPropagation();
        void toggleTrackFavorite(track.id);
      });

      const time = document.createElement("span");
      time.className = "track-time";
      time.textContent = app.formatTime(track.durationSeconds);

      row.append(num, main, albumCell, sysCell, favBtn, time);

      row.addEventListener("click", () => {
        const alreadySelected = tab?.selectedTrackId === track.id;
        if (tab) {
          tab.selectedTrackId = track.id;
          app.scheduleWorkspaceSave();
        }
        if (state.preferences.playlistLinkMode || alreadySelected) {
          void app.playback.startTrack(track, tab?.id);
        } else {
          renderPlaylistRows();
          app.playback.renderTransportChrome();
        }
      });

      fragment.appendChild(row);
    }
    refs.playlistBody.replaceChildren(fragment);
  }

  function renderGallery() {
    const groups = filteredConsoles();
    const albums = groups.flatMap((g) => g.albums);

    if (!albums.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "No album artwork matches the current filter.";
      refs.galleryGrid.replaceChildren(empty);
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const album of albums) {
      const cardBtn = document.createElement("button");
      cardBtn.type = "button";
      cardBtn.className = "gallery-card-button";
      if (state.selectedAlbumId === album.id) cardBtn.classList.add("is-selected");

      const frame = document.createElement("span");
      frame.className = "gallery-artwork-frame";
      const img = document.createElement("img");
      img.className = "gallery-artwork-image";
      img.alt = `${album.title} artwork`;
      img.src = album.artworkDataURL;
      frame.appendChild(img);

      const copy = document.createElement("span");
      const title = document.createElement("span");
      title.className = "gallery-card-title";
      title.textContent = album.title;
      const meta = document.createElement("span");
      meta.className = "gallery-card-meta";
      meta.textContent = `${album.consoleName} · ${album.year}`;
      copy.append(title, meta);

      cardBtn.append(frame, copy);
      cardBtn.addEventListener("click", () => {
        void openAlbumInPlaylist(album, { autoPlay: true });
      });
      fragment.appendChild(cardBtn);
    }
    refs.galleryGrid.replaceChildren(fragment);
  }

  function toggleAllConsoleGroups() {
    const consoles = state.catalog.consoles || [];
    const anyExpanded = consoles.some((c) => state.expandedConsoleIds.has(c.id));
    if (anyExpanded) {
      state.expandedConsoleIds.clear();
    } else {
      for (const c of consoles) state.expandedConsoleIds.add(c.id);
    }
    renderLibraryTree();
  }

  function setOptionsOpen(open) {
    state.optionsOpen = Boolean(open);
    refs.optionsOverlay.classList.toggle("is-open", state.optionsOpen);
    refs.optionsOverlay.setAttribute("aria-hidden", state.optionsOpen ? "false" : "true");
    refs.optionsBtn.setAttribute("aria-expanded", state.optionsOpen ? "true" : "false");
    refs.optionsBtn.classList.toggle("is-selected", state.optionsOpen);
    if (state.optionsOpen) {
      setVolumePopoverOpen(false);
      refs.indicator?.classList.add("is-hidden");
    } else {
      syncModeButtons();
    }
  }

  function setOptionsSection(sectionId) {
    state.optionsTab = sectionId;
    document.querySelectorAll("[data-options-tab]").forEach((btn) => {
      btn.classList.toggle("is-selected", btn.dataset.optionsTab === sectionId);
    });
    document.querySelectorAll("[data-options-page]").forEach((page) => {
      page.classList.toggle("is-hidden", page.dataset.optionsPage !== sectionId);
    });
  }

  function setVolumePopoverOpen(open) {
    state.volumePopoverOpen = Boolean(open);
    refs.volumePopover.hidden = !state.volumePopoverOpen;
    refs.volumeBtn.setAttribute("aria-expanded", state.volumePopoverOpen ? "true" : "false");
  }

  function renderAll() {
    app.applyPreferencesToDOM();
    app.syncOptionsInputsFromState();
    renderLibraryTree();
    renderTabs();
    renderPlaylistRows();
    renderGallery();
    updateTitlebarAndStats();
    syncModeButtons();
    app.playback.renderTransportChrome();
  }

  app.ui = {
    isCompactViewport,
    moveSelectionIndicator,
    refreshIndicatorPosition,
    setMobilePane,
    renderLibraryTree,
    openAlbumInPlaylist,
    openFavoritesTab,
    openRecentTab,
    createNewTab,
    closeTab,
    renderTabs,
    renderPlaylistRows,
    renderGallery,
    toggleSort,
    toggleAllConsoleGroups,
    setOptionsOpen,
    setOptionsSection,
    setVolumePopoverOpen,
    renderAll
  };
})();
