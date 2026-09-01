(() => {
function create({
  state,
  refs,
  sidebarNaturalCollator,
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
  databaseRowsToPlaylistTracks
}) {
  let renderedDatabaseGames = null;
  let databaseGameButtons = [];
  let databaseEmptyState = null;
  let databaseConsoleGroups = [];
  let selectedDatabaseGameButton = null;
  let databaseRowRenderGeneration = 0;
  let databaseGameClickTimer = 0;

  function invalidate() {
    renderedDatabaseGames = null;
    databaseGameButtons = [];
    databaseEmptyState = null;
    databaseConsoleGroups = [];
    selectedDatabaseGameButton = null;
    databaseRowRenderGeneration += 1;
  }

  function cancelPendingGameClick() {
    window.clearTimeout(databaseGameClickTimer);
    databaseGameClickTimer = 0;
  }

  function consoleNames() {
    return databaseConsoleGroups.map(({ consoleName }) => consoleName);
  }

  function groupedGamesByConsole(games) {
    const groupedGames = new Map();
    for (const game of games) {
      const consoleName = databaseConsoleName(game);
      const consoleGames = groupedGames.get(consoleName) || [];
      consoleGames.push(game);
      groupedGames.set(consoleName, consoleGames);
    }
    return groupedGames;
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
    const gamesForView = Array.isArray(state.databaseSearchGames) ? state.databaseSearchGames : state.databaseGames;
    if (renderedDatabaseGames !== gamesForView) {
      resetSidebarContent();
      selectedDatabaseGameButton = null;
      databaseConsoleGroups = [];
      const groupedGames = groupedGamesByConsole(gamesForView);
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

  return Object.freeze({
    cancelPendingGameClick,
    consoleNames,
    groupedGamesByConsole,
    invalidate,
    renderDatabaseGames
  });
}

window.SPCBoyDatabaseSidebar = Object.freeze({ create });
})();
