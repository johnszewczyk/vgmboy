(() => {
  function create({
    state,
    refs,
    COLUMN_DEFS,
    persistSettings,
    normalizeColumnOrder,
    valueForColumn,
    sortValue,
    compareSortValues = (left, right) => String(left).localeCompare(String(right)),
    getPlaylistRows,
    onRenderPlaylist,
    onColumnVisibilityChange = () => {}
  }) {
    let draggedColumnId = null;
    let columnMenu = null;
    let columnResizePointerId = null;
    let autoSizedPlaylistSignature = null;
    let textMeasureContext = null;
    const automaticallyHiddenColumnIds = new Set();
    let automaticVisibilitySignature = null;
    let columnResizeAnimationFrame = null;
    let columnResizeAnimationGeneration = 0;

    function allColumns() {
      return state.columnOrder
        .map((columnId) => COLUMN_DEFS.find((column) => column.id === columnId))
        .filter(Boolean);
    }

    function orderedColumns() {
      return allColumns().filter((column) => (
        state.columnVisibility[column.id] && !automaticallyHiddenColumnIds.has(column.id)
      ));
    }

    function isColumnVisible(column) {
      return Boolean(state.columnVisibility[column.id]) && !automaticallyHiddenColumnIds.has(column.id);
    }

    function columnWidthPercent(column) {
      if (!isColumnVisible(column)) return 0;
      const columns = orderedColumns();
      const total = columns.reduce((sum, candidate) => sum + Math.max(0, Number(state.columnWidths[candidate.id]) || 0), 0);
      if (total <= 0) return 100 / Math.max(1, columns.length);
      return (Math.max(0, Number(state.columnWidths[column.id]) || 0) / total) * 100;
    }

    function sortPlaylist() {
      const column = COLUMN_DEFS.find((candidate) => candidate.id === state.sortColumn) || COLUMN_DEFS.find((candidate) => candidate.id === "filename");
      const direction = state.sortDirection === "descending" ? -1 : 1;
      state.playlist.sort((left, right) => {
        const leftValue = sortValue(left, column, state.rootPath);
        const rightValue = sortValue(right, column, state.rootPath);
        const valueComparison = compareSortValues(leftValue, rightValue);
        if (valueComparison !== 0) return valueComparison * direction;
        return compareSortValues(String(left.id), String(right.id));
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
        checkbox.checked = state.columnVisibility[column.id] && !automaticallyHiddenColumnIds.has(column.id);
        checkbox.addEventListener("change", () => {
          automaticallyHiddenColumnIds.delete(column.id);
          state.columnVisibility[column.id] = checkbox.checked;
          if (!Object.values(state.columnVisibility).some(Boolean)) {
            state.columnVisibility[column.id] = true;
            checkbox.checked = true;
          }
          persistSettings();
          markAutoSized();
          closeColumnMenu();
          // Keep the existing cells alive so their width/opacity transitions
          // can run. Full content measurement belongs to playlist population
          // or an explicit header-seam auto-size action.
          syncWidths();
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

    function beginColumnResize(event, columnId) {
      event.preventDefault();
      event.stopPropagation();
      const startX = event.clientX;
      const table = refs.playlistHeaderRow.closest("table");
      const tableWidth = table?.getBoundingClientRect().width || 0;
      const handle = event.currentTarget;
      if (!Number.isFinite(tableWidth) || tableWidth <= 0) {
        return;
      }
      const resizedColumn = COLUMN_DEFS.find((column) => column.id === columnId);
      const startWidth = resizedColumn ? columnWidthPercent(resizedColumn) : state.columnWidths[columnId];
      const otherColumns = orderedColumns().filter((column) => column.id !== columnId);
      const startOtherWidths = new Map(otherColumns.map((column) => [column.id, columnWidthPercent(column)]));
      const startOtherTotal = otherColumns.reduce((sum, column) => sum + (startOtherWidths.get(column.id) || 0), 0);
      const pointerId = event.pointerId;
      columnResizePointerId = pointerId;
      const applyResizeWidths = (nextWidth) => {
        state.columnWidths[columnId] = nextWidth;
        if (!otherColumns.length) {
          syncWidths();
          return;
        }
        const targetOtherTotal = Math.max(4 * otherColumns.length, 100 - nextWidth);
        if (startOtherTotal > 0) {
          for (const column of otherColumns) {
            state.columnWidths[column.id] = Math.max(
              4,
              (startOtherWidths.get(column.id) || 0) * targetOtherTotal / startOtherTotal
            );
          }
        } else {
          const fallback = targetOtherTotal / otherColumns.length;
          for (const column of otherColumns) state.columnWidths[column.id] = fallback;
        }
        syncWidths();
      };
      const onMove = (moveEvent) => {
        if (moveEvent.pointerId !== pointerId) return;
        const nextWidth = Math.max(4, Math.min(80, startWidth + ((moveEvent.clientX - startX) / tableWidth) * 100));
        applyResizeWidths(nextWidth);
      };
      const finish = (finishEvent) => {
        if (finishEvent?.pointerId !== pointerId) return;
        document.removeEventListener("pointermove", onMove);
        document.removeEventListener("pointerup", onUp);
        document.removeEventListener("pointercancel", finish);
        handle?.releasePointerCapture?.(pointerId);
        columnResizePointerId = null;
        const draggedWidth = state.columnWidths[columnId];
        applyResizeWidths(draggedWidth);
        persistSettings();
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
      const visibilityChanged = refreshAutomaticVisibility({ force: true });
      if (visibilityChanged) {
        // Visibility changes alter row cell structure as well as the header.
        // Mark before rebuilding so the nested render does not auto-size again.
        markAutoSized();
        onRenderPlaylist({ sort: false });
      }
      const columns = orderedColumns();
      if (!columns.length || !state.playlist.length) return;
      const preferredWidths = columns.map((column) => columnContentWidth(column.id));
      const totalWidth = preferredWidths.reduce((sum, width) => sum + width, 0);
      if (!totalWidth) return;
      const table = refs.playlistHeaderTable;
      const availableWidth = refs.playlistScrollWrap?.clientWidth || table.clientWidth || totalWidth;
      const targetWidths = Object.fromEntries(columns.map((column, index) => [
        column.id,
        (preferredWidths[index] / totalWidth) * 100
      ]));
      animateColumnLayout(Math.max(availableWidth, totalWidth), targetWidths);
    }

    function isMeaningfulColumnValue(value) {
      const normalized = String(value ?? "").trim();
      return normalized.length > 0 && normalized !== "—";
    }

    function hasMeaningfulValue(column) {
      return state.playlist.some((track, rowIndex) => (
        isMeaningfulColumnValue(valueForColumn(track, column, rowIndex, state.rootPath))
      ));
    }

    function updateAutomaticColumnVisibility() {
      if (!state.playlist.length) return false;
      let changed = false;

      for (const column of allColumns()) {
        // The favorite affordance is structural rather than data-backed and
        // should remain available even when no metadata exists.
        if (column.id === "favorite" || state.columnVisibility[column.id] === false) {
          changed ||= automaticallyHiddenColumnIds.delete(column.id);
          continue;
        }

        if (hasMeaningfulValue(column)) {
          changed ||= automaticallyHiddenColumnIds.delete(column.id);
        } else if (!automaticallyHiddenColumnIds.has(column.id)) {
          automaticallyHiddenColumnIds.add(column.id);
          changed = true;
        }
      }
      return changed;
    }

    function refreshAutomaticVisibility({ force = false } = {}) {
      const signature = autoSizeSignature();
      if (!force && signature === automaticVisibilitySignature) return false;
      automaticVisibilitySignature = signature;
      const visibilityChanged = updateAutomaticColumnVisibility();
      if (visibilityChanged) onColumnVisibilityChange();
      return visibilityChanged;
    }

    function restoreAutomaticVisibility() {
      const changed = automaticallyHiddenColumnIds.size > 0;
      automaticallyHiddenColumnIds.clear();
      automaticVisibilitySignature = null;
      return changed;
    }

    function autoSizeColumn(columnId) {
      if (!state.playlist.length || !state.columnVisibility[columnId]) return;
      const columns = orderedColumns();
      const tableWidth = refs.playlistHeaderRow.closest("table").getBoundingClientRect().width;
      if (!Number.isFinite(tableWidth) || tableWidth <= 0) return;
      const nextWidth = Math.max(4, Math.min(80, (columnContentWidth(columnId) / tableWidth) * 100));
      const previousWidth = state.columnWidths[columnId];
      const targetWidths = { ...state.columnWidths };
      const otherColumns = columns.filter((column) => column.id !== columnId);
      const otherTotal = otherColumns.reduce((sum, column) => sum + (targetWidths[column.id] || 0), 0);
      const targetOtherTotal = Math.max(4 * otherColumns.length, 100 - nextWidth);
      targetWidths[columnId] = nextWidth;
      if (otherTotal > 0) {
        for (const column of otherColumns) {
          targetWidths[column.id] = Math.max(4, targetWidths[column.id] * targetOtherTotal / otherTotal);
        }
      } else {
        const fallback = targetOtherTotal / Math.max(1, otherColumns.length);
        for (const column of otherColumns) targetWidths[column.id] = fallback;
      }
      if (!Number.isFinite(previousWidth)) targetWidths[columnId] = nextWidth;
      animateColumnLayout(tableWidth, targetWidths);
    }

    function renderHeader() {
      refs.playlistHeaderRow.innerHTML = "";

      for (const column of allColumns()) {
        const th = document.createElement("th");
        th.dataset.columnId = column.id;
        th.draggable = true;
        th.className = column.className || "";
        th.classList.toggle("is-column-hidden", !isColumnVisible(column));
        th.style.width = `${columnWidthPercent(column)}%`;
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
        resizeHandle.addEventListener("pointerdown", (event) => beginColumnResize(event, column.id));
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
      const columns = allColumns();
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
      for (const column of allColumns()) {
        const header = refs.playlistHeaderRow.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
        if (header) {
          header.classList.toggle("is-column-hidden", !isColumnVisible(column));
          header.style.width = `${columnWidthPercent(column)}%`;
        }
      }
      for (const row of getPlaylistRows().values()) {
        for (const column of allColumns()) {
          const cell = row.querySelector(`[data-column-id="${CSS.escape(column.id)}"]`);
          if (cell) {
            cell.classList.toggle("is-column-hidden", !isColumnVisible(column));
            cell.style.width = `${columnWidthPercent(column)}%`;
          }
        }
      }
    }

    function setColumnResizeAnimationActive(active) {
      refs.playlistScrollWrap?.classList?.toggle?.("is-column-resizing", active);
    }

    function cancelColumnResizeAnimation() {
      columnResizeAnimationGeneration += 1;
      if (columnResizeAnimationFrame !== null) {
        window.cancelAnimationFrame?.(columnResizeAnimationFrame);
        columnResizeAnimationFrame = null;
      }
      setColumnResizeAnimationActive(false);
    }

    function applyColumnLayout(tableWidth, widths) {
      const width = `${Math.max(0, tableWidth)}px`;
      [refs.playlistHeaderTable, refs.playlistBodyTable].forEach((playlistTable) => {
        playlistTable.style.width = width;
        // Keep the percentage-based minimum. The actual table width is
        // interpolated separately so growth and shrink follow the same path.
        playlistTable.style.minWidth = "100%";
      });
      for (const column of allColumns()) {
        if (Object.hasOwn(widths, column.id)) state.columnWidths[column.id] = widths[column.id];
      }
      syncWidths();
    }

    function easeAnimationProgress(linearProgress) {
      const easing = window.SPCBoyFrontendAnimationContract?.easing || "easeInOut";
      if (easing !== "easeInOut") return linearProgress;
      return linearProgress < 0.5
        ? 2 * linearProgress * linearProgress
        : 1 - (Math.pow(-2 * linearProgress + 2, 2) / 2);
    }

    function animateColumnLayout(targetTableWidth, targetWidths) {
      cancelColumnResizeAnimation();

      const columns = orderedColumns();
      if (!columns.length) return;
      const measuredTable = refs.playlistHeaderTable?.getBoundingClientRect?.();
      const startTableWidth = Number(measuredTable?.width) || refs.playlistHeaderTable.clientWidth || targetTableWidth;
      const startWidths = Object.fromEntries(columns.map((column) => [column.id, columnWidthPercent(column)]));
      const duration = Number(state.autoResizeAnimationMilliseconds);
      const durationMilliseconds = Number.isFinite(duration) ? Math.max(0, Math.round(duration)) : 200;
      const requestFrame = window.requestAnimationFrame;

      if (durationMilliseconds === 0 || typeof requestFrame !== "function") {
        applyColumnLayout(targetTableWidth, targetWidths);
        persistSettings();
        return;
      }

      const animationGeneration = columnResizeAnimationGeneration;
      const startedAt = Number(window.performance?.now?.()) || 0;
      setColumnResizeAnimationActive(true);
      applyColumnLayout(startTableWidth, startWidths);

      const finish = () => {
        if (animationGeneration !== columnResizeAnimationGeneration) return;
        applyColumnLayout(targetTableWidth, targetWidths);
        setColumnResizeAnimationActive(false);
        columnResizeAnimationFrame = null;
        persistSettings();
      };

      const tick = (timestamp) => {
        if (animationGeneration !== columnResizeAnimationGeneration) return;
        const now = Number(timestamp);
        const elapsedMilliseconds = Math.max(0, (Number.isFinite(now) ? now : startedAt) - startedAt);
        const linearProgress = Math.min(1, elapsedMilliseconds / durationMilliseconds);
        const progress = easeAnimationProgress(linearProgress);
        const widths = Object.fromEntries(columns.map((column) => [
          column.id,
          startWidths[column.id] + ((targetWidths[column.id] - startWidths[column.id]) * progress)
        ]));
        applyColumnLayout(
          startTableWidth + ((targetTableWidth - startTableWidth) * progress),
          widths
        );
        if (linearProgress >= 1) {
          finish();
        } else {
          columnResizeAnimationFrame = requestFrame.call(window, tick);
        }
      };

      columnResizeAnimationFrame = requestFrame.call(window, tick);
    }

    function isResizing() {
      return columnResizePointerId !== null;
    }

    return Object.freeze({
      allColumns,
      orderedColumns,
      isColumnVisible: (columnId) => {
        const column = COLUMN_DEFS.find((candidate) => candidate.id === columnId);
        return column ? isColumnVisible(column) : false;
      },
      columnWidthPercent: (columnId) => {
        const column = COLUMN_DEFS.find((candidate) => candidate.id === columnId);
        return column ? columnWidthPercent(column) : 0;
      },
      sortPlaylist,
      renderHeader,
      autoSizeColumns,
      autoSizeColumn,
      autoSizeSignature,
      shouldAutoSize,
      markAutoSized,
      syncWidths,
      isResizing,
      refreshAutomaticVisibility,
      restoreAutomaticVisibility
    });
  }

  window.SPCBoyPlaylistColumns = Object.freeze({ create });
})();
