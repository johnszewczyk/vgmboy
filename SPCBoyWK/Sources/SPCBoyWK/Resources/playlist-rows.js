(() => {
  const PLAYLIST_VIRTUALIZATION_THRESHOLD = 200;
  const PLAYLIST_VIRTUAL_OVERSCAN = 12;

  function create({
    state,
    refs,
    columns,
    valueForColumn,
    persistSettings,
    isFavoritePresentation,
    toggleFavorites,
    renderSidebar,
    showContextMenu,
    playVisibleTrack,
    exportTrackAsAAC,
    updateTimingSummary,
    scheduleSelectionIndicators,
    onRenderPlaylist
  }) {
    const rowsByTrackId = new Map();
    let selectedPlaylistRow = null;
    let currentPlaylistRow = null;
    let playlistRenderGeneration = 0;
    let playlistVirtualRowHeight = 28;
    let playlistViewportFrame = 0;
    let playlistRowMeasurementFrame = 0;

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
      cell.colSpan = Math.max(1, columns.orderedColumns().length);
      cell.style.height = `${Math.max(0, Math.round(height))}px`;
      row.appendChild(cell);
      return row;
    }

    refs.playlistBodyWrap?.addEventListener("scroll", schedulePlaylistViewportRender, { passive: true });

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
          onRenderPlaylist();
        });
        td.appendChild(button);
      } else {
        td.textContent = String(valueForColumn(track, column, rowIndex, state.rootPath));
      }
      return td;
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

      for (const [id, row] of rowsByTrackId) updatePlaylistRowState(row, id);
      const nextRow = rowsByTrackId.get(track.id) || null;
      selectedPlaylistRow = nextRow;
      scheduleSelectionIndicators();
      if (focus) nextRow?.focus({ preventScroll: true });
      return track;
    }

    function refreshPlaylistPlaybackState() {
      for (const [id, row] of rowsByTrackId) updatePlaylistRowState(row, id);
      const nextSelectedRow = state.selectedTrackId ? rowsByTrackId.get(state.selectedTrackId) || null : null;
      selectedPlaylistRow = nextSelectedRow;

      currentPlaylistRow?.classList.remove("is-current");
      const nextCurrentRow = state.currentTrackId ? rowsByTrackId.get(state.currentTrackId) || null : null;
      nextCurrentRow?.classList.add("is-current");
      currentPlaylistRow = nextCurrentRow;
      scheduleSelectionIndicators();
    }

    function refreshPlaylistRow(trackId) {
      const track = state.playlist.find((entry) => entry.id === trackId);
      const rowIndex = state.playlist.findIndex((entry) => entry.id === trackId);
      const row = rowsByTrackId.get(trackId);
      if (!track || !row) return false;

      row.setAttribute("aria-label", `${track.title || track.filename || "Track"}`);
      for (const column of columns.orderedColumns()) {
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
          rowsByTrackId.set(track.id, row);
          if (state.selectedTrackId === track.id) selectedPlaylistRow = row;
          if (state.currentTrackId === track.id) currentPlaylistRow = row;

          for (const column of columns.orderedColumns()) {
            row.appendChild(renderPlaylistCell(track, column, rowIndex));
          }

          row.addEventListener("click", (event) => {
            selectPlaylistTrack(track.id, {
              focus: true,
              extend: event.metaKey || event.ctrlKey,
              range: event.shiftKey
            });
            updateTimingSummary();
          });

          row.addEventListener("dblclick", () => {
            playVisibleTrack(track.id, 0).catch((error) => {
              console.error(error);
            });
          });

          row.addEventListener("contextmenu", (event) => {
            showContextMenu(event, [["Export AAC", async () => {
              await exportTrackAsAAC(track);
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
      rowsByTrackId.clear();
      selectedPlaylistRow = null;
      currentPlaylistRow = null;
      if (sort) columns.sortPlaylist();
      const virtualized = playlistUsesVirtualRows();
      // Auto-sizing every cell defeats a catalog lookup. Large database playlists
      // retain the current widths; explicit column auto-size remains available.
      const playlistSignature = virtualized ? null : columns.autoSizeSignature();
      const shouldAutoSize = columns.shouldAutoSize(virtualized, playlistSignature);

      if (state.playlist.length === 0) {
        const row = document.createElement("tr");
        row.innerHTML = `<td colspan="${Math.max(1, columns.orderedColumns().length)}" class="empty-row"></td>`;
        refs.playlistBody.appendChild(row);
        scheduleSelectionIndicators();
        return;
      }

      if (shouldAutoSize) {
        columns.markAutoSized(playlistSignature);
        columns.autoSizeColumns();
        columns.renderHeader();
        columns.syncWidths();
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

    return Object.freeze({
      rows: () => rowsByTrackId,
      selectedRow: () => selectedPlaylistRow,
      playlistUsesVirtualRows,
      playlistVirtualRowHeight: () => playlistVirtualRowHeight,
      hasRow: (trackId) => rowsByTrackId.has(trackId),
      renderPlaylistCell,
      selectPlaylistTrack,
      refreshPlaylistPlaybackState,
      refreshPlaylistRow,
      playlistSortDependsOnMetadata,
      renderPlaylist
    });
  }

  window.SPCBoyPlaylistRows = Object.freeze({ create });
})();
