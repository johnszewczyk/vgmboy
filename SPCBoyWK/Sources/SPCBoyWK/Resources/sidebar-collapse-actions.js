(() => {
function create({
  state,
  collapsedDatabaseConsoles,
  expandedFolders,
  databaseConsoleNames,
  databaseGroupState,
  persistSettings,
  currentSidebarView,
  loadBrowserChildren,
  renderDatabaseGames,
  renderTree,
  syncTreeSelection,
  reportDatabaseSidebarError
}) {
  let databaseGroupTransitionGeneration = 0;

  function syncCollapsedConsolePersistence() {
    state.collapsedConsoleNames = [...collapsedDatabaseConsoles];
    persistSettings();
  }

  function databaseGroupStateSnapshot() {
    const knownGroupNames = databaseConsoleNames();
    return {
      expandedGroupNames: knownGroupNames.filter((name) => !collapsedDatabaseConsoles.has(name)),
      selectedGroupName: state.selectedDatabaseConsoleName || null,
      selectedGameID: state.selectedDatabaseGameKey || null,
      knownGroupNames
    };
  }

  async function applySharedDatabaseGroupAction(action, groupName = null, gameID = null, extra = {}) {
    const generation = ++databaseGroupTransitionGeneration;
    const next = await databaseGroupState(
      { ...databaseGroupStateSnapshot(), ...extra },
      action,
      groupName,
      gameID
    );
    if (generation !== databaseGroupTransitionGeneration || !next) return false;
    const expanded = new Set(Array.isArray(next.expandedGroupNames) ? next.expandedGroupNames : []);
    for (const knownName of databaseConsoleNames()) {
      if (expanded.has(knownName)) collapsedDatabaseConsoles.delete(knownName);
      else collapsedDatabaseConsoles.add(knownName);
    }
    state.selectedDatabaseConsoleName = next.selectedGroupName || null;
    state.selectedDatabaseGameKey = next.selectedGameID || null;
    syncCollapsedConsolePersistence();
    return true;
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

  return Object.freeze({
    applySharedDatabaseGroupAction,
    setAllDatabaseConsolesCollapsed,
    setAllSidebarNodesCollapsed
  });
}

window.SPCBoySidebarCollapseActions = Object.freeze({ create });
})();
