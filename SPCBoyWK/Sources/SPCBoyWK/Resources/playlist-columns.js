(() => {
  function create({
    state,
    refs,
    COLUMN_DEFS,
    persistSettings,
    normalizeColumnOrder,
    valueForColumn,
    sortValue,
    getPlaylistRows,
    onRenderPlaylist
  }) {
    let draggedColumnId = null;
    let columnMenu = null;
    let columnResizePointerId = null;
    let autoSizedPlaylistSignature = null;
    let textMeasureContext = null;

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
          markAutoSized();
          closeColumnMenu();
          renderHeader();
          onRenderPlaylist();
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
        for (const row of getPlaylistRows().values()) {
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
        renderHeader();
        syncWidths();
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
      renderHeader();
      syncWidths();
    }

    function renderHeader() {
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
          renderHeader();
          onRenderPlaylist();
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
          state.columnOrder = normalizeColumnOrder(nextOrder);
          persistSettings();
          renderHeader();
          onRenderPlaylist();
        });

        refs.playlistHeaderRow.appendChild(th);
      }
    }

    function autoSizeSignature() {
      const columns = orderedColumns();
      const firstID = state.playlist[0]?.id || "";
      const lastID = state.playlist.at(-1)?.id || "";
      return `${columns.map((column) => column.id).join("\u0001")}\u0002${state.playlist.length}\u0002${firstID}\u0002${lastID}`;
    }

    function shouldAutoSize(virtualized, signature) {
      return !virtualized && !isResizing() && state.columnAutoSize && signature !== autoSizedPlaylistSignature;
    }

    function markAutoSized(signature = autoSizeSignature()) {
      autoSizedPlaylistSignature = signature;
    }

    function syncWidths() {
      for (const column of orderedColumns()) {
        const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
        if (header) header.style.width = `${state.columnWidths[column.id]}%`;
      }
      for (const row of getPlaylistRows().values()) {
        for (const column of orderedColumns()) {
          const cell = row.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
          if (cell) cell.style.width = `${state.columnWidths[column.id]}%`;
        }
      }
    }

    function isResizing() {
      return columnResizePointerId !== null;
    }

    return Object.freeze({
      allColumns,
      orderedColumns,
      sortPlaylist,
      renderHeader,
      autoSizeColumns,
      autoSizeColumn,
      autoSizeSignature,
      shouldAutoSize,
      markAutoSized,
      syncWidths,
      isResizing
    });
  }

  window.SPCBoyPlaylistColumns = Object.freeze({ create });
})();
